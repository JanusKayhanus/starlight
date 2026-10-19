# Moonlight (Qt-free macOS branch) — run & configuration reference

This branch has no settings UI. Everything is configured either by **CLI flags**
(per run) or by the **`com.moonlight-stream.Moonlight` macOS preferences domain**
(persistent). Preferences are read at launch, so restart the app after changing
them.

Repo: `/Users/kayhan/moonlight-qt`
Reference build: `build/qtfree` (native) and `build/universal2` (arm64 + x86_64)
Current commit at time of writing: `503a7fd6`

---

## 1. Build and install

```sh
cd /Users/kayhan/moonlight-qt

# One-time dependency setup
git submodule update --init --recursive
python3 setup-deps.py

# Native build (Apple Silicon)
cmake -S . -B build/qtfree -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build/qtfree -j$(sysctl -n hw.logicalcpu)

# Universal build (arm64 + x86_64)
cmake -S . -B build/universal2 -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
cmake --build build/universal2 -j$(sysctl -n hw.logicalcpu)

# Optional signed DMG
scripts/generate-dmg.sh Release

# Launch from Finder
open build/qtfree/Moonlight.app
```

Binary used in all commands below:

```sh
./build/qtfree/Moonlight.app/Contents/MacOS/Moonlight
```

---

## 2. Run commands

```sh
# Launch with saved preferences (currently 3456x2160, 120 FPS, 500 Mbps, HDR, 4:4:4)
./build/qtfree/Moonlight.app/Contents/MacOS/Moonlight

# 4K, HDR, YUV 4:4:4, 120 FPS, 500 Mbps — fills the 16:9 M27P
./build/qtfree/Moonlight.app/Contents/MacOS/Moonlight \
    --resolution 3840x2160 --fps 120 --bitrate 500000 --hdr --yuv444

# Windowed 1080p60 for testing
./build/qtfree/Moonlight.app/Contents/MacOS/Moonlight \
    --1080 --fps 60 --bitrate 20000 --display-mode windowed

# Start on the built-in XDR display (display 1)
./build/qtfree/Moonlight.app/Contents/MacOS/Moonlight --display 1

# Start on the external M27P (display 0 = main display)
./build/qtfree/Moonlight.app/Contents/MacOS/Moonlight --display 0

# Log everything to a file
./build/qtfree/Moonlight.app/Contents/MacOS/Moonlight \
    --4K --fps 120 --bitrate 500000 --hdr --yuv444 > /tmp/moonlight.log 2>&1

# Stop a stuck instance
pkill -f 'Moonlight.app/Contents/MacOS/Moonlight'
```

---

## 3. CLI flags

| Flag | Meaning |
| --- | --- |
| `--720` / `--1080` / `--1440` / `--4K` | Standard resolution |
| `--resolution <W>x<H>` | Custom resolution |
| `--fps <10–480>` | Frame rate |
| `--bitrate <500–500000>` | Bitrate in Kbps |
| `--hdr` / `--no-hdr` | HDR on/off |
| `--yuv444` / `--no-yuv444` | YUV 4:4:4 on/off |
| `--video-codec auto\|h264\|hevc\|av1` | Force codec |
| `--display-mode fullscreen\|borderless\|windowed` | Window mode |
| `--display <index>` | Display to open on (0 = main) |
| `--help` | Usage |

If you change only resolution/FPS, the default bitrate is recomputed unless
`--bitrate` is also given.

---

## 4. Persistent settings (`defaults`)

### Syntax

```sh
# Booleans
defaults write com.moonlight-stream.Moonlight <key> -bool true|false

# Integers
defaults write com.moonlight-stream.Moonlight <key> -int <value>

# Read one value
defaults read com.moonlight-stream.Moonlight <key>

# Read everything
defaults read com.moonlight-stream.Moonlight
```

Changes take effect on the **next launch**.

### Display & video

