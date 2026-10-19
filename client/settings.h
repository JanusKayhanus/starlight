#pragma once

#include <cstdint>
#include <string>
#include <vector>

constexpr uint16_t kDefaultHttpPort = 47989;
constexpr uint16_t kDefaultHttpsPort = 47984;
constexpr int kDesktopAppId = 881448767;

struct DisplayMode {
    int width = 0;
    int height = 0;
};

// An app the host publishes in its /applist, such as "Desktop".
struct HostApp {
    int id = 0;
    std::string name;
    bool hdrSupported = false;
    bool isAppCollectorGame = false;

    // Set by the Qt build's UI and kept when the app list is refreshed.
    bool hidden = false;
    bool directLaunch = false;
};

struct HostConfig {
    std::string name;
    std::string address;
    uint16_t httpPort = kDefaultHttpPort;
    uint16_t httpsPort = kDefaultHttpsPort;
    std::string uuid;
    std::string serverCertPem;

    // The host's MAC address (6 bytes), for Wake-on-LAN. Empty if unknown.
    std::vector<uint8_t> macAddress;

    // Other addresses the host was reached at, also tried by Wake-on-LAN.
    // Empty if unknown.
    std::string remoteAddress;
    uint16_t remotePort = kDefaultHttpPort;
    std::string manualAddress;
    uint16_t manualPort = kDefaultHttpPort;
    std::string ipv6Address;
    uint16_t ipv6Port = kDefaultHttpPort;

    // The host's apps, sorted by name: saved ones until fetchAppList()
    // replaces them.
    std::vector<HostApp> apps;

    // The host's slot in the saved preferences (hosts.N), or 0 if it isn't saved.
    int savedIndex = 0;

    // Populated from the host's serverinfo response
    std::string appVersion;
    std::string gfeVersion;
    std::string gpuModel;
    bool isPaired = false;
    int serverCodecModeSupport = 0;
    int maxLumaPixelsHEVC = 0;
    int currentGameId = 0;
    bool isNvidiaServerSoftware = false;
    bool isSupportedServerVersion = true;
    std::vector<DisplayMode> displayModes;

    // The app to stream; see selectApp().
    int appId = kDesktopAppId;
    std::string appName = "Desktop";
    bool appIsAppCollectorGame = false;
};

struct ClientConfig {
    std::string uniqueId;
    std::string certPem;
    std::string keyPem;
};

// Reads this client's identity (unique ID, certificate and key) from
// Moonlight's saved preferences.
bool loadClientIdentity(ClientConfig& client, std::string& error);

// Every host saved in Moonlight's preferences (the Qt build's hosts.N.*
// slots), including its saved app list, in slot order.
std::vector<HostConfig> loadSavedHosts();

// Picks the host to stream from `hosts`. `query` matches a host's name
// (ignoring case), any of its addresses, or its UUID. An empty query picks the
// host last chosen in the launcher (see rememberLastHost()), or else the
// first saved host.
bool selectSavedHost(const std::vector<HostConfig>& hosts, const std::string& query,
                     HostConfig& host, std::string& error);

// Makes `host` the default for selectSavedHost(), as the Qt launcher did.
void rememberLastHost(const HostConfig& host);

// Sets the app to stream. `query` is an app ID or name (ignoring case); an
// empty query picks Desktop. A host with no known apps can only stream
// Desktop, under its well-known ID.
bool selectApp(HostConfig& host, const std::string& query, std::string& error);

// Saves what the host told us about itself (name, MAC address and app list)
// into its existing preference slot. Does nothing for an unsaved host.
void saveHostDetails(const HostConfig& host);

// Persists a freshly paired host (name, address, uuid and pinned certificate)
// into Moonlight's saved preferences, updating the existing entry if the host
// is already known or adding a new one otherwise.
bool savePairedHost(const HostConfig& host, std::string& error);
