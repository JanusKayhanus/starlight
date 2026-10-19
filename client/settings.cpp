#include "settings.h"

#include "cfprefs.h"

#include <cstdlib>
#include <sstream>

namespace {

constexpr const char* kTargetHostName = "DESKTOP-BUO46UK";
constexpr int kDesktopAppId = 881448767;

std::string keyForHost(int hostIndex, const char* suffix)
{
    std::ostringstream key;
    key << "hosts." << hostIndex << "." << suffix;
    return key.str();
}

std::string keyForApp(int hostIndex, int appIndex, const char* suffix)
{
    std::ostringstream key;
    key << "hosts." << hostIndex << ".apps." << appIndex << "." << suffix;
    return key.str();
}

} // namespace

bool loadMoonlightSettings(HostConfig& host, ClientConfig& client, std::string& error)
{
    client.uniqueId = CfPrefs::copyString("uniqueid");
    client.certPem = CfPrefs::copyData("certificate");
    client.keyPem = CfPrefs::copyData("key");

    if (client.certPem.empty() || client.keyPem.empty()) {
        error = "Moonlight's client certificate/key were not found in preferences";
        return false;
    }

    int selectedHost = 0;
    for (int i = 1; i <= 32; i++) {
        std::string hostname = CfPrefs::copyString(keyForHost(i, "hostname"));
        if (hostname == kTargetHostName) {
            selectedHost = i;
            break;
        }
    }

    // Fall back to any host that has a Desktop app if the exact host name changed.
    if (selectedHost == 0) {
        for (int i = 1; i <= 32 && selectedHost == 0; i++) {
            for (int app = 1; app <= 64; app++) {
                if (CfPrefs::copyString(keyForApp(i, app, "name")) == "Desktop") {
                    selectedHost = i;
                    break;
                }
            }
        }
    }

    if (selectedHost == 0) {
        error = "The host DESKTOP-BUO46UK was not found in Moonlight's preferences";
        return false;
    }

    host.name = CfPrefs::copyString(keyForHost(selectedHost, "hostname"));
    host.address = CfPrefs::copyString(keyForHost(selectedHost, "localaddress"));
    host.httpPort = (uint16_t)CfPrefs::copyInt(keyForHost(selectedHost, "localport"), 47989);
    host.uuid = CfPrefs::copyString(keyForHost(selectedHost, "uuid"));
    host.serverCertPem = CfPrefs::copyData(keyForHost(selectedHost, "srvcert"));
    host.isNvidiaServerSoftware = CfPrefs::copyBool(keyForHost(selectedHost, "nvidiasw"), false);
    host.appName = "Desktop";
    host.appId = kDesktopAppId;

    for (int app = 1; app <= 64; app++) {
        if (CfPrefs::copyString(keyForApp(selectedHost, app, "name")) == "Desktop") {
            int savedAppId = CfPrefs::copyInt(keyForApp(selectedHost, app, "id"), 0);
            if (savedAppId != 0) {
                host.appId = savedAppId;
            }
            host.appIsAppCollectorGame = CfPrefs::copyBool(keyForApp(selectedHost, app, "appcollector"), false);
            break;
        }
    }

    if (host.address.empty()) {
        error = "The selected host has no address";
        return false;
    }

    if (client.uniqueId.empty()) {
        client.uniqueId = "0123456789ABCDEF";
    }

    return true;
}
