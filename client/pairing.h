#pragma once

#include "cancellation.h"

#include <cstdint>
#include <string>

enum class PairState {
    Paired,
    AlreadyInProgress,
    Failed,
    PinWrong
};

// Pairs with a host using the same five-stage protocol as the Qt build
// (getservercert / clientchallenge / serverchallengeresp / clientpairingsecret
// / pairchallenge). On success, `serverCertPem` receives the host's PEM
// certificate so it can be pinned for later HTTPS requests. `uniqueId` is sent
// with every request; the host requires it and uses it to tie the stages
// together. Cancelling `cancel` (for example, when the user gives up while
// the host waits for the PIN) makes it fail promptly with kCancelledError.
PairState pairHost(const std::string& address, uint16_t httpPort, uint16_t httpsPort,
                   const std::string& serverAppVersion, const std::string& uniqueId,
                   const std::string& pin,
                   std::string& serverCertPem, std::string& error,
                   const CancellationToken* cancel = nullptr);
