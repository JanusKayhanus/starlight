#include "serverinfo.h"

#include "cfprefs.h"
#include "http.h"
#include "SDL_compat.h"
#include "xml.h"

#include <Limelight.h>

#include <cstdlib>
#include <string>
#include <vector>

#include <openssl/rand.h>

namespace {

// Saved by the Qt build's CompatFetcher from the Moonlight compatibility feed
constexpr const char* kLatestSupportedGfeVersionKey = "latestsupportedversion-v1";

std::string randomUuidHex()
{
    unsigned char bytes[16];
    RAND_bytes(bytes, sizeof(bytes));

    static const char k_Hex[] = "0123456789abcdef";
    std::string result;
    result.reserve(32);
    for (int i = 0; i < 16; i++) {
        result += k_Hex[bytes[i] >> 4];
        result += k_Hex[bytes[i] & 0xF];
    }
    return result;
}

bool endsWith(const std::string& value, const std::string& suffix)
{
    return value.size() >= suffix.size() &&
           value.compare(value.size() - suffix.size(), suffix.size(), suffix) == 0;
}

// Returns the XML status code of a response, or 200 if it has none.
int responseStatusCode(const std::string& xml)
{
    std::string statusCode = xmlAttribute(xml, "status_code");

    // Status code can be 0xFFFFFFFF in some rare cases on GFE 3.20.3,
    // so parse it as unsigned and cast the result to an int.
    return statusCode.empty() ? 200 : (int)strtoul(statusCode.c_str(), nullptr, 10);
}

bool verifyResponseStatus(const std::string& xml, std::string& error)
{
    int statusCode = responseStatusCode(xml);
    if (statusCode == 200) {
        return true;
    }

    error = "Host returned error " + std::to_string(statusCode) + ": " +
            xmlAttribute(xml, "status_message");
    return false;
}

// Splits a dotted version string, returning false if any part isn't a
// non-negative number.
bool parseVersion(const std::string& version, std::vector<int>& parts)
{
    parts.clear();
    size_t start = 0;
    for (;;) {
        size_t dot = version.find('.', start);
        std::string part = version.substr(start, dot == std::string::npos ? std::string::npos : dot - start);

        char* end = nullptr;
        long value = strtol(part.c_str(), &end, 10);
        if (part.empty() || *end != '\0' || value < 0) {
            return false;
        }
        parts.push_back((int)value);

        if (dot == std::string::npos) {
            return true;
        }
        start = dot + 1;
    }
}

// Port of the Qt build's CompatFetcher::isGfeVersionSupported(). This build
// doesn't fetch the compatibility feed itself, but uses the value the Qt
// build cached, if there is one.
bool isGfeVersionSupported(const std::string& gfeVersion)
{
    if (gfeVersion.find_first_not_of(" \t\r\n") == std::string::npos) {
        // If we don't have a GFE version, just allow it
        return true;
    }

    std::string latestSupportedVersion = CfPrefs::copyString(kLatestSupportedGfeVersionKey);
    if (latestSupportedVersion.empty()) {
        // We don't have compat data, so just assume it's supported
        return true;
    }

    std::vector<int> gfeVersionQuad;
    std::vector<int> latestSupportedVersionQuad;
    if (!parseVersion(gfeVersion, gfeVersionQuad) || gfeVersionQuad.size() <= 1) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Failed to parse GFE version: %s", gfeVersion.c_str());
        return true;
    }
    if (!parseVersion(latestSupportedVersion, latestSupportedVersionQuad) ||
            latestSupportedVersionQuad.size() <= 1) {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Failed to parse latest supported version: %s", latestSupportedVersion.c_str());
        return true;
    }

    for (size_t i = 0;; i++) {
        if (i >= gfeVersionQuad.size() && i >= latestSupportedVersionQuad.size()) {
            // Equal versions - this is fine
            return true;
        }

        // Treat missing decimal places as 0
        int actualVerVal = i < gfeVersionQuad.size() ? gfeVersionQuad[i] : 0;
        int latestSupportedVal = i < latestSupportedVersionQuad.size() ? latestSupportedVersionQuad[i] : 0;

        if (actualVerVal < latestSupportedVal) {
            // Actual version is lower than latest supported - this is fine
            return true;
        }
        else if (actualVerVal > latestSupportedVal) {
            // Actual version is greater than latest supported - this is bad
            SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                        "GFE version %s is not supported by this version of Moonlight",
                        gfeVersion.c_str());
            return false;
        }
    }
}

} // namespace

