#include "mappingmanager.h"
#include "cfprefs.h"
#include "path.h"

#include "SDL_compat.h"

#include <cstdlib>
#include <sstream>
#include <vector>

#define SER_GAMEPADMAPPING "gcmapping"

#define SER_GUID "guid"
#define SER_MAPPING "mapping"

namespace {

std::vector<std::string> splitLines(const std::string& text)
{
    std::vector<std::string> lines;
    std::istringstream stream(text);
    std::string line;
    while (std::getline(stream, line)) {
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        if (!line.empty()) {
            lines.push_back(line);
        }
    }
    return lines;
}

} // namespace

MappingManager::MappingManager()
{
    // First load existing saved mappings. This ensures the user's
    // hints can always override the old data.
    int mappingCount = CfPrefs::copyInt(SER_GAMEPADMAPPING ".size", 0);
    for (int i = 1; i <= mappingCount; i++) {
        std::ostringstream prefix;
        prefix << SER_GAMEPADMAPPING "." << i << ".";

        SdlGamepadMapping mapping(CfPrefs::copyString(prefix.str() + SER_GUID),
                                  CfPrefs::copyString(prefix.str() + SER_MAPPING));
        addMapping(mapping);
    }

    // Finally load mappings from SDL_HINT_GAMECONTROLLERCONFIG
    const char* hint = SDL_GetHint(SDL_HINT_GAMECONTROLLERCONFIG);
    if (hint != nullptr) {
        for (const std::string& sdlMapping : splitLines(hint)) {
            SdlGamepadMapping mapping(sdlMapping);
            addMapping(mapping);
        }
    }
}

void MappingManager::applyMappings()
{
    std::vector<uint8_t> mappingData = Path::readDataFile("gamecontrollerdb.txt");
    if (!mappingData.empty()) {
        int newMappings = SDL_GameControllerAddMappingsFromRW(
                    SDL_RWFromConstMem(mappingData.data(), (int)mappingData.size()), 1);

        if (newMappings > 0) {
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                        "Loaded %d new gamepad mappings",
                        newMappings);
        }
        else {
            if (newMappings < 0) {
                SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                             "Error loading gamepad mappings: %s",
                             SDL_GetError());
            }
            else if (newMappings == 0) {
                SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                            "0 new mappings found in gamecontrollerdb.txt. Is it corrupt?");
            }

            // Try deleting the cached mapping list just in case it's corrupt
            Path::deleteCacheFile("gamecontrollerdb.txt");
        }
    }
    else {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "Unable to load gamepad mapping file");
    }

    for (const auto& entry : m_Mappings) {
        const SdlGamepadMapping& mapping = entry.second;
        std::string sdlMappingString = mapping.getSdlMappingString();
        int ret = SDL_GameControllerAddMapping(sdlMappingString.c_str());
        if (ret < 0) {
            SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                        "Unable to add mapping: %s",
                        sdlMappingString.c_str());
        }
        else if (ret == 1) {
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                        "Loaded saved user mapping: %s",
                        sdlMappingString.c_str());
        }
    }
}

void MappingManager::addMapping(std::string mappingString)
{
    SdlGamepadMapping mapping(std::move(mappingString));
    addMapping(mapping);
}

void MappingManager::addMapping(SdlGamepadMapping& mapping)
{
    m_Mappings[mapping.getGuid()] = mapping;
}
