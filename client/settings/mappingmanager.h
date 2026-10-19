#pragma once

#include <map>
#include <string>

class SdlGamepadMapping
{
public:
    SdlGamepadMapping() {}

    SdlGamepadMapping(std::string string)
    {
        size_t comma = string.find(',');
        if (comma != std::string::npos) {
            m_Guid = string.substr(0, comma);
            m_Mapping = string.substr(comma + 1);
        }
    }

    SdlGamepadMapping(std::string guid, std::string mapping)
        : m_Guid(std::move(guid)),
          m_Mapping(std::move(mapping))
    {
    }

    bool operator==(const SdlGamepadMapping& other) const
    {
        return m_Guid == other.m_Guid && m_Mapping == other.m_Mapping;
    }

    const std::string& getGuid() const
    {
        return m_Guid;
    }

    const std::string& getMapping() const
    {
        return m_Mapping;
    }

    std::string getSdlMappingString() const
    {
        if (m_Guid.empty() || m_Mapping.empty()) {
            return {};
        }
        else {
            return m_Guid + "," + m_Mapping;
        }
    }

private:
    std::string m_Guid;
    std::string m_Mapping;
};

class MappingManager
{
public:
    MappingManager();

    void addMapping(std::string gamepadString);

    void addMapping(SdlGamepadMapping& gamepadMapping);

    void applyMappings();

private:
    std::map<std::string, SdlGamepadMapping> m_Mappings;
};