| Key | Type | Values / meaning |
| --- | --- | --- |
| `width` | int | Stream width (e.g. 3840) |
| `height` | int | Stream height (e.g. 2160) |
| `fps` | int | 10–480 |
| `bitrate` | int | Kbps, 500–500000 |
| `hdr` | bool | HDR streaming |
| `yuv444` | bool | YUV 4:4:4 |
| `videocfg` | int | 0 auto, 1 H.264, 2 HEVC, 4 AV1 |
| `videodec` | int | 0 auto, 1 force hardware, 2 force software |
| `renderer` | int | 0 auto, 1 Metal, 2 AVSampleBufferDisplayLayer |
| `framelatency` | int | 0 default, 1 fast, 2 balanced, 3 smooth |
| `windowmode` | int | 0 fullscreen, 1 borderless fullscreen (recommended), 2 windowed |
| `vsync` | bool | V-sync |
| `framepacing` | bool | Frame pacing |
| `packetsize` | int | 0 = auto (1392); e.g. 1024 for VPN |
| `gameopts` | bool | SOPS — let host change display mode |
| `showperfoverlay` | bool | Start with performance overlay |
| `keepawake` | bool | Prevent display sleep while streaming |

### Audio

| Key | Type | Values |
| --- | --- | --- |
| `audiocfg` | int | 0 stereo, 1 5.1 surround, 2 7.1 surround |
| `hostaudio` | bool | Play audio on the host instead of the client |

### Input

| Key | Type | Meaning |
| --- | --- | --- |
| `mouseacceleration` | bool | `true` = absolute/remote-desktop mouse mode |
| `abstouchmode` | bool | Absolute touch mode |
| `multicontroller` | bool | Multi-controller mode |
| `gamepadmouse` | bool | Gamepad mouse emulation |
| `swapmousebuttons` | bool | Swap left/right |
| `reversescroll` | bool | Reverse scroll direction |
| `swapfacebuttons` | bool | Swap A/B and X/Y |
| `capturesyskeys` | int | 0 off, 1 fullscreen only, 2 always |
| `backgroundgamepad` | bool | Gamepad input without focus |
| `muteonfocusloss` | bool | Mute when window loses focus |

### Session behavior

| Key | Type | Meaning |
| --- | --- | --- |
| `quitAppAfter` | bool | Quit the host app when the stream ends |
| `disableawdl` | bool | Suppress AirDrop/AWDL while streaming |
| `richpresence` | bool | Discord rich presence |
| `connwarnings` | bool | Show connection-quality overlays |

### Examples

```sh
# Make 4K120 HDR 4:4:4 500 Mbps the persistent default
defaults write com.moonlight-stream.Moonlight width -int 3840
defaults write com.moonlight-stream.Moonlight height -int 2160
defaults write com.moonlight-stream.Moonlight fps -int 120
defaults write com.moonlight-stream.Moonlight bitrate -int 500000
defaults write com.moonlight-stream.Moonlight hdr -bool true
defaults write com.moonlight-stream.Moonlight yuv444 -bool true

# Force HEVC + Metal, smoothest frame pacing, borderless fullscreen
defaults write com.moonlight-stream.Moonlight videocfg -int 2
defaults write com.moonlight-stream.Moonlight renderer -int 1
defaults write com.moonlight-stream.Moonlight framelatency -int 3
defaults write com.moonlight-stream.Moonlight windowmode -int 1

# 5.1 audio on the client
defaults write com.moonlight-stream.Moonlight audiocfg -int 1
defaults write com.moonlight-stream.Moonlight hostaudio -bool false

# Remote-desktop mouse + multi-controller
defaults write com.moonlight-stream.Moonlight mouseacceleration -bool true
defaults write com.moonlight-stream.Moonlight multicontroller -bool true

# Quit the host app when the stream ends
defaults write com.moonlight-stream.Moonlight quitAppAfter -bool true
```

### Keys that are read but ignored by this branch

These were UI-only or belong to features removed with Qt:

`unlockbitrate`, `autoadjustbitrate`, `mdns`, `detectnetblocking`,
`confwarnings`, `uidisplaymode`, `language`, `startwindowed`, `fullscreen`
(legacy). Leave them alone.

---

## 5. Inspect, back up, reset

```sh
# Show all current settings
defaults read com.moonlight-stream.Moonlight

# Back up everything (WARNING: contains the client private key + host certificate)
defaults export com.moonlight-stream.Moonlight ~/moonlight-prefs.plist

# Restore a backup
defaults import com.moonlight-stream.Moonlight ~/moonlight-prefs.plist

# Reset a single setting to its built-in default
defaults delete com.moonlight-stream.Moonlight framelatency

# Restart to apply
pkill -f 'Moonlight.app/Contents/MacOS/Moonlight'
open build/qtfree/Moonlight.app
```

