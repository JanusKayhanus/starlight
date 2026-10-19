#pragma once

#include "settings.h"

#include <string>

// Queries the host's HTTP serverinfo endpoint and fills in the fields of
// HostConfig that come from the host (version, codec support, current app).
bool fetchServerInfo(HostConfig& host, const ClientConfig& client, std::string& error);
