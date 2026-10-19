#pragma once

#include <cstdint>
#include <string>
#include <vector>

struct DisplayMode {
    int width = 0;
    int height = 0;
};

struct HostConfig {
    std::string name;
    std::string address;
    uint16_t httpPort = 47989;
    uint16_t httpsPort = 47984;
    std::string uuid;
    std::string serverCertPem;

    // Populated from the host's serverinfo response
    std::string appVersion;
    std::string gfeVersion;
    int serverCodecModeSupport = 0;
    int maxLumaPixelsHEVC = 0;
    int currentGameId = 0;
    bool isNvidiaServerSoftware = false;
    bool isSupportedServerVersion = true;
    std::vector<DisplayMode> displayModes;

    int appId = 881448767;
    std::string appName = "Desktop";
    bool appIsAppCollectorGame = false;
};

struct ClientConfig {
    std::string uniqueId;
    std::string certPem;
    std::string keyPem;
};

// Reads the already-paired host and client identity from Moonlight's saved
// preferences. The app intentionally has no settings or pairing UI.
bool loadMoonlightSettings(HostConfig& host, ClientConfig& client, std::string& error);

// Persists a freshly paired host (name, address, uuid and pinned certificate)
// into Moonlight's saved preferences, updating the existing entry if the host
// is already known or adding a new one otherwise.
bool savePairedHost(const HostConfig& host, std::string& error);
