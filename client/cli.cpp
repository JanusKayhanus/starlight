#include "cli.h"

#include "hostrequests.h"
#include "identity.h"
#include "pairing.h"
#include "serverinfo.h"
#include "settings.h"
#include "wol.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

namespace {

void printUsage()
{
    printf(
        "Usage: Moonlight [options]\n"
        "       Moonlight hosts\n"
        "       Moonlight apps [--host <host>]\n"
        "       Moonlight wake [--host <host>]\n"
        "       Moonlight quit [--host <host>]\n"
        "       Moonlight pair <host> [--pin <PIN>]\n"
        "\n"
        "Streams an app from a saved host, using the saved Moonlight\n"
        "preferences as defaults. Without --host, streams from the host last\n"
        "chosen in Moonlight; without --app, streams Desktop.\n"
        "\n"
        "  hosts   List the saved hosts\n"
        "  apps    List a host's apps (refreshing the saved list if it's online)\n"
        "  wake    Send a Wake-on-LAN packet to a host\n"
        "  quit    Quit the app a host is running\n"
        "  pair    Pair with a new host\n"
        "\n"
        "Options:\n"
        "  --host <host>                    Host name, address or UUID\n"
        "  --app <app>                      App name or ID (see `Moonlight apps`)\n"
        "  --720 | --1080 | --1440 | --4K   Select a standard resolution\n"
        "  --resolution <width>x<height>    Select a custom resolution\n"
        "  --fps <fps>                      Stream frame rate (10-480)\n"
        "  --bitrate <kbps>                 Video bitrate in Kbps (500-500000)\n"
        "  --hdr / --no-hdr                 Enable or disable HDR streaming\n"
        "  --yuv444 / --no-yuv444           Enable or disable YUV 4:4:4\n"
        "  --video-codec <codec>            auto, h264, hevc, or av1\n"
        "  --display-mode <mode>            fullscreen, borderless, or windowed\n"
        "  --display <index>                Start the stream on this display\n"
        "  --help                           Show this help\n");
}

bool parseResolution(const std::string& value, int& width, int& height)
{
    size_t x = value.find('x');
    if (x == std::string::npos) {
        x = value.find('X');
    }
    if (x == std::string::npos) {
        return false;
    }

    width = atoi(value.substr(0, x).c_str());
    height = atoi(value.substr(x + 1).c_str());
    return width > 0 && height > 0;
}

bool inRange(int value, int min, int max)
{
    return value >= min && value <= max;
}

} // namespace

