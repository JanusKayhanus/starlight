#include "hostrequests.h"

#include "http.h"
#include "serverinfo.h"
#include "SDL_compat.h"
#include "xml.h"

#include <algorithm>
#include <cctype>
#include <cstdlib>

namespace {

constexpr int kQuitTimeoutSeconds = 30;

std::string lowercase(std::string value)
{
    std::transform(value.begin(), value.end(), value.begin(),
                   [](unsigned char c) { return (char)std::tolower(c); });
    return value;
}

bool requestXml(const HostConfig& host, const ClientConfig& client, const std::string& endpoint,
                int timeoutSeconds, const CancellationToken* cancel,
                std::string& response, std::string& error)
{
    std::string path = "/" + endpoint + "?" + clientRequestQuery(client);
    return httpsGet(host.address, host.httpsPort, path,
                    client.certPem, client.keyPem, host.serverCertPem,
                    response, error, timeoutSeconds, nullptr, cancel) &&
           verifyHostResponse(response, error);
}

} // namespace

bool fetchAppList(HostConfig& host, const ClientConfig& client, std::string& error,
                  const CancellationToken* cancel)
{
    std::string response;
    if (!requestXml(host, client, "applist", kDefaultHttpTimeoutSeconds, cancel, response, error)) {
        return false;
    }

    std::vector<HostApp> apps;
    for (const std::string& appXml : xmlTags(response, "App")) {
        HostApp app;
        // Sunshine sends <AppTitle/> for an app with no name, which leaves
        // the name empty. That's still a valid app.
        app.name = xmlUnescape(xmlTag(appXml, "AppTitle"));
        app.id = atoi(xmlTag(appXml, "ID").c_str());
        app.hdrSupported = xmlTag(appXml, "IsHdrSupported") == "1";
        app.isAppCollectorGame = xmlTag(appXml, "IsAppCollectorGame") == "1";

        if (app.id == 0) {
            error = "The host sent an invalid app list";
            return false;
        }

        // Keep what the user chose for apps we already knew.
        for (const HostApp& known : host.apps) {
            if (known.id == app.id) {
                app.hidden = known.hidden;
                app.directLaunch = known.directLaunch;
                break;
            }
        }

        apps.push_back(app);
    }

    std::stable_sort(apps.begin(), apps.end(), [](const HostApp& a, const HostApp& b) {
        return lowercase(a.name) < lowercase(b.name);
    });

    host.apps = apps;
    return true;
}

bool quitRunningApp(HostConfig& host, const ClientConfig& client, std::string& error,
                    const CancellationToken* cancel)
{
    std::string response;
    if (!requestXml(host, client, "cancel", kQuitTimeoutSeconds, cancel, response, error)) {
        return false;
    }

    SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Quit response: %s", response.c_str());

    if (!fetchServerInfo(host, client, error, cancel)) {
        return false;
    }
    if (host.currentGameId != 0) {
        error = "The app is still running on " + host.name + ". It may have been started by another client.";
        return false;
    }
    return true;
}
