# SSHMan

A native macOS SSH connection manager built with SwiftUI. Manage your `~/.ssh/config` hosts, organize them into groups, generate SSH keys, and connect with your preferred terminal — all from a clean, themeable interface.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### Host Management
- **Visual SSH config editor** — reads and writes your `~/.ssh/config` directly
- **Host tiles** in a responsive 3-column grid with hover interactions
- **Double-click to connect** — launches SSH in your preferred terminal
- **Drag-and-drop grouping** — organize hosts into named groups
- **Import / Export** — share or backup your SSH config
- **Automatic backups** — creates `~/.ssh/config.bak` before every save

### SSH Key Management
- **Key discovery** — scans `~/.ssh/` and displays all key pairs with fingerprints
- **Key generation** — create Ed25519, RSA (4096-bit), or ECDSA keys
- **Copy public key** — one-click copy to clipboard
- **Deploy keys** — `ssh-copy-id` integration from the host context menu

### Terminal Integration
- **Ghostty** (direct binary launch)
- **Terminal.app** (AppleScript)
- **iTerm2** (AppleScript)
- **Custom app** — point to any terminal binary
- **Per-host overrides** — use a different terminal for specific hosts

### Theming
10 built-in color schemes inspired by popular editor themes:

| Dark | Light |
|------|-------|
| Dracula | GitHub Light |
| One Dark | Solarized Light |
| Tokyo Night | Catppuccin Latte |
| Nord | |
| Catppuccin Mocha | |
| Gruvbox Dark | |
| Rosé Pine | |

Theme selection persists across sessions and updates the entire UI instantly.

## Layout

SSHMan uses a Termius-inspired 3-column layout:

```
┌──────┬───────────────────────┬────────────────────┐
│ [H]  │  Search: [_________]  │  Edit Host         │
│ [K]  │                       │                    │
│ [S]  │  GROUP A         [+]  │  Host Alias        │
│      │  ┌─────┐ ┌─────┐     │  HostName          │
│      │  │srv-1│ │srv-2│     │  User              │
│      │  └─────┘ └─────┘     │  Port              │
│      │                       │  Identity File     │
│      │  UNGROUPED            │  ...               │
│      │  ┌─────┐ ┌─────┐     │                    │
│      │  │ dev │ │prod │     │  [Cancel] [Save]   │
│      │  └─────┘ └─────┘     │                    │
│ [:]  │  [+ Add Host]         │                    │
└──────┴───────────────────────┴────────────────────┘
  56px       flexible                ~380px
```

- **Left rail** — icon navigation: Hosts, Keys, Settings, plus a "More" menu for import/export/reload
- **Center panel** — switches between Hosts (tile grid), Keys, or Settings
- **Right panel** — slides in when editing or adding a host

## Building

**Requirements:** macOS 13+ and Swift 5.9+ (included with Xcode 15+)

```bash
# Clone
git clone https://github.com/LZDevs/SSHMan.git
cd SSHMan

# Build
swift build

# Run
swift run
```

No external dependencies — just SwiftUI and AppKit.

## Project Structure

```
Sources/
├── App.swift                    # App entry point & window config
├── Theme.swift                  # Theme system (10 themes + ThemeManager)
├── Models/
│   ├── SSHHost.swift            # SSH host model
│   ├── SSHConfig.swift          # Bidirectional ~/.ssh/config parser
│   ├── HostGroup.swift          # Host grouping with JSON persistence
│   └── TerminalConfig.swift     # Terminal app preferences & overrides
├── Services/
│   ├── SSHConfigService.swift   # CRUD operations on SSH config
│   ├── SSHKeyService.swift      # Key discovery, generation, clipboard
│   └── GhosttyService.swift     # Terminal launch (all terminal types)
└── Views/
    ├── ContentView.swift        # 3-column layout shell
    ├── SettingsView.swift       # Theme picker & terminal preferences
    ├── Sidebar/
    │   └── SidebarView.swift    # Host grid, groups, search, drag-drop
    ├── Hosts/
    │   ├── HostRowView.swift    # Host tile card + Add Host tile
    │   ├── HostFormView.swift   # Add/edit host form
    │   └── HostDetailView.swift # Host detail view
    └── Keys/
        └── KeyManagementView.swift  # SSH key list, generate, copy
```

## Data Storage

| Data | Location | Format |
|------|----------|--------|
| SSH hosts | `~/.ssh/config` | SSH config |
| Config backup | `~/.ssh/config.bak` | SSH config |
| Host groups | `~/Library/Application Support/SSHMan/groups.json` | JSON |
| Terminal overrides | `~/Library/Application Support/SSHMan/host_terminal_prefs.json` | JSON |
| Theme preference | UserDefaults | String |
| Default terminal | UserDefaults | String |

## SSH Config Directives

SSHMan parses and preserves these directives:

- `Host` — alias / pattern
- `HostName` — server address
- `User` — login username
- `Port` — connection port
- `IdentityFile` — path to private key
- `ProxyJump` — bastion / jump host
- `ForwardAgent` — agent forwarding toggle

Any unrecognized directives are preserved as-is in "extra options" so your config is never mangled.

## License

MIT
