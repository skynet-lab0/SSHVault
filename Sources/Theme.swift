import SwiftUI

// MARK: - Color hex helper

extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}

// MARK: - App Theme

struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let isDark: Bool

    let background: Color
    let sidebar: Color
    let surface: Color
    let foreground: Color
    let secondary: Color

    let accent: Color
    let cyan: Color
    let green: Color
    let orange: Color
    let pink: Color
    let red: Color
    let yellow: Color

    static func == (lhs: AppTheme, rhs: AppTheme) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Premade Themes

extension AppTheme {

    static let all: [AppTheme] = [
        .dracula, .oneDark, .tokyoNight, .nord,
        .catppuccinMocha, .gruvboxDark, .rosePine,
        .githubLight, .solarizedLight, .catppuccinLatte
    ]

    // ── Dark Themes ──

    static let dracula = AppTheme(
        id: "dracula", name: "Dracula", isDark: true,
        background: Color(hex: 0x282A36),
        sidebar:    Color(hex: 0x21222C),
        surface:    Color(hex: 0x44475A),
        foreground: Color(hex: 0xF8F8F2),
        secondary:  Color(hex: 0x6272A4),
        accent:     Color(hex: 0xBD93F9),
        cyan:       Color(hex: 0x8BE9FD),
        green:      Color(hex: 0x50FA7B),
        orange:     Color(hex: 0xFFB86C),
        pink:       Color(hex: 0xFF79C6),
        red:        Color(hex: 0xFF5555),
        yellow:     Color(hex: 0xF1FA8C)
    )

    static let oneDark = AppTheme(
        id: "one-dark", name: "One Dark", isDark: true,
        background: Color(hex: 0x282C34),
        sidebar:    Color(hex: 0x21252B),
        surface:    Color(hex: 0x2C313A),
        foreground: Color(hex: 0xABB2BF),
        secondary:  Color(hex: 0x5C6370),
        accent:     Color(hex: 0x61AFEF),
        cyan:       Color(hex: 0x56B6C2),
        green:      Color(hex: 0x98C379),
        orange:     Color(hex: 0xD19A66),
        pink:       Color(hex: 0xC678DD),
        red:        Color(hex: 0xE06C75),
        yellow:     Color(hex: 0xE5C07B)
    )

    static let tokyoNight = AppTheme(
        id: "tokyo-night", name: "Tokyo Night", isDark: true,
        background: Color(hex: 0x1A1B26),
        sidebar:    Color(hex: 0x16161E),
        surface:    Color(hex: 0x24283B),
        foreground: Color(hex: 0xA9B1D6),
        secondary:  Color(hex: 0x565F89),
        accent:     Color(hex: 0x7AA2F7),
        cyan:       Color(hex: 0x7DCFFF),
        green:      Color(hex: 0x9ECE6A),
        orange:     Color(hex: 0xFF9E64),
        pink:       Color(hex: 0xBB9AF7),
        red:        Color(hex: 0xF7768E),
        yellow:     Color(hex: 0xE0AF68)
    )

    static let nord = AppTheme(
        id: "nord", name: "Nord", isDark: true,
        background: Color(hex: 0x2E3440),
        sidebar:    Color(hex: 0x272C36),
        surface:    Color(hex: 0x3B4252),
        foreground: Color(hex: 0xECEFF4),
        secondary:  Color(hex: 0x4C566A),
        accent:     Color(hex: 0x88C0D0),
        cyan:       Color(hex: 0x8FBCBB),
        green:      Color(hex: 0xA3BE8C),
        orange:     Color(hex: 0xD08770),
        pink:       Color(hex: 0xB48EAD),
        red:        Color(hex: 0xBF616A),
        yellow:     Color(hex: 0xEBCB8B)
    )

    static let catppuccinMocha = AppTheme(
        id: "catppuccin-mocha", name: "Catppuccin Mocha", isDark: true,
        background: Color(hex: 0x1E1E2E),
        sidebar:    Color(hex: 0x181825),
        surface:    Color(hex: 0x313244),
        foreground: Color(hex: 0xCDD6F4),
        secondary:  Color(hex: 0x6C7086),
        accent:     Color(hex: 0xCBA6F7),
        cyan:       Color(hex: 0x89DCEB),
        green:      Color(hex: 0xA6E3A1),
        orange:     Color(hex: 0xFAB387),
        pink:       Color(hex: 0xF5C2E7),
        red:        Color(hex: 0xF38BA8),
        yellow:     Color(hex: 0xF9E2AF)
    )

