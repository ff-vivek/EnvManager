import Foundation

enum AppEnvironment {
    static let homeDirectoryOverrideKey = "ENV_MANAGER_HOME_OVERRIDE"
    static let backupDirectoryOverrideKey = "ENV_MANAGER_BACKUP_DIRECTORY_OVERRIDE"
    static let shellOverrideKey = "ENV_MANAGER_SHELL_OVERRIDE"

    static var homeDirectoryURL: URL {
        overrideURL(for: homeDirectoryOverrideKey) ?? FileManager.default.homeDirectoryForCurrentUser
    }

    static var homeDirectoryPath: String {
        homeDirectoryURL.path
    }

    static var backupDirectoryOverrideURL: URL? {
        overrideURL(for: backupDirectoryOverrideKey)
    }

    static var shellOverride: String? {
        ProcessInfo.processInfo.environment[shellOverrideKey]
    }

    static func displayPath(_ path: String) -> String {
        path.replacingOccurrences(of: homeDirectoryPath, with: "~")
    }

    private static func overrideURL(for key: String) -> URL? {
        guard let rawValue = ProcessInfo.processInfo.environment[key], !rawValue.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: rawValue, isDirectory: true)
    }
}
