import SwiftUI
import UniformTypeIdentifiers

struct PathEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let variable: EnvironmentVariable
    let onSave: (EnvironmentVariable) -> Void
    private let onPickFolder: () -> String?

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

    private var existingCount: Int {
        paths.filter(\.exists).count
    }

    init(
        variable: EnvironmentVariable,
        onSave: @escaping (EnvironmentVariable) -> Void,
        onPickFolder: @escaping () -> String? = PathEditorView.liveFolderPicker
    ) {
        self.variable = variable
        self.onSave = onSave
        self.onPickFolder = onPickFolder

        let components = variable.pathComponents.map { PathEntry(path: $0) }
        _paths = State(initialValue: components)
    }

    var body: some View {
        ZStack {
            FloeTheme.pageBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Edit \(variable.name)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(FloeTheme.inkPrimary)
                        Text("Reorder directories, remove dead entries, and browse for new folders before saving the updated path string.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FloeTheme.inkSecondary)
                    }

                    Spacer(minLength: 0)

                    FloeInfoPill(
                        title: "\(paths.count) entries",
                        systemImage: "list.bullet.indent",
                        tint: FloeTheme.primary
                    )
                }

                HStack(spacing: 14) {
                    FloeMetricCard(
                        title: "Resolved Paths",
                        value: "\(existingCount)",
                        detail: "Folders currently present on disk",
                        systemImage: "checkmark.seal",
                        tint: FloeTheme.secondary
                    )
                    FloeMetricCard(
                        title: "Missing Paths",
                        value: "\(max(paths.count - existingCount, 0))",
                        detail: "Candidates for cleanup or replacement",
                        systemImage: "exclamationmark.circle",
                        tint: FloeTheme.accent
                    )
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Directory order")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(FloeTheme.inkPrimary)
                        Spacer(minLength: 0)
                        Text("Drag to reorder")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(FloeTheme.inkSecondary)
                    }

                    List(selection: $selectedPath) {
                        ForEach(paths) { entry in
                            PathRowView(entry: entry)
                                .tag(entry.id)
                                .listRowBackground(Color.clear)
                        }
                        .onMove(perform: movePaths)
                    }
                    .accessibilityIdentifier("path-entries-list")
                    .frame(minHeight: 280)
                    .scrollContentBackground(.hidden)
                    .floeGlassField(cornerRadius: 20)

                    HStack(spacing: 12) {
                        Button {
                            showAddSheet = true
                        } label: {
                            Label("Add Path", systemImage: "plus")
                        }
                        .accessibilityIdentifier("path-add-button")
                        .buttonStyle(FloeButtonStyle(variant: .filled, compact: true))

                        Button {
                            if let selected = selectedPath,
                               let index = paths.firstIndex(where: { $0.id == selected }) {
                                paths.remove(at: index)
                                selectedPath = nil
                            }
                        } label: {
                            Label("Remove", systemImage: "minus")
                        }
                        .accessibilityIdentifier("path-remove-button")
                        .buttonStyle(FloeButtonStyle(variant: .danger, compact: true))
                        .disabled(selectedPath == nil)

                        Spacer(minLength: 0)

                        Button("Browse...") {
                            browseForFolder()
                        }
                        .accessibilityIdentifier("path-browse-button")
                        .buttonStyle(FloeButtonStyle(variant: .soft, compact: true))
                    }
                }
                .floeCard(fill: FloeTheme.primary.opacity(0.04), border: FloeTheme.border.opacity(0.18), shadow: .elevated)

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("path-cancel-button")
                    .buttonStyle(FloeButtonStyle(variant: .ghost))
                    .keyboardShortcut(.cancelAction)

                    Spacer(minLength: 0)

                    Button("Save Path") {
                        save()
                    }
                    .accessibilityIdentifier("path-save-button")
                    .buttonStyle(FloeButtonStyle(variant: .filled))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
        .frame(width: 640, height: 640)
        .sheet(isPresented: $showAddSheet) {
            AddPathSheet(newPath: $newPath, onAdd: {
                if !newPath.isEmpty {
                    paths.append(PathEntry(path: newPath))
                    newPath = ""
                }
            }, onPickFolder: onPickFolder)
        }
    }

    private func movePaths(from source: IndexSet, to destination: Int) {
        paths.move(fromOffsets: source, toOffset: destination)
    }

    private func browseForFolder() {
        if let path = onPickFolder() {
            paths.append(PathEntry(path: path))
        }
    }

    private func save() {
        let pathValue = paths.map(\.path).joined(separator: ":")
        var updatedVariable = variable
        updatedVariable.value = pathValue
        onSave(updatedVariable)
        dismiss()
    }

    private static func liveFolderPicker() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        return url.path
    }
}

struct PathRowView: View {
    let entry: PathEditorView.PathEntry

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .fill((entry.exists ? FloeTheme.secondary : FloeTheme.accent).opacity(0.18))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.22), lineWidth: 0.8)
                    )

                Image(systemName: entry.exists ? "folder.fill" : "folder.badge.questionmark")
                    .foregroundStyle(entry.exists ? FloeTheme.secondary : FloeTheme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.path)
                    .accessibilityIdentifier("path-entry-\(entry.path)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(FloeTheme.inkPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(entry.exists ? "Directory found" : "Directory not found")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(entry.exists ? FloeTheme.secondary : FloeTheme.accent)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .floeGlassField(cornerRadius: 16)
    }
}

struct AddPathSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var newPath: String
    let onAdd: () -> Void
    let onPickFolder: () -> String?

    var body: some View {
        ZStack {
            FloeTheme.pageBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add Path")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(FloeTheme.inkPrimary)
                    Text("Type a directory path or browse for a folder to add it to the list.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FloeTheme.inkSecondary)
                }

                TextField("Path", text: $newPath)
                    .accessibilityIdentifier("new-path-field")
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(FloeTheme.inkPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .floeGlassField(cornerRadius: 18)

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("new-path-cancel-button")
                    .buttonStyle(FloeButtonStyle(variant: .ghost))

                    Spacer(minLength: 0)

                    Button("Browse...") {
                        if let path = onPickFolder() {
                            newPath = path
                        }
                    }
                    .accessibilityIdentifier("new-path-browse-button")
                    .buttonStyle(FloeButtonStyle(variant: .soft))

                    Button("Add") {
                        onAdd()
                        dismiss()
                    }
                    .accessibilityIdentifier("new-path-add-button")
                    .buttonStyle(FloeButtonStyle(variant: .filled))
                    .disabled(newPath.isEmpty)
                }
            }
            .padding(24)
        }
        .frame(width: 460, height: 260)
    }
}