bool fetchServerInfo(HostConfig& host, const ClientConfig& client, std::string& error)
{
    std::string path = "/serverinfo?uniqueid=" + client.uniqueId + "&uuid=" + randomUuidHex();

    // Start over HTTP, which also tells us the HTTPS port.
    std::string response;
    if (!httpGet(host.address, host.httpPort, path, response, error) ||
            !verifyResponseStatus(response, error)) {
        return false;
    }

    int httpsPort = atoi(xmlTag(response, "HttpsPort").c_str());
    host.httpsPort = (uint16_t)(httpsPort > 0 && httpsPort <= 65535 ? httpsPort : 47984);

    // Once we have a pinned certificate, prefer HTTPS, since only HTTPS
    // properly reports the pairing status (and a few other attributes).
    // The host rejects an unpaired client with a 401, in which case we keep
    // the HTTP response, as the Qt build did.
    if (!host.serverCertPem.empty() && !client.certPem.empty() && !client.keyPem.empty()) {
        std::string httpsResponse;
        std::string httpsError;
        int httpStatusCode = 0;
        bool ok = httpsGet(host.address, host.httpsPort, path,
                           client.certPem, client.keyPem, host.serverCertPem,
                           httpsResponse, httpsError,
                           kDefaultHttpTimeoutSeconds, &httpStatusCode);
        if (ok && responseStatusCode(httpsResponse) == 200) {
            response = httpsResponse;
        }
        else if (httpStatusCode == 401 || (ok && responseStatusCode(httpsResponse) == 401)) {
            SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                        "Host rejected our client certificate; it no longer considers us paired");
        }
        else {
            if (!ok) {
                error = httpsError;
            }
            else {
                verifyResponseStatus(httpsResponse, error);
            }
            return false;
        }
    }

    host.appVersion = xmlTag(response, "appversion");
    if (host.appVersion.empty()) {
        error = "serverinfo did not include an app version";
        return false;
    }

    host.name = xmlTag(response, "hostname");
    if (host.name.empty()) {
        host.name = "UNKNOWN";
    }
    host.uuid = xmlTag(response, "uniqueid");

    std::string codecSupport = xmlTag(response, "ServerCodecModeSupport");
    if (!codecSupport.empty()) {
        host.serverCodecModeSupport = atoi(codecSupport.c_str());
    }
    else {
        // Assume H.264 is always supported
        host.serverCodecModeSupport = SCM_H264;
    }

    host.maxLumaPixelsHEVC = atoi(xmlTag(response, "MaxLumaPixelsHEVC").c_str());

    host.displayModes.clear();
    for (const std::string& modeXml : xmlTags(response, "DisplayMode")) {
        DisplayMode mode;
        mode.width = atoi(xmlTag(modeXml, "Width").c_str());
        mode.height = atoi(xmlTag(modeXml, "Height").c_str());
        if (mode.width != 0 && mode.height != 0) {
            host.displayModes.push_back(mode);
        }
    }

    std::string state = xmlTag(response, "state");

    // Real Nvidia host software (GeForce Experience and RTX Experience) both use the 'Mjolnir'
    // codename in the state field and no version of Sunshine does. We can use this to bypass
    // some assumptions about Nvidia hardware that don't apply to Sunshine hosts.
    host.isNvidiaServerSoftware = state.find("MJOLNIR") != std::string::npos;

    host.isPaired = xmlTag(response, "PairStatus") == "1";

    // GFE 2.8 started keeping currentgame set to the last game played. As a result, it no longer
    // has the semantics that its name would indicate. To contain the effects of this change as much
    // as possible, we'll force the current game to zero if the server isn't in a streaming session.
    host.currentGameId = endsWith(state, "_SERVER_BUSY") ?
                atoi(xmlTag(response, "currentgame").c_str()) : 0;

    host.gfeVersion = xmlTag(response, "GfeVersion");
    host.gpuModel = xmlTag(response, "gputype");
    host.isSupportedServerVersion = isGfeVersionSupported(host.gfeVersion);

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Host: %s (%s), app version: %s, GFE: %s, GPU: %s, codec modes: 0x%X, "
                "paired: %s, current game: %d",
                host.name.c_str(), host.address.c_str(),
                host.appVersion.c_str(), host.gfeVersion.c_str(), host.gpuModel.c_str(),
                host.serverCodecModeSupport, host.isPaired ? "yes" : "no",
                host.currentGameId);

    return true;
}