    static let gruvboxDark = AppTheme(
        id: "gruvbox-dark", name: "Gruvbox Dark", isDark: true,
        background: Color(hex: 0x282828),
        sidebar:    Color(hex: 0x1D2021),
        surface:    Color(hex: 0x3C3836),
        foreground: Color(hex: 0xEBDBB2),
        secondary:  Color(hex: 0x928374),
        accent:     Color(hex: 0xFE8019),
        cyan:       Color(hex: 0x8EC07C),
        green:      Color(hex: 0xB8BB26),
        orange:     Color(hex: 0xFE8019),
        pink:       Color(hex: 0xD3869B),
        red:        Color(hex: 0xFB4934),
        yellow:     Color(hex: 0xFABD2F)
    )

    static let rosePine = AppTheme(
        id: "rose-pine", name: "Rosé Pine", isDark: true,
        background: Color(hex: 0x191724),
        sidebar:    Color(hex: 0x13111E),
        surface:    Color(hex: 0x26233A),
        foreground: Color(hex: 0xE0DEF4),
        secondary:  Color(hex: 0x6E6A86),
        accent:     Color(hex: 0xC4A7E7),
        cyan:       Color(hex: 0x9CCFD8),
        green:      Color(hex: 0x31748F),
        orange:     Color(hex: 0xF6C177),
        pink:       Color(hex: 0xEBBCBA),
        red:        Color(hex: 0xEB6F92),
        yellow:     Color(hex: 0xF6C177)
    )

    // ── Light Themes ──

    static let githubLight = AppTheme(
        id: "github-light", name: "GitHub Light", isDark: false,
        background: Color(hex: 0xFFFFFF),
        sidebar:    Color(hex: 0xF6F8FA),
        surface:    Color(hex: 0xF6F8FA),
        foreground: Color(hex: 0x24292F),
        secondary:  Color(hex: 0x57606A),
        accent:     Color(hex: 0x0969DA),
        cyan:       Color(hex: 0x0550AE),
        green:      Color(hex: 0x1A7F37),
        orange:     Color(hex: 0xBC4C00),
        pink:       Color(hex: 0x8250DF),
        red:        Color(hex: 0xCF222E),
        yellow:     Color(hex: 0x9A6700)
    )

    static let solarizedLight = AppTheme(
        id: "solarized-light", name: "Solarized Light", isDark: false,
        background: Color(hex: 0xFDF6E3),
        sidebar:    Color(hex: 0xEEE8D5),
        surface:    Color(hex: 0xEEE8D5),
        foreground: Color(hex: 0x657B83),
        secondary:  Color(hex: 0x93A1A1),
        accent:     Color(hex: 0x268BD2),
        cyan:       Color(hex: 0x2AA198),
        green:      Color(hex: 0x859900),
        orange:     Color(hex: 0xCB4B16),
        pink:       Color(hex: 0xD33682),
        red:        Color(hex: 0xDC322F),
        yellow:     Color(hex: 0xB58900)
    )

    static let catppuccinLatte = AppTheme(
        id: "catppuccin-latte", name: "Catppuccin Latte", isDark: false,
        background: Color(hex: 0xEFF1F5),
        sidebar:    Color(hex: 0xE6E9EF),
        surface:    Color(hex: 0xDCE0E8),
        foreground: Color(hex: 0x4C4F69),
        secondary:  Color(hex: 0x9CA0B0),
        accent:     Color(hex: 0x8839EF),
        cyan:       Color(hex: 0x04A5E5),
        green:      Color(hex: 0x40A02B),
        orange:     Color(hex: 0xFE640B),
        pink:       Color(hex: 0xEA76CB),
        red:        Color(hex: 0xD20F39),
        yellow:     Color(hex: 0xDF8E1D)
    )
}

// MARK: - Theme Manager

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var current: AppTheme {
        didSet {
            UserDefaults.standard.set(current.id, forKey: "selectedTheme")
        }
    }

    private init() {
        let savedID = UserDefaults.standard.string(forKey: "selectedTheme") ?? "dracula"
        current = AppTheme.all.first { $0.id == savedID } ?? .dracula
    }

    func select(_ theme: AppTheme) {
        current = theme
    }
}
