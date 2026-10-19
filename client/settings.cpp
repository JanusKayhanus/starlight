#include "settings.h"

#include <CoreFoundation/CoreFoundation.h>

#include <cstdlib>
#include <sstream>
#include <vector>

namespace {

constexpr const char* kTargetHostName = "DESKTOP-BUO46UK";
constexpr int kDesktopAppId = 881448767;

std::string cfStringToStd(CFStringRef value)
{
    if (value == nullptr) {
        return {};
    }

    CFIndex length = CFStringGetLength(value);
    CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
    std::vector<char> buffer((size_t)maxSize);
    if (!CFStringGetCString(value, buffer.data(), maxSize, kCFStringEncodingUTF8)) {
        return {};
    }
    return std::string(buffer.data());
}

CFPropertyListRef copyPreference(const char* key)
{
    CFStringRef keyString = CFStringCreateWithCString(kCFAllocatorDefault, key,
                                                      kCFStringEncodingUTF8);
    if (keyString == nullptr) {
        return nullptr;
    }

    CFPropertyListRef value = CFPreferencesCopyAppValue(
        keyString, CFSTR("com.moonlight-stream.Moonlight"));
    CFRelease(keyString);
    return value;
}

std::string copyString(const char* key)
{
    CFPropertyListRef value = copyPreference(key);
    if (value == nullptr) {
        return {};
    }

    std::string result;
    if (CFGetTypeID(value) == CFStringGetTypeID()) {
        result = cfStringToStd((CFStringRef)value);
    }
    CFRelease(value);
    return result;
}

std::string copyData(const char* key)
{
    CFPropertyListRef value = copyPreference(key);
    if (value == nullptr) {
        return {};
    }

    std::string result;
    if (CFGetTypeID(value) == CFDataGetTypeID()) {
        CFDataRef data = (CFDataRef)value;
        result.assign((const char*)CFDataGetBytePtr(data), (size_t)CFDataGetLength(data));
    }
    CFRelease(value);
    return result;
}

int copyInt(const char* key, int defaultValue)
{
    std::string value = copyString(key);
    if (value.empty()) {
        return defaultValue;
    }
    return atoi(value.c_str());
}

std::string keyForHost(int hostIndex, const char* suffix)
{
    std::ostringstream key;
    key << "hosts." << hostIndex << "." << suffix;
    return key.str();
}

} // namespace

bool loadMoonlightSettings(HostConfig& host, ClientConfig& client, std::string& error)
{
    client.uniqueId = copyString("uniqueid");
    client.certPem = copyData("certificate");
    client.keyPem = copyData("key");

    if (client.certPem.empty() || client.keyPem.empty()) {
        error = "Moonlight's client certificate/key were not found in preferences";
        return false;
    }

    int selectedHost = 0;
    for (int i = 1; i <= 32; i++) {
        std::string key = keyForHost(i, "hostname");
        std::string hostname = copyString(key.c_str());
        if (hostname == kTargetHostName) {
            selectedHost = i;
            break;
        }
    }

    // Fall back to any host that has a Desktop app if the exact host name changed.
    if (selectedHost == 0) {
        for (int i = 1; i <= 32 && selectedHost == 0; i++) {
            for (int app = 1; app <= 64; app++) {
                std::ostringstream appNameKey;
                appNameKey << "hosts." << i << ".apps." << app << ".name";
                if (copyString(appNameKey.str().c_str()) == "Desktop") {
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

    host.name = copyString(keyForHost(selectedHost, "hostname").c_str());
    host.address = copyString(keyForHost(selectedHost, "localaddress").c_str());
    host.httpPort = (uint16_t)copyInt(keyForHost(selectedHost, "localport").c_str(), 47989);
    host.uuid = copyString(keyForHost(selectedHost, "uuid").c_str());
    host.serverCertPem = copyData(keyForHost(selectedHost, "srvcert").c_str());
    host.appName = "Desktop";
    host.appId = kDesktopAppId;

    for (int app = 1; app <= 64; app++) {
        std::ostringstream appNameKey;
        appNameKey << "hosts." << selectedHost << ".apps." << app << ".name";
        if (copyString(appNameKey.str().c_str()) == "Desktop") {
            std::ostringstream appIdKey;
            appIdKey << "hosts." << selectedHost << ".apps." << app << ".id";
            int savedAppId = copyInt(appIdKey.str().c_str(), 0);
            if (savedAppId != 0) {
                host.appId = savedAppId;
            }
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
