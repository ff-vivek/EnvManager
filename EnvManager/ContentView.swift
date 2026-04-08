import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel: EnvironmentViewModel

    @State private var selectedUserVariable: EnvironmentVariable?
    @State private var selectedSystemVariable: EnvironmentVariable?

    @State private var showingAddSheet = false
    @State private var showingPreview = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var searchText = ""

    @State private var variableToEdit: EnvironmentVariable?
    @State private var pathVariableToEdit: EnvironmentVariable?

    @MainActor
    init(viewModel: EnvironmentViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: EnvironmentViewModel())
    }

    private var filteredUserVariables: [EnvironmentVariable] {
        filterVariables(viewModel.userVariables)
    }

    private var filteredSystemVariables: [EnvironmentVariable] {
        filterVariables(viewModel.systemVariables)
    }

    var body: some View {
        ZStack {
            FloeTheme.pageBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    ShellSelectorView(
                        selectedShell: $viewModel.selectedShell,
                        selectedConfigFile: $viewModel.selectedConfigFile
                    )
                    metrics
                    userVariablesSection
                    systemVariablesSection
                    footerBar
                }
                .padding(20)
            }
        }
        .frame(minWidth: 760, minHeight: 720)
        .onAppear {
            viewModel.loadConfiguration()
        }
        .onReceive(NotificationCenter.default.publisher(for: .addVariable)) { _ in
            showingAddSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .editVariable)) { _ in
            editSelectedVariable()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteVariable)) { _ in
            if let selected = selectedUserVariable {
                deleteVariable(selected)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .reloadConfig)) { _ in
            viewModel.loadConfiguration()
        }
        .onReceive(NotificationCenter.default.publisher(for: .selectShell)) { notification in
            if let shell = notification.object as? ShellType {
                viewModel.selectedShell = shell
            }
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

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(FloeTheme.primary.opacity(0.16))
                            .frame(width: 58, height: 58)
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(FloeTheme.primary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("EnvManager")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(FloeTheme.inkPrimary)
                        Text("A glassy shell-variable workspace with floating controls, translucent panels, and safer dotfile edits.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(FloeTheme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 10) {
                    FloeInfoPill(
                        title: viewModel.selectedShell.displayName,
                        systemImage: "chevron.left.forwardslash.chevron.right",
                        tint: FloeTheme.primary
                    )
                    FloeInfoPill(
                        title: viewModel.currentConfig?.displayPath ?? viewModel.selectedConfigFile.replacingOccurrences(
                            of: AppEnvironment.homeDirectoryPath,
                            with: "~"
                        ),
                        systemImage: "doc.text",
                        tint: FloeTheme.accent
                    )
                    FloeInfoPill(
                        title: viewModel.hasUnsavedChanges ? "Pending edits" : "Synced",
                        systemImage: viewModel.hasUnsavedChanges ? "sparkles" : "checkmark.circle.fill",
                        tint: viewModel.hasUnsavedChanges ? FloeTheme.accent : FloeTheme.secondary
                    )
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 10) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("New Variable", systemImage: "plus")
                }
                .accessibilityIdentifier("header-new-variable-button")
                .buttonStyle(FloeButtonStyle(variant: .filled))

                Button {
                    showingPreview = true
                } label: {
                    Label("Preview", systemImage: "doc.richtext")
                }
                .accessibilityIdentifier("header-preview-button")
                .buttonStyle(FloeButtonStyle(variant: .soft))
                .disabled(!viewModel.hasUnsavedChanges)
            }
        }
        .floeCard(fill: FloeTheme.primary.opacity(0.05), border: FloeTheme.border.opacity(0.18), shadow: .elevated)
    }

    private var metrics: some View {
        HStack(spacing: 14) {
            FloeMetricCard(
                title: "User Variables",
                value: "\(viewModel.userVariables.count)",
                detail: "Editable exports from the selected config",
                systemImage: "slider.horizontal.3",
                tint: FloeTheme.primary
            )
            FloeMetricCard(
                title: "System Variables",
                value: "\(viewModel.systemVariables.count)",
                detail: "Read-only process environment snapshot",
                systemImage: "server.rack",
                tint: FloeTheme.secondary
            )
            FloeMetricCard(
                title: "Change State",
                value: viewModel.hasUnsavedChanges ? "Pending" : "Clean",
                detail: viewModel.hasUnsavedChanges ? "Preview and apply when ready" : "No pending writes",
                systemImage: viewModel.hasUnsavedChanges ? "clock.arrow.circlepath" : "checkmark.seal",
                tint: FloeTheme.accent
            )
        }
    }

    private var userVariablesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("User Variables")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(FloeTheme.inkPrimary)
                    Text("Edit exported variables in the active shell config. PATH-style values open a dedicated path editor.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FloeTheme.inkSecondary)
                }

                Spacer(minLength: 0)

                if let selected = selectedUserVariable {
                    FloeInfoPill(
                        title: selected.name,
                        systemImage: selected.isPath ? "folder.badge.gearshape" : "character.cursor.ibeam",
                        tint: selected.isPath ? FloeTheme.accent : FloeTheme.primary
                    )
                }
            }

            HStack(spacing: 12) {
                FloeSearchField(text: $searchText, accessibilityIdentifier: "variable-search-field")
                Button {
                    showingAddSheet = true
                } label: {
                    Label("New", systemImage: "plus")
                }
                .accessibilityIdentifier("user-variables-new-button")
                .buttonStyle(FloeButtonStyle(variant: .filled, compact: true))

                Button {
                    editSelectedVariable()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .accessibilityIdentifier("user-variables-edit-button")
                .buttonStyle(FloeButtonStyle(variant: .soft, compact: true))
                .disabled(selectedUserVariable == nil)

                Button {
                    if let selected = selectedUserVariable {
                        deleteVariable(selected)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityIdentifier("user-variables-delete-button")
                .buttonStyle(FloeButtonStyle(variant: .danger, compact: true))
                .disabled(selectedUserVariable == nil)
            }

            if filteredUserVariables.isEmpty {
                FloeEmptyState(
                    title: searchText.isEmpty ? "No user variables yet" : "No matching user variables",
                    message: searchText.isEmpty ? "Create your first export to start managing this shell config." : "Try a different search term or clear the filter.",
                    systemImage: searchText.isEmpty ? "plus.square.on.square" : "magnifyingglass"
                )
            } else {
                Table(filteredUserVariables, selection: Binding(
                    get: { selectedUserVariable?.id },
                    set: { id in selectedUserVariable = viewModel.userVariables.first { $0.id == id } }
                )) {
                    TableColumn("Variable") { variable in
                        HStack(spacing: 10) {
                            Image(systemName: variable.isPath ? "folder.badge.gearshape" : "character.cursor.ibeam")
                                .foregroundStyle(variable.isPath ? FloeTheme.accent : FloeTheme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(variable.name)
                                    .accessibilityIdentifier("user-variable-\(variable.name)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(FloeTheme.inkPrimary)
                                Text(variable.isPath ? "Path-aware variable" : "Standard export")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(FloeTheme.inkSecondary)
                            }
                        }
                    }
                    .width(min: 170, ideal: 210, max: 250)

                    TableColumn("Value") { variable in
                        Text(variable.value)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(FloeTheme.inkPrimary)
                    }

                    TableColumn("Source") { variable in
                        if let source = variable.sourceFile {
                            Text((source as NSString).lastPathComponent)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(FloeTheme.inkSecondary)
                        }
                    }
                    .width(min: 100, ideal: 120, max: 140)
                }
                .accessibilityIdentifier("user-variables-table")
                .tableStyle(.bordered)
                .frame(minHeight: 250)
            }

            if let selected = selectedUserVariable {
                selectedVariableSummary(for: selected)
            }
        }
        .floeCard()
    }

    private var systemVariablesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Variables")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(FloeTheme.inkPrimary)
                    Text("Read-only values from the current process environment. Useful for comparing shell config output with the running app state.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FloeTheme.inkSecondary)
                }

                Spacer(minLength: 0)

                FloeInfoPill(
                    title: "\(filteredSystemVariables.count) visible",
                    systemImage: "eye",
                    tint: FloeTheme.secondary
                )
            }

            if filteredSystemVariables.isEmpty {
                FloeEmptyState(
                    title: "No matching system variables",
                    message: "Adjust the current search to inspect a different part of the process environment.",
                    systemImage: "magnifyingglass"
                )
            } else {
                Table(filteredSystemVariables, selection: Binding(
                    get: { selectedSystemVariable?.id },
                    set: { id in selectedSystemVariable = viewModel.systemVariables.first { $0.id == id } }
                )) {
                    TableColumn("Variable", value: \.name)
                        .width(min: 180, ideal: 220, max: 260)

                    TableColumn("Value") { variable in
                        Text(variable.value)
                            .accessibilityIdentifier("system-variable-\(variable.name)")
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(FloeTheme.inkSecondary)
                    }
                }
                .accessibilityIdentifier("system-variables-table")
                .tableStyle(.bordered)
                .frame(minHeight: 190)
            }
        }
        .floeCard()
    }

    private var footerBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: viewModel.hasUnsavedChanges ? "sparkles.rectangle.stack" : "checkmark.circle.fill")
                    .foregroundStyle(viewModel.hasUnsavedChanges ? FloeTheme.accent : FloeTheme.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.hasUnsavedChanges ? "Unsaved changes ready to preview" : "Everything is in sync")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(FloeTheme.inkPrimary)
                    Text(viewModel.hasUnsavedChanges ? "Writes create a backup before updating the shell config file." : "Reload at any time to refresh from disk.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FloeTheme.inkSecondary)
                }
            }

            Spacer(minLength: 0)

            Button("Reload") {
                viewModel.loadConfiguration()
            }
            .accessibilityIdentifier("reload-button")
            .buttonStyle(FloeButtonStyle(variant: .ghost))

            Button("Preview Changes") {
                showingPreview = true
            }
            .accessibilityIdentifier("preview-changes-button")
            .buttonStyle(FloeButtonStyle(variant: .soft))
            .disabled(!viewModel.hasUnsavedChanges)

            Button("Apply") {
                applyChanges()
            }
            .accessibilityIdentifier("apply-changes-button")
            .buttonStyle(FloeButtonStyle(variant: .filled))
            .keyboardShortcut(.defaultAction)
            .disabled(!viewModel.hasUnsavedChanges)
        }
        .floeCard(fill: FloeTheme.secondary.opacity(0.04), border: FloeTheme.border.opacity(0.18), shadow: .soft)
    }

    @ViewBuilder
    private func selectedVariableSummary(for variable: EnvironmentVariable) -> some View {
        HStack(spacing: 12) {
            summaryTile(
                title: "Source",
                value: variable.sourceFile.map { ($0 as NSString).lastPathComponent } ?? "Pending",
                systemImage: "doc.text",
                tint: FloeTheme.primary
            )
            summaryTile(
                title: "Line",
                value: variable.lineNumber.map(String.init) ?? "New",
                systemImage: "list.number",
                tint: FloeTheme.secondary
            )
            summaryTile(
                title: "Type",
                value: variable.isPath ? "Path editor" : "Text editor",
                systemImage: variable.isPath ? "folder.badge.gearshape" : "character.cursor.ibeam",
                tint: FloeTheme.accent
            )
        }
    }

    private func summaryTile(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(FloeTheme.inkTertiary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FloeTheme.inkPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .floeGlassField(cornerRadius: 16)
    }

    private func filterVariables(_ variables: [EnvironmentVariable]) -> [EnvironmentVariable] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return variables }

        return variables.filter { variable in
            variable.name.localizedCaseInsensitiveContains(query) ||
            variable.value.localizedCaseInsensitiveContains(query) ||
            (variable.sourceFile?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private func editSelectedVariable() {
        guard let selected = selectedUserVariable else { return }

        if selected.isPath {
            pathVariableToEdit = selected
        } else {
            variableToEdit = selected
        }
    }

    private func deleteVariable(_ variable: EnvironmentVariable) {
        viewModel.deleteVariable(variable)
        if selectedUserVariable?.id == variable.id {
            selectedUserVariable = nil
        }
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
        ZStack {
            FloeTheme.pageBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preview Changes")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(FloeTheme.inkPrimary)
                        Text("The following content will be written to \(viewModel.currentConfig?.displayPath ?? "the selected config file").")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(FloeTheme.inkSecondary)
                    }

                    Spacer(minLength: 0)

                    FloeInfoPill(
                        title: viewModel.selectedShell.displayName,
                        systemImage: "terminal",
                        tint: FloeTheme.primary
                    )
                }

                ScrollView {
                    Text(viewModel.previewChanges())
                        .accessibilityIdentifier("preview-changes-text")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(FloeTheme.inkPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                }
                .frame(minHeight: 260)
                .floeGlassField(cornerRadius: 20)

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier("preview-cancel-button")
                    .buttonStyle(FloeButtonStyle(variant: .ghost))
                    .keyboardShortcut(.cancelAction)

                    Spacer(minLength: 0)

                    Button("Apply Changes") {
                        onApply()
                        dismiss()
                    }
                    .accessibilityIdentifier("preview-apply-button")
                    .buttonStyle(FloeButtonStyle(variant: .filled))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
        .frame(width: 680, height: 520)
    }
}

enum FloeTheme {
    static let primary = Color(light: (0.365, 0.557, 0.996), dark: (0.529, 0.678, 1.000))
    static let secondary = Color(light: (0.251, 0.784, 0.651), dark: (0.404, 0.867, 0.741))
    static let accent = Color(light: (0.976, 0.737, 0.333), dark: (1.000, 0.803, 0.475))
    static let danger = Color(light: (0.932, 0.388, 0.431), dark: (1.000, 0.545, 0.580))

    static let background = Color(light: (0.945, 0.965, 1.000), dark: (0.055, 0.067, 0.106))
    static let surface = Color(light: (0.955, 0.972, 1.000), dark: (0.118, 0.133, 0.192))
    static let border = Color(light: (1.000, 1.000, 1.000), dark: (0.825, 0.867, 0.980))
    static let chrome = Color(light: (0.843, 0.898, 1.000), dark: (0.251, 0.333, 0.541))
    static let glassTint = Color(light: (0.878, 0.925, 1.000), dark: (0.145, 0.173, 0.255))
    static let glassShadow = Color(light: (0.208, 0.333, 0.569), dark: (0.000, 0.000, 0.000))

    static let inkPrimary = Color(light: (0.098, 0.153, 0.255), dark: (0.963, 0.975, 1.000))
    static let inkSecondary = Color(light: (0.337, 0.420, 0.565), dark: (0.682, 0.749, 0.886))
    static let inkTertiary = Color(light: (0.506, 0.584, 0.733), dark: (0.561, 0.627, 0.769))

    static var pageBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    background,
                    surface.opacity(0.72),
                    chrome.opacity(0.44)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(primary.opacity(0.20))
                .frame(width: 420, height: 420)
                .blur(radius: 38)
                .offset(x: -250, y: -260)

            Circle()
                .fill(accent.opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 42)
                .offset(x: 250, y: 230)

            Circle()
                .fill(secondary.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 34)
                .offset(x: 320, y: -180)

            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
                .blur(radius: 1.5)
                .offset(y: -230)
        }
    }
}