bool applyCommandLineOverrides(int argc, char** argv,
                               StreamingPreferences* preferences,
                               StreamTarget& target,
                               bool& shouldExit,
                               std::string& error)
{
    bool displaySet = false;
    bool bitrateSet = false;

    shouldExit = false;

    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];

        auto nextValue = [&](const char* name) -> std::string {
            if (i + 1 >= argc) {
                error = std::string("Missing value for ") + name;
                return {};
            }
            return argv[++i];
        };

        if (arg == "--help" || arg == "-h") {
            printUsage();
            shouldExit = true;
            return true;
        }
        else if (arg == "--host") {
            target.host = nextValue("--host");
            if (target.host.empty()) {
                return false;
            }
        }
        else if (arg == "--app") {
            target.app = nextValue("--app");
            if (target.app.empty()) {
                return false;
            }
        }
        else if (arg == "--720") {
            preferences->width = 1280;
            preferences->height = 720;
            displaySet = true;
        }
        else if (arg == "--1080") {
            preferences->width = 1920;
            preferences->height = 1080;
            displaySet = true;
        }
        else if (arg == "--1440") {
            preferences->width = 2560;
            preferences->height = 1440;
            displaySet = true;
        }
        else if (arg == "--4K") {
            preferences->width = 3840;
            preferences->height = 2160;
            displaySet = true;
        }
        else if (arg == "--resolution") {
            std::string value = nextValue("--resolution");
            if (value.empty()) {
                return false;
            }

            if (!parseResolution(value, preferences->width, preferences->height) ||
                    !inRange(preferences->width, 1, 7680) ||
                    !inRange(preferences->height, 1, 7680)) {
                error = "Invalid resolution: " + value;
                return false;
            }
            displaySet = true;
        }
        else if (arg == "--fps") {
            std::string value = nextValue("--fps");
            if (value.empty()) {
                return false;
            }

            int fps = atoi(value.c_str());
            if (!inRange(fps, 10, 480)) {
                error = "FPS must be between 10 and 480";
                return false;
            }
            preferences->fps = fps;
            displaySet = true;
        }
        else if (arg == "--bitrate") {
            std::string value = nextValue("--bitrate");
            if (value.empty()) {
                return false;
            }

            int bitrate = atoi(value.c_str());
            if (!inRange(bitrate, 500, 500000)) {
                error = "Bitrate must be between 500 and 500000 Kbps";
                return false;
            }
            preferences->bitrateKbps = bitrate;
            bitrateSet = true;
        }
        else if (arg == "--hdr") {
            preferences->enableHdr = true;
        }
        else if (arg == "--no-hdr") {
            preferences->enableHdr = false;
        }
        else if (arg == "--yuv444") {
            preferences->enableYUV444 = true;
        }
        else if (arg == "--no-yuv444") {
            preferences->enableYUV444 = false;
        }
        else if (arg == "--video-codec") {
            std::string value = nextValue("--video-codec");
            if (value.empty()) {
                return false;
            }

            if (value == "auto") {
                preferences->videoCodecConfig = StreamingPreferences::VCC_AUTO;
            }
            else if (value == "h264") {
                preferences->videoCodecConfig = StreamingPreferences::VCC_FORCE_H264;
            }
            else if (value == "hevc") {
                preferences->videoCodecConfig = StreamingPreferences::VCC_FORCE_HEVC;
            }
            else if (value == "av1") {
                preferences->videoCodecConfig = StreamingPreferences::VCC_FORCE_AV1;
            }
            else {
                error = "Invalid video codec: " + value;
                return false;
            }
        }
        else if (arg == "--display") {
            std::string value = nextValue("--display");
            if (value.empty()) {
                return false;
            }

            int display = atoi(value.c_str());
            if (display < 0) {
                error = "Display index must be zero or greater";
                return false;
            }
            preferences->startDisplay = display;
        }
        else if (arg == "--display-mode") {
            std::string value = nextValue("--display-mode");
            if (value.empty()) {
                return false;
            }

            if (value == "fullscreen") {
                preferences->windowMode = StreamingPreferences::WM_FULLSCREEN;
            }
            else if (value == "borderless") {
                preferences->windowMode = StreamingPreferences::WM_FULLSCREEN_DESKTOP;
            }
            else if (value == "windowed") {
                preferences->windowMode = StreamingPreferences::WM_WINDOWED;
            }
            else {
                error = "Invalid display mode: " + value;
                return false;
            }
        }
        else {
            error = "Unknown option: " + arg;
            return false;
        }
    }

    // Match the original client: when the display mode or frame rate changes
    // but the bitrate wasn't explicitly chosen, recompute the default bitrate.
    if (!bitrateSet && displaySet) {
        preferences->bitrateKbps = StreamingPreferences::getDefaultBitrate(
            preferences->width, preferences->height, preferences->fps,
            preferences->enableYUV444);
    }

    return true;
}

namespace {

bool isValidPin(const std::string& pin)
{
    if (pin.size() != 4) {
        return false;
    }
    return pin.find_first_not_of("0123456789") == std::string::npos;
}

void printPairUsage()
{
    fprintf(stderr,
            "Usage: Moonlight pair <host> [--pin <4-digit PIN>]\n"
            "\n"
            "Pairs with the given host (hostname or IP address). Moonlight prints\n"
            "a PIN, which you then enter on the host (in Sunshine, under the\n"
            "PIN tab of its web UI). Use --pin to choose the PIN yourself.\n");
}

} // namespace

