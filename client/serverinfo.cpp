#include "serverinfo.h"

#include "http.h"
#include "SDL_compat.h"
#include "xml.h"

#include <cstdlib>
#include <string>

#include <openssl/rand.h>

namespace {

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

} // namespace

bool fetchServerInfo(HostConfig& host, const ClientConfig& client, std::string& error)
{
    std::string path = "/serverinfo?uniqueid=" + client.uniqueId + "&uuid=" + randomUuidHex();

    std::string response;
    if (!httpGet(host.address, host.httpPort, path, response, error)) {
        return false;
    }

    std::string statusCode = xmlAttribute(response, "status_code");
    if (!statusCode.empty() && statusCode != "200") {
        error = "Host returned error " + statusCode + ": " +
                xmlAttribute(response, "status_message");
        return false;
    }

    host.appVersion = xmlTag(response, "appversion");
    if (host.appVersion.empty()) {
        error = "serverinfo did not include an app version";
        return false;
    }

    host.gfeVersion = xmlTag(response, "GfeVersion");
    host.maxLumaPixelsHEVC = atoi(xmlTag(response, "MaxLumaPixelsHEVC").c_str());
    host.serverCodecModeSupport = atoi(xmlTag(response, "ServerCodecModeSupport").c_str());
    host.currentGameId = atoi(xmlTag(response, "currentgame").c_str());

    int httpsPort = atoi(xmlTag(response, "HttpsPort").c_str());
    host.httpsPort = (uint16_t)(httpsPort != 0 ? httpsPort : 47984);

    host.displayModes.clear();
    for (const std::string& modeXml : xmlTags(response, "DisplayMode")) {
        DisplayMode mode;
        mode.width = atoi(xmlTag(modeXml, "Width").c_str());
        mode.height = atoi(xmlTag(modeXml, "Height").c_str());
        if (mode.width != 0 && mode.height != 0) {
            host.displayModes.push_back(mode);
        }
    }

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                "Host: %s (%s), app version: %s, GFE: %s, codec modes: 0x%X, current game: %d",
                host.name.c_str(), host.address.c_str(),
                host.appVersion.c_str(), host.gfeVersion.c_str(),
                host.serverCodecModeSupport, host.currentGameId);

    return true;
}
