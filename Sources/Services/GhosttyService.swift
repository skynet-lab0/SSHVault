import Foundation

/// Launches SSH connections in configurable terminal applications
struct TerminalService {
    private static let prefs = TerminalPreferences.shared

    /// Shell-escape a string for safe use in sh -c
    private static func shellEscape(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Expand ~ to the full home directory path
    private static func expandTilde(_ path: String) -> String {
        if path.hasPrefix("~/") {
            return FileManager.default.homeDirectoryForCurrentUser.path + String(path.dropFirst(1))
        }
        return path
    }

    /// Launch an SSH connection using the resolved terminal for this host
    static func connect(to host: SSHHost) {
        var cmd = "ssh"
        if !host.identityFile.isEmpty {
            cmd += " -i \(shellEscape(expandTilde(host.identityFile)))"
        }
        if let port = host.port, port != 22 {
            cmd += " -p \(port)"
        }
        if host.forwardAgent {
            cmd += " -A"
        }
        if !host.proxyJump.isEmpty {
            cmd += " -J \(shellEscape(host.proxyJump))"
        }
        let target: String
        if !host.user.isEmpty {
            target = "\(host.user)@\(host.hostName)"
        } else {
            target = host.hostName
        }
        cmd += " \(shellEscape(target))"

        let terminal = prefs.resolvedTerminal(for: host.host)
        let customPath = prefs.resolvedCustomPath(for: host.host)
        launchTerminal(shellCommand: cmd, using: terminal, customAppPath: customPath)
    }

    /// Run ssh-copy-id to push a public key to the host
    static func copyKeyToHost(_ host: SSHHost, keyPath: String) {
        let fullPath = expandTilde(keyPath)
        var cmd = "ssh-copy-id"
        cmd += " -i \(shellEscape(fullPath))"
        if let port = host.port, port != 22 {
            cmd += " -p \(port)"
        }
        let target: String
        if !host.user.isEmpty {
            target = "\(host.user)@\(host.hostName)"
        } else {
            target = host.hostName
        }
        cmd += " \(shellEscape(target))"

        let terminal = prefs.resolvedTerminal(for: host.host)
        let customPath = prefs.resolvedCustomPath(for: host.host)
        launchTerminal(shellCommand: cmd, using: terminal, customAppPath: customPath)
    }

    /// Launch a shell command in the specified terminal app
    private static func launchTerminal(shellCommand: String, using terminal: TerminalApp, customAppPath: String = "") {
        switch terminal {
        case .ghostty:
            launchDirectBinary(
                binPath: TerminalApp.ghostty.appPath + "/Contents/MacOS/ghostty",
                shellCommand: shellCommand
            )
        case .terminal:
            launchViaAppleScript(
                script: "tell application \"Terminal\" to do script \"\(escapeAppleScript(shellCommand))\"",
                appName: "Terminal"
            )
        case .iterm2:
            launchViaAppleScript(
                script: "tell application \"iTerm2\" to create window with default profile command \"\(escapeAppleScript(shellCommand))\"",
                appName: "iTerm2"
            )
        case .custom:
            guard !customAppPath.isEmpty else {
                print("Custom terminal path not configured")
                return
            }
            // Assume custom app follows the same pattern as Ghostty (binary -e /bin/sh -c "cmd")
            let appName = URL(fileURLWithPath: customAppPath).deletingPathExtension().lastPathComponent
            let binPath = customAppPath + "/Contents/MacOS/\(appName)"
            launchDirectBinary(binPath: binPath, shellCommand: shellCommand)
        }
    }

    /// Launch a terminal via direct binary execution (Ghostty-style: binary -e /bin/sh -c "cmd")
    private static func launchDirectBinary(binPath: String, shellCommand: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binPath)
        process.arguments = ["-e", "/bin/sh", "-c", shellCommand]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            print("Failed to launch terminal: \(error)")
        }
    }

    /// Launch a terminal via AppleScript (Terminal.app, iTerm2)
    private static func launchViaAppleScript(script: String, appName: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            print("Failed to launch \(appName): \(error)")
        }
    }

    /// Escape a string for safe embedding in AppleScript double-quoted strings
    private static func escapeAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
