import SwiftUI

struct SettingsView: View {
    @ObservedObject var configStore: ConfigStore
    @ObservedObject var loginItemManager: LoginItemManager

    var body: some View {
        TabView {
            SharesTabView(configStore: configStore)
                .tabItem { Label("共有", systemImage: "externaldrive") }
            AdvancedTabView(configStore: configStore, loginItemManager: loginItemManager)
                .tabItem { Label("詳細設定", systemImage: "gearshape") }
        }
        .frame(minWidth: 540, minHeight: 460)
    }
}

// MARK: - Shares Tab

struct SharesTabView: View {
    @ObservedObject var configStore: ConfigStore
    @State private var selectedID: UUID?
    @State private var showingAddSheet = false
    @State private var editingShare: ShareConfig?
    @State private var errorMessage: String?

    private var selectedShare: ShareConfig? {
        guard let id = selectedID else { return nil }
        return configStore.config.shares.first(where: { $0.id == id })
    }

    var body: some View {
        VStack(spacing: 0) {
            shareList
            Divider()
            toolbar
        }
        .sheet(isPresented: $showingAddSheet) {
            ShareEditSheet(
                existingShare: editingShare,
                onSave: { share, password in
                    let key = KeychainKey(host: share.host, shareName: share.shareName)
                    do {
                        try KeychainStore.setPassword(password, for: key)
                    } catch {
                        errorMessage = "パスワードの保存に失敗しました: \(error.localizedDescription)"
                    }
                    do {
                        if editingShare != nil {
                            try configStore.updateShare(share)
                        } else {
                            try configStore.addShare(share)
                        }
                    } catch {
                        errorMessage = "設定の保存に失敗しました: \(error.localizedDescription)"
                    }
                    editingShare = nil
                    showingAddSheet = false
                },
                onCancel: {
                    editingShare = nil
                    showingAddSheet = false
                }
            )
        }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var shareList: some View {
        List(selection: $selectedID) {
            ForEach(configStore.config.shares) { share in
                ShareRow(share: share)
                    .tag(share.id)
            }
        }
        .listStyle(.inset)
        .frame(minHeight: 220)
        .onTapGesture(count: 2) {
            guard editingShare == nil, let share = selectedShare else { return }
            editingShare = share
            showingAddSheet = true
        }
    }

    private var toolbar: some View {
        HStack(spacing: 0) {
            Button {
                editingShare = nil
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)

            Divider().frame(height: 16)

            Button {
                if let id = selectedID {
                    do {
                        try configStore.removeShare(id: id)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    selectedID = nil
                }
            } label: {
                Image(systemName: "minus")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(selectedID == nil)

            Divider().frame(height: 16)

            Button {
                if let share = selectedShare {
                    editingShare = share
                    showingAddSheet = true
                }
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(selectedShare == nil)

            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

private struct ShareRow: View {
    let share: ShareConfig

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: share.enabled
                ? "externaldrive.connected.to.line.below"
                : "externaldrive")
                .foregroundStyle(share.enabled ? Color.accentColor : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(share.host)  /  \(share.shareName)")
                    .font(.body)
                Text(share.mountPoint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !share.enabled {
                Text("無効")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Share Edit Sheet

struct ShareEditSheet: View {
    var existingShare: ShareConfig?
    var onSave: (ShareConfig, String) -> Void
    var onCancel: () -> Void

    @State private var host: String = ""
    @State private var shareName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var mountPoint: String = ""
    @State private var enabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text(existingShare == nil ? "共有の追加" : "共有の編集")
                    .font(.headline)
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 12)

            Divider()

            Form {
                Section("接続先") {
                    LabeledContent("ホスト") {
                        TextField("", text: $host)
                            .textFieldStyle(.plain)
                    }
                    LabeledContent("共有名") {
                        TextField("", text: $shareName)
                            .textFieldStyle(.plain)
                            .onChange(of: shareName) { newValue in
                                if mountPoint.isEmpty || mountPoint == "/Volumes/\(shareName)" {
                                    mountPoint = "/Volumes/\(newValue)"
                                }
                            }
                    }
                }

                Section("認証") {
                    LabeledContent("ユーザー名") {
                        TextField("", text: $username)
                            .textFieldStyle(.plain)
                    }
                    LabeledContent("パスワード") {
                        SecureField("", text: $password)
                            .textFieldStyle(.plain)
                    }
                }

                Section("オプション") {
                    LabeledContent("マウント先") {
                        TextField("", text: $mountPoint)
                            .textFieldStyle(.plain)
                    }
                    Toggle("有効", isOn: $enabled)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("キャンセル") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") {
                    let share = ShareConfig(
                        id: existingShare?.id ?? UUID(),
                        host: host,
                        shareName: shareName,
                        username: username,
                        mountPoint: mountPoint.isEmpty ? "/Volumes/\(shareName)" : mountPoint,
                        enabled: enabled
                    )
                    onSave(share, password)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(host.isEmpty || shareName.isEmpty || username.isEmpty)
            }
            .padding()
        }
        .frame(width: 460)
        .onAppear {
            if let share = existingShare {
                host = share.host
                shareName = share.shareName
                username = share.username
                mountPoint = share.mountPoint
                enabled = share.enabled
                if let pw = try? KeychainStore.password(
                    for: KeychainKey(host: share.host, shareName: share.shareName)
                ) {
                    password = pw
                }
            }
        }
    }
}

// MARK: - Advanced Tab

struct AdvancedTabView: View {
    @ObservedObject var configStore: ConfigStore
    @ObservedObject var loginItemManager: LoginItemManager

    @State private var newQuietStart: String = "23:00"
    @State private var newQuietEnd: String = "07:00"
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("チェック間隔") {
                    Stepper(
                        "\(configStore.config.checkIntervalSeconds) 秒",
                        value: Binding(
                            get: { configStore.config.checkIntervalSeconds },
                            set: { newVal in
                                var c = configStore.config
                                c.checkIntervalSeconds = max(30, min(600, newVal))
                                saveConfig(c)
                            }
                        ),
                        step: 30
                    )
                }
                LabeledContent("失敗通知まで") {
                    Stepper(
                        "\(configStore.config.consecutiveFailuresBeforeNotify) 回連続",
                        value: Binding(
                            get: { configStore.config.consecutiveFailuresBeforeNotify },
                            set: { newVal in
                                var c = configStore.config
                                c.consecutiveFailuresBeforeNotify = max(1, newVal)
                                saveConfig(c)
                            }
                        ),
                        step: 1
                    )
                }
            } header: {
                Label("マウント設定", systemImage: "arrow.clockwise")
            }

            Section {
                ForEach(Array(configStore.config.quietHours.enumerated()), id: \.offset) { index, range in
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text("\(range.start)  〜  \(range.end)")
                        Spacer()
                        Button {
                            do {
                                try configStore.removeQuietHour(at: index)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                HStack(spacing: 6) {
                    TextField("HH:MM", text: $newQuietStart)
                        .frame(width: 72)
                        .textFieldStyle(.roundedBorder)
                    Text("〜")
                        .foregroundStyle(.secondary)
                    TextField("HH:MM", text: $newQuietEnd)
                        .frame(width: 72)
                        .textFieldStyle(.roundedBorder)
                    Spacer()
                    Button {
                        let range = QuietHourRange(start: newQuietStart, end: newQuietEnd)
                        do {
                            try configStore.addQuietHour(range)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .disabled(newQuietStart.isEmpty || newQuietEnd.isEmpty)
                }
            } header: {
                Label("休止時間帯", systemImage: "moon.zzz")
            } footer: {
                Text("この時間帯はマウント試行を行いません。日またぎ範囲 (例: 23:00 〜 07:00) にも対応します。")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("ログイン時に自動起動", isOn: Binding(
                    get: { loginItemManager.isEnabled },
                    set: { _ in
                        do {
                            try loginItemManager.toggle()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                ))
            } header: {
                Label("スタートアップ", systemImage: "power")
            }
        }
        .formStyle(.grouped)
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveConfig(_ config: AppConfig) {
        do {
            try configStore.update(config)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
