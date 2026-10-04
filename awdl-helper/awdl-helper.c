// Privileged helper daemon that suppresses AWDL while Moonlight is streaming.
//
// Apple Wireless Direct Link (AWDL) powers AirDrop, AirPlay, Sidecar and
// other Continuity features. While it is active, the Wi-Fi radio periodically
// hops away from the infrastructure channel to service AWDL, which causes
// large latency spikes while streaming over Wi-Fi.
//
// Bringing awdl0 down prevents this, but requires root and macOS eagerly
// brings it back up. This daemon runs as root via launchd and, while any
// Moonlight client requests it, watches the routing socket to immediately
// force awdl0 back down. AWDL is restored once no client requests it.
//
// Usage:
//   MoonlightAWDLHelper --install    Install and start the LaunchDaemon (root)
//   MoonlightAWDLHelper --uninstall  Stop and remove the LaunchDaemon (root)
//   MoonlightAWDLHelper --daemon     Run the daemon (invoked by launchd)

#include "awdlhelper.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mach-o/dyld.h>
#include <net/if.h>
#include <net/route.h>
#include <os/log.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <sys/wait.h>

extern char** environ;

#define AWDL_IFNAME "awdl0"
#define MAX_CLIENTS 16

// ---------------------------------------------------------------------------
// Daemon
// ---------------------------------------------------------------------------

static volatile sig_atomic_t s_Terminate;

static void handleTerminationSignal(int sig)
{
    (void)sig;
    s_Terminate = 1;
}

// Returns true if awdl0's state was changed
static bool setAwdlUp(int ctlSock, bool up)
{
    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strlcpy(ifr.ifr_name, AWDL_IFNAME, sizeof(ifr.ifr_name));

    if (ioctl(ctlSock, SIOCGIFFLAGS, &ifr) < 0) {
        // Interface doesn't exist
        return false;
    }

    bool isUp = (ifr.ifr_flags & IFF_UP) != 0;
    if (isUp == up) {
        return false;
    }

    if (up) {
        ifr.ifr_flags |= IFF_UP;
    }
    else {
        ifr.ifr_flags &= ~IFF_UP;
    }

    if (ioctl(ctlSock, SIOCSIFFLAGS, &ifr) < 0) {
        os_log_error(OS_LOG_DEFAULT, "Failed to set " AWDL_IFNAME " %{public}s: %d",
                     up ? "up" : "down", errno);
        return false;
    }

    return true;
}

static int createListenSocket(void)
{
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        return -1;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strlcpy(addr.sun_path, AWDL_HELPER_SOCKET_PATH, sizeof(addr.sun_path));

    unlink(AWDL_HELPER_SOCKET_PATH);
    if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0 ||
            chmod(AWDL_HELPER_SOCKET_PATH, 0666) < 0 ||
            listen(sock, MAX_CLIENTS) < 0) {
        close(sock);
        return -1;
    }

    fcntl(sock, F_SETFD, FD_CLOEXEC);
    return sock;
}

