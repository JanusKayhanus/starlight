#pragma once

#include <cstdint>
#include <string>

bool httpGet(const std::string& host, uint16_t port, const std::string& path,
             std::string& response, std::string& error);

bool httpsGet(const std::string& host, uint16_t port, const std::string& path,
              const std::string& clientCertPem, const std::string& clientKeyPem,
              const std::string& serverCertPem,
              std::string& response, std::string& error);