bool handlePairCommandIfPresent(int argc, char** argv, int& exitCode)
{
    if (argc < 2 || std::string(argv[1]) != "pair") {
        return false;
    }

    std::string host;
    std::string pin;

    for (int i = 2; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--pin") {
            if (i + 1 >= argc) {
                fprintf(stderr, "Missing value for --pin\n");
                exitCode = 1;
                return true;
            }
            pin = argv[++i];
        }
        else if (arg == "--help" || arg == "-h") {
            printPairUsage();
            exitCode = 0;
            return true;
        }
        else if (!arg.empty() && arg[0] == '-') {
            fprintf(stderr, "Unknown option: %s\n", arg.c_str());
            exitCode = 1;
            return true;
        }
        else if (host.empty()) {
            host = arg;
        }
        else {
            fprintf(stderr, "Unexpected argument: %s\n", arg.c_str());
            exitCode = 1;
            return true;
        }
    }

    if (host.empty()) {
        printPairUsage();
        exitCode = 1;
        return true;
    }

    // The client chooses the PIN and the user enters it on the host, as in the
    // Qt build. The host never displays a PIN of its own.
    if (pin.empty()) {
        char buffer[5];
        snprintf(buffer, sizeof(buffer), "%04u", arc4random_uniform(10000));
        pin = buffer;
    }

    if (!isValidPin(pin)) {
        fprintf(stderr, "The PIN must be 4 digits\n");
        exitCode = 1;
        return true;
    }

    ClientConfig client;
    client.uniqueId = Identity::getUniqueId();
    client.certPem = Identity::getCertificate();
    client.keyPem = Identity::getPrivateKey();
    if (client.certPem.empty() || client.keyPem.empty()) {
        fprintf(stderr, "Unable to load or create the client identity\n");
        exitCode = 1;
        return true;
    }

    HostConfig hostConfig;
    hostConfig.address = host;
    hostConfig.httpPort = 47989;
    hostConfig.httpsPort = 47984;

    std::string error;
    if (!fetchServerInfo(hostConfig, client, error)) {
        fprintf(stderr, "Unable to reach %s: %s\n", host.c_str(), error.c_str());
        exitCode = 1;
        return true;
    }

    fprintf(stderr, "Pairing with %s (%s, app version %s)...\n",
            hostConfig.name.c_str(), host.c_str(), hostConfig.appVersion.c_str());
    fprintf(stderr, "\n    Enter PIN %s on %s to finish pairing.\n\n",
            pin.c_str(), hostConfig.name.c_str());

    std::string serverCert;
    PairState state = pairHost(hostConfig.address, hostConfig.httpPort, hostConfig.httpsPort,
                               hostConfig.appVersion, client.uniqueId, pin, serverCert, error);
    switch (state) {
    case PairState::Paired:
        hostConfig.serverCertPem = serverCert;

        // Now that the host trusts us, it reports its MAC address (for
        // Wake-on-LAN) and its apps. Saving works without them.
        if (fetchServerInfo(hostConfig, client, error) && !fetchAppList(hostConfig, client, error)) {
            fprintf(stderr, "Unable to fetch the host's apps: %s\n", error.c_str());
        }

        if (!savePairedHost(hostConfig, error)) {
            fprintf(stderr, "Paired, but saving the host failed: %s\n", error.c_str());
            exitCode = 1;
            return true;
        }
        printf("Paired with %s (%s) successfully.\n", hostConfig.name.c_str(), hostConfig.address.c_str());
        exitCode = 0;
        return true;

    case PairState::PinWrong:
        fprintf(stderr, "Pairing failed: incorrect PIN\n");
        exitCode = 1;
        return true;

    case PairState::AlreadyInProgress:
        fprintf(stderr, "Pairing failed: %s\n", error.c_str());
        exitCode = 1;
        return true;

    case PairState::Failed:
    default:
        fprintf(stderr, "Pairing failed: %s\n", error.c_str());
        exitCode = 1;
        return true;
    }
}

