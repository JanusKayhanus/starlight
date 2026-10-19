#pragma once

#include <cstdint>
#include <string>
#include <vector>

class Path
{
public:
    static std::string getLogDir();
    static std::string getCacheDir();

    // Reads a bundled data file (gamecontrollerdb.txt, ModeSeven.ttf,
    // vt_renderer.metal, ...) from the cache directory, the working directory,
    // or the application bundle's Resources directory.
    static std::vector<uint8_t> readDataFile(const std::string& fileName);
    static void writeCacheFile(const std::string& fileName, const std::vector<uint8_t>& data);
    static void deleteCacheFile(const std::string& fileName);
    static std::string getCacheFilePath(const std::string& fileName);
    static std::string getDataFilePath(const std::string& fileName);

    static void initialize();
};
