#pragma once

#include "cancellation.h"
#include "settings.h"

#include <string>

// Queries the host's HTTP serverinfo endpoint and fills in the fields of
// HostConfig that come from the host (version, codec support, current app,
// MAC address).
bool fetchServerInfo(HostConfig& host, const ClientConfig& client, std::string& error,
                     const CancellationToken* cancel = nullptr);

// The "uniqueid=…&uuid=…" query the host expects on every request.
std::string clientRequestQuery(const ClientConfig& client);

// Checks the status_code of a host's XML response; on failure, `error`
// describes it.
bool verifyHostResponse(const std::string& xml, std::string& error);
