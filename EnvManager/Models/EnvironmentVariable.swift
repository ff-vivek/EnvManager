import Foundation

struct EnvironmentVariable: Identifiable, Hashable {
    let id: UUID
    var name: String
    var value: String
    var sourceFile: String?
    var lineNumber: Int?
    var isSystemVariable: Bool

    init(id: UUID = UUID(), name: String, value: String, sourceFile: String? = nil, lineNumber: Int? = nil, isSystemVariable: Bool = false) {
        self.id = id
        self.name = name
        self.value = value
        self.sourceFile = sourceFile
        self.lineNumber = lineNumber
        self.isSystemVariable = isSystemVariable
    }

    var isPath: Bool {
        name == "PATH" || name == "MANPATH" || name == "INFOPATH"
    }

    var pathComponents: [String] {
        value.split(separator: ":").map(String.init)
    }

    static func validate(name: String) -> Bool {
        let pattern = #"^[A-Za-z_][A-Za-z0-9_]*$"#
        return name.range(of: pattern, options: .regularExpression) != nil
    }
}

struct ShellConfig: Identifiable {
    let id: UUID
    let shellType: ShellType
    let filePath: String
    var content: String
    var variables: [EnvironmentVariable]
    var lastModified: Date?

    init(id: UUID = UUID(), shellType: ShellType, filePath: String, content: String = "", variables: [EnvironmentVariable] = []) {
        self.id = id
        self.shellType = shellType
        self.filePath = filePath
        self.content = content
        self.variables = variables

        if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
           let modDate = attrs[.modificationDate] as? Date {
            self.lastModified = modDate
        }
    }

    var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    var displayPath: String {
        filePath.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
}