enum FloeShadowStyle {
    case subtle
    case soft
    case elevated

    var radius: CGFloat {
        switch self {
        case .subtle: return 6
        case .soft: return 12
        case .elevated: return 24
        }
    }

    var yOffset: CGFloat {
        switch self {
        case .subtle: return 2
        case .soft: return 6
        case .elevated: return 12
        }
    }

    var opacity: Double {
        switch self {
        case .subtle: return 0.06
        case .soft: return 0.10
        case .elevated: return 0.16
        }
    }
}

struct FloeCardModifier: ViewModifier {
    var fill: Color = FloeTheme.glassTint.opacity(0.16)
    var border: Color = FloeTheme.border.opacity(0.24)
    var shadow: FloeShadowStyle = .soft

    func body(content: Content) -> some View {
        content
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(fill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(.white.opacity(0.24), lineWidth: 0.9)
                            .blur(radius: 0.2)
                    )
                    .shadow(color: FloeTheme.glassShadow.opacity(shadow.opacity), radius: shadow.radius, x: 0, y: shadow.yOffset)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }
}

extension View {
    func floeCard(
        fill: Color = FloeTheme.surface.opacity(0.94),
        border: Color = FloeTheme.border.opacity(0.75),
        shadow: FloeShadowStyle = .soft
    ) -> some View {
        modifier(FloeCardModifier(fill: fill, border: border, shadow: shadow))
    }

