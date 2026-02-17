import Foundation

struct SSHHost: Identifiable, Codable, Hashable {
    let id: UUID
    var host: String
    var hostName: String
    var user: String
    var port: Int?
    var identityFile: String
    var proxyJump: String
    var forwardAgent: Bool
    var extraOptions: [String: String]
    var comment: String

    init(
        id: UUID = UUID(),
        host: String = "",
        hostName: String = "",
        user: String = "",
        port: Int? = nil,
        identityFile: String = "",
        proxyJump: String = "",
        forwardAgent: Bool = false,
        extraOptions: [String: String] = [:],
        comment: String = ""
    ) {
        self.id = id
        self.host = host
        self.hostName = hostName
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.proxyJump = proxyJump
        self.forwardAgent = forwardAgent
        self.extraOptions = extraOptions
        self.comment = comment
    }

    /// The display name — uses the host alias
    var displayName: String {
        host.isEmpty ? hostName : host
    }

    /// Build the ssh command string for this host
    var sshCommand: String {
        // If there's a Host alias, just use that
        if !host.isEmpty && host != "*" {
            return "ssh \(host)"
        }
        var cmd = "ssh"
        if !user.isEmpty {
            cmd += " \(user)@\(hostName)"
        } else {
            cmd += " \(hostName)"
        }
        if let port, port != 22 {
            cmd += " -p \(port)"
        }
        return cmd
    }

    /// Whether this is a wildcard/default host
    var isWildcard: Bool {
        host == "*"
    }
}
