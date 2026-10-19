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

void setString(const std::string& key, const std::string& value);
void setInt(const std::string& key, int value);
void setBool(const std::string& key, bool value);
void setData(const std::string& key, const std::string& value);

// Deletes `key`, if it exists.
void remove(const std::string& key);

// Deletes every key that starts with `prefix`.
void removeWithPrefix(const std::string& prefix);

// Renames every key that starts with `from` to start with `to` instead,
// keeping its value.
void renamePrefix(const std::string& from, const std::string& to);

} // namespace CfPrefs
