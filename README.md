# Moonlight Desktop (Qt-free macOS client)

This experimental branch is a macOS-only, Qt-free direct-streaming client for
[NVIDIA GameStream / Sunshine](https://github.com/LizardByte/Sunshine).

On launch, it reads the already-paired **DESKTOP-BUO46UK** host from Moonlight's
saved preferences and immediately opens the **Desktop** app in a fullscreen
stream window. There is no launcher, settings window, host discovery, pairing
flow, or Qt runtime.

The app uses:
- **moonlight-common-c** for the GameStream protocol
- **FFmpeg + VideoToolbox** for H.264 hardware decoding
- **SDL2** for the window, Metal-backed presentation, audio output, and input
- **OpenSSL** for the HTTPS launch request, using the existing paired identity
- **CoreFoundation preferences** to read the host and client certificates

## Build

Requirements:
- macOS 13 or later
- Xcode command line tools
- CMake 3.20+ and Ninja
- Prebuilt SDL2/FFmpeg/OpenSSL/Opus dependencies

Setup:
```sh
git submodule update --init --recursive
python3 setup-deps.py
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
open build/Moonlight.app
```

For a distributable DMG:
```sh
scripts/generate-dmg.sh Release
```

The host, app ID, and paired credentials are read from the existing
`com.moonlight-stream.Moonlight` preferences. If DESKTOP-BUO46UK has not been
paired by the previous Moonlight app, launch will fail; pair it once with the
original client first.

Optional environment overrides for the stream (defaults: 3456x2160, 60 FPS, 100 Mbps):
- `MOONLIGHT_WIDTH`, `MOONLIGHT_HEIGHT`, `MOONLIGHT_FPS`
- `MOONLIGHT_BITRATE` (kbps)

Exit the stream with **Cmd+Q** or **Ctrl+Alt+Shift+Q**.

If launching from Finder fails with "No route to host", macOS is denying Local
Network access to this un-signed development build. Run the binary from a
terminal once, or allow it under System Settings → Privacy & Security → Local
Network. Building with a stable Developer ID signature avoids the prompt.
