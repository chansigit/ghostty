import SwiftUI

struct TriggersView: View {
    @ObservedObject var store: TriggerStore
    var onApply: () -> Void
    var onClose: () -> Void

    @State private var selection: TriggerItem.ID?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                list
                detail
            }
            .padding()

            Divider()
            HStack {
                Button { add() } label: { Image(systemName: "plus") }
                Button { remove() } label: { Image(systemName: "minus") }
                    .disabled(selection == nil)
                Spacer()
                if let errorMessage {
                    Text(errorMessage).foregroundColor(.red).font(.caption)
                }
                Button("Close") { apply(); onClose() }
                Button("Apply") { apply() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 760, minHeight: 360)
        .onAppear { selection = store.items.first?.id }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(store.items) { item in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill").font(.caption)
                        Text(item.name.isEmpty ? "(unnamed)" : item.name).bold()
                    }
                    Text("/\(item.regex)/")
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                    Text("Send Text \(item.text)")
                        .font(.caption)
                        .lineLimit(1)
                }
                .opacity(item.enabled ? 1 : 0.4)
                .tag(item.id)
            }
        }
        .frame(width: 320)
    }

    @ViewBuilder
    private var detail: some View {
        if let idx = store.items.firstIndex(where: { $0.id == selection }) {
            let item = $store.items[idx]
            Form {
                TextField("Name:", text: item.name)
                TextField("Regular Expression:", text: item.regex)
                    .font(.system(.body, design: .monospaced))
                Toggle("Enabled", isOn: item.enabled)
                TextField("Send Text:", text: item.text)
                    .font(.system(.body, design: .monospaced))
                Text("The regex is matched against the text before the cursor, " +
                     "e.g. (?i)password.*:\\s*$. Escapes: \\n \\r \\t \\e \\\\ \\xNN. " +
                     "End the text with \\r to press Return.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Text is stored in plain text in your config directory.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            Text("No trigger selected")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func add() {
        let item = TriggerItem(name: "New Trigger")
        store.items.append(item)
        selection = item.id
    }

    private func remove() {
        guard let idx = store.items.firstIndex(where: { $0.id == selection }) else { return }
        store.items.remove(at: idx)
        selection = store.items.indices.contains(idx) ? store.items[idx].id : store.items.last?.id
    }

    private func apply() {
        do {
            try store.save()
            errorMessage = nil
            onApply()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
