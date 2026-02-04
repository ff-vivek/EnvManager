import Foundation

class ShellConfigParser {

    func parseConfigFile(at path: String, shellType: ShellType) -> ShellConfig? {
        guard FileManager.default.fileExists(atPath: path),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        let variables = parseVariables(from: content, shellType: shellType, filePath: path)
        return ShellConfig(shellType: shellType, filePath: path, content: content, variables: variables)
    }

    func parseVariables(from content: String, shellType: ShellType, filePath: String) -> [EnvironmentVariable] {
        var variables: [EnvironmentVariable] = []
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            if let variable = parseLine(line, shellType: shellType, filePath: filePath, lineNumber: index + 1) {
                variables.append(variable)
            }
        }

        return variables
    }

    private func parseLine(_ line: String, shellType: ShellType, filePath: String, lineNumber: Int) -> EnvironmentVariable? {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)

        // Skip comments and empty lines
        if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
            return nil
        }

        switch shellType {
        case .zsh, .bash:
            return parseBashZshExport(trimmedLine, filePath: filePath, lineNumber: lineNumber)
        case .fish:
            return parseFishSet(trimmedLine, filePath: filePath, lineNumber: lineNumber)
        }
    }

    private func parseBashZshExport(_ line: String, filePath: String, lineNumber: Int) -> EnvironmentVariable? {
        // Match: export VAR=value or export VAR="value" or export VAR='value'
        let pattern = #"^export\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let nameRange = Range(match.range(at: 1), in: line),
              let valueRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let name = String(line[nameRange])
        var value = String(line[valueRange])

        // Remove surrounding quotes
        value = stripQuotes(value)

        return EnvironmentVariable(
            name: name,
            value: value,
            sourceFile: filePath,
            lineNumber: lineNumber,
            isSystemVariable: false
        )
    }

    private func parseFishSet(_ line: String, filePath: String, lineNumber: Int) -> EnvironmentVariable? {
        // Match: set -gx VAR value or set -x VAR value
        let pattern = #"^set\s+(-[gxUe]+\s+)*([A-Za-z_][A-Za-z0-9_]*)\s+(.*)$"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        guard let nameRange = Range(match.range(at: 2), in: line),
              let valueRange = Range(match.range(at: 3), in: line) else {
            return nil
        }

        let name = String(line[nameRange])
        var value = String(line[valueRange])

        // Fish uses space-separated path components, convert to colon-separated for display
        if name == "PATH" || name == "MANPATH" {
            value = value.components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .map { stripQuotes($0) }
                .joined(separator: ":")
        } else {
            value = stripQuotes(value)
        }

        return EnvironmentVariable(
            name: name,
            value: value,
            sourceFile: filePath,
            lineNumber: lineNumber,
            isSystemVariable: false
        )
    }

    private func stripQuotes(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespaces)

        // Remove double quotes
        if result.hasPrefix("\"") && result.hasSuffix("\"") && result.count >= 2 {
            result = String(result.dropFirst().dropLast())
        }
        // Remove single quotes
        else if result.hasPrefix("'") && result.hasSuffix("'") && result.count >= 2 {
            result = String(result.dropFirst().dropLast())
        }

        return result
    }

    func getSystemVariables() -> [EnvironmentVariable] {
        let env = ProcessInfo.processInfo.environment
        return env.map { key, value in
            EnvironmentVariable(
                name: key,
                value: value,
                sourceFile: nil,
                lineNumber: nil,
                isSystemVariable: true
            )
        }.sorted { $0.name < $1.name }
    }

    func getAllConfigs(for shellType: ShellType) -> [ShellConfig] {
        var configs: [ShellConfig] = []

        for path in shellType.configFiles {
            if let config = parseConfigFile(at: path, shellType: shellType) {
                configs.append(config)
            }
        }

        return configs
    }
}
