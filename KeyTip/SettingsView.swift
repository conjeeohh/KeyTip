//
//  SettingsView.swift
//  KeyTip
//
//  偏好设置视图
//  提供自定义快捷键配置管理界面
//

import SwiftUI

/// 偏好设置主视图
struct SettingsView: View {

    /// 当前选中的应用配置 Bundle ID
    @State private var selectedBundleID: String?

    /// 所有已配置的应用
    @State private var configuredApps: [String] = []

    /// 新增自定义快捷键对话框显示状态
    @State private var showingAddSheet = false

    /// 新增隐藏项的输入
    @State private var newHiddenItemID = ""

    // MARK: - 偏好设置状态
    
    @AppStorage(ConfigKeys.triggerModifier) private var triggerModifier: TriggerModifier = .command
    @AppStorage(ConfigKeys.triggerDuration) private var triggerDuration: Double = 0.6

    /// 触发热键修饰键选择 (废弃，改用 AppStorage)
    // @State private var selectedModifier = "Option"
    // @State private var selectedKey = "Z"

    var body: some View {
        TabView {
            generalSettingsView
                .tabItem {
                    Label("通用", systemImage: "gear")
                }

            appConfigListView
                .tabItem {
                    Label("应用配置", systemImage: "app.badge.checkmark")
                }

            aboutView
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
        }
        .frame(width: 540, height: 420)
        .onAppear {
            refreshConfigList()
        }
    }

    // MARK: - 通用设置

    private var generalSettingsView: some View {
        Form {
            Section("触发机制 (长按触发，松开消失)") {
                Picker("修饰键", selection: $triggerModifier) {
                    ForEach(TriggerModifier.allCases) { modifier in
                        Text(modifier.displayName).tag(modifier)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: triggerModifier) { _ in postConfigChangedNotification() }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("长按触发时长:")
                        Spacer()
                        Text(String(format: "%.1f 秒", triggerDuration))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $triggerDuration, in: 0.3...1.5, step: 0.1)
                        .onChange(of: triggerDuration) { _ in postConfigChangedNotification() }
                }
                .padding(.top, 4)
            }

            Section("行为") {
                Toggle("登录时自动启动", isOn: .constant(false))
            }

            Section("辅助功能") {
                HStack {
                    let granted = AccessibilityHelper.isAccessibilityGranted()
                    Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(granted ? .green : .orange)
                    Text(granted ? "辅助功能权限已授予" : "未授予辅助功能权限")

                    Spacer()

                    if !granted {
                        Button("前往设置") {
                            AccessibilityHelper.openAccessibilitySettings()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - 应用配置列表

    private var appConfigListView: some View {
        VStack(spacing: 0) {
            if configuredApps.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("暂无自定义配置")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("当 HUD 弹出时，你可以通过编辑配置文件\n来隐藏或添加快捷键。")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)

                    Button("打开配置文件目录") {
                        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                        let appDir = appSupport.appendingPathComponent("KeyTip", isDirectory: true)
                        NSWorkspace.shared.open(appDir)
                    }
                    .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(configuredApps, id: \.self, selection: $selectedBundleID) { bundleID in
                    HStack {
                        Image(systemName: "app.fill")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading) {
                            Text(bundleID)
                                .font(.system(size: 13))
                            if let config = ConfigStore.shared.config(for: bundleID) {
                                Text("隐藏: \(config.hiddenItems.count)  自定义: \(config.customItems.count)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                // 底部工具栏
                HStack {
                    Button(action: {
                        if let bundleID = selectedBundleID {
                            ConfigStore.shared.resetConfig(for: bundleID)
                            refreshConfigList()
                        }
                    }) {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedBundleID == nil)
                    .help("删除选中应用的配置")

                    Spacer()

                    Button("打开配置文件目录") {
                        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                        let appDir = appSupport.appendingPathComponent("KeyTip", isDirectory: true)
                        NSWorkspace.shared.open(appDir)
                    }
                    .controlSize(.small)
                }
                .padding(8)
            }
        }
    }

    // MARK: - 关于

    private var aboutView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("KeyTip")
                .font(.system(size: 24, weight: .bold))

            Text("全局快捷键查看工具")
                .foregroundStyle(.secondary)

            Text("版本 1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider()
                .frame(width: 200)

            Text("按 ⌥Z 查看当前应用的快捷键")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 辅助方法

    private func refreshConfigList() {
        configuredApps = Array(ConfigStore.shared.configuration.appConfigs.keys).sorted()
    }

    private func postConfigChangedNotification() {
        NotificationCenter.default.post(name: NSNotification.Name("HotKeyConfigChanged"), object: nil)
    }
}

#Preview {
    SettingsView()
}
