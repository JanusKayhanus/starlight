#pragma once

#include "settings/streamingpreferences.h"

#include <string>

// Applies the supported command line overrides on top of the saved
// preferences. Returns false if the command line was invalid; `error`
// then contains a message suitable for printing. `shouldExit` is set
// when the command line was handled without starting a stream (--help).
bool applyCommandLineOverrides(int argc, char** argv,
                               StreamingPreferences* preferences,
                               bool& shouldExit,
                               std::string& error);

// Handles the "pair" subcommand (`Moonlight pair <host> [--pin <PIN>]`).
// Returns true if the command was present and handled, in which case `exitCode`
// is the process exit status.
bool handlePairCommandIfPresent(int argc, char** argv, int& exitCode);
