import Foundation

class ShellConfigWriter {

    private let backupDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        backupDirectory = appSupport.appendingPathComponent("EnvManager/Backups", isDirectory: true)

        try? FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    }

    func createBackup(of filePath: String) throws -> URL {
        let fileName = (filePath as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupName = "\(fileName)_\(timestamp)"
        let backupURL = backupDirectory.appendingPathComponent(backupName)

        try FileManager.default.copyItem(atPath: filePath, toPath: backupURL.path)
        return backupURL
    }

    func addVariable(_ variable: EnvironmentVariable, to config: ShellConfig) throws -> String {
        var content = config.content

        // Ensure content ends with newline
        if !content.hasSuffix("\n") {
            content += "\n"
        }

        // Add the export statement
        let exportLine = config.shellType.formatExport(name: variable.name, value: variable.value)
        content += exportLine + "\n"

        return content
    }

    func updateVariable(_ variable: EnvironmentVariable, in config: ShellConfig) throws -> String {
        guard let lineNumber = variable.lineNumber else {
            // Variable doesn't exist, add it
            return try addVariable(variable, to: config)
        }

        var lines = config.content.components(separatedBy: .newlines)

        guard lineNumber > 0 && lineNumber <= lines.count else {
            throw WriterError.invalidLineNumber
        }

        // Replace the line with updated export
        let newLine = config.shellType.formatExport(name: variable.name, value: variable.value)
        lines[lineNumber - 1] = newLine

        return lines.joined(separator: "\n")
    }

    func deleteVariable(_ variable: EnvironmentVariable, from config: ShellConfig) throws -> String {
        guard let lineNumber = variable.lineNumber else {
            throw WriterError.variableNotFound
        }

        var lines = config.content.components(separatedBy: .newlines)

        guard lineNumber > 0 && lineNumber <= lines.count else {
            throw WriterError.invalidLineNumber
        }

        // Comment out the line instead of deleting to be safe
        lines[lineNumber - 1] = "# \(lines[lineNumber - 1]) # Removed by EnvManager"

        return lines.joined(separator: "\n")
    }

    func writeConfig(_ content: String, to filePath: String, createBackup: Bool = true) throws {
        // Create backup if file exists
        if createBackup && FileManager.default.fileExists(atPath: filePath) {
            _ = try self.createBackup(of: filePath)
        }

        // Ensure parent directory exists
        let parentDir = (filePath as NSString).deletingLastPathComponent
        if !FileManager.default.fileExists(atPath: parentDir) {
            try FileManager.default.createDirectory(atPath: parentDir, withIntermediateDirectories: true)
        }

        // Write the file
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    func createConfigFileIfNeeded(at path: String, shellType: ShellType) throws {
        if FileManager.default.fileExists(atPath: path) {
            return
        }

        let header: String
        switch shellType {
        case .zsh:
            header = """
            # ~/.zshrc - Zsh configuration
            # Created by EnvManager

            """
        case .bash:
            header = """
            # ~/.bashrc - Bash configuration
            # Created by EnvManager

            """
        case .fish:
            header = """
            # ~/.config/fish/config.fish - Fish configuration
            # Created by EnvManager

            """
        }

        try writeConfig(header, to: path, createBackup: false)
    }

    func getBackups() -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }
    }

    func restoreBackup(_ backupURL: URL, to originalPath: String) throws {
        // Backup current before restoring
        if FileManager.default.fileExists(atPath: originalPath) {
            _ = try createBackup(of: originalPath)
        }

        try FileManager.default.copyItem(at: backupURL, to: URL(fileURLWithPath: originalPath))
    }

    enum WriterError: Error, LocalizedError {
        case invalidLineNumber
        case variableNotFound
        case fileNotFound
        case permissionDenied

        var errorDescription: String? {
            switch self {
            case .invalidLineNumber:
                return "Invalid line number in configuration file"
            case .variableNotFound:
                return "Variable not found in configuration file"
            case .fileNotFound:
                return "Configuration file not found"
            case .permissionDenied:
                return "Permission denied to modify configuration file"
            }
        }
    }
}
