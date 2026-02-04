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

    var isEditing: Bool {
        existingVariable != nil
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(isEditing ? "Edit Variable" : "New Variable")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("Variable Name:", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isEditing)
                    .onChange(of: name) { _ in
                        showValidationError = false
                    }

                VStack(alignment: .leading) {
                    Text("Value:")
                    TextEditor(text: $value)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 60)
                        .border(Color.gray.opacity(0.3))
                }

                if showValidationError {
                    Text(validationMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                Text("Preview:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(shellType.formatExport(name: name.isEmpty ? "VAR" : name, value: value))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
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

    private func save() {
        // Validate name
        guard EnvironmentVariable.validate(name: name) else {
            validationMessage = "Invalid variable name. Use only letters, numbers, and underscores. Must start with a letter or underscore."
            showValidationError = true
            return
        }

        let variable = EnvironmentVariable(
            id: existingVariable?.id ?? UUID(),
            name: name,
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
