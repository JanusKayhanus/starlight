#include "settings.h"

#include "cfprefs.h"

#include <algorithm>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <sstream>

namespace {

// The Qt build's QSettings arrays: "hosts.size" and "hosts.N.*" with N
// starting at 1, and the same for each host's "apps".
constexpr int kMaxHostSlots = 32;
constexpr const char* kLastHostUuidKey = "launcher.lastHostUuid";

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

const char* const kAppKeys[] = { "name", "id", "hdr", "appcollector", "hidden", "directlaunch" };

std::string lowercase(std::string value)
{
    std::transform(value.begin(), value.end(), value.begin(),
                   [](unsigned char c) { return (char)std::tolower(c); });
    return value;
}

void sortApps(std::vector<HostApp>& apps)
{
    std::stable_sort(apps.begin(), apps.end(), [](const HostApp& a, const HostApp& b) {
        return lowercase(a.name) < lowercase(b.name);
    });
}

uint16_t copyPort(const std::string& key)
{
    int port = CfPrefs::copyInt(key, kDefaultHttpPort);
    return (uint16_t)(port > 0 && port <= 65535 ? port : kDefaultHttpPort);
}

// The number of saved host slots. Older preferences may lack "hosts.size",
// so fall back to the highest slot in use.
int savedHostCount()
{
    int count = CfPrefs::copyInt("hosts.size", 0);
    if (count > 0) {
        return std::min(count, kMaxHostSlots);
    }

    for (int i = kMaxHostSlots; i >= 1; i--) {
        if (!CfPrefs::copyString(keyForHost(i, "hostname")).empty() ||
            !CfPrefs::copyString(keyForHost(i, "localaddress")).empty()) {
            return i;
        }
    }
    return 0;
}

std::vector<HostApp> loadSavedApps(int hostIndex)
{
    std::vector<HostApp> apps;
    int count = CfPrefs::copyInt(keyForHost(hostIndex, "apps.size"), 0);
    for (int i = 1; i <= count; i++) {
        HostApp app;
        app.id = CfPrefs::copyInt(keyForApp(hostIndex, i, "id"), 0);
        app.name = CfPrefs::copyString(keyForApp(hostIndex, i, "name"));
        app.hdrSupported = CfPrefs::copyBool(keyForApp(hostIndex, i, "hdr"), false);
        app.isAppCollectorGame = CfPrefs::copyBool(keyForApp(hostIndex, i, "appcollector"), false);
        app.hidden = CfPrefs::copyBool(keyForApp(hostIndex, i, "hidden"), false);
        app.directLaunch = CfPrefs::copyBool(keyForApp(hostIndex, i, "directlaunch"), false);
        if (app.id != 0) {
            apps.push_back(app);
        }
    }
    sortApps(apps);
    return apps;
}

void saveApps(int hostIndex, const std::vector<HostApp>& apps)
{
    int oldCount = CfPrefs::copyInt(keyForHost(hostIndex, "apps.size"), 0);

    for (size_t i = 0; i < apps.size(); i++) {
        int appIndex = (int)i + 1;
        const HostApp& app = apps[i];
        CfPrefs::setString(keyForApp(hostIndex, appIndex, "name"), app.name);
        CfPrefs::setInt(keyForApp(hostIndex, appIndex, "id"), app.id);
        CfPrefs::setBool(keyForApp(hostIndex, appIndex, "hdr"), app.hdrSupported);
        CfPrefs::setBool(keyForApp(hostIndex, appIndex, "appcollector"), app.isAppCollectorGame);
        CfPrefs::setBool(keyForApp(hostIndex, appIndex, "hidden"), app.hidden);
        CfPrefs::setBool(keyForApp(hostIndex, appIndex, "directlaunch"), app.directLaunch);
    }

    // Drop slots left over from a longer list.
    for (int appIndex = (int)apps.size() + 1; appIndex <= oldCount; appIndex++) {
        for (const char* key : kAppKeys) {
            CfPrefs::remove(keyForApp(hostIndex, appIndex, key));
        }
    }

    CfPrefs::setInt(keyForHost(hostIndex, "apps.size"), (int)apps.size());
}

bool hostMatches(const HostConfig& host, const std::string& query)
{
    std::string lowered = lowercase(query);
    return lowercase(host.name) == lowered ||
           lowercase(host.uuid) == lowered ||
           host.address == query ||
           host.remoteAddress == query ||
           host.manualAddress == query ||
           host.ipv6Address == query;
}

} // namespace

