#pragma once

#include <cstdlib>

#define THROW_BAD_ALLOC_IF_NULL(x) \
    if ((x) == nullptr) throw std::bad_alloc()

namespace Utils {
    // Reads an integer (decimal or 0x-prefixed hex) from the environment.
    // Returns true only when the variable exists and parses successfully,
    // matching the semantics of the Qt helper this replaces.
    template <typename T>
    bool getEnvironmentVariableOverride(const char* name, T* value) {
        const char* env = getenv(name);
        if (env == nullptr || *env == '\0') {
            return false;
        }

        char* end = nullptr;
        long parsed = strtol(env, &end, 0);
        if (end == env) {
            return false;
        }

        *value = (T)parsed;
        return true;
    }
}
