#include "wol.h"

#include "corelog.h"

#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netdb.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cerrno>
#include <cstring>
#include <set>
#include <utility>
#include <vector>

namespace {

// Ports used as-is: the standard WoL port (privileged) and the one the
// Moonlight Internet Hosting Tool opens.
const uint16_t k_StaticWolPorts[] = { 9, 47009 };

// GameStream ports, offset from the HTTP port for hosts using alternate ports.
const uint16_t k_DynamicWolPorts[] = { 47998, 47999, 48000, 48002, 48010 };

std::vector<uint8_t> magicPacket(const std::vector<uint8_t>& mac)
{
    std::vector<uint8_t> payload(6, 0xFF);
    for (int i = 0; i < 16; i++) {
        payload.insert(payload.end(), mac.begin(), mac.end());
    }
    return payload;
}

std::string numericAddress(const struct sockaddr* address)
{
    char buffer[INET6_ADDRSTRLEN] = {};
    if (address->sa_family == AF_INET) {
        inet_ntop(AF_INET, &((const struct sockaddr_in*)address)->sin_addr, buffer, sizeof(buffer));
    }
    else if (address->sa_family == AF_INET6) {
        inet_ntop(AF_INET6, &((const struct sockaddr_in6*)address)->sin6_addr, buffer, sizeof(buffer));
    }
    return buffer;
}

// Broadcast addresses of every IPv4 interface that's up, and IPv6 all-nodes
// multicast on every IPv6 one, in case the host has dropped out of ARP caches.
std::vector<std::string> localBroadcastAddresses()
{
    std::vector<std::string> result;
    struct ifaddrs* interfaces = nullptr;
    if (getifaddrs(&interfaces) != 0) {
        return result;
    }

    std::set<std::string> ipv6Interfaces;
    for (struct ifaddrs* ifa = interfaces; ifa != nullptr; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == nullptr ||
            (ifa->ifa_flags & IFF_UP) == 0 || (ifa->ifa_flags & IFF_LOOPBACK) != 0) {
            continue;
        }

        if (ifa->ifa_addr->sa_family == AF_INET &&
            (ifa->ifa_flags & IFF_BROADCAST) != 0 && ifa->ifa_broadaddr != nullptr) {
            result.push_back(numericAddress(ifa->ifa_broadaddr));
        }
        else if (ifa->ifa_addr->sa_family == AF_INET6) {
            ipv6Interfaces.insert(ifa->ifa_name);
        }
    }
    freeifaddrs(interfaces);

    for (const std::string& name : ipv6Interfaces) {
        result.push_back("ff02::1%" + name);
    }
    return result;
}

} // namespace

bool sendWakeOnLan(const HostConfig& host, std::string& error)
{
    if (host.macAddress.size() != 6) {
        error = "No MAC address is saved for " + host.name +
                ". Connect to it once while it's on so the host can report it.";
        return false;
    }

    const std::vector<uint8_t> payload = magicPacket(host.macAddress);

    // Each address with the HTTP port it's known on, or 0 for broadcast
    // addresses, which get every known port.
    std::vector<std::pair<std::string, uint16_t>> targets;
    std::set<std::string> seen;
    std::set<uint16_t> basePorts;
    auto addTarget = [&](const std::string& address, uint16_t port) {
        if (!address.empty() && seen.insert(address).second) {
            targets.emplace_back(address, port);
            if (port != 0) {
                basePorts.insert(port);
            }
        }
    };

    addTarget(host.address, host.httpPort);
    addTarget(host.remoteAddress, host.remotePort);
    addTarget(host.manualAddress, host.manualPort);
    addTarget(host.ipv6Address, host.ipv6Port);
    addTarget("255.255.255.255", 0);
    for (const std::string& broadcast : localBroadcastAddresses()) {
        addTarget(broadcast, 0);
    }

    bool sent = false;
    for (const auto& target : targets) {
        // Literal addresses skip DNS, which could delay the packets.
        struct addrinfo hints = {};
        hints.ai_socktype = SOCK_DGRAM;
        hints.ai_flags = AI_NUMERICHOST;
        struct addrinfo* resolved = nullptr;
        if (getaddrinfo(target.first.c_str(), nullptr, &hints, &resolved) != 0) {
            hints.ai_flags = 0;
            int err = getaddrinfo(target.first.c_str(), nullptr, &hints, &resolved);
            if (err != 0) {
                coreLog(CoreLogLevel::Warning, "Unable to resolve %s: %s",
                            target.first.c_str(), gai_strerror(err));
                continue;
            }
        }

        std::vector<uint16_t> ports(std::begin(k_StaticWolPorts), std::end(k_StaticWolPorts));
        std::set<uint16_t> targetBasePorts = target.second != 0 ?
                    std::set<uint16_t> { target.second } : basePorts;
        for (uint16_t basePort : targetBasePorts) {
            for (uint16_t port : k_DynamicWolPorts) {
                ports.push_back((uint16_t)(port - kDefaultHttpPort + basePort));
            }
        }

        for (struct addrinfo* ai = resolved; ai != nullptr; ai = ai->ai_next) {
            int fd = socket(ai->ai_family, SOCK_DGRAM, IPPROTO_UDP);
            if (fd < 0) {
                continue;
            }

            int enable = 1;
            setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &enable, sizeof(enable));

            for (uint16_t port : ports) {
                struct sockaddr_storage address = {};
                memcpy(&address, ai->ai_addr, ai->ai_addrlen);
                if (ai->ai_family == AF_INET) {
                    ((struct sockaddr_in*)&address)->sin_port = htons(port);
                }
                else {
                    ((struct sockaddr_in6*)&address)->sin6_port = htons(port);
                }

                if (sendto(fd, payload.data(), payload.size(), 0,
                           (struct sockaddr*)&address, ai->ai_addrlen) == (ssize_t)payload.size()) {
                    coreLog(CoreLogLevel::Info, "Sent WoL packet to %s via %s:%u",
                                host.name.c_str(), target.first.c_str(), port);
                    sent = true;
                }
                else {
                    coreLog(CoreLogLevel::Warning, "Sending WoL packet to %s:%u failed: %s",
                                target.first.c_str(), port, strerror(errno));
                }
            }
            close(fd);
        }
        freeaddrinfo(resolved);
    }

    if (!sent) {
        error = "Unable to send any Wake-on-LAN packets";
    }
    return sent;
}
