import Foundation
import SwiftUI

/// In-memory clipboard for SSH hosts. Copy from local or remote, paste to the other.
final class HostClipboardService: ObservableObject {
    @Published private(set) var hosts: [SSHHost] = []

    var hasContent: Bool { !hosts.isEmpty }

    /// Copy hosts (e.g. selected). Wildcard hosts are not copied.
    func copy(_ hostsToCopy: [SSHHost]) {
        hosts = hostsToCopy.filter { !$0.isWildcard }
    }

    /// Produce new hosts with new IDs and aliases unique against existingAliases. Caller adds them to config.
    func prepareForPaste(existingAliases: Set<String>) -> [SSHHost] {
        var taken = existingAliases
        return hosts.map { host in
            var alias = host.host.isEmpty ? "pasted" : host.host
            var counter = 1
            while taken.contains(alias) {
                alias = (host.host.isEmpty ? "pasted" : host.host) + "-\(counter)"
                counter += 1
            }
            taken.insert(alias)
            return SSHHost(
                id: UUID(),
                host: SSHConfig.sanitizeAlias(alias),
                label: host.label,
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
        }
    }
}
