#pragma once

#include <cstdint>
#include <string>

struct HostConfig {
    std::string name;
    std::string address;
    uint16_t httpPort = 47989;
    std::string uuid;
    std::string serverCertPem;
    int appId = 881448767;
    std::string appName = "Desktop";
};

struct ClientConfig {
    std::string uniqueId;
    std::string certPem;
    std::string keyPem;
};

// Reads the already-paired host and client identity from Moonlight's saved
// preferences. The app intentionally has no settings or pairing UI.
bool loadMoonlightSettings(HostConfig& host, ClientConfig& client, std::string& error);
