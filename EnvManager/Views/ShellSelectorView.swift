import SwiftUI

struct ShellSelectorView: View {
    @Binding var selectedShell: ShellType
    @Binding var selectedConfigFile: String

    var body: some View {
        HStack(spacing: 16) {
            HStack {
                Text("Shell:")
                    .foregroundColor(.secondary)

                Picker("Shell", selection: $selectedShell) {
                    ForEach(ShellType.allCases) { shell in
                        Text(shell.displayName).tag(shell)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }

            HStack {
                Text("Config:")
                    .foregroundColor(.secondary)

                Picker("Config File", selection: $selectedConfigFile) {
                    ForEach(selectedShell.configFiles, id: \.self) { file in
                        Text(displayPath(file)).tag(file)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 150)
            }

            Spacer()

            if FileManager.default.fileExists(atPath: selectedConfigFile) {
                Label("File exists", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Label("File will be created", systemImage: "plus.circle")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .onChange(of: selectedShell) { newShell in
            selectedConfigFile = newShell.primaryConfigFile
        }
    }

    private func displayPath(_ path: String) -> String {
        path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }
}
