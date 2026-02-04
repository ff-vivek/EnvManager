import SwiftUI

@main
struct EnvManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandMenu("Variables") {
                Button("New Variable...") {
                    NotificationCenter.default.post(name: .addVariable, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Edit Variable...") {
                    NotificationCenter.default.post(name: .editVariable, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)

                Divider()

                Button("Delete Variable") {
                    NotificationCenter.default.post(name: .deleteVariable, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }

            CommandMenu("Shell") {
                Button("Zsh") {
                    NotificationCenter.default.post(name: .selectShell, object: ShellType.zsh)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Bash") {
                    NotificationCenter.default.post(name: .selectShell, object: ShellType.bash)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Fish") {
                    NotificationCenter.default.post(name: .selectShell, object: ShellType.fish)
                }
                .keyboardShortcut("3", modifiers: .command)

                Divider()

                Button("Reload Configuration") {
                    NotificationCenter.default.post(name: .reloadConfig, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let addVariable = Notification.Name("addVariable")
    static let editVariable = Notification.Name("editVariable")
    static let deleteVariable = Notification.Name("deleteVariable")
    static let selectShell = Notification.Name("selectShell")
    static let reloadConfig = Notification.Name("reloadConfig")
}
