import SwiftUI

/// A transient message shown as a floating toast.
struct ToastInfo: Identifiable, Equatable {
    enum Kind { case info, success, error }
    let id = UUID()
    let kind: Kind
    let message: String
}

/// A compact, floating toast card. Rendered as an overlay (no layout impact) so it never pushes
/// or overlaps the rest of the window. Tap to dismiss; also auto-dismisses.
struct ToastView: View {
    let toast: ToastInfo
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.system(size: 15, weight: .semibold))
            Text(toast.message)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 460)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
    }

    private var icon: String {
        switch toast.kind {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    private var tint: Color {
        switch toast.kind {
        case .info: return .accentColor
        case .success: return .green
        case .error: return .red
        }
    }
}