Do **not** delete the whole `com.moonlight-stream.Moonlight` domain — it contains
the pairing identity (`certificate`, `key`, `uniqueid`, `hosts.N.srvcert`).
Deleting it un-pairs the client.

---

## 6. Hotkeys (all `Ctrl+Alt+Shift+X`)

| Keys | Action |
| --- | --- |
| `Q` | Quit stream |
| `E` | Quit stream and host app |
| `X` | Toggle fullscreen |
| `N` | Move stream to next display |
| `S` | Toggle performance overlay |
| `M` | Toggle remote-desktop mouse mode |
| `C` | Toggle cursor visibility |
| `D` | Minimize |
| `V` | Paste clipboard to host |
| `L` | Toggle pointer-region lock |
| `K` | Toggle keyboard grab |
| `Z` | Release input capture |

`Cmd+Q` also exits the stream.

---

## 7. Environment-variable overrides (advanced/debug)

```sh
# Force a specific decoder
H264_DECODER_HINT=h264_videotoolbox ...
HEVC_DECODER_HINT=hevc_videotoolbox ...
AV1_DECODER_HINT=av1_videotoolbox ...

# Disable the Metal renderer (falls back to AVSampleBufferDisplayLayer)
VT_FORCE_METAL=0 ...

# Force the AVSampleBufferDisplayLayer indirect path
VT_FORCE_INDIRECT=1 ...

# Override decoder capabilities / color tagging
DECODER_CAPS=0x0 COLOR_SPACE_OVERRIDE=2 COLOR_RANGE_OVERRIDE=1 ...

# Force SDL audio backend
ML_AUDIO=sdl ...

# Match the host display mode to the stream resolution
MATCH_DISPLAY_MODE_TO_VIDEO=1 ...

# Ignore specific gamepads
STREAM_IGNORE_DEVICE_GUIDS=03000000...,03000000... ...

# Disable the gamepad quit combo
NO_GAMEPAD_QUIT=1 ...

# Use the fullscreen-Space path instead of borderless (leaves the menu-bar strip)
MOONLIGHT_FULLSCREEN_SPACES=1 ...

# Use true modesetting fullscreen (not recommended)
I_WANT_BUGGY_FULLSCREEN=1 ...
```

---

## 8. Host session control

End a stale/stuck stream on the host (needed when the host is stuck at a
previous resolution/refresh rate):

```sh
python3 - <<'PY'
import plistlib, subprocess
pl = plistlib.loads(subprocess.check_output(['defaults','export','com.moonlight-stream.Moonlight','-']))
open('/tmp/ml-client.pem','wb').write(pl['certificate'])
open('/tmp/ml-client.key','wb').write(pl['key'])
PY
chmod 600 /tmp/ml-client.key

# Quit the running app on the host
curl -sk --cert /tmp/ml-client.pem --key /tmp/ml-client.key \
     https://192.168.0.215:47984/cancel

rm -f /tmp/ml-client.pem /tmp/ml-client.key
```

Check host state:

```sh
curl -s 'http://192.168.0.215:47989/serverinfo?uniqueid=0123456789ABCDEF&uuid=0123456789abcdef0123456789abcdef'
```

`<currentgame>0</currentgame>` and `SUNSHINE_SERVER_FREE` mean nothing is
running.

---

## 9. Notes

- Fullscreen is a borderless managed window covering the whole display, with
  the menu bar/Dock hidden only while streaming. It appears in Mission Control.
- Video scaling is aspect-preserving: `3456×2160` (16:10) shows side bars on a
  16:9 display. Use `3840×2160` to fill it.
- The monitor reports `5120×2880`; streaming 4K upscales to it. For native 5K,
  use `--resolution 5120x2880` if the host can encode it at your target FPS.
- Settings are read only at startup; no UI writes them back.
- Audio follows `hostaudio`. With `hostaudio` enabled the host plays audio
  locally, so the client intentionally receives no audio to render. If no audio
  arrives with `hostaudio` disabled, check the host's audio capture device.
- If a stream ends but the host keeps the app running, the next launch uses
  `/resume`, which keeps the host's existing resolution/refresh rate. Use the
  cancel command in section 8 (or exit with `Ctrl+Alt+Shift+E`) to force a
  fresh launch.
