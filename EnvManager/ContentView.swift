import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = EnvironmentViewModel()

    @State private var selectedUserVariable: EnvironmentVariable?
    @State private var selectedSystemVariable: EnvironmentVariable?

    @State private var showingAddSheet = false
    @State private var showingPreview = false
    @State private var showingError = false
    @State private var errorMessage = ""

    @State private var variableToEdit: EnvironmentVariable?
    @State private var pathVariableToEdit: EnvironmentVariable?

    var body: some View {
        VStack(spacing: 0) {
            // Shell Selector
            ShellSelectorView(
                selectedShell: $viewModel.selectedShell,
                selectedConfigFile: $viewModel.selectedConfigFile
            )

            Divider()

            // Main Content
            VStack(spacing: 16) {
                // User Variables Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("User Variables")
                            .font(.headline)

                        Spacer()

                        Button {
                            showingAddSheet = true
                        } label: {
                            Label("New...", systemImage: "plus")
                        }

                        Button {
                            if let selected = selectedUserVariable {
                                if selected.isPath {
                                    pathVariableToEdit = selected
                                } else {
                                    variableToEdit = selected
                                }
                            }
                        } label: {
                            Label("Edit...", systemImage: "pencil")
                        }
                        .disabled(selectedUserVariable == nil)

                        Button {
                            if let selected = selectedUserVariable {
                                deleteVariable(selected)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(selectedUserVariable == nil)
                    }

                    Table(viewModel.userVariables, selection: Binding(
                        get: { selectedUserVariable?.id },
                        set: { id in selectedUserVariable = viewModel.userVariables.first { $0.id == id } }
                    )) {
                        TableColumn("Variable") { variable in
                            HStack {
                                if variable.isPath {
                                    Image(systemName: "folder.badge.gearshape")
                                        .foregroundColor(.blue)
                                }
                                Text(variable.name)
                                    .fontWeight(variable.isPath ? .semibold : .regular)
                            }
                        }
                        .width(min: 120, ideal: 150, max: 200)

                        TableColumn("Value") { variable in
                            Text(variable.value)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .font(.system(.body, design: .monospaced))
                        }

                        TableColumn("Source") { variable in
                            if let source = variable.sourceFile {
                                Text((source as NSString).lastPathComponent)
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .width(min: 80, ideal: 100, max: 120)
                    }
                    .tableStyle(.bordered)
                    .frame(minHeight: 180)
                }

                Divider()

                // System Variables Section (Read-only)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("System Variables")
                            .font(.headline)
                        Text("(Read-only)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    Table(viewModel.systemVariables, selection: Binding(
                        get: { selectedSystemVariable?.id },
                        set: { id in selectedSystemVariable = viewModel.systemVariables.first { $0.id == id } }
                    )) {
                        TableColumn("Variable", value: \.name)
                            .width(min: 120, ideal: 150, max: 200)

                        TableColumn("Value") { variable in
                            Text(variable.value)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .tableStyle(.bordered)
                    .frame(minHeight: 150)
                }
            }
            .padding()

            Divider()

            // Bottom Action Bar
            HStack {
                if viewModel.hasUnsavedChanges {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Unsaved changes")
                        .foregroundColor(.orange)
                        .font(.caption)
                }

                Spacer()

                Button("Preview Changes...") {
                    showingPreview = true
                }
                .disabled(!viewModel.hasUnsavedChanges)

                Button("Apply") {
                    applyChanges()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.hasUnsavedChanges)

                Button("Reload") {
                    viewModel.loadConfiguration()
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 650, minHeight: 550)
        .onAppear {
            viewModel.loadConfiguration()
        }
        .sheet(isPresented: $showingAddSheet) {
            VariableEditorView(shellType: viewModel.selectedShell) { variable in
                viewModel.addVariable(variable)
            }
        }
        .sheet(item: $variableToEdit) { variable in
            VariableEditorView(shellType: viewModel.selectedShell, existingVariable: variable) { updated in
                viewModel.updateVariable(updated)
            }
        }
        .sheet(item: $pathVariableToEdit) { variable in
            PathEditorView(variable: variable) { updated in
                viewModel.updateVariable(updated)
            }
        }
        .sheet(isPresented: $showingPreview) {
            PreviewChangesView(viewModel: viewModel) {
                applyChanges()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func deleteVariable(_ variable: EnvironmentVariable) {
        viewModel.deleteVariable(variable)
    }

    private func applyChanges() {
        do {
            try viewModel.saveChanges()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct PreviewChangesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: EnvironmentViewModel
    let onApply: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Preview Changes")
                .font(.title2)
                .fontWeight(.semibold)

            Text("The following changes will be made to \(viewModel.currentConfig?.displayPath ?? "config file"):")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                Text(viewModel.previewChanges())
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(nsColor: .textBackgroundColor))
            .border(Color.gray.opacity(0.3))
            .frame(minHeight: 200)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Apply Changes") {
                    onApply()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 550, height: 400)
    }
}

#Preview {
    ContentView()
}
