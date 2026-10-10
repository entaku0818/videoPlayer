//
//  SettingsView.swift
//  videoPlayer
//
//  アプリ設定。ライブラリ/IPTV タブのツールバーから開く。
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(BackgroundPlaybackSettings.key) private var isBackgroundPlaybackEnabled = true

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("バックグラウンド再生", isOn: $isBackgroundPlaybackEnabled)
                        .accessibilityIdentifier("backgroundPlaybackToggle")
                } header: {
                    Text("再生")
                } footer: {
                    Text("オンにすると、ホーム画面に戻ったり画面をロックしたりしても音声の再生を続けます。ロック画面やコントロールセンターから操作できます。")
                }

                Section {
                    LabeledContent("バージョン", value: appVersion)
                } header: {
                    Text("アプリについて")
                } footer: {
                    Text(IPTVCopy.disclaimer)
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

/// ツールバー用の設定ボタン（シート表示）
struct SettingsButton: View {
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel("設定")
        .sheet(isPresented: $isPresented) {
            SettingsView()
        }
    }
}

#Preview {
    SettingsView()
}
