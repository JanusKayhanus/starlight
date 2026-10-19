#include "settings.h"

#include "cfprefs.h"

#include <cstdio>
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

bool savePairedHost(const HostConfig& host, std::string& error)
{
    int hostIndex = 0;

    // Update an existing entry for this host if we have one (matching on the
    // host's UUID first, then on its local address).
    for (int i = 1; i <= 32 && hostIndex == 0; i++) {
        std::string uuid = CfPrefs::copyString(keyForHost(i, "uuid"));
        std::string address = CfPrefs::copyString(keyForHost(i, "localaddress"));
        bool matchesUuid = !host.uuid.empty() && uuid == host.uuid;
        bool matchesAddress = !host.address.empty() && address == host.address;
        if (matchesUuid || matchesAddress) {
            hostIndex = i;
        }
    }

    // Otherwise use the first free slot.
    for (int i = 1; i <= 32 && hostIndex == 0; i++) {
        if (CfPrefs::copyString(keyForHost(i, "hostname")).empty() &&
            CfPrefs::copyString(keyForHost(i, "localaddress")).empty()) {
            hostIndex = i;
        }
    }

    if (hostIndex == 0) {
        error = "No free host slot is available in Moonlight's preferences";
        return false;
    }

    CfPrefs::setString(keyForHost(hostIndex, "hostname"), host.name);
    CfPrefs::setString(keyForHost(hostIndex, "localaddress"), host.address);
    CfPrefs::setInt(keyForHost(hostIndex, "localport"), host.httpPort);
    CfPrefs::setString(keyForHost(hostIndex, "uuid"), host.uuid);
    CfPrefs::setData(keyForHost(hostIndex, "srvcert"), host.serverCertPem);
    CfPrefs::setBool(keyForHost(hostIndex, "nvidiasw"), host.isNvidiaServerSoftware);

    fprintf(stderr, "Saved paired host '%s' (%s) to preference slot %d\n",
            host.name.c_str(), host.address.c_str(), hostIndex);
    return true;
}
