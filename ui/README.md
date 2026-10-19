# Starlight UI

A native SwiftUI front end for the Qt-free client. It comes in two apps:

- **Starlight**, the real app, which `Moonlight.app` opens. It manages hosts
  through the C++ core in `client/` and streams in the Moonlight client's own
  window.
- **StarlightMockApp**, which runs the same UI against mock services so it can
  be built and reviewed on its own.

## Running the real app

Build it with CMake, which builds the core library and passes its library
paths to SwiftPM, then open the bundle:

```sh
cmake --build build
open build/Moonlight.app
```

The first time it reaches the network, macOS asks for Local Network access.
Settings edit the real streaming preferences (`com.moonlight-stream.Moonlight`),
which the client reads when a stream starts.

## Running the mock app

Open `ui/Package.swift` in Xcode, pick the **StarlightMockApp** scheme and run.
Or from the command line:

```sh
swift run --package-path ui StarlightMockApp
```

Requires macOS 14 or later.

The mock app shows four sample computers. A fifth, "Living Room PC", is
"discovered" after two seconds. Waking, pairing and connecting are all
simulated with short delays. Settings are saved to a separate preferences
suite (`com.moonlight-stream.Moonlight.ui-mock`), so the real app's streaming
preferences are never touched.

## What's here

| Scene | Files | Notes |
|---|---|---|
| Computers window | `Views/Computers/` | Expandable host cards with Connect, Wake or Pair, and each host's apps |
| Add Computer / pairing | `ComputersView.swift` | Address sheet, then a sheet showing the PIN to enter in Sunshine |
| Stream window | `Views/Session/` | Just the remote screen, drawn into `StreamSurfaceView` (a `CAMetalLayer`-backed `NSView`) |
| View menu | `Scenes/StarlightCommands.swift` | Scale to Fit / Actual Size, Move to Display (⌃⌘1…), Disconnect |
| Settings | `Views/Settings/` | General, Video, Input and Audio tabs |
| Menu bar extra | `Views/MenuBar/` | Open sessions, every computer with a one-click action |

`StarlightScenes` puts all of these together. An app creates a `HostStore` and
returns `StarlightScenes(store:)` from its `body`; see
`Sources/Starlight/StarlightApp.swift` and
`Sources/StarlightMockApp/StarlightMockApp.swift`.

The stream window has no on-screen controls. Display, scaling and full screen
are in the View menu, where macOS users expect them. "Move to Display" moves
the window between **this Mac's** screens: the GameStream protocol has no way
to ask the host for a particular remote display. That is configured per app
in Sunshine, and those apps show up in each host card.

## How it's connected to the core

The UI depends only on two protocols. The Starlight target
(`Sources/Starlight/`) implements them on top of the core:

- `StarlightCore` (`Sources/StarlightCore/`) is a small Objective-C++ bridge
  over the core's host management, which CMake builds as `libMoonlightCore.a`
  (no SDL, so the UI process never loads it). Its calls block; every one takes
  an `SLCancellation`.
- `CoreHostService` runs those calls on a background queue and cancels them
  when the calling task is cancelled.
- `ClientStreamController` runs the bundled client
  (`Contents/MacOS/Moonlight --host <uuid> --app <id>`). `start` returns when
  the client logs its first frame; a failed launch throws the client's last
  error line, and the end of the stream comes back through `onTermination`.
  The app sets `HostStore.opensStreamWindows` to false, so Connect opens no
  stream window and failures show as alerts.

### `HostService`

| Method | Core |
|---|---|
| `loadSavedHosts()` | `loadSavedHosts()`: every `hosts.N.*` slot |
| `fetchStatus(for:)` | `fetchServerInfo()` (also saves the MAC address) |
| `fetchApps(for:)` | `fetchAppList()` over HTTPS `/applist`, saved with `saveHostDetails()`. Hidden apps are left out |
| `wake(_:)` | `sendWakeOnLan()` |
| `resolve(address:)` | `fetchServerInfo()`, over HTTPS if the address belongs to a saved host |
| `pair(_:pin:)` | `pairHost()` (cancellable), then `savePairedHost()` with the MAC address and apps |
| `quitApp(on:)` | `quitRunningApp()` |
| `forget(_:)` | `removeSavedHost()`, which compacts the host array as the Qt build did |
| `discoverHosts()` | `NWBrowser` for `_nvstream._tcp`, then `fetchServerInfo()`; only unpaired hosts are reported |

### `StreamControlling`

`ClientStreamController` streams in the client's SDL window. Rendering inside
the app instead means reworking `Session` (`client/streaming/session.cpp`):

- The Metal renderer (`vt_metal.mm`) takes its layer from
  `StreamSurfaceView.metalLayer` rather than `SDL_Metal_CreateView()`.
- `Session::exec()` stops owning the main thread; its per-event work runs from
  the app's run loop.
- Keyboard and mouse input comes from `StreamSurfaceView` (`NSEvent`) instead
  of SDL window events. Gamepads and audio can stay on SDL.

`Session` already reports launch failures and disconnects through
`SessionCallbacks`, which an in-process controller would turn into `start`
errors and `onTermination`. The core supports one stream at a time.

### Preferences

`PreferenceKey` uses the same keys and values as
`client/settings/streamingpreferences.cpp`. The Starlight app passes the
core's domain to `StarlightScenes` (`UserDefaults.standard` inside
Moonlight.app), so Settings edits exactly what the client reads at launch.
