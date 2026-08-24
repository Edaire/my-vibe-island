public enum TerminalHostCategory: String, Codable, Equatable, Sendable {
    case terminal
    case multiplexer
    case ide
    case desktopApp
    case remote
    case fallback
}

public enum TerminalPermissionRequirement: String, Codable, Equatable, Sendable {
    case automation
    case accessibility
    case urlScheme
    case cli
    case socket
    case none
}

public struct TerminalCapabilityDescriptor: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let category: TerminalHostCategory
    public let supportLevel: AgentSupportLevel
    public let supportedPrecisions: [JumpPrecision]
    public let bundleIdentifiers: [String]
    public let cliCommands: [String]
    public let permissionRequirements: [TerminalPermissionRequirement]

    public var isExperimental: Bool {
        supportLevel == .experimental
    }

    public var isWorkspaceLevel: Bool {
        supportedPrecisions.contains(.workspace)
            && !supportedPrecisions.contains(.exactPane)
            && !supportedPrecisions.contains(.exactWindow)
    }

    public init(
        id: String,
        displayName: String,
        category: TerminalHostCategory,
        supportLevel: AgentSupportLevel,
        supportedPrecisions: [JumpPrecision],
        bundleIdentifiers: [String] = [],
        cliCommands: [String] = [],
        permissionRequirements: [TerminalPermissionRequirement] = [.none]
    ) {
        self.id = id
        self.displayName = displayName
        self.category = category
        self.supportLevel = supportLevel
        self.supportedPrecisions = supportedPrecisions
        self.bundleIdentifiers = bundleIdentifiers
        self.cliCommands = cliCommands
        self.permissionRequirements = permissionRequirements
    }
}

public struct TerminalRegistry: Codable, Equatable, Sendable {
    public let descriptors: [TerminalCapabilityDescriptor]

    public init(descriptors: [TerminalCapabilityDescriptor]) {
        self.descriptors = descriptors
    }

    public func descriptor(for id: String) -> TerminalCapabilityDescriptor? {
        descriptors.first { $0.id == id }
    }

    public func descriptor(bundleIdentifier: String) -> TerminalCapabilityDescriptor? {
        descriptors.first { $0.bundleIdentifiers.contains(bundleIdentifier) }
    }

    public func descriptor(cliCommand: String) -> TerminalCapabilityDescriptor? {
        descriptors.first { $0.cliCommands.contains(cliCommand) }
    }

    public func descriptors(supporting precision: JumpPrecision) -> [TerminalCapabilityDescriptor] {
        descriptors.filter { $0.supportedPrecisions.contains(precision) }
    }
}

