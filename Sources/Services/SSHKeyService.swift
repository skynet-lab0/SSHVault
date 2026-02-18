import Foundation
import AppKit

/// Represents an SSH key pair found on disk
struct SSHKeyInfo: Identifiable, Hashable {
    let id: String  // filename of private key
    let privateKeyPath: String
    let publicKeyPath: String?
    let keyType: String
    let fingerprint: String
    let comment: String
    var isLoadedInAgent: Bool = false

    var name: String { id }
    var hasPublicKey: Bool { publicKeyPath != nil }
}

/// Manages SSH keys in ~/.ssh/
final class SSHKeyService {
    static let shared = SSHKeyService()

    private let sshDir: URL
    private let fm = FileManager.default

    private init() {
        sshDir = fm.homeDirectoryForCurrentUser.appendingPathComponent(".ssh", isDirectory: true)
    }

    /// Scan ~/.ssh/ for key pairs
    func listKeys() -> [SSHKeyInfo] {
        guard let files = try? fm.contentsOfDirectory(atPath: sshDir.path) else {
            return []
        }

        let pubFiles = Set(files.filter { $0.hasSuffix(".pub") })
        var keys: [SSHKeyInfo] = []

        // Find private keys (files that have a matching .pub or are known key names)
        let knownKeyNames: Set<String> = ["id_rsa", "id_ed25519", "id_ecdsa", "id_dsa"]
        let skipFiles: Set<String> = ["config", "config.bak", "config.tmp", "known_hosts",
                                       "known_hosts.old", "authorized_keys", "environment"]

        for file in files.sorted() {
            if file.hasPrefix(".") || file.hasSuffix(".pub") || skipFiles.contains(file) { continue }

            let hasPub = pubFiles.contains(file + ".pub")
            let isKnown = knownKeyNames.contains(file)

            // Heuristic: it's a key if it has a .pub companion or is a known key name
            // or we can check with ssh-keygen
            if hasPub || isKnown {
                let privatePath = sshDir.appendingPathComponent(file).path
                let publicPath = hasPub ? sshDir.appendingPathComponent(file + ".pub").path : nil
                let info = getKeyInfo(name: file, privatePath: privatePath, publicPath: publicPath)
                keys.append(info)
            }
        }

        let loadedFingerprints = listAgentKeys()
        for i in keys.indices {
            if loadedFingerprints.contains(keys[i].fingerprint) {
                keys[i].isLoadedInAgent = true
            }
        }

        return keys
    }

    private func getKeyInfo(name: String, privatePath: String, publicPath: String?) -> SSHKeyInfo {
        var keyType = "unknown"
        var fingerprint = ""
        var comment = ""

        // Try to get fingerprint from the key
        let targetPath = publicPath ?? privatePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        process.arguments = ["-l", "-f", targetPath]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        if let _ = try? process.run() {
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                // Output format: "256 SHA256:xxx comment (ED25519)"
                let parts = output.components(separatedBy: " ")
                if parts.count >= 2 {
                    fingerprint = parts[1]
                }
                // Key type is in parentheses at the end
                if let typeMatch = output.components(separatedBy: "(").last?.dropLast() {
                    keyType = String(typeMatch)
                }
                // Comment is between fingerprint and type
                if parts.count >= 3 {
                    let commentParts = parts[2..<parts.count]
                    let joined = commentParts.joined(separator: " ")
                    if let parenIdx = joined.lastIndex(of: "(") {
                        comment = String(joined[joined.startIndex..<parenIdx]).trimmingCharacters(in: .whitespaces)
                    } else {
                        comment = joined
                    }
                }
            }
        }

        return SSHKeyInfo(
            id: name,
            privateKeyPath: privatePath,
            publicKeyPath: publicPath,
            keyType: keyType,
            fingerprint: fingerprint,
            comment: comment
        )
    }

    /// Generate a new SSH key pair
    func generateKey(name: String, type: String = "ed25519", comment: String = "", passphrase: String = "") -> Bool {
        let safeName = name.trimmingCharacters(in: .whitespaces)

        // Reject path traversal and special characters
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard !safeName.isEmpty,
              !safeName.contains("/"),
              !safeName.contains("\\"),
              !safeName.hasPrefix("."),
              safeName.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return false
        }

        let keyPath = sshDir.appendingPathComponent(safeName).path

        // Don't overwrite existing keys
        if fm.fileExists(atPath: keyPath) {
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        process.arguments = [
            "-t", type,
            "-f", keyPath,
            "-N", passphrase,
            "-C", comment.isEmpty ? name : comment
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Copy a public key to clipboard
    func copyPublicKey(_ key: SSHKeyInfo) -> Bool {
        guard let pubPath = key.publicKeyPath,
              let content = try? String(contentsOfFile: pubPath, encoding: .utf8) else {
            return false
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content.trimmingCharacters(in: .whitespacesAndNewlines), forType: .string)
        return true
    }

    // MARK: - SSH Agent

    /// Check if ssh-agent is running and accessible
    func isAgentRunning() -> Bool {
        guard let sock = ProcessInfo.processInfo.environment["SSH_AUTH_SOCK"] else { return false }
        return fm.fileExists(atPath: sock)
    }

    /// List fingerprints of keys currently loaded in the agent
    func listAgentKeys() -> Set<String> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-add")
        process.arguments = ["-l"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            // Each line: "256 SHA256:xxx comment (ED25519)"
            var fingerprints = Set<String>()
            for line in output.components(separatedBy: "\n") {
                let parts = line.components(separatedBy: " ")
                if parts.count >= 2 && parts[1].hasPrefix("SHA256:") {
                    fingerprints.insert(parts[1])
                }
            }
            return fingerprints
        } catch {
            return []
        }
    }

    /// Path to the askpass helper script used for passphrase prompts
    private lazy var askPassScriptPath: String = {
        let path = NSTemporaryDirectory() + "sshvault-askpass.sh"
        let script = """
        #!/bin/bash
        exec osascript - "$1" <<'APPLESCRIPT'
        on run argv
            set promptText to item 1 of argv
            display dialog promptText default answer "" with hidden answer buttons {"Cancel", "OK"} default button "OK" with title "SSHVault" with icon caution
            return text returned of result
        end run
        APPLESCRIPT
        """
        try? script.write(toFile: path, atomically: true, encoding: .utf8)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }()

    /// Add a key to the ssh-agent
    func addKeyToAgent(keyPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-add")
        process.arguments = ["--apple-use-keychain", keyPath]

        var env = ProcessInfo.processInfo.environment
        env["SSH_ASKPASS"] = askPassScriptPath
        env["SSH_ASKPASS_REQUIRE"] = "prefer"
        env["DISPLAY"] = ":0"
        process.environment = env

        process.standardInput = FileHandle.nullDevice
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Remove a specific key from the ssh-agent
    func removeKeyFromAgent(keyPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-add")
        process.arguments = ["-d", keyPath]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Remove all keys from the ssh-agent
    func removeAllKeysFromAgent() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-add")
        process.arguments = ["-D"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
