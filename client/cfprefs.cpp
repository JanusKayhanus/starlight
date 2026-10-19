#include "cfprefs.h"

#include <CoreFoundation/CoreFoundation.h>

#include <vector>

namespace {

constexpr const char* kDomain = "com.moonlight-stream.Moonlight";

CFPropertyListRef copyPreference(const std::string& key)
{
    CFStringRef keyString = CFStringCreateWithCString(kCFAllocatorDefault, key.c_str(),
                                                      kCFStringEncodingUTF8);
    if (keyString == nullptr) {
        return nullptr;
    }

    CFStringRef domain = CFStringCreateWithCString(kCFAllocatorDefault, kDomain,
                                                   kCFStringEncodingUTF8);
    CFPropertyListRef value = domain != nullptr ?
                CFPreferencesCopyAppValue(keyString, domain) : nullptr;
    if (domain != nullptr) {
        CFRelease(domain);
    }
    CFRelease(keyString);
    return value;
}

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

} // namespace

namespace CfPrefs {

std::string copyString(const std::string& key)
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

int copyInt(const std::string& key, int defaultValue)
{
    CFPropertyListRef value = copyPreference(key);
    if (value == nullptr) {
        return defaultValue;
    }

    int result = defaultValue;
    if (CFGetTypeID(value) == CFNumberGetTypeID()) {
        CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &result);
    }
    else if (CFGetTypeID(value) == CFStringGetTypeID()) {
        result = atoi(cfStringToStd((CFStringRef)value).c_str());
    }
    else if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
        result = CFBooleanGetValue((CFBooleanRef)value) ? 1 : 0;
    }
    CFRelease(value);
    return result;
}

bool copyBool(const std::string& key, bool defaultValue)
{
    CFPropertyListRef value = copyPreference(key);
    if (value == nullptr) {
        return defaultValue;
    }

    bool result = defaultValue;
    if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
        result = CFBooleanGetValue((CFBooleanRef)value);
    }
    else if (CFGetTypeID(value) == CFNumberGetTypeID()) {
        int intValue = defaultValue ? 1 : 0;
        CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &intValue);
        result = intValue != 0;
    }
    else if (CFGetTypeID(value) == CFStringGetTypeID()) {
        std::string stringValue = cfStringToStd((CFStringRef)value);
        result = stringValue == "1" || stringValue == "true";
    }
    CFRelease(value);
    return result;
}

std::string copyData(const std::string& key)
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

} // namespace CfPrefs
