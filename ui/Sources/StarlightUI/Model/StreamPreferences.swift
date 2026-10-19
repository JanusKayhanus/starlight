import Foundation

/// Preference keys and values shared with the streaming core.
///
/// The keys and raw values match `client/settings/streamingpreferences.cpp`
/// exactly, so when the app runs under the core's bundle identifier the
/// Settings window edits the same values the core reads at launch. The mock
/// app points `@AppStorage` at a separate suite so it never touches them.
public enum PreferenceKey {
    public static let width = "width"
    public static let height = "height"
    public static let fps = "fps"
    public static let bitrate = "bitrate"
    public static let autoAdjustBitrate = "autoadjustbitrate"
    public static let videoCodec = "videocfg"
    public static let hdr = "hdr"
    public static let yuv444 = "yuv444"
    public static let videoDecoder = "videodec"
    public static let renderer = "renderer"
    public static let framePacing = "framepacing"
    public static let frameLatency = "framelatency"
    public static let windowMode = "windowmode"
    public static let keepAwake = "keepawake"
    public static let disableAwdl = "disableawdl"

    public static let captureSystemKeys = "capturesyskeys"
    /// Despite its name, this is the core's `absoluteMouseMode`.
    public static let absoluteMouse = "mouseacceleration"
    public static let swapMouseButtons = "swapmousebuttons"
    public static let reverseScroll = "reversescroll"
    public static let multiController = "multicontroller"
    public static let gamepadMouse = "gamepadmouse"
    public static let swapFaceButtons = "swapfacebuttons"
    public static let backgroundGamepad = "backgroundgamepad"

    public static let audioConfig = "audiocfg"
    public static let playAudioOnHost = "hostaudio"
    public static let muteOnFocusLoss = "muteonfocusloss"

    public static let mdns = "mdns"
    public static let quitAppAfter = "quitAppAfter"
    public static let showPerformanceOverlay = "showperfoverlay"
    public static let connectionWarnings = "connwarnings"
    public static let richPresence = "richpresence"
}

/// Defaults used when a key has never been written, matching
/// `StreamingPreferences::reload()`.
public enum PreferenceDefault {
    public static let width = 1920
    public static let height = 1080
    public static let fps = 60
    public static let bitrate = defaultBitrate(width: width, height: height, fps: fps, yuv444: false)
}

public enum VideoCodecPreference: Int, CaseIterable, Identifiable {
    case automatic = 0
    case h264 = 1
    case hevc = 2
    // 3 is the deprecated "HEVC HDR" value, which the core migrates away.
    case av1 = 4

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .h264: return "H.264"
        case .hevc: return "HEVC (H.265)"
        case .av1: return "AV1"
        }
    }
}

public enum VideoDecoderPreference: Int, CaseIterable, Identifiable {
    case automatic = 0
    case hardware = 1
    case software = 2

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .hardware: return "Hardware only"
        case .software: return "Software only"
        }
    }
}

public enum RendererPreference: Int, CaseIterable, Identifiable {
    case automatic = 0
    // 1 was the Qt build's Vulkan renderer and is no longer valid.
    case metal = 2
    case sampleBufferLayer = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Automatic"
        case .metal: return "Metal"
        case .sampleBufferLayer: return "AVSampleBufferDisplayLayer"
        }
    }
}

public enum FrameLatencyPreference: Int, CaseIterable, Identifiable {
    case `default` = 0
    case fast = 1
    case balanced = 2
    case smooth = 3

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .default: return "Default"
        case .fast: return "Fast (lowest latency)"
        case .balanced: return "Balanced"
        case .smooth: return "Smooth"
        }
    }
}

public enum WindowModePreference: Int, CaseIterable, Identifiable {
    case fullScreen = 0
    case borderless = 1
    case windowed = 2

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .fullScreen: return "Full Screen"
        case .borderless: return "Borderless"
        case .windowed: return "Window"
        }
    }
}

public enum CaptureSystemKeysPreference: Int, CaseIterable, Identifiable {
    case never = 0
    case inFullScreen = 1
    case always = 2

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .never: return "Never"
        case .inFullScreen: return "In Full Screen"
        case .always: return "Always"
        }
    }
}

public enum AudioConfigPreference: Int, CaseIterable, Identifiable {
    case stereo = 0
    case surround51 = 1
    case surround71 = 2

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .stereo: return "Stereo"
        case .surround51: return "5.1 Surround"
        case .surround71: return "7.1 Surround"
        }
    }
}

/// Port of `StreamingPreferences::getDefaultBitrate()`. Returns kbps.
public func defaultBitrate(width: Int, height: Int, fps: Int, yuv444: Bool) -> Int {
    // Don't scale bitrate linearly beyond 60 FPS.
    let fps = Double(fps)
    let frameRateFactor = (fps <= 60 ? fps : (60 * (fps / 60).squareRoot())) / 30

    let table: [(pixels: Int, factor: Double)] = [
        (640 * 360, 1),
        (854 * 480, 2),
        (1280 * 720, 5),
        (1920 * 1080, 10),
        (2560 * 1440, 20),
        (3840 * 2160, 40)
    ]

    let pixels = width * height
    var resolutionFactor = table[table.count - 1].factor
    for (index, entry) in table.enumerated() where pixels <= entry.pixels {
        if pixels == entry.pixels || index == 0 {
            resolutionFactor = entry.factor
        } else {
            // Interpolate between the neighbouring table entries.
            let lower = table[index - 1]
            let fraction = Double(pixels - lower.pixels) / Double(entry.pixels - lower.pixels)
            resolutionFactor = fraction * (entry.factor - lower.factor) + lower.factor
        }
        break
    }

    if yuv444 {
        // 4:4:4 doubles the raw YUV data compared to 4:2:0.
        resolutionFactor *= 2
    }

    return Int((resolutionFactor * frameRateFactor).rounded()) * 1000
}
