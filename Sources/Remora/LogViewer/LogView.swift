import SwiftUI

struct LogView: View {
    @State private var entries: [LogEntry] = []
    @State private var filterLevel: LogLevel? = nil
    @State private var searchText: String = ""
    @State private var autoScroll: Bool = true

    private var filteredEntries: [LogEntry] {
        entries.filter { entry in
            let levelMatch = filterLevel == nil || entry.level == filterLevel
            let textMatch = searchText.isEmpty ||
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                entry.category.localizedCaseInsensitiveContains(searchText)
            return levelMatch && textMatch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("レベル", selection: $filterLevel) {
                    Text("すべて").tag(LogLevel?.none)
                    Text("INFO").tag(LogLevel?.some(.info))
                    Text("NOTICE").tag(LogLevel?.some(.notice))
                    Text("ERROR").tag(LogLevel?.some(.error))
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)

                TextField("検索", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)

                Toggle("自動スクロール", isOn: $autoScroll)

                Spacer()

                Button("コピー") {
                    let text = filteredEntries.map { formatEntry($0) }.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }

                Button("クリア") {
                    Task { await LogStore.shared.clear() }
                }

                Button("Console.app") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Console.app"))
                }
            }
            .padding(8)

            Divider()

            ScrollViewReader { proxy in
                List(filteredEntries) { entry in
                    LogEntryRow(entry: entry)
                        .id(entry.id)
                }
                .onChange(of: filteredEntries.count) { _ in
                    if autoScroll, let last = filteredEntries.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .task {
            for await snapshot in await LogStore.shared.makeStream() {
                entries = snapshot
            }
        }
    }

    private static let entryFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private func formatEntry(_ entry: LogEntry) -> String {
        "[\(Self.entryFormatter.string(from: entry.date))] [\(entry.level.rawValue.uppercased())] [\(entry.category)] \(entry.message)"
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    private var levelColor: Color {
        switch entry.level {
        case .info: return .primary
        case .notice: return .orange
        case .error: return .red
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(formattedTime)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(entry.level.rawValue.uppercased())
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundColor(levelColor)
                .frame(width: 50, alignment: .leading)

            Text(entry.category)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(levelColor)
                .textSelection(.enabled)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private var formattedTime: String {
        Self.timeFormatter.string(from: entry.date)
    }
}