namespace {

// Parses "<command> [--host <host>] [<host>]" for the host commands.
bool parseHostArgument(int argc, char** argv, std::string& host, int& exitCode)
{
    for (int i = 2; i < argc; i++) {
        std::string arg = argv[i];
        if (arg == "--host") {
            if (i + 1 >= argc) {
                fprintf(stderr, "Missing value for --host\n");
                exitCode = 1;
                return false;
            }
            host = argv[++i];
        }
        else if (arg == "--help" || arg == "-h") {
            printUsage();
            exitCode = 0;
            return false;
        }
        else if (!arg.empty() && arg[0] != '-' && host.empty()) {
            host = arg;
        }
        else {
            fprintf(stderr, "Unexpected argument: %s\n", arg.c_str());
            exitCode = 1;
            return false;
        }
    }
    return true;
}

std::string formatMac(const std::vector<uint8_t>& mac)
{
    if (mac.size() != 6) {
        return "unknown";
    }
    char buffer[18];
    snprintf(buffer, sizeof(buffer), "%02x:%02x:%02x:%02x:%02x:%02x",
             mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
    return buffer;
}

int listHosts()
{
    std::vector<HostConfig> hosts = loadSavedHosts();
    if (hosts.empty()) {
        printf("No saved hosts. Pair with one first: Moonlight pair <host>\n");
        return 0;
    }

    HostConfig defaultHost;
    std::string error;
    selectSavedHost(hosts, "", defaultHost, error);

    for (const HostConfig& host : hosts) {
        printf("%s%s\n", host.name.c_str(), host.uuid == defaultHost.uuid ? " (default)" : "");
        printf("  Address: %s:%u\n", host.address.c_str(), host.httpPort);
        printf("  UUID:    %s\n", host.uuid.c_str());
        printf("  MAC:     %s\n", formatMac(host.macAddress).c_str());
        printf("  Apps:    %zu saved\n", host.apps.size());
    }
    return 0;
}

int listApps(const std::string& query)
{
    std::string error;
    ClientConfig client;
    HostConfig host;
    if (!loadClientIdentity(client, error) ||
            !selectSavedHost(loadSavedHosts(), query, host, error)) {
        fprintf(stderr, "%s\n", error.c_str());
        return 1;
    }

    // Refresh the list if the host is reachable; otherwise show the saved one.
    bool online = fetchServerInfo(host, client, error);
    if (online && host.isPaired && fetchAppList(host, client, error)) {
        saveHostDetails(host);
    }
    else {
        fprintf(stderr, "Unable to get %s's current apps (%s); showing the saved list.\n",
                host.name.c_str(), !online ? error.c_str() :
                                    !host.isPaired ? "this client isn't paired with it" : error.c_str());
    }

    if (host.apps.empty()) {
        printf("No apps are known for %s.\n", host.name.c_str());
        return 0;
    }

    for (const HostApp& app : host.apps) {
        printf("%10d  %s%s%s\n", app.id, app.name.c_str(),
               app.hdrSupported ? "  [HDR]" : "",
               online && app.id == host.currentGameId ? "  (running)" : "");
    }
    return 0;
}

int wakeHost(const std::string& query)
{
    std::string error;
    HostConfig host;
    if (!selectSavedHost(loadSavedHosts(), query, host, error) ||
            !sendWakeOnLan(host, error)) {
        fprintf(stderr, "%s\n", error.c_str());
        return 1;
    }
    printf("Sent Wake-on-LAN packets to %s (%s).\n", host.name.c_str(), formatMac(host.macAddress).c_str());
    return 0;
}

int quitApp(const std::string& query)
{
    std::string error;
    ClientConfig client;
    HostConfig host;
    if (!loadClientIdentity(client, error) ||
            !selectSavedHost(loadSavedHosts(), query, host, error) ||
            !fetchServerInfo(host, client, error)) {
        fprintf(stderr, "%s\n", error.c_str());
        return 1;
    }

    if (host.currentGameId == 0) {
        printf("%s isn't running an app.\n", host.name.c_str());
        return 0;
    }

    if (!quitRunningApp(host, client, error)) {
        fprintf(stderr, "%s\n", error.c_str());
        return 1;
    }
    printf("Quit the running app on %s.\n", host.name.c_str());
    return 0;
}

} // namespace

bool handleHostCommandIfPresent(int argc, char** argv, int& exitCode)
{
    if (argc < 2) {
        return false;
    }

    std::string command = argv[1];
    if (command != "hosts" && command != "apps" && command != "wake" && command != "quit") {
        return false;
    }

    std::string host;
    if (!parseHostArgument(argc, argv, host, exitCode)) {
        return true;
    }

    if (command == "hosts") {
        exitCode = listHosts();
    }
    else if (command == "apps") {
        exitCode = listApps(host);
    }
    else if (command == "wake") {
        exitCode = wakeHost(host);
    }
    else {
        exitCode = quitApp(host);
    }
    return true;
}
