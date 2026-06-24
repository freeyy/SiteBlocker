import SwiftUI

/// A full-window dimming overlay with a spinner + message, shown while a privileged operation runs
/// (e.g. installing the background service, which can take several seconds while macOS prompts for
/// a password). It captures all interaction so the UI reads as "busy", not "frozen".
struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
            .frame(minWidth: 220)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        }
        .contentShape(Rectangle())
        .transition(.opacity)
    }
}