static int runDaemon(void)
{
    if (geteuid() != 0) {
        fprintf(stderr, "The daemon must run as root\n");
        return EXIT_FAILURE;
    }

    // Don't use SA_RESTART so poll() is interrupted by these
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = handleTerminationSignal;
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    signal(SIGPIPE, SIG_IGN);

    int ctlSock = socket(AF_INET, SOCK_DGRAM, 0);
    int routeSock = socket(PF_ROUTE, SOCK_RAW, AF_UNSPEC);
    int listenSock = createListenSocket();
    if (ctlSock < 0 || routeSock < 0 || listenSock < 0) {
        os_log_error(OS_LOG_DEFAULT, "Failed to initialize AWDL helper: %d", errno);
        return EXIT_FAILURE;
    }

    int clients[MAX_CLIENTS];
    bool clientWantsSuppression[MAX_CLIENTS];
    int clientCount = 0;

    bool suppressing = false;
    bool weDisabled = false;

    while (!s_Terminate) {
        struct pollfd fds[2 + MAX_CLIENTS];
        fds[0] = (struct pollfd){ listenSock, POLLIN, 0 };
        fds[1] = (struct pollfd){ routeSock, POLLIN, 0 };
        for (int i = 0; i < clientCount; i++) {
            fds[2 + i] = (struct pollfd){ clients[i], POLLIN, 0 };
        }

        if (poll(fds, 2 + clientCount, -1) < 0) {
            if (errno == EINTR) {
                continue;
            }
            os_log_error(OS_LOG_DEFAULT, "poll() failed: %d", errno);
            break;
        }

        // Process client requests first (in reverse, so removals are safe)
        for (int i = clientCount - 1; i >= 0; i--) {
            if (!(fds[2 + i].revents & (POLLIN | POLLHUP | POLLERR))) {
                continue;
            }

            char cmds[64];
            ssize_t n = read(clients[i], cmds, sizeof(cmds));
            if (n > 0) {
                // Only the most recent command matters
                clientWantsSuppression[i] = cmds[n - 1] == '1';
            }
            else {
                // Client disconnected, so drop its request
                close(clients[i]);
                clientCount--;
                clients[i] = clients[clientCount];
                clientWantsSuppression[i] = clientWantsSuppression[clientCount];
            }
        }

        if (fds[0].revents & POLLIN) {
            int client = accept(listenSock, NULL, NULL);
            if (client >= 0) {
                const char version = AWDL_HELPER_VERSION;
                fcntl(client, F_SETFD, FD_CLOEXEC);
                if (clientCount == MAX_CLIENTS || write(client, &version, 1) != 1) {
                    close(client);
                }
                else {
                    clients[clientCount] = client;
                    clientWantsSuppression[clientCount] = false;
                    clientCount++;
                }
            }
        }

        bool shouldSuppress = false;
        for (int i = 0; i < clientCount; i++) {
            shouldSuppress |= clientWantsSuppression[i];
        }

        if (shouldSuppress != suppressing) {
            suppressing = shouldSuppress;
            os_log(OS_LOG_DEFAULT, "AWDL suppression %{public}s",
                   suppressing ? "enabled" : "disabled");

            if (suppressing) {
                weDisabled |= setAwdlUp(ctlSock, false);
            }
            else if (weDisabled) {
                setAwdlUp(ctlSock, true);
                weDisabled = false;
            }
        }

        if (fds[1].revents & POLLIN) {
            // Routing socket reads always return exactly one message
            union {
                struct if_msghdr ifm;
                char buf[4096];
            } msg;
            ssize_t n = read(routeSock, &msg, sizeof(msg));
            if (suppressing &&
                    n >= (ssize_t)sizeof(struct if_msghdr) &&
                    msg.ifm.ifm_type == RTM_IFINFO &&
                    (msg.ifm.ifm_flags & IFF_UP) &&
                    msg.ifm.ifm_index == if_nametoindex(AWDL_IFNAME)) {
                // Something (sharingd, airportd, etc.) brought AWDL
                // back up. Knock it back down immediately.
                weDisabled |= setAwdlUp(ctlSock, false);
            }
        }
    }

    if (weDisabled) {
        setAwdlUp(ctlSock, true);
    }

    for (int i = 0; i < clientCount; i++) {
        close(clients[i]);
    }
    close(listenSock);
    unlink(AWDL_HELPER_SOCKET_PATH);
    close(routeSock);
    close(ctlSock);
    return EXIT_SUCCESS;
}

// ---------------------------------------------------------------------------
// Installation
// ---------------------------------------------------------------------------

