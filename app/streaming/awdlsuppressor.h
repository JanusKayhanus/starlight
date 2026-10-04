#pragma once

// Apple Wireless Direct Link (AWDL) powers AirDrop, AirPlay, Sidecar and
// other Continuity features. While it is active, the Wi-Fi radio periodically
// hops away from the infrastructure channel to service AWDL, which causes
// large latency spikes and packet bursts while streaming over Wi-Fi.
//
// Suppressing AWDL requires root, so it is handled by a small LaunchDaemon
// (see awdl-helper/) that starts at boot and only acts while Moonlight is
// connected and requesting suppression. If the daemon isn't installed (or is
// outdated), we install it from our app bundle, which prompts for admin
// credentials once.
namespace AwdlSuppressor {

// Enables or disables AWDL suppression. This never blocks on the user
// and is safe to call from any thread.
void setSuppressed(bool suppressed);

}
