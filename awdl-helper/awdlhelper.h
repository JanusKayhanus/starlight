#pragma once

// Shared definitions between Moonlight and the privileged AWDL helper daemon.
//
// Protocol: upon accepting a connection, the daemon writes a single byte
// containing AWDL_HELPER_VERSION. The client then writes '1' to request that
// AWDL be suppressed or '0' to release its request. Closing the connection
// also releases the request. AWDL is suppressed while any client requests it.

#define AWDL_HELPER_LABEL "com.moonlight-stream.awdl-helper"
#define AWDL_HELPER_BUNDLE_NAME "MoonlightAWDLHelper"
#define AWDL_HELPER_INSTALL_PATH "/Library/PrivilegedHelperTools/" AWDL_HELPER_LABEL
#define AWDL_HELPER_PLIST_PATH "/Library/LaunchDaemons/" AWDL_HELPER_LABEL ".plist"
#define AWDL_HELPER_SOCKET_PATH "/var/run/" AWDL_HELPER_LABEL ".sock"

// Bump this when the helper changes to trigger a reinstall
#define AWDL_HELPER_VERSION 1
