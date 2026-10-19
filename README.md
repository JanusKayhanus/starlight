# Moonlight Desktop (Qt-free macOS client)

This branch is a macOS-only, Qt-free direct-streaming client for
[NVIDIA GameStream / Sunshine](https://github.com/LizardByte/Sunshine).

On launch, it reads the already-paired **DESKTOP-BUO46UK** host and the
**Desktop** app from Moonlight's saved preferences and opens a fullscreen
stream window. There is no launcher, settings window, host discovery, pairing
flow, or Qt runtime.

The application is feature-equivalent to the previous macOS client's streaming
pipeline:

- **moonlight-common-c** for the GameStream protocol
- **FFmpeg + VideoToolbox** hardware decoding for H.264, HEVC Main/Main10,
  HEVC RExt 4:4:4 8/10-bit, and AV1
- **Metal** renderer with 10-bit EDR output, HDR10 mastering metadata, and
  BT.601/709/2020 color conversion (the original `vt_renderer.metal` pipeline)
- **VideoToolbox AVSampleBufferDisplayLayer** renderer fallback
- **Frame pacing** with the original Pacer implementation and
  `CAMetalDisplayLink` presentation on macOS 14+
- Highest-priority codec negotiation: 4:4:4 and HDR profiles are selected from
  the host's advertised codec modes, exactly as before
- HDR launch negotiation (`hdrMode`, static metadata capabilities) and HDR
  mode-change callbacks
- SDL2 audio output, input handling (keyboard, mouse, gamepads, touch,
  rumble, DualSense features), and the performance/status overlays
- AWDL (AirDrop) suppression while streaming via the bundled privileged helper
- **OpenSSL** for the HTTPS launch request, using the existing paired identity

## Build

Requirements:
- macOS 13 or later
- Xcode command line tools
- CMake 3.20+ and Ninja
- Prebuilt SDL2/SDL2_ttf/FFmpeg/OpenSSL/Opus dependencies

Setup:
```sh
git submodule update --init --recursive
python3 setup-deps.py
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
open build/Moonlight.app
```

For a distributable universal DMG:
```sh
scripts/generate-dmg.sh Release
```

The host, app ID, resolution, frame rate, bitrate, HDR, and YUV 4:4:4 settings
are read from the existing `com.moonlight-stream.Moonlight` preferences. If
DESKTOP-BUO46UK has not been paired by the previous Moonlight app, launch will
fail; pair it once with the original client first.

## Command line

Saved preferences are the defaults; these options override them per run:

```sh
# 4K, HDR, YUV 4:4:4, 120 FPS, 500 Mbps
./build/Moonlight.app/Contents/MacOS/Moonlight \
    --resolution 3840x2160 --fps 120 --bitrate 500000 --hdr --yuv444
```

| Option | Meaning |
| --- | --- |
| `--720`, `--1080`, `--1440`, `--4K` | Standard resolutions |
| `--resolution <width>x<height>` | Custom resolution |
| `--fps <fps>` | Frame rate (10–480) |
| `--bitrate <kbps>` | Video bitrate (500–500000) |
| `--hdr`, `--no-hdr` | Enable or disable HDR |
| `--yuv444`, `--no-yuv444` | Enable or disable YUV 4:4:4 |
| `--video-codec <codec>` | `auto`, `h264`, `hevc`, or `av1` |
| `--display-mode <mode>` | `fullscreen`, `borderless`, or `windowed` |
| `--help` | Show usage |

When only the resolution or frame rate is changed, the default bitrate is
recomputed using the original formula (unless `--bitrate` is also given).

Exit the stream with **Cmd+Q** or **Ctrl+Alt+Shift+Q**.

## Notes

- The performance overlay is toggled with **Ctrl+Alt+Shift+S**.
- Audio follows the saved "Play audio on host" preference. With that option
  enabled the host plays audio locally, so this client intentionally receives
  no audio to render. If the host sends no audio even with client playback
  enabled, check the host's audio capture device — this client renders audio
  correctly once packets arrive (verified with a 48 kHz stereo Opus stream).
- If launching from Finder fails with "No route to host", macOS is denying
  Local Network access to this un-signed development build. Run the binary
  from a terminal once, or allow it under System Settings → Privacy & Security
  → Local Network. Building with a stable Developer ID signature avoids the
  prompt.
- The AWDL helper is installed on first stream, which prompts for admin
  credentials once. It is only active while a stream is connected.