bool loadClientIdentity(ClientConfig& client, std::string& error)
{
    client.uniqueId = CfPrefs::copyString("uniqueid");
    client.certPem = CfPrefs::copyData("certificate");
    client.keyPem = CfPrefs::copyData("key");

    if (client.certPem.empty() || client.keyPem.empty()) {
        error = "Moonlight's client certificate/key were not found in preferences";
        return false;
    }

    if (client.uniqueId.empty()) {
        client.uniqueId = "0123456789ABCDEF";
    }

    return true;
}

std::vector<HostConfig> loadSavedHosts()
{
    std::vector<HostConfig> hosts;
    int count = savedHostCount();
    for (int i = 1; i <= count; i++) {
        HostConfig host;
        host.savedIndex = i;
        host.name = CfPrefs::copyString(keyForHost(i, "hostname"));
        host.address = CfPrefs::copyString(keyForHost(i, "localaddress"));
        host.httpPort = copyPort(keyForHost(i, "localport"));
        host.remoteAddress = CfPrefs::copyString(keyForHost(i, "remoteaddress"));
        host.remotePort = copyPort(keyForHost(i, "remoteport"));
        host.manualAddress = CfPrefs::copyString(keyForHost(i, "manualaddress"));
        host.manualPort = copyPort(keyForHost(i, "manualport"));
        host.ipv6Address = CfPrefs::copyString(keyForHost(i, "ipv6address"));
        host.ipv6Port = copyPort(keyForHost(i, "ipv6port"));
        host.uuid = CfPrefs::copyString(keyForHost(i, "uuid"));
        host.serverCertPem = CfPrefs::copyData(keyForHost(i, "srvcert"));
        host.isNvidiaServerSoftware = CfPrefs::copyBool(keyForHost(i, "nvidiasw"), false);
        host.apps = loadSavedApps(i);

        std::string mac = CfPrefs::copyData(keyForHost(i, "mac"));
        if (mac.size() == 6) {
            host.macAddress.assign(mac.begin(), mac.end());
        }

        // A host that only has a manual address is still usable through it.
        if (host.address.empty()) {
            if (!host.manualAddress.empty()) {
                host.address = host.manualAddress;
                host.httpPort = host.manualPort;
            }
            else if (!host.remoteAddress.empty()) {
                host.address = host.remoteAddress;
                host.httpPort = host.remotePort;
            }
        }

        if (!host.name.empty() || !host.address.empty()) {
            hosts.push_back(host);
        }
    }
    return hosts;
}

bool selectSavedHost(const std::vector<HostConfig>& hosts, const std::string& query,
                     HostConfig& host, std::string& error)
{
    if (hosts.empty()) {
        error = "No hosts are saved in Moonlight's preferences. Pair with one first: Moonlight pair <host>";
        return false;
    }

    const HostConfig* selected = nullptr;
    if (!query.empty()) {
        for (const HostConfig& candidate : hosts) {
            if (hostMatches(candidate, query)) {
                selected = &candidate;
                break;
            }
        }
        if (selected == nullptr) {
            error = "No saved host matches \"" + query + "\"";
            return false;
        }
    }
    else {
        std::string lastHostUuid = CfPrefs::copyString(kLastHostUuidKey);
        for (const HostConfig& candidate : hosts) {
            if (!lastHostUuid.empty() && candidate.uuid == lastHostUuid) {
                selected = &candidate;
                break;
            }
        }
        if (selected == nullptr) {
            selected = &hosts.front();
        }
    }

    if (selected->address.empty()) {
        error = "The host " + selected->name + " has no saved address";
        return false;
    }

    host = *selected;
    return true;
}

