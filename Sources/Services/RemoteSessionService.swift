import Foundation
import SwiftUI
import os

private let logger = Logger(subsystem: "com.lzdevs.sshvault", category: "remote-session")

/// Holds current remote target and its loaded hosts/groups/keys.
/// Resolves hostAlias via SSHConfigService to run RemoteSSHService.
final class RemoteSessionService: ObservableObject {
    @Published var remoteTargets: [RemoteTarget] = []
    @Published var currentRemote: RemoteTarget?
    @Published var hosts: [SSHHost] = []
    @Published var groups: [HostGroup] = []
    @Published var keys: [SSHKeyInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var editingHost: SSHHost?
    @Published var showingAddHost = false

    private weak var configService: SSHConfigService?
    /// When set, edit requests (e.g. clicking another host) go through this instead of setting editingHost directly.
    var onRequestEditHost: ((SSHHost) -> Void)?
    /// Updated by the edit form so the request-edit callback can read current dirty state without stale capture.
    @Published var remoteEditFormDirty = false
    var remoteEditFormSaveHandler: (() -> Void)?
    /// When user tries to switch host with dirty form; alert is shown and this is the target host.
    @Published var pendingRemoteEditHost: SSHHost?
    @Published var showUnsavedRemoteEditAlert = false

    init() {
        remoteTargets = RemoteTarget.loadAll()
    }

    /// Must be called once (e.g. from ContentView) to resolve host aliases.
    func configure(configService: SSHConfigService) {
        self.configService = configService
    }

    /// Resolve host alias to SSHHost from local config
    func resolveHost(for target: RemoteTarget) -> SSHHost? {
        configService?.hosts.first { $0.host == target.hostAlias }
    }

    // MARK: - Targets

    func addTarget(_ target: RemoteTarget) {
        guard !remoteTargets.contains(where: { $0.hostAlias == target.hostAlias }) else { return }
        remoteTargets.append(target)
        RemoteTarget.saveAll(remoteTargets)
    }

    func renameTarget(_ target: RemoteTarget, to name: String) {
        guard let idx = remoteTargets.firstIndex(where: { $0.id == target.id }) else { return }
        remoteTargets[idx].name = name
        if currentRemote?.id == target.id { currentRemote = remoteTargets[idx] }
        RemoteTarget.saveAll(remoteTargets)
    }

    func removeTarget(_ target: RemoteTarget) {
        remoteTargets.removeAll { $0.id == target.id }
        if currentRemote?.id == target.id {
            currentRemote = nil
            hosts = []
            groups = []
            keys = []
        }
        RemoteTarget.saveAll(remoteTargets)
    }

    func loadTargets() {
        remoteTargets = RemoteTarget.loadAll()
    }

    // MARK: - Open remote & load

    func open(_ target: RemoteTarget) {
        guard let sshHost = resolveHost(for: target) else {
            errorMessage = "Local host \"\(target.hostAlias)\" not found in config"
            return
        }
        currentRemote = target
        errorMessage = nil
        Task { await loadRemote(sshHost: sshHost, target: target) }
    }

    func close() {
        currentRemote = nil
        hosts = []
        groups = []
        keys = []
        errorMessage = nil
        editingHost = nil
        showingAddHost = false
    }

    func refresh() {
        guard let target = currentRemote, let sshHost = resolveHost(for: target) else { return }
        Task { await loadRemote(sshHost: sshHost, target: target) }
    }

    @MainActor
    private func loadRemote(sshHost: SSHHost, target: RemoteTarget) async {
        isLoading = true
        errorMessage = nil

        let configResult = await RemoteSSHService.fetchConfig(host: sshHost)
        switch configResult {
        case .success(let content):
            hosts = SSHConfig.parse(content: content)
        case .failure(let err):
            errorMessage = err.localizedDescription
            hosts = []
        }

        let keysResult = await RemoteSSHService.fetchKeys(host: sshHost)
        switch keysResult {
        case .success(let k):
            keys = k
        case .failure(let err):
            if errorMessage == nil { errorMessage = err.localizedDescription }
            keys = []
        }

        groups = HostGroup.loadAll(from: RemoteTarget.groupsURL(for: target.id))
        isLoading = false
    }

    // MARK: - Save remote config & groups

    func saveRemoteConfig() {
        guard let target = currentRemote, let sshHost = resolveHost(for: target) else { return }
        // Snapshot hosts on main actor so the async Task sees the latest list (e.g. just-added host)
        let content = SSHConfig.serialize(hosts: hosts)
        Task {
            let result = await RemoteSSHService.writeConfig(host: sshHost, content: content)
            await MainActor.run {
                if case .failure(let err) = result {
                    errorMessage = err.localizedDescription
                }
            }
        }
    }

    func saveRemoteGroups() {
        guard let target = currentRemote else { return }
        HostGroup.saveAll(groups, to: RemoteTarget.groupsURL(for: target.id))
    }

    /// Call when user selects a host to edit; respects onRequestEditHost so parent can prompt for unsaved changes.
    func requestEditHost(_ host: SSHHost) {
        if let cb = onRequestEditHost {
            cb(host)
        } else {
            editingHost = host
        }
    }

    // MARK: - Host CRUD (in-memory + write back)

    func addHost(_ host: SSHHost) {
        hosts.append(host)
        saveRemoteConfig()
    }

    func updateHost(_ host: SSHHost) {
        if let idx = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[idx] = host
            saveRemoteConfig()
        }
    }

    func deleteHost(_ host: SSHHost) {
        hosts.removeAll { $0.id == host.id }
        for i in groups.indices {
            groups[i].hostIDs.removeAll { $0 == host.host }
        }
        saveRemoteConfig()
        saveRemoteGroups()
    }

    // MARK: - Groups (mirror SSHConfigService API)

    func addGroup(_ group: HostGroup) {
        groups.append(group)
        saveRemoteGroups()
    }

    func renameGroup(_ group: HostGroup, to name: String) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[idx].name = name
        saveRemoteGroups()
    }

    func deleteGroup(_ group: HostGroup) {
        groups.removeAll { $0.id == group.id }
        saveRemoteGroups()
    }

    func moveGroupUp(_ group: HostGroup) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }), idx > 0 else { return }
        groups.swapAt(idx, idx - 1)
        saveRemoteGroups()
    }

    func moveGroupDown(_ group: HostGroup) {
        guard let idx = groups.firstIndex(where: { $0.id == group.id }), idx < groups.count - 1 else { return }
        groups.swapAt(idx, idx + 1)
        saveRemoteGroups()
    }

    func moveHost(_ host: SSHHost, to group: HostGroup) {
        for i in groups.indices { groups[i].hostIDs.removeAll { $0 == host.host } }
        if let idx = groups.firstIndex(where: { $0.id == group.id }) {
            groups[idx].hostIDs.append(host.host)
        }
        saveRemoteGroups()
    }

    func removeHostFromGroups(_ host: SSHHost) {
        for i in groups.indices { groups[i].hostIDs.removeAll { $0 == host.host } }
        saveRemoteGroups()
    }
}
