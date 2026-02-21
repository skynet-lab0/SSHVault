import Foundation
import os

private let logger = Logger(subsystem: "com.lzdevs.sshvault", category: "remote-ssh")

/// Runs SSH commands against a host (using local ~/.ssh/config for connection params).
/// Used to read/write remote ~/.ssh/config and list remote keys.
enum RemoteSSHService {
    private static let defaultSSHPort = 22

    /// Run a remote command; stdout returned as string. Stdin can be provided.
    private static func run(
        host: SSHHost,
        remoteCommand: String,
        stdinData: Data? = nil,
        timeout: TimeInterval = 30
    ) async -> Result<String, Error> {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
                // Override RemoteCommand so our command runs (hosts with RemoteCommand in config would otherwise ignore the requested command)
                process.arguments = ["-o", "RemoteCommand=none", host.host, remoteCommand]

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                if let data = stdinData {
                    let inPipe = Pipe()
                    process.standardInput = inPipe
                    do {
                        try inPipe.fileHandleForWriting.write(contentsOf: data)
                        try inPipe.fileHandleForWriting.close()
                    } catch {
                        continuation.resume(returning: .failure(error))
                        return
                    }
                } else {
                    process.standardInput = FileHandle.nullDevice
                }

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let stdout = String(data: outData, encoding: .utf8) ?? ""
                    let stderr = String(data: errData, encoding: .utf8) ?? ""

                    if process.terminationStatus != 0 {
                        let msg = stderr.isEmpty ? "Exit code \(process.terminationStatus)" : stderr
                        continuation.resume(returning: .failure(RemoteSSHError.commandFailed(msg)))
                        return
                    }
                    continuation.resume(returning: .success(stdout))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }

    /// Fetch remote ~/.ssh/config content.
    static func fetchConfig(host: SSHHost) async -> Result<String, Error> {
        let cmd = "cat ~/.ssh/config 2>/dev/null || true"
        let result = await run(host: host, remoteCommand: cmd)
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    /// Write content to remote ~/.ssh/config (atomic: temp file + chmod + mv).
    static func writeConfig(host: SSHHost, content: String) async -> Result<Void, Error> {
        guard let data = content.data(using: .utf8) else {
            return .failure(RemoteSSHError.encoding)
        }
        let cmd = "cat > ~/.ssh/config.new && chmod 600 ~/.ssh/config.new && mv -f ~/.ssh/config.new ~/.ssh/config"
        let result = await run(host: host, remoteCommand: cmd, stdinData: data)
        return result.map { _ in () }
    }

    /// List SSH keys on the remote ~/.ssh directory.
    static func fetchKeys(host: SSHHost) async -> Result<[SSHKeyInfo], Error> {
        let listResult = await run(host: host, remoteCommand: "ls -1 ~/.ssh 2>/dev/null || true")
        guard case .success(let listOut) = listResult else { return listResult.map { _ in [] } }

        let skipFiles: Set<String> = ["config", "config.bak", "config.tmp", "known_hosts", "known_hosts.old", "authorized_keys", "environment"]
        let knownKeyNames: Set<String> = ["id_rsa", "id_ed25519", "id_ecdsa", "id_dsa"]
        let files = listOut.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
        let pubFiles = Set(files.filter { $0.hasSuffix(".pub") })

        var keys: [SSHKeyInfo] = []
        for file in files.sorted() {
            if file.hasPrefix(".") || file.hasSuffix(".pub") || skipFiles.contains(file) { continue }
            let hasPub = pubFiles.contains(file + ".pub")
            let isKnown = knownKeyNames.contains(file)
            if !hasPub && !isKnown { continue }

            let remotePath = "~/.ssh/\(file)"
            let remotePubPath = hasPub ? "~/.ssh/\(file).pub" : nil
            let infoResult = await getRemoteKeyInfo(host: host, name: file, remotePath: remotePath, remotePubPath: remotePubPath)
            keys.append(infoResult)
        }
        return .success(keys)
    }

    private static func getRemoteKeyInfo(host: SSHHost, name: String, remotePath: String, remotePubPath: String?) async -> SSHKeyInfo {
        let keyFile = (remotePubPath ?? remotePath).shellEscaped
        let result = await run(host: host, remoteCommand: "ssh-keygen -l -f \(keyFile) 2>/dev/null || true")
        var keyType = "unknown"
        var fingerprint = ""
        var comment = ""

        if case .success(let output) = result, !output.isEmpty {
            let parts = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: " ")
            if parts.count >= 2 { fingerprint = parts[1] }
            if let last = parts.last?.dropLast(), parts.last?.hasSuffix(")") == true {
                keyType = String(last)
            }
            if parts.count >= 3 {
                let commentParts = parts[2..<parts.count]
                let joined = commentParts.joined(separator: " ")
                if let idx = joined.lastIndex(of: "(") {
                    comment = String(joined[..<idx]).trimmingCharacters(in: .whitespaces)
                } else {
                    comment = joined
                }
            }
        }

        return SSHKeyInfo(
            id: name,
            privateKeyPath: remotePath,
            publicKeyPath: remotePubPath,
            keyType: keyType,
            fingerprint: fingerprint,
            comment: comment,
            isLoadedInAgent: false
        )
    }

    /// Read remote file content (e.g. public key) for copy-to-clipboard.
    static func readRemoteFile(host: SSHHost, remotePath: String) async -> Result<String, Error> {
        let cmd = "cat \(remotePath.shellEscaped) 2>/dev/null || true"
        return await run(host: host, remoteCommand: cmd)
    }
}

enum RemoteSSHError: LocalizedError {
    case commandFailed(String)
    case encoding

    var errorDescription: String? {
        switch self {
        case .commandFailed(let msg): return msg
        case .encoding: return "Failed to encode content"
        }
    }
}
