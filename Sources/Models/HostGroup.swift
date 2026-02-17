import Foundation

struct HostGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var hostIDs: [String] // host aliases belonging to this group

    init(id: UUID = UUID(), name: String = "", hostIDs: [String] = []) {
        self.id = id
        self.name = name
        self.hostIDs = hostIDs
    }

    static let supportDir: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SSHMan", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let storageURL = supportDir.appendingPathComponent("groups.json")

    static func loadAll() -> [HostGroup] {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let groups = try? JSONDecoder().decode([HostGroup].self, from: data) else {
            return []
        }
        return groups
    }

    static func saveAll(_ groups: [HostGroup]) {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }
}
