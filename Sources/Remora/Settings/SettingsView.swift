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
        .padding()
        .frame(minWidth: 520, minHeight: 440)
    }
}

struct SharesTabView: View {
    @ObservedObject var configStore: ConfigStore
    @State private var selectedID: UUID?
    @State private var showingAddSheet = false
    @State private var editingShare: ShareConfig?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading) {
            List(selection: $selectedID) {
                ForEach(configStore.config.shares) { share in
                    HStack {
                        Image(systemName: share.enabled ? "externaldrive.connected.to.line.below" : "externaldrive")
                            .foregroundColor(share.enabled ? .accentColor : .secondary)
                        VStack(alignment: .leading) {
                            Text("\(share.host)/\(share.shareName)")
                                .font(.body)
                            Text(share.mountPoint)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(share.id)
                }
            }
            .frame(minHeight: 200)

            HStack {
                Button("追加") { showingAddSheet = true }
                Button("編集") {
                    if let id = selectedID,
                       let share = configStore.config.shares.first(where: { $0.id == id }) {
                        editingShare = share
                        showingAddSheet = true
                    }
                }
                .disabled(selectedID == nil)
                Button("削除") {
                    if let id = selectedID {
                        do {
                            try configStore.removeShare(id: id)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        selectedID = nil
                    }
                }
                .disabled(selectedID == nil)
            }
            .padding(.top, 4)
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
}

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
        VStack(alignment: .leading, spacing: 16) {
            Text(existingShare == nil ? "共有の追加" : "共有の編集")
                .font(.headline)

            Form {
                TextField("ホスト (例: 192.168.1.10)", text: $host)
                TextField("共有名 (例: shared)", text: $shareName)
                    .onChange(of: shareName) { newValue in
                        if mountPoint.isEmpty || mountPoint == "/Volumes/\(shareName)" {
                            mountPoint = "/Volumes/\(newValue)"
                        }
                    }
                TextField("ユーザー名", text: $username)
                SecureField("パスワード", text: $password)
                TextField("マウント先", text: $mountPoint)
                Toggle("有効", isOn: $enabled)
            }

            HStack {
                Spacer()
                Button("キャンセル") { onCancel() }
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
                .disabled(host.isEmpty || shareName.isEmpty || username.isEmpty)
            }
        }
        .padding()
        .frame(width: 480)
        .onAppear {
            if let share = existingShare {
                host = share.host
                shareName = share.shareName
                username = share.username
                mountPoint = share.mountPoint
                enabled = share.enabled
                if let pw = try? KeychainStore.password(for: KeychainKey(host: share.host, shareName: share.shareName)) {
                    password = pw
                }
            }
        }
    }
}

struct AdvancedTabView: View {
    @ObservedObject var configStore: ConfigStore
    @ObservedObject var loginItemManager: LoginItemManager

    @State private var newQuietStart: String = "23:00"
    @State private var newQuietEnd: String = "07:00"
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("チェック間隔") {
                Stepper(
                    "\(configStore.config.checkIntervalSeconds) 秒",
                    value: Binding(
                        get: { configStore.config.checkIntervalSeconds },
                        set: { newVal in
                            var c = configStore.config
                            c.checkIntervalSeconds = max(30, min(600, newVal))
                            do {
                                try configStore.update(c)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    ),
                    step: 30
                )
            }

            Section("連続失敗通知") {
                Stepper(
                    "\(configStore.config.consecutiveFailuresBeforeNotify) 回",
                    value: Binding(
                        get: { configStore.config.consecutiveFailuresBeforeNotify },
                        set: { newVal in
                            var c = configStore.config
                            c.consecutiveFailuresBeforeNotify = max(1, newVal)
                            do {
                                try configStore.update(c)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    ),
                    step: 1
                )
            }

            Section("休止時間帯") {
                ForEach(Array(configStore.config.quietHours.enumerated()), id: \.offset) { index, range in
                    HStack {
                        Text("\(range.start) 〜 \(range.end)")
                        Spacer()
                        Button("削除") {
                            do {
                                try configStore.removeQuietHour(at: index)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                        .foregroundColor(.red)
                    }
                }

                HStack {
                    TextField("開始 (HH:MM)", text: $newQuietStart)
                        .frame(width: 80)
                    Text("〜")
                    TextField("終了 (HH:MM)", text: $newQuietEnd)
                        .frame(width: 80)
                    Button("追加") {
                        let range = QuietHourRange(start: newQuietStart, end: newQuietEnd)
                        do {
                            try configStore.addQuietHour(range)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }

            Section("自動起動") {
                Toggle("ログイン時に自動起動", isOn: Binding(
                    get: { loginItemManager.isEnabled },
                    set: { _ in try? loginItemManager.toggle() }
                ))
            }
        }
        .padding()
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}