static int runCommand(const char* const argv[])
{
    pid_t pid;
    int err = posix_spawn(&pid, argv[0], NULL, NULL, (char* const*)argv, environ);
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

static void stopDaemon(void)
{
    const char* const bootout[] = {
        "/bin/launchctl", "bootout", "system/" AWDL_HELPER_LABEL, NULL
    };

    // This fails harmlessly if the daemon isn't loaded
    runCommand(bootout);
}

static bool copyFile(const char* src, const char* dst, mode_t mode)
{
    char tmpPath[PATH_MAX];
    snprintf(tmpPath, sizeof(tmpPath), "%s.tmp", dst);

    int in = open(src, O_RDONLY | O_CLOEXEC);
    if (in < 0) {
        return false;
    }

    unlink(tmpPath);
    int out = open(tmpPath, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, mode);
    if (out < 0) {
        close(in);
        return false;
    }

    bool ok = true;
    char buf[65536];
    ssize_t n;
    while ((n = read(in, buf, sizeof(buf))) > 0) {
        if (write(out, buf, n) != n) {
            ok = false;
            break;
        }
    }

    ok = ok && n == 0 &&
         fchown(out, 0, 0) == 0 &&
         fchmod(out, mode) == 0;

    close(in);
    if (close(out) < 0) {
        ok = false;
    }

    // Atomically replace the old file
    if (!ok || rename(tmpPath, dst) < 0) {
        unlink(tmpPath);
        return false;
    }

    return true;
}

static bool writePlist(void)
{
    FILE* f = fopen(AWDL_HELPER_PLIST_PATH ".tmp", "w");
    if (f == NULL) {
        return false;
    }

    fprintf(f,
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n"
            "<plist version=\"1.0\">\n"
            "<dict>\n"
            "\t<key>Label</key>\n"
            "\t<string>" AWDL_HELPER_LABEL "</string>\n"
            "\t<key>ProgramArguments</key>\n"
            "\t<array>\n"
            "\t\t<string>" AWDL_HELPER_INSTALL_PATH "</string>\n"
            "\t\t<string>--daemon</string>\n"
            "\t</array>\n"
            "\t<key>RunAtLoad</key>\n"
            "\t<true/>\n"
            "\t<key>KeepAlive</key>\n"
            "\t<true/>\n"
            "\t<key>ProcessType</key>\n"
            "\t<string>Interactive</string>\n"
            "</dict>\n"
            "</plist>\n");

    bool ok = fchown(fileno(f), 0, 0) == 0 && fchmod(fileno(f), 0644) == 0;
    if (fclose(f) != 0 || !ok || rename(AWDL_HELPER_PLIST_PATH ".tmp", AWDL_HELPER_PLIST_PATH) < 0) {
        unlink(AWDL_HELPER_PLIST_PATH ".tmp");
        return false;
    }

    return true;
}

static int install(void)
{
    if (geteuid() != 0) {
        fprintf(stderr, "Installation must be run as root\n");
        return EXIT_FAILURE;
    }

    char exePath[PATH_MAX];
    uint32_t size = sizeof(exePath);
    char resolvedPath[PATH_MAX];
    if (_NSGetExecutablePath(exePath, &size) != 0 || realpath(exePath, resolvedPath) == NULL) {
        fprintf(stderr, "Unable to determine executable path\n");
        return EXIT_FAILURE;
    }

    stopDaemon();

    mkdir("/Library/PrivilegedHelperTools", 0755);
    if (strcmp(resolvedPath, AWDL_HELPER_INSTALL_PATH) != 0 &&
            !copyFile(resolvedPath, AWDL_HELPER_INSTALL_PATH, 0755)) {
        fprintf(stderr, "Failed to install helper binary: %d\n", errno);
        return EXIT_FAILURE;
    }

    if (!writePlist()) {
        fprintf(stderr, "Failed to write LaunchDaemon plist: %d\n", errno);
        return EXIT_FAILURE;
    }

    const char* const bootstrap[] = {
        "/bin/launchctl", "bootstrap", "system", AWDL_HELPER_PLIST_PATH, NULL
    };
    int err = runCommand(bootstrap);
    if (err != 0) {
        fprintf(stderr, "launchctl bootstrap failed: %d\n", err);
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

static int uninstall(void)
{
    if (geteuid() != 0) {
        fprintf(stderr, "Uninstallation must be run as root\n");
        return EXIT_FAILURE;
    }

    // The daemon restores AWDL when it is stopped
    stopDaemon();
    unlink(AWDL_HELPER_PLIST_PATH);
    unlink(AWDL_HELPER_INSTALL_PATH);
    unlink(AWDL_HELPER_SOCKET_PATH);
    return EXIT_SUCCESS;
}

int main(int argc, char* argv[])
{
    if (argc == 2 && strcmp(argv[1], "--daemon") == 0) {
        return runDaemon();
    }
    else if (argc == 2 && strcmp(argv[1], "--install") == 0) {
        return install();
    }
    else if (argc == 2 && strcmp(argv[1], "--uninstall") == 0) {
        return uninstall();
    }

    fprintf(stderr, "Usage: %s --install | --uninstall | --daemon\n", argv[0]);
    return EXIT_FAILURE;
}
