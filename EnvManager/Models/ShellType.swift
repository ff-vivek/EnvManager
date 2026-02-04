import Foundation

enum ShellType: String, CaseIterable, Identifiable {
    case zsh
    case bash
    case fish

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zsh: return "Zsh"
        case .bash: return "Bash"
        case .fish: return "Fish"
        }
    }

    var configFiles: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .zsh:
            return [
                "\(home)/.zshrc",
                "\(home)/.zshenv",
                "\(home)/.zprofile"
            ]
        case .bash:
            return [
                "\(home)/.bashrc",
                "\(home)/.bash_profile",
                "\(home)/.profile"
            ]
        case .fish:
            return [
                "\(home)/.config/fish/config.fish"
            ]
        }
    }

    var primaryConfigFile: String {
        configFiles.first ?? ""
    }

    var exportPattern: String {
        switch self {
        case .zsh, .bash:
            return #"^\s*export\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$"#
        case .fish:
            return #"^\s*set\s+(-[gxU]+\s+)?([A-Za-z_][A-Za-z0-9_]*)\s+(.*)$"#
        }
    }

    func formatExport(name: String, value: String) -> String {
        switch self {
        case .zsh, .bash:
            let escapedValue = value.contains(" ") || value.contains("$") ? "\"\(value)\"" : value
            return "export \(name)=\(escapedValue)"
        case .fish:
            return "set -gx \(name) \(value)"
        }
    }

    static func detect() -> ShellType {
        if let shell = ProcessInfo.processInfo.environment["SHELL"] {
            if shell.contains("zsh") { return .zsh }
            if shell.contains("bash") { return .bash }
            if shell.contains("fish") { return .fish }
        }
        return .zsh
    }
}
