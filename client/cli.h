#pragma once

#include "settings/streamingpreferences.h"

#include <string>

// What to stream, from --host and --app. Empty means the default.
struct StreamTarget {
    std::string host;
    std::string app;
};

// Applies the supported command line overrides on top of the saved
// preferences, and reads the host and app to stream into `target`. Returns
// false if the command line was invalid; `error` then contains a message
// suitable for printing. `shouldExit` is set when the command line was
// handled without starting a stream (--help).
bool applyCommandLineOverrides(int argc, char** argv,
                               StreamingPreferences* preferences,
                               StreamTarget& target,
                               bool& shouldExit,
                               std::string& error);

// Handles the "hosts", "apps", "wake" and "quit" subcommands. Returns true if one was
// present and handled, in which case `exitCode` is the process exit status.
bool handleHostCommandIfPresent(int argc, char** argv, int& exitCode);

// Handles the "pair" subcommand (`Moonlight pair <host> [--pin <PIN>]`).
// Returns true if the command was present and handled, in which case `exitCode`
// is the process exit status.
bool handlePairCommandIfPresent(int argc, char** argv, int& exitCode);
