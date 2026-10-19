# Starlight UI

A native SwiftUI front end for the Qt-free client. It is not wired to the
streaming core yet: it runs against mock services so the UI can be built and
reviewed on its own.

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
`Sources/StarlightMockApp/StarlightMockApp.swift`.

The stream window has no on-screen controls. Display, scaling and full screen
are in the View menu, where macOS users expect them. "Move to Display" moves
the window between **this Mac's** screens: the GameStream protocol has no way
to ask the host for a particular remote display. That is configured per app
in Sunshine, and those apps show up in each host card.

## Connecting it to the core

The UI depends only on two protocols, so connecting it means implementing them
on top of the C++ code in `client/`, most likely through a thin Objective-C++
bridge.

### `HostService`

| Method | Core |
|---|---|
| `loadSavedHosts()` | `settings.cpp`: generalize `loadMoonlightSettings()` to read every `hosts.N.*` slot instead of the hardcoded host |
| `fetchStatus(for:)` | `fetchServerInfo()` |
| `fetchApps(for:)` | New: HTTPS `/applist`. Its absence is why only "Desktop" works today |
| `wake(_:)` | New: parse the MAC address from serverinfo and send a Wake-on-LAN packet |
| `resolve(address:)` | `fetchServerInfo()` over HTTP for a typed address |
| `pair(_:pin:)` | `pairHost()`, then `savePairedHost()`. Needs a cancel hook in `http.cpp`, since the first stage waits indefinitely |
| `quitApp(on:)` | `/cancel`, as in `Session::quitHostApp()` |
| `forget(_:)` | Clear the host's preference slot |
| `discoverHosts()` | New: `NWBrowser` for `_nvstream._tcp` (Info.plist already declares the Bonjour service) |

The core's HTTP calls block, so run them off the main thread.

### `StreamControlling`

Wraps `Session` (`client/streaming/session.cpp`). Today `Session` creates its
own SDL window and runs an SDL event loop on the main thread. To render into
the SwiftUI window instead:

- The Metal renderer (`vt_metal.mm`) takes its layer from
  `StreamSurfaceView.metalLayer` rather than `SDL_Metal_CreateView()`.
- `Session::exec()` stops owning the main thread; its per-event work runs from
  the app's run loop.
- Keyboard and mouse input comes from `StreamSurfaceView` (`NSEvent`) instead
  of SDL window events. Gamepads and audio can stay on SDL.
- Launch errors (`displayLaunchError()`, which only logs today) are thrown
  from `start(host:app:surface:)`, and unexpected disconnects are reported
  through `onTermination`.

The core supports one stream at a time.

### Preferences

`PreferenceKey` uses the same keys and values as
`client/settings/streamingpreferences.cpp`. When the app runs under the core's
bundle identifier, pass `UserDefaults.standard` to `StarlightScenes` and
Settings edits exactly what the core reads. `StreamingPreferences` is read
once, so call `reload()` before each stream.
