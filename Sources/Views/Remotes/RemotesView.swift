import SwiftUI

struct RemotesView: View {
    @EnvironmentObject var configService: SSHConfigService
    @ObservedObject var remoteSession: RemoteSessionService
    @ObservedObject private var tm = ThemeManager.shared

    @State private var showingAddRemote = false
    @State private var targetToRename: RemoteTarget?
    @State private var renameName = ""
    @State private var targetToDelete: RemoteTarget?
    @State private var showDeleteConfirm = false

    private var t: AppTheme { tm.current }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5)

            if remoteSession.currentRemote != nil {
                RemoteDetailView(remoteSession: remoteSession, onClose: { remoteSession.close() })
            } else {
                targetList
            }
        }
        .background(t.background)
        .sheet(isPresented: $showingAddRemote) { AddRemoteSheet(configService: configService, remoteSession: remoteSession) }
        .alert("Rename Remote", isPresented: .init(
            get: { targetToRename != nil },
            set: { if !$0 { targetToRename = nil } }
        )) {
            TextField("Name", text: $renameName)
            Button("Cancel", role: .cancel) { targetToRename = nil }
            Button("Rename") {
                if let target = targetToRename, !renameName.isEmpty {
                    remoteSession.renameTarget(target, to: renameName)
                }
                targetToRename = nil
            }
        } message: {
            Text("Display name for this remote connection.")
        }
        .alert("Delete Remote?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let target = targetToDelete { remoteSession.removeTarget(target) }
            }
        } message: {
            if let target = targetToDelete {
                Text("Remove \"\(target.name)\" from the list? This does not change the remote server.")
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Remote SSH")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(t.foreground)
            Spacer()
            Button {
                showingAddRemote = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                    Text("Add remote").font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(t.accent)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(t.accent.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .help("Add a host from your local config to manage its remote ~/.ssh")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var targetList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let err = remoteSession.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(t.orange)
                        Text(err).font(.system(size: 11)).foregroundColor(t.orange).lineLimit(3)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(t.orange.opacity(0.1)))
                    .padding(.horizontal, 16)
                }

                if remoteSession.remoteTargets.isEmpty {
                    emptyState
                } else {
                    ForEach(remoteSession.remoteTargets) { target in
                        targetRow(target)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func targetRow(_ target: RemoteTarget) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .font(.system(size: 14))
                .foregroundColor(t.accent.opacity(0.8))
                .frame(width: 28, height: 28)
            Text(target.name)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(t.foreground)
                .lineLimit(1)
            Text(target.hostAlias)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundColor(t.secondary)
                .lineLimit(1)
            Spacer()
            if remoteSession.isLoading && remoteSession.currentRemote?.id == target.id {
                ProgressView().scaleEffect(0.7)
            } else {
                Button("Open") {
                    remoteSession.open(target)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(t.accent)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 9).fill(t.surface.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.secondary.opacity(0.2), lineWidth: 0.5))
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                renameName = target.name
                targetToRename = target
            } label: { Label("Rename", systemImage: "pencil") }
            Button(role: .destructive) {
                targetToDelete = target
                showDeleteConfirm = true
            } label: { Label("Delete", systemImage: "trash") }
        }
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            Image(systemName: "network")
                .font(.system(size: 32))
                .foregroundColor(t.secondary.opacity(0.5))
            Text("No remote targets")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(t.secondary)
            Text("Add a host from your local SSH config to manage its remote ~/.ssh")
                .font(.system(size: 11))
                .foregroundColor(t.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button { showingAddRemote = true } label: {
                Text("Add remote").font(.system(size: 12, weight: .medium))
                    .foregroundColor(t.accent)
            }
            .buttonStyle(.plain)
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Sheet to pick a local host and add as RemoteTarget
struct AddRemoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var configService: SSHConfigService
    @ObservedObject var remoteSession: RemoteSessionService
    @ObservedObject private var tm = ThemeManager.shared

    private var t: AppTheme { tm.current }
    private var localHosts: [SSHHost] {
        configService.hosts.filter { !$0.isWildcard }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add remote target")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()
            Text("Choose a host from your local SSH config. SSHVault will connect to it and manage its ~/.ssh directory.")
                .font(.system(size: 12))
                .foregroundColor(t.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
            List(localHosts) { host in
                Button {
                    let target = RemoteTarget(name: host.displayName, hostAlias: host.host)
                    remoteSession.addTarget(target)
                    dismiss()
                } label: {
                    HStack {
                        Text(host.displayName).foregroundColor(t.foreground)
                        Text(host.host).font(.system(size: 11, design: .monospaced)).foregroundColor(t.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
        .frame(width: 380, height: 320)
    }
}
