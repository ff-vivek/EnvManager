import SwiftUI
import UniformTypeIdentifiers

struct PathEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let variable: EnvironmentVariable
    let onSave: (EnvironmentVariable) -> Void

    @State private var paths: [PathEntry] = []
    @State private var selectedPath: PathEntry.ID?
    @State private var showAddSheet = false
    @State private var newPath = ""

    struct PathEntry: Identifiable, Hashable {
        let id = UUID()
        var path: String
        var exists: Bool

        init(path: String) {
            self.path = path
            self.exists = FileManager.default.fileExists(atPath: path)
        }
    }

    init(variable: EnvironmentVariable, onSave: @escaping (EnvironmentVariable) -> Void) {
        self.variable = variable
        self.onSave = onSave

        let components = variable.pathComponents.map { PathEntry(path: $0) }
        _paths = State(initialValue: components)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Edit PATH")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }

            Text("Drag to reorder. Paths are searched in order from top to bottom.")
                .font(.caption)
                .foregroundColor(.secondary)

            List(selection: $selectedPath) {
                ForEach(paths) { entry in
                    PathRowView(entry: entry)
                        .tag(entry.id)
                }
                .onMove(perform: movePaths)
            }
            .listStyle(.bordered)
            .frame(minHeight: 250)

            HStack {
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Path", systemImage: "plus")
                }

                Button {
                    if let selected = selectedPath,
                       let index = paths.firstIndex(where: { $0.id == selected }) {
                        paths.remove(at: index)
                        selectedPath = nil
                    }
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selectedPath == nil)

                Spacer()

                Button("Browse...") {
                    browseForFolder()
                }
            }

            Divider()

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
            }
        }
        .padding()
        .frame(width: 500, height: 450)
        .sheet(isPresented: $showAddSheet) {
            AddPathSheet(newPath: $newPath) {
                if !newPath.isEmpty {
                    paths.append(PathEntry(path: newPath))
                    newPath = ""
                }
            }
        }
    }

    private func movePaths(from source: IndexSet, to destination: Int) {
        paths.move(fromOffsets: source, toOffset: destination)
    }

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            paths.append(PathEntry(path: url.path))
        }
    }

    private func save() {
        let pathValue = paths.map(\.path).joined(separator: ":")
        var updatedVariable = variable
        updatedVariable.value = pathValue
        onSave(updatedVariable)
        dismiss()
    }
}

struct PathRowView: View {
    let entry: PathEditorView.PathEntry

    var body: some View {
        HStack {
            Image(systemName: entry.exists ? "folder.fill" : "folder.badge.questionmark")
                .foregroundColor(entry.exists ? .blue : .orange)

            Text(entry.path)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if !entry.exists {
                Text("Not found")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 2)
    }
}

struct AddPathSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var newPath: String
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Path")
                .font(.headline)

            TextField("Path:", text: $newPath)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Browse...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    if panel.runModal() == .OK, let url = panel.url {
                        newPath = url.path
                    }
                }

                Button("Add") {
                    onAdd()
                    dismiss()
                }
                .disabled(newPath.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
