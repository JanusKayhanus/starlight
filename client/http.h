#pragma once

#include <cstdint>
#include <string>

constexpr int kDefaultHttpTimeoutSeconds = 15;

// `timeoutSeconds` bounds each send/receive; 0 waits indefinitely (for
// requests the host deliberately holds open, like the first pairing stage).
bool httpGet(const std::string& host, uint16_t port, const std::string& path,
             std::string& response, std::string& error,
             int timeoutSeconds = kDefaultHttpTimeoutSeconds);

// `httpStatusCode`, if provided, receives the HTTP status of the response
// (0 if none was received), so callers can tell an unpaired client (401)
// apart from other failures.
bool httpsGet(const std::string& host, uint16_t port, const std::string& path,
              const std::string& clientCertPem, const std::string& clientKeyPem,
              const std::string& serverCertPem,
              std::string& response, std::string& error,
              int timeoutSeconds = kDefaultHttpTimeoutSeconds,
              int* httpStatusCode = nullptr);
