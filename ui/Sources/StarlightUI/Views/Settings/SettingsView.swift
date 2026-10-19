import AppKit
import SwiftUI

/// The Settings window (⌘,). Every control is bound with `@AppStorage` to a
/// key the core already reads (see `PreferenceKey`).
public struct SettingsView: View {
    public init() {}

    public var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            VideoSettings()
                .tabItem { Label("Video", systemImage: "display") }
            InputSettings()
                .tabItem { Label("Input", systemImage: "keyboard") }
            AudioSettings()
                .tabItem { Label("Audio", systemImage: "speaker.wave.2") }
        }
        .frame(width: 520)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @AppStorage(PreferenceKey.mdns) private var findComputers = true
    @AppStorage(PreferenceKey.quitAppAfter) private var quitAppAfter = false
    @AppStorage(PreferenceKey.keepAwake) private var keepAwake = true
    @AppStorage(PreferenceKey.disableAwdl) private var disableAwdl = true
    @AppStorage(PreferenceKey.showPerformanceOverlay) private var showPerformanceOverlay = false
    @AppStorage(PreferenceKey.connectionWarnings) private var connectionWarnings = true
    @AppStorage(PreferenceKey.richPresence) private var richPresence = true

    var body: some View {
        Form {
            Section {
                Toggle("Find computers on the local network", isOn: $findComputers)
                Toggle("Quit the app on the computer when disconnecting", isOn: $quitAppAfter)
            }
            Section {
                Toggle("Keep this Mac awake while connected", isOn: $keepAwake)
                Toggle("Turn off AirDrop while connected", isOn: $disableAwdl)
            } footer: {
                Text("AirDrop’s wireless scanning can cause stutter on Wi‑Fi.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Toggle("Show performance statistics", isOn: $showPerformanceOverlay)
                Toggle("Warn about poor connection quality", isOn: $connectionWarnings)
                Toggle("Show activity in Discord", isOn: $richPresence)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Video

private struct VideoSettings: View {
    @AppStorage(PreferenceKey.width) private var width = PreferenceDefault.width
    @AppStorage(PreferenceKey.height) private var height = PreferenceDefault.height
    @AppStorage(PreferenceKey.fps) private var fps = PreferenceDefault.fps
    @AppStorage(PreferenceKey.bitrate) private var bitrate = PreferenceDefault.bitrate
    @AppStorage(PreferenceKey.autoAdjustBitrate) private var autoAdjustBitrate = true
    @AppStorage(PreferenceKey.videoCodec) private var codec = VideoCodecPreference.automatic.rawValue
    @AppStorage(PreferenceKey.hdr) private var hdr = false
    @AppStorage(PreferenceKey.yuv444) private var yuv444 = false
    @AppStorage(PreferenceKey.framePacing) private var framePacing = false
    @AppStorage(PreferenceKey.frameLatency) private var frameLatency = FrameLatencyPreference.default.rawValue
    @AppStorage(PreferenceKey.windowMode) private var windowMode = WindowModePreference.borderless.rawValue
    @AppStorage(PreferenceKey.renderer) private var renderer = RendererPreference.automatic.rawValue
    @AppStorage(PreferenceKey.videoDecoder) private var decoder = VideoDecoderPreference.automatic.rawValue

    private static let frameRates = [30, 60, 90, 120, 144, 165, 240]

    var body: some View {
        Form {
            Section {
                Picker("Resolution", selection: resolution) {
                    ForEach(resolutionChoices) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                Picker("Frame rate", selection: $fps) {
                    ForEach(frameRateChoices, id: \.self) { rate in
                        Text("\(rate) FPS").tag(rate)
                    }
                }
                Picker("Open streams in", selection: $windowMode) {
                    ForEach(WindowModePreference.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
            }

            Section {
                LabeledContent("Bitrate") {
                    HStack {
                        Slider(value: bitrateMbps, in: 1...500)
                        Text("\(bitrate / 1000) Mbps")
                            .monospacedDigit()
                            .frame(width: 70, alignment: .trailing)
                    }
                }
                Toggle("Adjust bitrate for network conditions", isOn: $autoAdjustBitrate)
                Button("Use Recommended Bitrate") {
                    bitrate = defaultBitrate(width: width, height: height, fps: fps, yuv444: yuv444)
                }
            }

            Section {
                Picker("Video codec", selection: $codec) {
                    ForEach(VideoCodecPreference.allCases) { codec in
                        Text(codec.title).tag(codec.rawValue)
                    }
                }
                Toggle(isOn: $yuv444) {
                    Text("Full-color 4:4:4")
                    Text("Sharper text. Uses more bandwidth.")
                }
                Toggle(isOn: $hdr) {
                    Text("HDR")
                    Text("Needs an HDR display on this Mac and the host.")
                }
            }

            Section {
                Picker("Frame latency", selection: $frameLatency) {
                    ForEach(FrameLatencyPreference.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                Toggle("Frame pacing", isOn: $framePacing)
                Picker("Renderer", selection: $renderer) {
                    ForEach(RendererPreference.allCases) { renderer in
                        Text(renderer.title).tag(renderer.rawValue)
                    }
                }
                Picker("Decoder", selection: $decoder) {
                    ForEach(VideoDecoderPreference.allCases) { decoder in
                        Text(decoder.title).tag(decoder.rawValue)
                    }
                }
            } header: {
                Text("Advanced")
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var frameRateChoices: [Int] {
        Self.frameRates.contains(fps) ? Self.frameRates : (Self.frameRates + [fps]).sorted()
    }

    /// The standard choices, plus the saved resolution if it's a custom one
    /// (for example, set with --resolution on the command line).
    private var resolutionChoices: [Resolution] {
        let choices = Resolution.choices
        let current = Resolution(width: width, height: height, title: "\(width) × \(height)")
        return choices.contains(current) ? choices : choices + [current]
    }

    private var resolution: Binding<Resolution> {
        Binding {
            Resolution(width: width, height: height, title: "")
        } set: { choice in
            width = choice.width
            height = choice.height
        }
    }

    private var bitrateMbps: Binding<Double> {
        Binding {
            Double(bitrate) / 1000
        } set: { mbps in
            bitrate = Int(mbps.rounded()) * 1000
        }
    }
}

/// A resolution choice for the Video tab.
private struct Resolution: Hashable, Identifiable {
    var width: Int
    var height: Int
    var title: String

    var id: String { "\(width)x\(height)" }

    static func == (lhs: Resolution, rhs: Resolution) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }

    @MainActor
    static var choices: [Resolution] {
        var choices = [
            Resolution(width: 1280, height: 720, title: "720p"),
            Resolution(width: 1920, height: 1080, title: "1080p"),
            Resolution(width: 2560, height: 1440, title: "1440p"),
            Resolution(width: 3840, height: 2160, title: "4K")
        ]

        // Offer this Mac's own display at full Retina resolution.
        if let screen = NSScreen.main {
            let scale = screen.backingScaleFactor
            let native = Resolution(width: Int(screen.frame.width * scale),
                                    height: Int(screen.frame.height * scale),
                                    title: "This Mac’s display (\(Int(screen.frame.width * scale)) × \(Int(screen.frame.height * scale)))")
            if !choices.contains(native) {
                choices.append(native)
            }
        }
        return choices
    }
}

// MARK: - Input

private struct InputSettings: View {
    @AppStorage(PreferenceKey.captureSystemKeys) private var captureSystemKeys = CaptureSystemKeysPreference.never.rawValue
    @AppStorage(PreferenceKey.absoluteMouse) private var absoluteMouse = false
    @AppStorage(PreferenceKey.swapMouseButtons) private var swapMouseButtons = false
    @AppStorage(PreferenceKey.reverseScroll) private var reverseScroll = false
    @AppStorage(PreferenceKey.multiController) private var multiController = true
    @AppStorage(PreferenceKey.gamepadMouse) private var gamepadMouse = true
    @AppStorage(PreferenceKey.swapFaceButtons) private var swapFaceButtons = false
    @AppStorage(PreferenceKey.backgroundGamepad) private var backgroundGamepad = false

    var body: some View {
        Form {
            Section {
                Picker("Send system shortcuts to the computer", selection: $captureSystemKeys) {
                    ForEach(CaptureSystemKeysPreference.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
            } footer: {
                Text("Includes ⌘Tab, Mission Control and Spotlight.")
                    .foregroundStyle(.secondary)
            }
            Section("Mouse") {
                Toggle(isOn: $absoluteMouse) {
                    Text("Optimize for remote desktop")
                    Text("The remote pointer follows your cursor exactly.")
                }
                Toggle("Swap left and right buttons", isOn: $swapMouseButtons)
                Toggle("Reverse scroll direction", isOn: $reverseScroll)
            }
            Section("Game Controllers") {
                Toggle("Treat each controller as a separate player", isOn: $multiController)
                Toggle("Use a controller as a mouse (hold Start)", isOn: $gamepadMouse)
                Toggle("Swap A/B and X/Y buttons", isOn: $swapFaceButtons)
                Toggle("Keep controllers working in the background", isOn: $backgroundGamepad)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Audio

private struct AudioSettings: View {
    @AppStorage(PreferenceKey.audioConfig) private var audioConfig = AudioConfigPreference.stereo.rawValue
    @AppStorage(PreferenceKey.playAudioOnHost) private var playAudioOnHost = false
    @AppStorage(PreferenceKey.muteOnFocusLoss) private var muteOnFocusLoss = false

    var body: some View {
        Form {
            Picker("Channels", selection: $audioConfig) {
                ForEach(AudioConfigPreference.allCases) { config in
                    Text(config.title).tag(config.rawValue)
                }
            }
            Toggle("Play sound on the remote computer too", isOn: $playAudioOnHost)
            Toggle("Mute when Starlight isn’t the active app", isOn: $muteOnFocusLoss)
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }
}
