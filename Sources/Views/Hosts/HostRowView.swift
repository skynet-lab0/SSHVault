import SwiftUI
import AppKit

struct HostRowView: View {
    let host: SSHHost
    var isSelected: Bool = false
    var onEdit: (() -> Void)?
    var onConnect: (() -> Void)?
    /// When set, single/double tap on the left part (icon+text) triggers these; edit button is not covered.
    var onSingleClick: ((NSEvent.ModifierFlags) -> Void)?
    var onDoubleClick: (() -> Void)?

    @ObservedObject private var tm = ThemeManager.shared
    @ObservedObject private var prefs = TerminalPreferences.shared
    @State private var isHovered = false
    @State private var singleTapWork: DispatchWorkItem?
    private var t: AppTheme { tm.current }

    private var leftContent: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(host.isWildcard
                        ? t.orange.opacity(0.15)
                        : t.accent.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: host.isWildcard ? "asterisk" : (host.icon.isEmpty ? "server.rack" : host.icon))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(host.isWildcard ? t.orange : t.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(host.displayName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(t.foreground)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !host.hostName.isEmpty {
                    Text(connectionString)
                        .font(.system(size: 10.5))
                        .foregroundColor(t.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    var body: some View {
        HStack(spacing: 10) {
            if onSingleClick != nil || onDoubleClick != nil {
                leftContent
                    .onTapGesture(count: 2) {
                        singleTapWork?.cancel()
                        singleTapWork = nil
                        onDoubleClick?()
                    }
                    .onTapGesture(count: 1) {
                        guard let onSingleClick else { return }
                        let flags = NSEvent.modifierFlags
                        singleTapWork?.cancel()
                        let work = DispatchWorkItem { onSingleClick(flags) }
                        singleTapWork = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
                    }
            } else {
                leftContent
            }

            if let onEdit {
                Button(action: onEdit) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isHovered ? t.accent.opacity(0.2) : t.surface.opacity(0.6))
                            .frame(width: 26, height: 26)
                        Image(systemName: "pencil")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(isHovered ? t.accent : t.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Edit host")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(isHovered
                    ? t.surface.opacity(0.9)
                    : (isSelected ? t.accent.opacity(0.2) : t.surface.opacity(0.6)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .strokeBorder(
                    isSelected ? t.accent : (isHovered ? t.accent.opacity(0.4) : t.secondary.opacity(0.2)),
                    lineWidth: isSelected ? 2 : 0.5
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("SSH Host \(host.displayName)")
        .accessibilityHint("Click Edit to edit, double-click to connect. Hold Command or Control and click to multi-select.")
        .accessibilityAction(.default) { onConnect?() }
    }

    private var connectionString: String {
        let displayHost = prefs.maskHostIP ? "***.***.***.***" : host.hostName
        var parts: [String] = []
        if !host.user.isEmpty {
            parts.append("\(host.user)@\(displayHost)")
        } else {
            parts.append(displayHost)
        }
        if let port = host.port, port != TerminalService.defaultSSHPort {
            parts.append(":\(port)")
        }
        return parts.joined()
    }
}
