import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("appAppearance") private var appAppearanceRawValue = AppAppearance.system.rawValue
    @AppStorage("isICloudBackupEnabled") private var isICloudBackupEnabled = false

    private var appAppearance: Binding<AppAppearance> {
        Binding {
            AppAppearance(rawValue: appAppearanceRawValue) ?? .system
        } set: { newValue in
            appAppearanceRawValue = newValue.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("화면") {
                    Picker("모드", selection: appAppearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("백업") {
                    Toggle("iCloud 백업", isOn: $isICloudBackupEnabled)
                    Text("변경한 백업 설정은 앱을 다시 실행한 뒤 적용됩니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("앱 정보") {
                    LabeledContent("버전", value: appVersionText)
                    Button {
                        openTermsAndPolicy()
                    } label: {
                        HStack {
                            Text("이용약관 및 정책")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        openDeveloperApps()
                    } label: {
                        HStack {
                            Text("개발자의 다른 앱")
                            Spacer()
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(version) (\(build))"
    }

    private func openDeveloperApps() {
        guard let url = URL(string: "https://apps.apple.com/search?term=Seunghwa%20Baek&entity=software") else {
            return
        }
        openURL(url)
    }

    private func openTermsAndPolicy() {
        guard let url = URL(string: "https://gotgam100.github.io/Dayco/") else {
            return
        }
        openURL(url)
    }
}
