import Foundation
import SwiftUI

@MainActor
class EnvironmentViewModel: ObservableObject {
    @Published var selectedShell: ShellType = .zsh {
        didSet {
            if oldValue != selectedShell {
                selectedConfigFile = selectedShell.primaryConfigFile
                loadConfiguration()
            }
        }
    }

    @Published var selectedConfigFile: String = "" {
        didSet {
            if oldValue != selectedConfigFile {
                loadConfiguration()
            }
        }
    }

    @Published var userVariables: [EnvironmentVariable] = []
    @Published var systemVariables: [EnvironmentVariable] = []
    @Published var currentConfig: ShellConfig?
    @Published var hasUnsavedChanges = false

    private let parser = ShellConfigParser()
    private let writer = ShellConfigWriter()

    private var pendingAdditions: [EnvironmentVariable] = []
    private var pendingUpdates: [EnvironmentVariable] = []
    private var pendingDeletions: [EnvironmentVariable] = []

    init() {
        selectedShell = ShellType.detect()
        selectedConfigFile = selectedShell.primaryConfigFile
    }

    func loadConfiguration() {
        // Load system variables
        systemVariables = parser.getSystemVariables()

        // Load user variables from config file
        if let config = parser.parseConfigFile(at: selectedConfigFile, shellType: selectedShell) {
            currentConfig = config
            userVariables = config.variables
        } else {
            // File doesn't exist yet
            currentConfig = ShellConfig(shellType: selectedShell, filePath: selectedConfigFile)
            userVariables = []
        }

        // Clear pending changes
        pendingAdditions.removeAll()
        pendingUpdates.removeAll()
        pendingDeletions.removeAll()
        hasUnsavedChanges = false
    }

    func addVariable(_ variable: EnvironmentVariable) {
        var newVar = variable
        newVar.sourceFile = selectedConfigFile

        // Check for duplicates
        if let existingIndex = userVariables.firstIndex(where: { $0.name == variable.name }) {
            // Update existing instead
            userVariables[existingIndex] = newVar
            if let pendingIndex = pendingAdditions.firstIndex(where: { $0.name == variable.name }) {
                pendingAdditions[pendingIndex] = newVar
            } else {
                pendingUpdates.append(newVar)
            }
        } else {
            userVariables.append(newVar)
            pendingAdditions.append(newVar)
        }

        hasUnsavedChanges = true
    }

    func updateVariable(_ variable: EnvironmentVariable) {
        if let index = userVariables.firstIndex(where: { $0.id == variable.id }) {
            userVariables[index] = variable

            // Track in pending updates if not a new addition
            if !pendingAdditions.contains(where: { $0.id == variable.id }) {
                if let updateIndex = pendingUpdates.firstIndex(where: { $0.id == variable.id }) {
                    pendingUpdates[updateIndex] = variable
                } else {
                    pendingUpdates.append(variable)
                }
            } else {
                // Update the pending addition
                if let addIndex = pendingAdditions.firstIndex(where: { $0.id == variable.id }) {
                    pendingAdditions[addIndex] = variable
                }
            }

            hasUnsavedChanges = true
        }
    }

    func deleteVariable(_ variable: EnvironmentVariable) {
        userVariables.removeAll { $0.id == variable.id }

        // If it was a pending addition, just remove it
        if pendingAdditions.contains(where: { $0.id == variable.id }) {
            pendingAdditions.removeAll { $0.id == variable.id }
        } else {
            // Otherwise, track for deletion
            pendingDeletions.append(variable)
        }

        // Remove from pending updates if present
        pendingUpdates.removeAll { $0.id == variable.id }

        hasUnsavedChanges = true
    }

    func previewChanges() -> String {
        guard var config = currentConfig else {
            return "No configuration loaded"
        }

        var content = config.content

        // Apply deletions
        for variable in pendingDeletions {
            if let updated = try? writer.deleteVariable(variable, from: config) {
                content = updated
                config = ShellConfig(shellType: config.shellType, filePath: config.filePath, content: content, variables: config.variables)
            }
        }

        // Apply updates
        for variable in pendingUpdates {
            if let updated = try? writer.updateVariable(variable, in: config) {
                content = updated
                config = ShellConfig(shellType: config.shellType, filePath: config.filePath, content: content, variables: config.variables)
            }
        }

        // Apply additions
        for variable in pendingAdditions {
            if let updated = try? writer.addVariable(variable, to: config) {
                content = updated
                config = ShellConfig(shellType: config.shellType, filePath: config.filePath, content: content, variables: config.variables)
            }
        }

        return content
    }

    func saveChanges() throws {
        guard let config = currentConfig else {
            throw SaveError.noConfiguration
        }

        // Create config file if needed
        try writer.createConfigFileIfNeeded(at: selectedConfigFile, shellType: selectedShell)

        // Generate new content
        let newContent = previewChanges()

        // Write to file
        try writer.writeConfig(newContent, to: selectedConfigFile)

        // Reload to get fresh state
        loadConfiguration()
    }

    enum SaveError: Error, LocalizedError {
        case noConfiguration

        var errorDescription: String? {
            switch self {
            case .noConfiguration:
                return "No configuration loaded"
            }
        }
    }
}
