#include "awdlsuppressor.h"

#include "SDL_compat.h"
#include "awdlhelper.h"

#include <mutex>
#include <string>
#include <thread>

#include <errno.h>
#include <limits.h>
#include <libgen.h>
#include <spawn.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mach-o/dyld.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>

extern char** environ;

namespace AwdlSuppressor {

static std::mutex s_Lock;
static bool s_Desired = false;
static int s_Fd = -1;
static bool s_Installing = false;
static bool s_InstallFailed = false;

// Returns a connected socket to the helper daemon or -1 if the daemon
// isn't running or is running a different version than ours.
static int connectToHelper()
{
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        return -1;
    }

    int val = 1;
    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &val, sizeof(val));

    // Don't hang if the daemon is wedged
    struct timeval timeout = { 1, 0 };
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));

    struct sockaddr_un addr = {};
    addr.sun_family = AF_UNIX;
    strlcpy(addr.sun_path, AWDL_HELPER_SOCKET_PATH, sizeof(addr.sun_path));

    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sock);
        return -1;
    }

    char version;
    if (read(sock, &version, 1) != 1) {
        close(sock);
        return -1;
    }

    if (version != AWDL_HELPER_VERSION) {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION,
                    "AWDL helper version mismatch (installed: %d, expected: %d)",
                    version, AWDL_HELPER_VERSION);
        close(sock);
        return -1;
    }

    return sock;
}

static void requestSuppressionLocked()
{
    const char cmd = '1';
    if (write(s_Fd, &cmd, 1) == 1) {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "AWDL suppression enabled");
    }
    else {
        SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                    "Failed to request AWDL suppression: %d",
                    errno);
        close(s_Fd);
        s_Fd = -1;
    }
}

static bool getBundledHelperPath(std::string& path)
{
    char exePath[PATH_MAX];
    uint32_t size = sizeof(exePath);
    if (_NSGetExecutablePath(exePath, &size) != 0) {
        return false;
    }

    char resolved[PATH_MAX];
    if (realpath(exePath, resolved) == nullptr) {
        return false;
    }

    path = std::string(dirname(resolved)) + "/" AWDL_HELPER_BUNDLE_NAME;
    return access(path.c_str(), X_OK) == 0;
}

static int installHelper(const std::string& helperPath)
{
    // The path is passed via argv and escaped with "quoted form of"
    // so it can't break out of the shell command.
    const char* args[] = {
        "/usr/bin/osascript",
        "-e", "on run argv",
        "-e", "do shell script (quoted form of item 1 of argv) & \" --install\" "
              "with prompt \"Moonlight wants to install a helper that disables AirDrop (AWDL) "
              "while streaming to prevent Wi-Fi latency spikes. You will only be asked once.\" "
              "with administrator privileges",
        "-e", "end run",
        helperPath.c_str(),
        nullptr
    };

    pid_t pid;
    int err = posix_spawn(&pid, args[0], nullptr, nullptr, (char* const*)args, environ);
    if (err != 0) {
        return err;
    }

    int status;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno != EINTR) {
            return errno;
        }
    }

    return WIFEXITED(status) ? WEXITSTATUS(status) : -1;
}

static void installThread()
{
    std::string helperPath;
    int fd = -1;

    if (!getBundledHelperPath(helperPath)) {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                     "AWDL helper is missing from the app bundle");
    }
    else {
        SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "Installing AWDL helper daemon");

        int err = installHelper(helperPath);
        if (err != 0) {
            // Most likely the user cancelled the authorization prompt
            SDL_LogWarn(SDL_LOG_CATEGORY_APPLICATION,
                        "AWDL helper installation failed: %d",
                        err);
        }
        else {
            // Wait up to 5 seconds for launchd to start the daemon
            for (int i = 0; i < 50 && fd < 0; i++) {
                fd = connectToHelper();
                if (fd < 0) {
                    usleep(100 * 1000);
                }
            }

            if (fd < 0) {
                SDL_LogError(SDL_LOG_CATEGORY_APPLICATION,
                             "AWDL helper daemon didn't start after installation");
            }
        }
    }

    std::lock_guard<std::mutex> lock(s_Lock);

    s_Installing = false;

    if (fd < 0) {
        // Don't nag the user again until Moonlight is restarted
        s_InstallFailed = true;
    }
    else if (s_Desired && s_Fd < 0) {
        s_Fd = fd;
        requestSuppressionLocked();
    }
    else {
        close(fd);
    }
}

void setSuppressed(bool suppressed)
{
    std::lock_guard<std::mutex> lock(s_Lock);

    s_Desired = suppressed;

    if (!suppressed) {
        // Closing our connection releases our suppression request
        if (s_Fd >= 0) {
            close(s_Fd);
            s_Fd = -1;
            SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "AWDL suppression disabled");
        }
        return;
    }

    if (s_Fd >= 0 || s_Installing) {
        return;
    }

    s_Fd = connectToHelper();
    if (s_Fd >= 0) {
        requestSuppressionLocked();
    }
    else if (!s_InstallFailed) {
        // The daemon isn't installed or is outdated. Install it from our
        // bundle in the background, since this prompts for credentials.
        s_Installing = true;
        std::thread(installThread).detach();
    }
}

}
