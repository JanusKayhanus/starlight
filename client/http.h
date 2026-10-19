#pragma once

#include "cancellation.h"

#include <cstdint>
#include <string>

constexpr int kDefaultHttpTimeoutSeconds = 15;

// `timeoutSeconds` bounds each wait for the host (connecting, sending,
// receiving); 0 waits indefinitely (for requests the host deliberately holds
// open, like the first pairing stage). If `cancel` is given, cancelling it
// makes the request fail promptly with `kCancelledError`. Resolving a host
// name can't be interrupted.
bool httpGet(const std::string& host, uint16_t port, const std::string& path,
             std::string& response, std::string& error,
             int timeoutSeconds = kDefaultHttpTimeoutSeconds,
             const CancellationToken* cancel = nullptr);

// `httpStatusCode`, if provided, receives the HTTP status of the response
// (0 if none was received), so callers can tell an unpaired client (401)
// apart from other failures.
bool httpsGet(const std::string& host, uint16_t port, const std::string& path,
              const std::string& clientCertPem, const std::string& clientKeyPem,
              const std::string& serverCertPem,
              std::string& response, std::string& error,
              int timeoutSeconds = kDefaultHttpTimeoutSeconds,
              int* httpStatusCode = nullptr,
              const CancellationToken* cancel = nullptr);
