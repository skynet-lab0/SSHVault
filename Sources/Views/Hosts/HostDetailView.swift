import SwiftUI

struct HostDetailView: View {
    @EnvironmentObject var configService: SSHConfigService
    let hostID: UUID
    @Binding var selectedHost: SSHHost?
    var onEdit: (() -> Void)?
    @State private var availableKeys: [SSHKeyInfo] = []
    private let terminalPrefs = TerminalPreferences.shared

    /// Always read the latest version from the service
    private var host: SSHHost? {
        configService.hosts.first { $0.id == hostID }
    }

    var body: some View {
        if let host {
            detailContent(host)
        } else {
            Text("Host not found")
                .foregroundColor(.secondary)
        }
    }

    func detailContent(_ host: SSHHost) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(host.displayName)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        if !host.hostName.isEmpty {
                            Text(host.hostName)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        Button {
                            TerminalService.connect(to: host)
                        } label: {
                            Label("Connect", systemImage: "terminal")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(host.isWildcard)

                        Button {
                            onEdit?()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.bottom, 8)

                // Comment
                if !host.comment.isEmpty {
                    GroupBox("Comment") {
                        Text(host.comment.replacingOccurrences(of: "# ", with: ""))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Connection Details
                GroupBox("Connection") {
                    DetailGrid {
                        DetailRow(label: "Host Alias", value: host.host)
                        DetailRow(label: "HostName", value: host.hostName)
                        DetailRow(label: "User", value: host.user)
                        DetailRow(label: "Port", value: host.port.map(String.init) ?? "22")
                    }
                }

                // Terminal
                GroupBox("Terminal") {
                    DetailGrid {
                        let resolved = terminalPrefs.resolvedTerminal(for: host.host)
                        let hasOverride = terminalPrefs.hasOverride(for: host.host)
                        DetailRow(
                            label: "Terminal App",
                            value: resolved.displayName + (hasOverride ? " (override)" : " (default)")
                        )
                    }
                }

                // Authentication
                GroupBox("Authentication") {
                    VStack(alignment: .leading, spacing: 8) {
                        if host.identityFile.isEmpty {
                            HStack {
                                Text("Identity File")
                                    .foregroundColor(.secondary)
                                    .frame(width: 120, alignment: .trailing)
                                Text("None")
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .italic()
                                Spacer()
                                Menu {
                                    ForEach(availableKeys) { key in
                                        Button {
                                            assignKey(key, to: host)
                                        } label: {
                                            Label(
                                                "\(key.name) (\(key.keyType))",
                                                systemImage: "key"
                                            )
                                        }
                                    }
                                } label: {
                                    Label("Assign Key", systemImage: "key.fill")
                                        .font(.caption)
                                }
                                .menuStyle(.borderedButton)
                                .controlSize(.small)
                                .disabled(availableKeys.isEmpty)
                            }
                        } else {
                            HStack {
                                DetailGrid {
                                    DetailRow(label: "Identity File", value: host.identityFile)
                                }
                                Spacer()
                                Menu {
                                    ForEach(availableKeys) { key in
                                        Button {
                                            assignKey(key, to: host)
                                        } label: {
                                            HStack {
                                                Text(key.name)
                                                Text("(\(key.keyType))")
                                                    .foregroundColor(.secondary)
                                                if "~/.ssh/\(key.name)" == host.identityFile {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                    Divider()
                                    Button("Remove Key", role: .destructive) {
                                        removeKey(from: host)
                                    }
                                } label: {
                                    Label("Change", systemImage: "key")
                                        .font(.caption)
                                }
                                .menuStyle(.borderedButton)
                                .controlSize(.small)
                            }

                            Button {
                                TerminalService.copyKeyToHost(host, keyPath: host.identityFile)
                            } label: {
                                Label("Copy Public Key to Server", systemImage: "paperplane.fill")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Runs ssh-copy-id to install your public key on the server")
                            .disabled(host.isWildcard || host.hostName.isEmpty)
                        }

                        if host.forwardAgent {
                            DetailGrid {
                                DetailRow(label: "Forward Agent", value: "Yes")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Proxy
                if !host.proxyJump.isEmpty {
                    GroupBox("Proxy") {
                        DetailGrid {
                            DetailRow(label: "ProxyJump", value: host.proxyJump)
                        }
                    }
                }

                // Extra Options
                if !host.extraOptions.isEmpty {
                    GroupBox("Additional Options") {
                        DetailGrid {
                            ForEach(host.extraOptions.keys.sorted(), id: \.self) { key in
                                DetailRow(label: key, value: host.extraOptions[key] ?? "")
                            }
                        }
                    }
                }

                // SSH Command
                GroupBox("Quick Connect") {
                    HStack {
                        Text(host.sshCommand)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(host.sshCommand, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy SSH command")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
        }
        .onAppear {
            availableKeys = SSHKeyService.shared.listKeys()
        }
    }

    private func assignKey(_ key: SSHKeyInfo, to host: SSHHost) {
        var updated = host
        updated.identityFile = "~/.ssh/\(key.name)"
        configService.updateHost(updated)
    }

    private func removeKey(from host: SSHHost) {
        var updated = host
        updated.identityFile = ""
        configService.updateHost(updated)
    }
}

// MARK: - Helper Views

struct DetailGrid<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Grid(alignment: .leadingFirstTextBaseline, verticalSpacing: 8) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .trailing)
            Text(value.isEmpty ? "—" : value)
                .textSelection(.enabled)
        }
    }
}
