import SwiftUI

extension RemoteHost {
    /// The one-line status under the host's name.
    var statusLine: String {
        switch status {
        case .unknown:
            return "Checking…"
        case .online:
            return "Online · \(address)"
        case .busy:
            return "\(runningApp?.name ?? "App") running · \(address)"
        case .offline:
            return canWake ? "Offline · Wake on LAN available" : "Offline"
        case .unpaired:
            return "Not paired · \(address)"
        }
    }

    var statusColor: Color {
        switch status {
        case .unknown, .offline:
            return .secondary
        case .online:
            return .green
        case .busy:
            return .accentColor
        case .unpaired:
            return .orange
        }
    }
}

struct StatusDot: View {
    var color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .accessibilityHidden(true)
    }
}

/// The small monitor next to each host's name.
struct HostThumbnail: View {
    var host: RemoteHost

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        let lit = host.isReachable && host.isPaired

        shape
            .fill(lit ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(Color.primary.opacity(0.08)))
            .overlay(alignment: .topLeading) {
                if lit {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(.white.opacity(0.85))
                        .frame(width: 20, height: 13)
                        .offset(x: 7, y: 6)
                }
            }
            .overlay {
                shape.strokeBorder(Color.primary.opacity(0.25), lineWidth: 2)
            }
            .frame(width: 44, height: 32)
            .accessibilityHidden(true)
    }
}
