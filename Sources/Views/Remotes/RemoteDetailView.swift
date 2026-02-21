import SwiftUI
import AppKit

struct RemoteDetailView: View {
    @EnvironmentObject var hostClipboard: HostClipboardService
    @ObservedObject var remoteSession: RemoteSessionService
    var onClose: () -> Void
    @ObservedObject private var tm = ThemeManager.shared

    @State private var selectedSegment = 0
    @State private var searchText = ""
    @State private var showingAddGroup = false
    @State private var newGroupName = ""
    @State private var hostsToDelete: [SSHHost] = []
    @State private var showDeleteConfirm = false
    @State private var groupToRename: HostGroup?
    @State private var renameGroupName = ""
    @State private var groupToDelete: HostGroup?
    @State private var showDeleteGroupConfirm = false
    @State private var selectedHostIDs: Set<UUID> = []
    @State private var copiedKeyID: String?

    private var t: AppTheme { tm.current }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5)

            Picker("", selection: $selectedSegment) {
                Text("Hosts").tag(0)
                Text("Keys").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if selectedSegment == 0 {
                hostsContent
            } else {
                keysContent
            }
        }
        .background(t.background)
        .overlay { if selectedSegment == 0 { hostListKeyboardShortcuts } else { EmptyView() } }
        .alert("New Group", isPresented: $showingAddGroup) {
            TextField("Group name", text: $newGroupName)
            Button("Cancel", role: .cancel) { newGroupName = "" }
            Button("Create") {
                if !newGroupName.isEmpty {
                    remoteSession.addGroup(HostGroup(name: newGroupName))
                    newGroupName = ""
                }
            }
        }
        .alert("Rename Group", isPresented: .init(
            get: { groupToRename != nil },
            set: { if !$0 { groupToRename = nil } }
        )) {
            TextField("Group name", text: $renameGroupName)
            Button("Cancel", role: .cancel) { groupToRename = nil }
            Button("Rename") {
                if let group = groupToRename, !renameGroupName.isEmpty {
                    remoteSession.renameGroup(group, to: renameGroupName)
                }
                groupToRename = nil
            }
        }
        .alert("Delete Group?", isPresented: $showDeleteGroupConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let group = groupToDelete { remoteSession.deleteGroup(group) }
            }
        } message: {
            if let group = groupToDelete {
                Text("Delete \"\(group.name)\"? Hosts will become ungrouped.")
            }
        }
        .alert(hostsToDelete.count > 1 ? "Delete \(hostsToDelete.count) Hosts?" : "Delete Host?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { hostsToDelete = [] }
            Button("Delete", role: .destructive) {
                for host in hostsToDelete { remoteSession.deleteHost(host) }
                hostsToDelete = []
                selectedHostIDs.removeAll()
            }
        } message: {
            if hostsToDelete.count == 1, let host = hostsToDelete.first {
                Text("Delete \"\(host.displayName)\" on the remote?")
            } else if hostsToDelete.count > 1 {
                Text("Delete \(hostsToDelete.count) hosts on the remote?")
            }
        }
    }

    private var detailHeader: some View {
        HStack {
            Text(remoteSession.currentRemote?.name ?? "Remote")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(t.foreground)
            Spacer()
            Button("Refresh") { remoteSession.refresh() }
                .font(.system(size: 11))
                .foregroundColor(t.secondary)
                .buttonStyle(.plain)
            Button("Close") { onClose() }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(t.accent)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var sortedGroups: [HostGroup] {
        remoteSession.groups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredHosts: [SSHHost] {
        let base = searchText.isEmpty
            ? remoteSession.hosts
            : remoteSession.hosts.filter {
                let q = searchText.lowercased()
                return $0.host.lowercased().contains(q) ||
                    $0.hostName.lowercased().contains(q) ||
                    $0.user.lowercased().contains(q)
              }
        return base.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private var ungroupedHosts: [SSHHost] {
        if remoteSession.groups.isEmpty { return filteredHosts }
        let allGrouped = Set(remoteSession.groups.flatMap { $0.hostIDs })
        return filteredHosts.filter { !allGrouped.contains($0.host) }
    }

    private var hostsContent: some View {
        VStack(spacing: 0) {
            remoteSearchBar
            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5).padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if filteredHosts.isEmpty && !searchText.isEmpty {
                        Text("No results for \"\(searchText)\"")
                            .font(.system(size: 13))
                            .foregroundColor(t.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        if !remoteSession.groups.isEmpty { remoteGroupedSections }
                        remoteUngroupedSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }

            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5)
            HStack {
                Button { showingAddGroup = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus").font(.system(size: 12))
                        Text("New Group").font(.system(size: 11))
                    }
                    .foregroundColor(t.secondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("\(remoteSession.hosts.count) host\(remoteSession.hosts.count == 1 ? "" : "s")")
                    .font(.system(size: 10.5))
                    .foregroundColor(t.secondary.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private var remoteSearchBar: some View {
        HStack(spacing: 8) {
            Button {
                remoteSession.showingAddHost = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(t.accent.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(t.accent)
                }
            }
            .buttonStyle(.plain)
            .help("Add host on remote")

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(t.secondary)
                    .font(.system(size: 12, weight: .medium))
                TextField("Search hosts...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundColor(t.foreground)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(t.secondary).font(.system(size: 11))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7).fill(t.surface.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(t.secondary.opacity(0.2), lineWidth: 0.5))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var remoteGroupedSections: some View {
        ForEach(sortedGroups) { group in
            let groupHosts = filteredHosts.filter { group.hostIDs.contains($0.host) }
            if !groupHosts.isEmpty || searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    remoteSectionHeader(group.name, group: group)
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(groupHosts) { host in remoteHostTile(host) }
                    }
                }
                .dropDestination(for: String.self) { aliases, _ in
                    for a in aliases {
                        guard let h = remoteSession.hosts.first(where: { $0.host == a }) else { continue }
                        remoteSession.moveHost(h, to: group)
                    }
                    return !aliases.isEmpty
                }
            }
        }
    }

    @ViewBuilder
    private var remoteUngroupedSection: some View {
        let hosts = ungroupedHosts
        if !hosts.isEmpty || remoteSession.groups.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                remoteSectionHeader(remoteSession.groups.isEmpty ? "Hosts" : "Ungrouped", group: nil)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(hosts) { host in remoteHostTile(host) }
                }
            }
            .dropDestination(for: String.self) { aliases, _ in
                for a in aliases {
                    guard let h = remoteSession.hosts.first(where: { $0.host == a }) else { continue }
                    remoteSession.removeHostFromGroups(h)
                }
                return !aliases.isEmpty
            }
        }
    }

    private func remoteSectionHeader(_ title: String, group: HostGroup?) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundColor(t.secondary)
                .tracking(0.6)
            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5)
            if group != nil {
                Button {
                    remoteSession.showingAddHost = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(t.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 2)
        .contentShape(Rectangle())
        .contextMenu {
            if let group {
                Button { renameGroupName = group.name; groupToRename = group } label: { Label("Rename", systemImage: "pencil") }
                Divider()
                Button { remoteSession.moveGroupUp(group) } label: { Label("Move Up", systemImage: "arrow.up") }
                    .disabled(sortedGroups.first?.id == group.id)
                Button { remoteSession.moveGroupDown(group) } label: { Label("Move Down", systemImage: "arrow.down") }
                    .disabled(sortedGroups.last?.id == group.id)
                Divider()
                Button(role: .destructive) { groupToDelete = group; showDeleteGroupConfirm = true } label: { Label("Delete Group", systemImage: "trash") }
            }
        }
    }

    private func remoteHostTile(_ host: SSHHost) -> some View {
        let isSelected = selectedHostIDs.contains(host.id)
        let contextMenuTargets: [SSHHost] = isSelected
            ? remoteSession.hosts.filter { selectedHostIDs.contains($0.id) }
            : [host]

        return HostRowView(host: host, isSelected: isSelected, onEdit: { remoteSession.editingHost = host }, onConnect: { connectToHostOnRemote(host) })
            .modifier(HostTileClickModifier(hostID: host.id, selectedHostIDs: $selectedHostIDs, onDoubleClick: { connectToHostOnRemote(host) }))
            .draggable(host.host)
            .contextMenu {
                Button { connectToHostOnRemote(host) } label: { Label("Connect", systemImage: "terminal") }
                Button { remoteSession.editingHost = host } label: { Label("Edit", systemImage: "pencil") }
                if !host.isWildcard {
                    Button { duplicateRemoteHost(host) } label: { Label("Duplicate", systemImage: "doc.on.doc") }
                }
                let copyTargets = contextMenuTargets.filter { !$0.isWildcard }
                if !copyTargets.isEmpty {
                    Button { hostClipboard.copy(copyTargets) } label: {
                        Label(copyTargets.count > 1 ? "Copy (\(copyTargets.count) hosts)" : "Copy", systemImage: "doc.on.clipboard")
                    }
                }
                if hostClipboard.hasContent {
                    Button { pasteToRemote(ontoGroupOf: host) } label: {
                        Label(hostClipboard.hosts.count > 1 ? "Paste (\(hostClipboard.hosts.count) hosts)" : "Paste", systemImage: "doc.on.clipboard.fill")
                    }
                }
                Divider()
                if !remoteSession.groups.isEmpty {
                    Menu(contextMenuTargets.count > 1 ? "Move to Group (\(contextMenuTargets.count) hosts)" : "Move to Group") {
                        ForEach(sortedGroups) { g in
                            Button(g.name) {
                                for target in contextMenuTargets { remoteSession.moveHost(target, to: g) }
                                selectedHostIDs.removeAll()
                            }
                        }
                        Divider()
                        Button("Remove from Group") {
                            for target in contextMenuTargets { remoteSession.removeHostFromGroups(target) }
                            selectedHostIDs.removeAll()
                        }
                    }
                }
                Divider()
                Button(role: .destructive) {
                    hostsToDelete = contextMenuTargets
                    showDeleteConfirm = true
                } label: {
                    Label(contextMenuTargets.count > 1 ? "Delete (\(contextMenuTargets.count) hosts)" : "Delete", systemImage: "trash")
                }
            }
    }

    private func connectToHostOnRemote(_ host: SSHHost) {
        guard let target = remoteSession.currentRemote,
              let sshHost = remoteSession.resolveHost(for: target) else { return }
        TerminalService.connectToHostOnRemote(remoteHost: sshHost, hostAliasOnRemote: host.host)
    }

    private func duplicateRemoteHost(_ host: SSHHost) {
        guard !host.isWildcard else { return }
        let taken = Set(remoteSession.hosts.map(\.host))
        var alias = host.host.isEmpty ? "copy" : host.host + "-copy"
        var counter = 2
        while taken.contains(alias) {
            alias = (host.host.isEmpty ? "copy" : host.host + "-copy") + "-\(counter)"
            counter += 1
        }
        let copy = SSHHost(
            id: UUID(),
            host: SSHConfig.sanitizeAlias(alias),
            label: host.label.isEmpty ? alias : host.label + " (copy)",
            hostName: host.hostName,
            user: host.user,
            port: host.port,
            identityFile: host.identityFile,
            proxyJump: host.proxyJump,
            forwardAgent: host.forwardAgent,
            icon: host.icon,
            sftpPath: host.sftpPath,
            sshInitPath: host.sshInitPath,
            extraOptions: host.extraOptions,
            comment: host.comment
        )
        remoteSession.addHost(copy)
        for i in remoteSession.groups.indices {
            if remoteSession.groups[i].hostIDs.contains(host.host) {
                remoteSession.groups[i].hostIDs.append(copy.host)
            }
        }
        remoteSession.saveRemoteGroups()
        remoteSession.editingHost = copy
    }

    private func pasteToRemote(ontoGroupOf rightClickedHost: SSHHost?) {
        let existing = Set(remoteSession.hosts.map(\.host))
        let toAdd = hostClipboard.prepareForPaste(existingAliases: existing)
        for h in toAdd { remoteSession.addHost(h) }
        if let rightClickedHost,
           let idx = remoteSession.groups.firstIndex(where: { $0.hostIDs.contains(rightClickedHost.host) }) {
            for h in toAdd { remoteSession.groups[idx].hostIDs.append(h.host) }
            remoteSession.saveRemoteGroups()
        }
    }

    private var selectedHosts: [SSHHost] {
        remoteSession.hosts.filter { selectedHostIDs.contains($0.id) }
    }

    private func performCopy() {
        let copyTargets = selectedHosts.filter { !$0.isWildcard }
        if !copyTargets.isEmpty { hostClipboard.copy(copyTargets) }
    }

    private func performPaste() {
        guard hostClipboard.hasContent else { return }
        let target = selectedHosts.count == 1 ? selectedHosts.first : nil
        pasteToRemote(ontoGroupOf: target)
    }

    private func performDelete() {
        guard !selectedHosts.isEmpty else { return }
        hostsToDelete = selectedHosts
        showDeleteConfirm = true
    }

    private func performDuplicate() {
        guard selectedHosts.count == 1, let host = selectedHosts.first, !host.isWildcard else { return }
        duplicateRemoteHost(host)
    }

    @ViewBuilder
    private var hostListKeyboardShortcuts: some View {
        Group {
            Button("Copy", action: performCopy)
                .keyboardShortcut("c", modifiers: .command)
            Button("Paste", action: performPaste)
                .keyboardShortcut("v", modifiers: .command)
            Button("Delete", action: performDelete)
                .keyboardShortcut(.delete, modifiers: [])
            Button("Duplicate", action: performDuplicate)
                .keyboardShortcut("d", modifiers: .command)
        }
        .frame(width: 0, height: 0).opacity(0).allowsHitTesting(false)
    }

    private var sortedKeys: [SSHKeyInfo] {
        remoteSession.keys.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var keysContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                if remoteSession.keys.isEmpty {
                    VStack(spacing: 10) {
                        Spacer().frame(height: 40)
                        Image(systemName: "key.fill")
                            .font(.system(size: 28))
                            .foregroundColor(t.accent.opacity(0.5))
                        Text("No keys on remote")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(t.secondary)
                        Spacer().frame(height: 40)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(sortedKeys) { key in remoteKeyCard(key) }
                }
            }
            .padding(16)
        }
    }

    private func remoteKeyCard(_ key: SSHKeyInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(t.pink.opacity(0.12)).frame(width: 34, height: 34)
                    Image(systemName: "key.fill").font(.system(size: 13, weight: .medium)).foregroundColor(t.pink)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(key.name).font(.system(size: 12.5, weight: .semibold)).foregroundColor(t.foreground)
                    if !key.comment.isEmpty {
                        Text(key.comment).font(.system(size: 10.5)).foregroundColor(t.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Text(key.keyType.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(t.cyan)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(t.cyan.opacity(0.1)))
                if key.hasPublicKey {
                    Button {
                        copyRemotePublicKey(key)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: copiedKeyID == key.id ? "checkmark" : "doc.on.doc").font(.system(size: 10))
                            Text(copiedKeyID == key.id ? "Copied!" : "Copy Pub").font(.system(size: 10.5, weight: .medium))
                        }
                        .foregroundColor(copiedKeyID == key.id ? t.green : t.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 5).fill(copiedKeyID == key.id ? t.green.opacity(0.12) : t.accent.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
            }
            if !key.fingerprint.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "number").font(.system(size: 9, weight: .medium)).foregroundColor(t.secondary.opacity(0.5))
                    Text(key.fingerprint).font(.system(size: 10, design: .monospaced)).foregroundColor(t.secondary)
                        .textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "folder").font(.system(size: 9, weight: .medium)).foregroundColor(t.secondary.opacity(0.4))
                Text(key.privateKeyPath).font(.system(size: 10, design: .monospaced))
                    .foregroundColor(t.secondary.opacity(0.5)).lineLimit(1).truncationMode(.middle)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 9).fill(t.surface.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(t.secondary.opacity(0.15), lineWidth: 0.5))
    }

    private func copyRemotePublicKey(_ key: SSHKeyInfo) {
        guard let target = remoteSession.currentRemote,
              let sshHost = remoteSession.resolveHost(for: target) else { return }
        let path = key.publicKeyPath ?? key.privateKeyPath
        Task {
            let result = await RemoteSSHService.readRemoteFile(host: sshHost, remotePath: path)
            await MainActor.run {
                if case .success(let content) = result {
                    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(trimmed, forType: .string)
                    copiedKeyID = key.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [id = key.id] in
                        if copiedKeyID == id { copiedKeyID = nil }
                    }
                }
            }
        }
    }
}
