import SwiftUI

struct VariableListView: View {
    let title: String
    let variables: [EnvironmentVariable]
    let isEditable: Bool
    @Binding var selection: EnvironmentVariable?
    var onEdit: ((EnvironmentVariable) -> Void)?
    var onDelete: ((EnvironmentVariable) -> Void)?

    @State private var sortOrder = [KeyPathComparator(\EnvironmentVariable.name)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            Table(variables, selection: Binding(
                get: { selection?.id },
                set: { newId in selection = variables.first { $0.id == newId } }
            ), sortOrder: $sortOrder) {
                TableColumn("Variable", value: \.name) { variable in
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

                TableColumn("Value", value: \.value) { variable in
                    Text(variable.value)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(variable.isSystemVariable ? .secondary : .primary)
                }
            }
            .tableStyle(.bordered)
            .frame(minHeight: 150)
            .onChange(of: sortOrder) { newOrder in
                // Handle sort order change if needed
            }

            if isEditable {
                HStack {
                    Spacer()

                    if let selected = selection {
                        Button("Edit...") {
                            onEdit?(selected)
                        }
                        .disabled(selection == nil)

                        Button("Delete") {
                            onDelete?(selected)
                        }
                        .disabled(selection == nil)
                    }
                }
            }
        }
    }
}

struct VariableRow: View {
    let variable: EnvironmentVariable

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack {
                    if variable.isPath {
                        Image(systemName: "folder.badge.gearshape")
                            .foregroundColor(.blue)
                    }
                    Text(variable.name)
                        .fontWeight(.medium)
                }

                Text(variable.value)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if let source = variable.sourceFile {
                Text((source as NSString).lastPathComponent)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}
