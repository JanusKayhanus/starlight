#pragma once

#include "settings.h"

#include <string>

// Sends Wake-on-LAN magic packets for `host`, the way the Qt build did: to
// every address the host was saved with, to the broadcast address of each
// network interface, and to IPv6 all-nodes multicast, on port 9, 47009 and
// the GameStream ports. Returns true if at least one packet was sent; the
// host may still not wake up. Needs the host's MAC address, which serverinfo
// reports once paired (see saveHostDetails()).
bool sendWakeOnLan(const HostConfig& host, std::string& error);