void rememberLastHost(const HostConfig& host)
{
    if (!host.uuid.empty()) {
        CfPrefs::setString(kLastHostUuidKey, host.uuid);
    }
}

bool selectApp(HostConfig& host, const std::string& query, std::string& error)
{
    const HostApp* selected = nullptr;

    if (query.empty()) {
        for (const HostApp& app : host.apps) {
            if (lowercase(app.name) == "desktop") {
                selected = &app;
                break;
            }
        }
        if (selected == nullptr) {
            // No app list, or no Desktop in it: use Desktop's well-known ID.
            host.appId = kDesktopAppId;
            host.appName = "Desktop";
            host.appIsAppCollectorGame = false;
            return true;
        }
    }
    else {
        char* end = nullptr;
        long id = strtol(query.c_str(), &end, 10);
        bool isNumber = *end == '\0';
        for (const HostApp& app : host.apps) {
            if ((isNumber && app.id == id) || lowercase(app.name) == lowercase(query)) {
                selected = &app;
                break;
            }
        }
        if (selected == nullptr) {
            error = "No app on " + host.name + " matches \"" + query + "\".";
            if (host.apps.empty()) {
                error += " The host didn't report any apps.";
            }
            else {
                error += " Available apps:";
                for (const HostApp& app : host.apps) {
                    error += "\n  " + app.name + " (" + std::to_string(app.id) + ")";
                }
            }
            return false;
        }
    }

    host.appId = selected->id;
    host.appName = selected->name;
    host.appIsAppCollectorGame = selected->isAppCollectorGame;
    return true;
}

void saveHostDetails(const HostConfig& host)
{
    int hostIndex = host.savedIndex;
    if (hostIndex <= 0) {
        return;
    }

    if (!host.name.empty()) {
        CfPrefs::setString(keyForHost(hostIndex, "hostname"), host.name);
    }
    if (host.macAddress.size() == 6) {
        CfPrefs::setData(keyForHost(hostIndex, "mac"),
                         std::string(host.macAddress.begin(), host.macAddress.end()));
    }

    // Like the Qt build, keep the saved list if the host didn't send one.
    if (!host.apps.empty()) {
        saveApps(hostIndex, host.apps);
    }
}

bool savePairedHost(const HostConfig& host, std::string& error)
{
    int hostIndex = 0;

    // Update an existing entry for this host if we have one (matching on the
    // host's UUID first, then on its local address).
    for (int i = 1; i <= kMaxHostSlots && hostIndex == 0; i++) {
        std::string uuid = CfPrefs::copyString(keyForHost(i, "uuid"));
        std::string address = CfPrefs::copyString(keyForHost(i, "localaddress"));
        bool matchesUuid = !host.uuid.empty() && uuid == host.uuid;
        bool matchesAddress = !host.address.empty() && address == host.address;
        if (matchesUuid || matchesAddress) {
            hostIndex = i;
        }
    }

    // Otherwise use the first free slot.
    for (int i = 1; i <= kMaxHostSlots && hostIndex == 0; i++) {
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

    // The Qt build reads only as many slots as "hosts.size" says.
    if (CfPrefs::copyInt("hosts.size", 0) < hostIndex) {
        CfPrefs::setInt("hosts.size", hostIndex);
    }

    HostConfig saved = host;
    saved.savedIndex = hostIndex;
    saveHostDetails(saved);

    fprintf(stderr, "Saved paired host '%s' (%s) to preference slot %d\n",
            host.name.c_str(), host.address.c_str(), hostIndex);
    return true;
}