public extension TerminalRegistry {
    static let `default` = TerminalRegistry(descriptors: [
        TerminalCapabilityDescriptor(
            id: "custom-url",
            displayName: "Custom URL",
            category: .desktopApp,
            supportLevel: .supported,
            supportedPrecisions: [.exactPane],
            permissionRequirements: [.urlScheme]
        ),
        TerminalCapabilityDescriptor(
            id: "codex-deeplink",
            displayName: "Codex Desktop App",
            category: .desktopApp,
            supportLevel: .experimental,
            supportedPrecisions: [.exactPane],
            permissionRequirements: [.urlScheme]
        ),
        TerminalCapabilityDescriptor(
            id: "supacode",
            displayName: "Supacode",
            category: .terminal,
            supportLevel: .experimental,
            supportedPrecisions: [.exactPane],
            permissionRequirements: [.socket]
        ),
        TerminalCapabilityDescriptor(
            id: "cmux",
            displayName: "cmux",
            category: .terminal,
            supportLevel: .experimental,
            supportedPrecisions: [.exactPane],
            permissionRequirements: [.socket]
        ),
        TerminalCapabilityDescriptor(
            id: "tmux",
            displayName: "tmux",
            category: .multiplexer,
            supportLevel: .supported,
            supportedPrecisions: [.exactPane],
            cliCommands: ["tmux"],
            permissionRequirements: [.cli, .automation]
        ),
        TerminalCapabilityDescriptor(
            id: "zellij",
            displayName: "Zellij",
            category: .multiplexer,
            supportLevel: .experimental,
            supportedPrecisions: [.exactPane],
            cliCommands: ["zellij"],
            permissionRequirements: [.cli]
        ),
        TerminalCapabilityDescriptor(
            id: "wezterm",
            displayName: "WezTerm",
            category: .terminal,
            supportLevel: .supported,
            supportedPrecisions: [.exactPane],
            cliCommands: ["wezterm"],
            permissionRequirements: [.cli]
        ),
        TerminalCapabilityDescriptor(
            id: "kaku",
            displayName: "Kaku",
            category: .terminal,
            supportLevel: .experimental,
            supportedPrecisions: [.exactPane],
            cliCommands: ["kaku"],
            permissionRequirements: [.cli]
        ),
        TerminalCapabilityDescriptor(
            id: "otty",
            displayName: "Otty",
            category: .terminal,
            supportLevel: .experimental,
            supportedPrecisions: [.exactPane],
            permissionRequirements: [.socket]
        ),
        TerminalCapabilityDescriptor(
            id: "kitty",
            displayName: "Kitty",
            category: .terminal,
            supportLevel: .experimental,
            supportedPrecisions: [.exactWindow],
            cliCommands: ["kitty"],
            permissionRequirements: [.socket]
        ),
        TerminalCapabilityDescriptor(
            id: "ghostty",
            displayName: "Ghostty",
            category: .terminal,
            supportLevel: .supported,
            supportedPrecisions: [.exactWindow],
            bundleIdentifiers: ["com.mitchellh.ghostty", "com.github.mitchellh.ghostty"],
            permissionRequirements: [.automation]
        ),
        TerminalCapabilityDescriptor(
            id: "warp",
            displayName: "Warp",
            category: .terminal,
            supportLevel: .experimental,
            supportedPrecisions: [.exactWindow],
            bundleIdentifiers: ["dev.warp.Warp-Stable"],
            permissionRequirements: [.urlScheme, .accessibility]
        ),
        TerminalCapabilityDescriptor(
            id: "iterm",
            displayName: "iTerm2",
            category: .terminal,
            supportLevel: .supported,
            supportedPrecisions: [.exactPane],
            bundleIdentifiers: ["com.googlecode.iterm2"],
            permissionRequirements: [.automation]
        ),
        TerminalCapabilityDescriptor(
            id: "terminal-tty",
            displayName: "Terminal.app",
            category: .terminal,
            supportLevel: .supported,
            supportedPrecisions: [.exactWindow],
            bundleIdentifiers: ["com.apple.Terminal"],
            permissionRequirements: [.automation]
        ),
        TerminalCapabilityDescriptor(
            id: "vscode-workspace",
            displayName: "VS Code",
            category: .ide,
            supportLevel: .supported,
            supportedPrecisions: [.workspace],
            bundleIdentifiers: ["com.microsoft.VSCode"],
            cliCommands: ["code"],
            permissionRequirements: [.cli]
        ),
        TerminalCapabilityDescriptor(
            id: "vscode-insiders-workspace",
            displayName: "VS Code Insiders",
            category: .ide,
            supportLevel: .supported,
            supportedPrecisions: [.workspace],
            bundleIdentifiers: ["com.microsoft.VSCodeInsiders"],
            cliCommands: ["code-insiders"],
            permissionRequirements: [.cli]
        ),
        TerminalCapabilityDescriptor(
            id: "cursor-workspace",
            displayName: "Cursor",
            category: .ide,
            supportLevel: .supported,
            supportedPrecisions: [.workspace],
            bundleIdentifiers: ["com.todesktop.230313mzl4w4u92"],
            cliCommands: ["cursor"],
            permissionRequirements: [.cli]
        ),
        TerminalCapabilityDescriptor(
            id: "windsurf-workspace",
            displayName: "Windsurf",
            category: .ide,
            supportLevel: .supported,
            supportedPrecisions: [.workspace],
            bundleIdentifiers: ["com.exafunction.windsurf"],
            cliCommands: ["windsurf"],
            permissionRequirements: [.cli]
        ),
        TerminalCapabilityDescriptor(
            id: "trae-workspace",
            displayName: "Trae",
            category: .ide,
            supportLevel: .experimental,
            supportedPrecisions: [.workspace],
            bundleIdentifiers: ["com.trae.app"],
            cliCommands: ["trae"],
            permissionRequirements: [.cli]
        ),
        TerminalCapabilityDescriptor(
            id: "qoder-workspace",
            displayName: "Qoder IDE",
            category: .ide,
            supportLevel: .experimental,
            supportedPrecisions: [.workspace],
            cliCommands: ["qoder"],
            permissionRequirements: [.cli]
        ),
        TerminalCapabilityDescriptor(
            id: "jetbrains-workspace",
            displayName: "JetBrains IDEs",
            category: .ide,
            supportLevel: .supported,
            supportedPrecisions: [.workspace],
            bundleIdentifiers: [
                "com.jetbrains.intellij",
                "com.jetbrains.intellij-EAP",
                "com.jetbrains.WebStorm",
                "com.jetbrains.PyCharm",
                "com.jetbrains.goland",
                "com.jetbrains.rider",
                "com.jetbrains.CLion",
                "com.jetbrains.PhpStorm",
                "com.jetbrains.RubyMine",
                "com.jetbrains.datagrip"
            ],
            cliCommands: [
                "idea",
                "webstorm",
                "pycharm",
                "goland",
                "rider",
                "clion",
                "phpstorm",
                "rubymine",
                "datagrip"
            ],
            permissionRequirements: [.cli]
        ),
        TerminalCapabilityDescriptor(
            id: "ide-workspace",
            displayName: "IDE Workspace",
            category: .ide,
            supportLevel: .supported,
            supportedPrecisions: [.workspace],
            permissionRequirements: [.cli]
        ),
        TerminalCapabilityDescriptor(
            id: "workspace",
            displayName: "Workspace",
            category: .fallback,
            supportLevel: .supported,
            supportedPrecisions: [.workspace]
        ),
        TerminalCapabilityDescriptor(
            id: "claude-desktop-code",
            displayName: "Claude Desktop Code",
            category: .desktopApp,
            supportLevel: .detectedOnly,
            supportedPrecisions: [.application]
        ),
        TerminalCapabilityDescriptor(
            id: "application",
            displayName: "Application",
            category: .fallback,
            supportLevel: .supported,
            supportedPrecisions: [.application]
        ),
        TerminalCapabilityDescriptor(
            id: "remote-hint",
            displayName: "Remote Hint",
            category: .remote,
            supportLevel: .supported,
            supportedPrecisions: [.remoteHint]
        ),
        TerminalCapabilityDescriptor(
            id: "unsupported",
            displayName: "Unsupported",
            category: .fallback,
            supportLevel: .detectedOnly,
            supportedPrecisions: [.unsupported]
        )
    ])
}
