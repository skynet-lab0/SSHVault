import Foundation
import os

private let logger = Logger(subsystem: "com.lzdevs.sshvault", category: "remotes")

struct RemoteTarget: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var hostAlias: String

    init(id: UUID = UUID(), name: String = "", hostAlias: String = "") {
        self.id = id
        self.name = name
        self.hostAlias = hostAlias
    }

    static let supportDir: URL = HostGroup.supportDir

    static let storageURL = supportDir.appendingPathComponent("remote_targets.json")

    static func loadAll() -> [RemoteTarget] {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let targets = try? JSONDecoder().decode([RemoteTarget].self, from: data) else {
            return []
        }
        return targets
    }

    static func saveAll(_ targets: [RemoteTarget]) {
        guard let data = try? JSONEncoder().encode(targets) else { return }
        do {
            try data.write(to: storageURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storageURL.path)
        } catch {
            logger.error("Failed to save remote targets: \(error.localizedDescription, privacy: .private)")
        }
    }

    /// Per-remote groups file path for this target
    static func groupsURL(for targetID: UUID) -> URL {
        supportDir.appendingPathComponent("remote_groups_\(targetID.uuidString).json")
    }
}
