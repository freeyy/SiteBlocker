import SwiftUI
import AppKit

// Renders the app icon master (1024×1024 PNG) used by Scripts/make-icon.sh to build AppIcon.icns.

struct IconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 224, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.42, green: 0.36, blue: 0.92),
                                 Color(red: 0.29, green: 0.55, blue: 0.98)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 224, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 6)
                )
                .shadow(color: .black.opacity(0.25), radius: 30, y: 16)
                .padding(96)

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 460, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        }
        .frame(width: 1024, height: 1024)
    }
}

@main
struct IconMain {
    @MainActor
    static func main() {
        NSApplication.shared.setActivationPolicy(.accessory)
        let renderer = ImageRenderer(content: IconView())
        renderer.scale = 1
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("icon render failed"); return
        }
        let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/AppIcon-master.png"
        try? png.write(to: URL(fileURLWithPath: out))
        print("wrote \(out)")
    }
}
