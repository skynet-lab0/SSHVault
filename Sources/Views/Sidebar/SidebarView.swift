import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject var configService: SSHConfigService
    @EnvironmentObject var hostClipboard: HostClipboardService
    @ObservedObject private var tm = ThemeManager.shared
    @Binding var searchText: String
    @Binding var showingAddHost: Bool
    @Binding var addHostGroupID: UUID?
    var onEdit: ((SSHHost) -> Void)?
    var onHostSingleClick: ((SSHHost) -> Void)?
    var onConnect: ((SSHHost) -> Void)?
    var onDuplicate: ((SSHHost) -> Void)?
    /// When false (e.g. Edit Host form is open), host list shortcuts are disabled so Cmd+V etc. reach the form.
    var hostListShortcutsEnabled: Bool = true

    @State private var showingAddGroup = false
    @State private var newGroupName = ""
    @State private var hostsToDelete: [SSHHost] = []
    @State private var showDeleteConfirm = false
    @State private var groupToRename: HostGroup?
    @State private var renameGroupName = ""
    @State private var groupToDelete: HostGroup?
    @State private var showDeleteGroupConfirm = false
    @State private var selectedHostIDs: Set<UUID> = []

    private var t: AppTheme { tm.current }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var sortedGroups: [HostGroup] {
        configService.groups.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var filteredHosts: [SSHHost] {
        let base = searchText.isEmpty
            ? configService.hosts
            : configService.hosts.filter {
                let q = searchText.lowercased()
                return $0.host.lowercased().contains(q) ||
                    $0.hostName.lowercased().contains(q) ||
                    $0.user.lowercased().contains(q)
              }
        return base.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5).padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if filteredHosts.isEmpty && !searchText.isEmpty {
                        emptySearchState
                    } else {
                        if !configService.groups.isEmpty { groupedSections }
                        ungroupedSection
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
                Text("\(configService.hosts.count) host\(configService.hosts.count == 1 ? "" : "s")")
                    .font(.system(size: 10.5))
                    .foregroundColor(t.secondary.opacity(0.7))
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(t.secondary.opacity(0.4))
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
        }
        .background(t.background)
        .overlay { if hostListShortcutsEnabled { hostListKeyboardShortcuts } else { EmptyView() } }
        .alert("New Group", isPresented: $showingAddGroup) {
            TextField("Group name", text: $newGroupName)
            Button("Cancel", role: .cancel) { newGroupName = "" }
            Button("Create") {
                if !newGroupName.isEmpty {
                    configService.addGroup(HostGroup(name: newGroupName))
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
                    configService.renameGroup(group, to: renameGroupName)
                }
                groupToRename = nil
            }
        }
        .alert("Delete Group?", isPresented: $showDeleteGroupConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let group = groupToDelete { configService.deleteGroup(group) }
            }
        } message: {
            if let group = groupToDelete {
                Text("Are you sure you want to delete \"\(group.name)\"? Hosts in this group will become ungrouped.")
            }
        }
        .alert(hostsToDelete.count > 1 ? "Delete \(hostsToDelete.count) Hosts?" : "Delete Host?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { hostsToDelete = [] }
            Button("Delete", role: .destructive) {
                for host in hostsToDelete { configService.deleteHost(host) }
                hostsToDelete = []
                selectedHostIDs.removeAll()
            }
        } message: {
            if hostsToDelete.count == 1, let host = hostsToDelete.first {
                Text("Are you sure you want to delete \"\(host.displayName)\"? This will update your SSH config file.")
            } else if hostsToDelete.count > 1 {
                Text("Are you sure you want to delete \(hostsToDelete.count) hosts? This will update your SSH config file.")
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Button { showingAddHost = true } label: {
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
            .help("Add Host")

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
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 7).fill(t.surface.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(t.secondary.opacity(0.2), lineWidth: 0.5))
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 40)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light)).foregroundColor(t.secondary.opacity(0.5))
            Text("No results for \"\(searchText)\"")
                .font(.system(size: 13, weight: .medium)).foregroundColor(t.secondary)
            Spacer(minLength: 40)
        }.frame(maxWidth: .infinity)
    }

    // MARK: - Sections

    @ViewBuilder
    private var groupedSections: some View {
        ForEach(sortedGroups) { group in
            let groupHosts = filteredHosts.filter { group.hostIDs.contains($0.host) }
            if !groupHosts.isEmpty || searchText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(group.name, group: group)
                        .contentShape(Rectangle())
                        .dropDestination(for: String.self) { a, _ in dropHosts(a, into: group) }
                        .contextMenu {
                            Button { renameGroupName = group.name; groupToRename = group } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Divider()
                            Button { configService.moveGroupUp(group) } label: {
                                Label("Move Up", systemImage: "arrow.up")
                            }
                            .disabled(sortedGroups.first?.id == group.id)
                            Button { configService.moveGroupDown(group) } label: {
                                Label("Move Down", systemImage: "arrow.down")
                            }
                            .disabled(sortedGroups.last?.id == group.id)
                            Divider()
                            Button(role: .destructive) {
                                groupToDelete = group; showDeleteGroupConfirm = true
                            } label: {
                                Label("Delete Group", systemImage: "trash")
                            }
                        }
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(groupHosts) { host in hostTile(host) }
                    }
                }
                .dropDestination(for: String.self) { a, _ in dropHosts(a, into: group) }
            }
        }
    }

    @ViewBuilder
    private var ungroupedSection: some View {
        let hosts = ungroupedHosts
        if !hosts.isEmpty || configService.groups.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !configService.groups.isEmpty || !hosts.isEmpty {
                    sectionHeader(configService.groups.isEmpty ? "Hosts" : "Ungrouped")
                        .contentShape(Rectangle())
                        .dropDestination(for: String.self) { aliases, _ in
                            for alias in aliases {
                                guard let h = configService.hosts.first(where: { $0.host == alias }) else { continue }
                                removeHostFromGroups(h)
                            }
                            return !aliases.isEmpty
                        }
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(hosts) { host in hostTile(host) }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, group: HostGroup? = nil) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10.5, weight: .bold)).foregroundColor(t.secondary).tracking(0.6)
            Rectangle().fill(t.secondary.opacity(0.2)).frame(height: 0.5)
            if let group {
                Button {
                    addHostGroupID = group.id
                    showingAddHost = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .medium)).foregroundColor(t.secondary)
                }.buttonStyle(.plain).help("Add host to \(group.name)")
            }
        }.padding(.horizontal, 2)
    }

    // MARK: - Host Tile

    private func hostTile(_ host: SSHHost) -> some View {
        let isSelected = selectedHostIDs.contains(host.id)
        let contextMenuTargets: [SSHHost] = isSelected
            ? configService.hosts.filter { selectedHostIDs.contains($0.id) }
            : [host]

        return HostRowView(
            host: host,
            isSelected: isSelected,
            onEdit: { selectedHostIDs = [host.id]; onEdit?(host) },
            onConnect: { onConnect?(host) },
            onSingleClickImmediate: { flags in
                if flags.contains(.command) || flags.contains(.control) {
                    if selectedHostIDs.contains(host.id) {
                        selectedHostIDs.remove(host.id)
                    } else {
                        selectedHostIDs.insert(host.id)
                    }
                } else {
                    selectedHostIDs = [host.id]
                }
            },
            onSingleClickDelayed: { onHostSingleClick?(host) },
            onDoubleClick: { onConnect?(host) }
        )
            .draggable(host.host)
            .help("Click to select, ⌘/Ctrl+click to multi-select, double-click to connect")
            .contextMenu {
                Button { onConnect?(host) } label: { Label("Connect", systemImage: "terminal") }
                if !host.isWildcard {
                    Button { TerminalService.openSFTP(to: host) } label: {
                        Label("SFTP", systemImage: "folder.badge.gearshape")
                    }
                }
                Button { selectedHostIDs = [host.id]; onEdit?(host) } label: { Label("Edit", systemImage: "pencil") }
                if !host.isWildcard {
                    Button { duplicateHost(host) } label: { Label("Duplicate", systemImage: "doc.on.doc") }
                }
                let copyTargets = contextMenuTargets.filter { !$0.isWildcard }
                if !copyTargets.isEmpty {
                    Button { hostClipboard.copy(copyTargets) } label: {
                        Label(copyTargets.count > 1 ? "Copy (\(copyTargets.count) hosts)" : "Copy", systemImage: "doc.on.clipboard")
                    }
                }
                if hostClipboard.hasContent {
                    Button { pasteToLocal(ontoGroupOf: host) } label: {
                        Label(hostClipboard.hosts.count > 1 ? "Paste (\(hostClipboard.hosts.count) hosts)" : "Paste", systemImage: "doc.on.clipboard.fill")
                    }
                }
                if !host.identityFile.isEmpty && !host.isWildcard {
                    Button { TerminalService.copyKeyToHost(host, keyPath: host.identityFile) } label: {
                        Label("Copy Public Key to Server", systemImage: "paperplane.fill")
                    }
                }
                Divider()
                if !configService.groups.isEmpty {
                    Menu(contextMenuTargets.count > 1 ? "Move to Group (\(contextMenuTargets.count) hosts)" : "Move to Group") {
                        ForEach(sortedGroups) { g in
                            Button(g.name) {
                                for target in contextMenuTargets { moveHost(target, to: g) }
                                selectedHostIDs.removeAll()
                            }
                        }
                        Divider()
                        Button("Remove from Group") {
                            for target in contextMenuTargets { removeHostFromGroups(target) }
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

    // MARK: - Helpers

    private var ungroupedHosts: [SSHHost] {
        if configService.groups.isEmpty { return filteredHosts }
        let allGrouped = Set(configService.groups.flatMap { $0.hostIDs })
        return filteredHosts.filter { !allGrouped.contains($0.host) }
    }

    func moveHost(_ host: SSHHost, to group: HostGroup) {
        for i in configService.groups.indices { configService.groups[i].hostIDs.removeAll { $0 == host.host } }
        if let idx = configService.groups.firstIndex(where: { $0.id == group.id }) {
            configService.groups[idx].hostIDs.append(host.host)
        }
        configService.saveGroups()
    }

    func dropHosts(_ aliases: [String], into group: HostGroup) -> Bool {
        for a in aliases { if let h = configService.hosts.first(where: { $0.host == a }) { moveHost(h, to: group) } }
        return !aliases.isEmpty
    }

    func removeHostFromGroups(_ host: SSHHost) {
        for i in configService.groups.indices { configService.groups[i].hostIDs.removeAll { $0 == host.host } }
        configService.saveGroups()
    }

    private func duplicateHost(_ host: SSHHost) {
        guard !host.isWildcard else { return }
        let taken = Set(configService.hosts.map(\.host))
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
        configService.addHost(copy)
        for i in configService.groups.indices {
            if configService.groups[i].hostIDs.contains(host.host) {
                configService.groups[i].hostIDs.append(copy.host)
            }
        }
        configService.saveGroups()
        onDuplicate?(copy)
    }

    private func pasteToLocal(ontoGroupOf rightClickedHost: SSHHost?) {
        let existing = Set(configService.hosts.map(\.host))
        let toAdd = hostClipboard.prepareForPaste(existingAliases: existing)
        for h in toAdd { configService.addHost(h) }
        if let rightClickedHost,
           let idx = configService.groups.firstIndex(where: { $0.hostIDs.contains(rightClickedHost.host) }) {
            for h in toAdd { configService.groups[idx].hostIDs.append(h.host) }
            configService.saveGroups()
        }
    }

    private var selectedHosts: [SSHHost] {
        configService.hosts.filter { selectedHostIDs.contains($0.id) }
    }

    private func performCopy() {
        let copyTargets = selectedHosts.filter { !$0.isWildcard }
        if !copyTargets.isEmpty { hostClipboard.copy(copyTargets) }
    }

    private func performPaste() {
        guard hostClipboard.hasContent else { return }
        let target = selectedHosts.count == 1 ? selectedHosts.first : nil
        pasteToLocal(ontoGroupOf: target)
    }

    private func performDelete() {
        guard !selectedHosts.isEmpty else { return }
        hostsToDelete = selectedHosts
        showDeleteConfirm = true
    }

    private func performDuplicate() {
        guard selectedHosts.count == 1, let host = selectedHosts.first, !host.isWildcard else { return }
        duplicateHost(host)
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
}