    func floeGlassField(cornerRadius: CGFloat = 18) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(FloeTheme.glassTint.opacity(0.18))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 0.8)
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(FloeTheme.chrome.opacity(0.18), lineWidth: 1)
        )
    }
}

enum FloeButtonVariant {
    case filled
    case soft
    case ghost
    case danger
}

struct FloeButtonStyle: ButtonStyle {
    let variant: FloeButtonVariant
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 13 : 14, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, compact ? 14 : 18)
            .padding(.vertical, compact ? 9 : 12)
            .background {
                RoundedRectangle(cornerRadius: compact ? 17 : 20, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 17 : 20, style: .continuous)
                            .fill(backgroundColor.opacity(configuration.isPressed ? 0.76 : 1.0))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 17 : 20, style: .continuous)
                            .stroke(.white.opacity(0.22), lineWidth: 0.9)
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 17 : 20, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .shadow(
                color: shadowColor.opacity(configuration.isPressed ? 0.08 : 0.14),
                radius: configuration.isPressed ? 8 : 16,
                x: 0,
                y: configuration.isPressed ? 3 : 8
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: compact ? 17 : 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(configuration.isPressed ? 0.06 : 0.20), .white.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .mask(
                        RoundedRectangle(cornerRadius: compact ? 17 : 20, style: .continuous)
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        switch variant {
        case .filled:
            return FloeTheme.primary.opacity(0.74)
        case .soft:
            return FloeTheme.surface.opacity(0.30)
        case .ghost:
            return FloeTheme.glassTint.opacity(0.10)
        case .danger:
            return FloeTheme.danger.opacity(0.20)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .filled:
            return .white
        case .soft, .ghost:
            return FloeTheme.inkPrimary
        case .danger:
            return FloeTheme.danger
        }
    }

    private var borderColor: Color {
        switch variant {
        case .filled:
            return FloeTheme.primary.opacity(0.18)
        case .soft, .ghost:
            return FloeTheme.border.opacity(0.18)
        case .danger:
            return FloeTheme.danger.opacity(0.22)
        }
    }

    private var borderWidth: CGFloat {
        switch variant {
        case .ghost, .soft:
            return 1
        default:
            return 0.9
        }
    }

    private var shadowColor: Color {
        switch variant {
        case .filled:
            return FloeTheme.primary
        case .danger:
            return FloeTheme.danger
        case .soft, .ghost:
            return .black
        }
    }
}

