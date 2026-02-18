import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var tm = ThemeManager.shared

    private var t: AppTheme { tm.current }
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 8)

            Image(systemName: "server.rack")
                .font(.system(size: 44, weight: .thin))
                .foregroundColor(t.accent)

            Text("SSHMan")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(t.foreground)

            Text("Version \(version)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(t.secondary)

            Text("A lightweight macOS SSH connection manager.\nManage hosts, keys, and SFTP connections.")
                .font(.system(size: 12))
                .foregroundColor(t.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Divider().padding(.horizontal, 30)

            VStack(spacing: 8) {
                linkRow(label: "GitHub", url: "https://github.com/LZDevs/SSHMan", icon: "chevron.left.forwardslash.chevron.right")
                linkRow(label: "Releases", url: "https://github.com/LZDevs/SSHMan/releases", icon: "arrow.down.circle")
                linkRow(label: "Report Issue", url: "https://github.com/LZDevs/SSHMan/issues", icon: "exclamationmark.bubble")
            }

            Divider().padding(.horizontal, 30)

            Text("Made by LZDevs")
                .font(.system(size: 11))
                .foregroundColor(t.secondary.opacity(0.6))

            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.cancelAction)

            Spacer().frame(height: 8)
        }
        .frame(width: 300)
        .padding(.vertical, 8)
    }

    private func linkRow(label: String, url: String, icon: String) -> some View {
        Button {
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 16)
                    .foregroundColor(t.accent)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(t.foreground)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9))
                    .foregroundColor(t.secondary.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(t.surface.opacity(0.5)))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 30)
    }
}
