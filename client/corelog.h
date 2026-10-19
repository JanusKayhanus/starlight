#pragma once

// Logging for the host-management core (HTTP, serverinfo, pairing, app list,
// Wake-on-LAN), which doesn't depend on SDL so the UI can link it without
// loading SDL. Messages go to stderr until an app installs its own handler;
// the streaming client routes them to SDL's log.
enum class CoreLogLevel {
    Info,
    Warning,
    Error,
};

using CoreLogHandler = void (*)(CoreLogLevel level, const char* message);

// Replaces the handler. Not thread-safe: call it once, at startup.
void setCoreLogHandler(CoreLogHandler handler);

void coreLog(CoreLogLevel level, const char* format, ...) __attribute__((format(printf, 2, 3)));