struct FloeMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle()
                            .fill(tint.opacity(0.18))
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.26), lineWidth: 0.8)
                    )

                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(FloeTheme.inkTertiary)
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(FloeTheme.inkPrimary)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FloeTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .floeCard(fill: tint.opacity(0.08), border: tint.opacity(0.12), shadow: .subtle)
    }
}

struct FloeInfoPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        Capsule(style: .continuous)
                            .fill(tint.opacity(0.12))
                    )
            }
            .overlay(
                Capsule(style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 0.8)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.14), lineWidth: 1)
            )
    }
}

struct FloeEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(FloeTheme.primary)
            Text(title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(FloeTheme.inkPrimary)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FloeTheme.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .floeGlassField(cornerRadius: 20)
    }
}

struct FloeSearchField: View {
    @Binding var text: String
    var accessibilityIdentifier: String = ""

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(FloeTheme.inkTertiary)
            TextField("Search variables or values", text: $text)
                .accessibilityIdentifier(accessibilityIdentifier)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FloeTheme.inkPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(FloeTheme.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .floeGlassField(cornerRadius: 18)
    }
}

struct FloeSelectableChipStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? .white : FloeTheme.inkPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(isSelected ? FloeTheme.primary.opacity(0.74) : FloeTheme.glassTint.opacity(0.10))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.22), lineWidth: 0.8)
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? FloeTheme.primary.opacity(0.24) : FloeTheme.border.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: FloeTheme.glassShadow.opacity(configuration.isPressed ? 0.06 : 0.12), radius: configuration.isPressed ? 8 : 14, x: 0, y: configuration.isPressed ? 3 : 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

private extension Color {
    init(light: (Double, Double, Double), dark: (Double, Double, Double)) {
        self.init(
            nsColor: NSColor(name: nil) { appearance in
                let bestMatch = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
                let colors = (bestMatch == .darkAqua || bestMatch == .vibrantDark) ? dark : light
                return NSColor(
                    srgbRed: colors.0,
                    green: colors.1,
                    blue: colors.2,
                    alpha: 1
                )
            }
        )
    }
}

#Preview {
    ContentView()
}
