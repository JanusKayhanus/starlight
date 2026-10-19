#pragma once

#include "cancellation.h"
#include "settings.h"

#include <string>

// HTTPS requests to a paired host outside of a stream. Each one blocks, so
// run it off the main thread, and fails with `kCancelledError` if `cancel` is
// cancelled.

// Replaces `host.apps` with the host's /applist, sorted by name. Keeps the
// hidden and direct-launch flags of apps that were already known.
bool fetchAppList(HostConfig& host, const ClientConfig& client, std::string& error,
                  const CancellationToken* cancel = nullptr);

// Quits the app the host is running (/cancel), then checks with serverinfo
// that it really quit: hosts report success even when they refuse to quit an
// app another client started.
bool quitRunningApp(HostConfig& host, const ClientConfig& client, std::string& error,
                    const CancellationToken* cancel = nullptr);
