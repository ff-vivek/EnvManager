import SwiftUI

struct VariableEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let shellType: ShellType
    var existingVariable: EnvironmentVariable? = nil
    let onSave: (EnvironmentVariable) -> Void

    @State private var name: String = ""
    @State private var value: String = ""
    @State private var showValidationError = false
    @State private var validationMessage = ""
    @State private var hasAppeared = false

    private var isEditing: Bool {
        existingVariable != nil
    }

    private var previewText: String {
        shellType.formatExport(name: name.isEmpty ? "VAR_NAME" : name, value: value)
    }

    var body: some View {
        ZStack {
            FloeTheme.pageBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isEditing ? "Edit Variable" : "New Variable")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(FloeTheme.inkPrimary)
                        Text("Compose a shell export with Floe-style spacing and a live preview before saving it to the pending change set.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FloeTheme.inkSecondary)
                    }

                    Spacer(minLength: 0)

                    FloeInfoPill(
                        title: shellType.displayName,
                        systemImage: "terminal",
                        tint: FloeTheme.primary
                    )
                }

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Variable name")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(FloeTheme.inkTertiary)

                        TextField("MY_VARIABLE", text: $name)
                            .accessibilityIdentifier("variable-name-field")
                            .textFieldStyle(.plain)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(FloeTheme.inkPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(floeFieldBackground)
                            .disabled(isEditing)
                            .onChange(of: name) { _ in
                                showValidationError = false
                            }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Value")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(FloeTheme.inkTertiary)

                        TextEditor(text: $value)
                            .accessibilityIdentifier("variable-value-field")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(FloeTheme.inkPrimary)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 110)
                            .background(floeFieldBackground)
                    }

                    if showValidationError {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(FloeTheme.danger)
                            Text(validationMessage)
                                .accessibilityIdentifier("variable-validation-message")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(FloeTheme.danger)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(FloeTheme.danger.opacity(0.10))
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preview")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(FloeTheme.inkTertiary)

                        Text(previewText)
                            .accessibilityIdentifier("variable-preview-text")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(FloeTheme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .floeGlassField(cornerRadius: 18)
                    }
                }
                .floeCard(fill: FloeTheme.primary.opacity(0.04), border: FloeTheme.border.opacity(0.18), shadow: .elevated)

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("variable-cancel-button")
                    .buttonStyle(FloeButtonStyle(variant: .ghost))
                    .keyboardShortcut(.cancelAction)

                    Spacer(minLength: 0)

                    Button(isEditing ? "Save Changes" : "Save Variable") {
                        save()
                    }
                    .accessibilityIdentifier("variable-save-button")
                    .buttonStyle(FloeButtonStyle(variant: .filled))
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(24)
        }
        .frame(width: 480, height: 470)
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
                if let existing = existingVariable {
                    name = existing.name
                    value = existing.value
                }
            }
        }
    }

    private var floeFieldBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.clear)
            .floeGlassField(cornerRadius: 18)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard EnvironmentVariable.validate(name: trimmedName) else {
            validationMessage = "Invalid variable name. Use letters, numbers, and underscores only, and start with a letter or underscore."
            showValidationError = true
            return
        }

        let variable = EnvironmentVariable(
            id: existingVariable?.id ?? UUID(),
            name: trimmedName,
            value: value,
            sourceFile: existingVariable?.sourceFile,
            lineNumber: existingVariable?.lineNumber,
            isSystemVariable: false
        )

        onSave(variable)
        dismiss()
    }
}

struct VariableEditorView_Previews: PreviewProvider {
    static var previews: some View {
        VariableEditorView(shellType: .zsh) { _ in }
    }
}
