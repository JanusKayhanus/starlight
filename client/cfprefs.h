#pragma once

#include <cstdint>
#include <string>

// Thin wrappers around the application's saved preferences. Moonlight's
// preferences are stored in the standard user defaults domain, so the
// Qt-free client reads the same values the Qt build wrote.
namespace CfPrefs {

std::string copyString(const std::string& key);
int copyInt(const std::string& key, int defaultValue);
bool copyBool(const std::string& key, bool defaultValue);
std::string copyData(const std::string& key);

} // namespace CfPrefs
