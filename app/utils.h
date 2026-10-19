#pragma once

#include <QString>

#define THROW_BAD_ALLOC_IF_NULL(x) \
    if ((x) == nullptr) throw std::bad_alloc()

namespace Utils {
    template <typename T>
    bool getEnvironmentVariableOverride(const char* name, T* value) {
        bool ok;
        *value = (T)qEnvironmentVariableIntValue(name, &ok);
        return ok;
    }
}
