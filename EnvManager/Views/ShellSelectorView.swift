import SwiftUI

struct ShellSelectorView: View {
    @Binding var selectedShell: ShellType
    @Binding var selectedConfigFile: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shell Target")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(FloeTheme.inkPrimary)
                    Text("Choose the shell family and the config file EnvManager should inspect and update.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FloeTheme.inkSecondary)
                }

                Spacer(minLength: 0)

                FloeInfoPill(
                    title: FileManager.default.fileExists(atPath: selectedConfigFile) ? "Existing file" : "File will be created",
                    systemImage: FileManager.default.fileExists(atPath: selectedConfigFile) ? "checkmark.circle.fill" : "plus.circle",
                    tint: FileManager.default.fileExists(atPath: selectedConfigFile) ? FloeTheme.secondary : FloeTheme.accent
                )
            }

            HStack(spacing: 12) {
                ForEach(ShellType.allCases) { shell in
                    Button {
                        selectedShell = shell
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shell.displayName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Text((shell.primaryConfigFile as NSString).lastPathComponent)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(selectedShell == shell ? Color.white.opacity(0.8) : FloeTheme.inkSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("shell-\(shell.rawValue)-button")
                    .buttonStyle(FloeSelectableChipStyle(isSelected: selectedShell == shell))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration file")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(FloeTheme.inkTertiary)

                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .foregroundStyle(FloeTheme.primary)
                    Picker("Config File", selection: $selectedConfigFile) {
                        ForEach(selectedShell.configFiles, id: \.self) { file in
                            Text(displayPath(file)).tag(file)
                        }
                    }
                    .accessibilityIdentifier("shell-config-picker")
                    .pickerStyle(.menu)
                    .labelsHidden()

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .floeGlassField(cornerRadius: 18)
            }
        }
        .floeCard(fill: FloeTheme.primary.opacity(0.05), border: FloeTheme.border.opacity(0.16), shadow: .soft)
        .onChange(of: selectedShell) { newShell in
            selectedConfigFile = newShell.primaryConfigFile
        }
    }

    private func displayPath(_ path: String) -> String {
        AppEnvironment.displayPath(path)
    }
}
