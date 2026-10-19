#include "path.h"

#include "SDL_compat.h"

#include <climits>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>

#include <mach-o/dyld.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

namespace {

std::string s_LogDir;
std::string s_CacheDir;

std::string homeDir()
{
    const char* home = getenv("HOME");
    return home != nullptr ? std::string(home) : std::string();
}

bool fileExists(const std::string& path)
{
    struct stat st = {};
    return stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

std::string executableDir()
{
    char exePath[PATH_MAX];
    uint32_t size = sizeof(exePath);
    if (_NSGetExecutablePath(exePath, &size) != 0) {
        return {};
    }

    char resolved[PATH_MAX];
    if (realpath(exePath, resolved) == nullptr) {
        return {};
    }

    std::string path(resolved);
    size_t slash = path.find_last_of('/');
    return slash == std::string::npos ? std::string() : path.substr(0, slash);
}

std::string bundleResourcesDir()
{
    std::string dir = executableDir();
    if (dir.empty()) {
        return {};
    }

    // Contents/MacOS/Moonlight -> Contents/Resources
    return dir + "/../Resources";
}

std::string currentDir()
{
    char buffer[PATH_MAX];
    if (getcwd(buffer, sizeof(buffer)) == nullptr) {
        return {};
    }
    return std::string(buffer);
}

std::string joinPath(const std::string& dir, const std::string& name)
{
    if (dir.empty()) {
        return name;
    }
    return dir + "/" + name;
}

} // namespace

void Path::initialize()
{
    s_LogDir = "/tmp";

    std::string home = homeDir();
    if (!home.empty()) {
        s_CacheDir = home + "/Library/Caches/com.moonlight-stream.Moonlight";
    }
    else {
        s_CacheDir = "/tmp";
    }
}

std::string Path::getLogDir()
{
    if (s_LogDir.empty()) {
        initialize();
    }
    return s_LogDir;
}

std::string Path::getCacheDir()
{
    if (s_CacheDir.empty()) {
        initialize();
    }
    return s_CacheDir;
}

std::string Path::getCacheFilePath(const std::string& fileName)
{
    return joinPath(getCacheDir(), fileName);
}

std::string Path::getDataFilePath(const std::string& fileName)
{
    // Check the cache location first (used by writeCacheFile())
    std::string candidatePath = getCacheFilePath(fileName);
    if (fileExists(candidatePath)) {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Found %s at %s",
                    fileName.c_str(), candidatePath.c_str());
        return candidatePath;
    }

    // Check the current directory
    candidatePath = joinPath(currentDir(), fileName);
    if (fileExists(candidatePath)) {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Found %s at %s",
                    fileName.c_str(), candidatePath.c_str());
        return candidatePath;
    }

    // Now try the resources of our app bundle
    candidatePath = joinPath(bundleResourcesDir(), fileName);
    if (fileExists(candidatePath)) {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Found %s at %s",
                    fileName.c_str(), candidatePath.c_str());
        return candidatePath;
    }

    // Finally check the directory of our executable
    candidatePath = joinPath(executableDir(), fileName);
    if (fileExists(candidatePath)) {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Found %s at %s",
                    fileName.c_str(), candidatePath.c_str());
        return candidatePath;
    }

    SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION, "Unable to find data file: %s",
                fileName.c_str());
    return {};
}

std::vector<uint8_t> Path::readDataFile(const std::string& fileName)
{
    std::string path = getDataFilePath(fileName);
    if (path.empty()) {
        return {};
    }

    std::ifstream file(path, std::ios::binary);
    if (!file) {
        return {};
    }

    return std::vector<uint8_t>(std::istreambuf_iterator<char>(file),
                                std::istreambuf_iterator<char>());
}

void Path::writeCacheFile(const std::string& fileName, const std::vector<uint8_t>& data)
{
    std::string cacheDir = getCacheDir();

    // Create the cache path if it does not exist
    mkdir(cacheDir.c_str(), 0755);

    std::ofstream file(joinPath(cacheDir, fileName), std::ios::binary | std::ios::trunc);
    if (file) {
        file.write(reinterpret_cast<const char*>(data.data()), (std::streamsize)data.size());
    }
}

void Path::deleteCacheFile(const std::string& fileName)
{
    unlink(getCacheFilePath(fileName).c_str());
}
