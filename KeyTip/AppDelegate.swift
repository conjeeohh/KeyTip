//
//  AppDelegate.swift
//  KeyTip
//
//  应用代理 - 管理状态栏图标、应用生命周期和全局事件
//

import Cocoa
import SwiftUI

/// 应用代理
/// 负责管理 Menu Bar 状态栏图标，以及应用的全局生命周期
/// 标记为 @MainActor 以满足 Swift 6 严格并发安全要求
/// 所有 UI 操作必须在主线程执行，AppDelegate 作为 UI 生命周期管理者应绑定到主 Actor
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - 属性

    /// 状态栏图标项，必须持有强引用，否则会被 ARC 回收导致图标消失
    private var statusItem: NSStatusItem?

    /// 状态栏菜单
    private var statusMenu: NSMenu?

    /// 偏好设置窗口（手动管理，避免 SettingsLink 限制）
    private var settingsWindow: NSWindow?

    /// 全局热键管理器
    private let hotKeyManager = HotKeyManager()

    /// HUD 悬浮窗控制器
    private let hudController = HUDPanelController()

    // MARK: - 生命周期

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 设置状态栏图标
        setupStatusBar()

        // 2. 检查并请求辅助功能权限
        checkAccessibilityPermission()

        // 3. 启动全局热键监听
        setupHotKey()

        print("✅ KeyTip 已启动，运行于状态栏模式")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 停止热键监听，释放资源
        hotKeyManager.stopListening()
        // 关闭 HUD
        hudController.dismiss()
        print("🛑 KeyTip 即将退出")
    }

    // MARK: - 状态栏设置

    /// 配置 Menu Bar 状态栏图标和菜单
    private func setupStatusBar() {
        // 在系统状态栏创建一个固定长度的图标项
        // NSStatusBar.variable 表示图标宽度自适应内容
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // 配置状态栏按钮外观
        if let button = statusItem?.button {
            // 使用 SF Symbols 图标 "keyboard" 作为状态栏图标
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyTip")
            // 设置图标尺寸，使其在状态栏中显示合适
            button.image?.size = NSSize(width: 18, height: 18)
            // 启用模板模式，使图标自动适配系统深色/浅色主题
            button.image?.isTemplate = true
        }

        // 创建并配置下拉菜单
        let menu = NSMenu()

        // "关于 KeyTip" 菜单项
        let aboutItem = NSMenuItem(title: "关于 KeyTip", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // "偏好设置" 菜单项（后续 Step 5 会实现完整功能）
        let prefsItem = NSMenuItem(title: "偏好设置...", action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // "检查辅助功能权限" 菜单项
        let accessibilityItem = NSMenuItem(title: "检查辅助功能权限", action: #selector(checkAccessibility), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(NSMenuItem.separator())

        // "退出" 菜单项
        let quitItem = NSMenuItem(title: "退出 KeyTip", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusMenu = menu
    }

    // MARK: - 全局热键

    /// 配置并启动全局热键监听
    private func setupHotKey() {
        applyHotKeyConfig()
        
        // 监听配置改变的通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("HotKeyConfigChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.applyHotKeyConfig()
            }
        }

        hotKeyManager.startListening(
            onStart: { [weak self] appInfo in
                self?.handleLongPressStart(appInfo: appInfo)
            },
            onEnd: { [weak self] in
                self?.handleLongPressEnd()
            }
        )
    }
    
    private func applyHotKeyConfig() {
        let defaults = UserDefaults.standard
        // 获取修饰键，如果不存在则退化为 command
        let modifierRaw = defaults.string(forKey: ConfigKeys.triggerModifier) ?? TriggerModifier.command.rawValue
        let modifier = TriggerModifier(rawValue: modifierRaw) ?? .command
        
        let duration = defaults.object(forKey: ConfigKeys.triggerDuration) as? Double ?? 0.6
        
        hotKeyManager.updateConfig(modifier: modifier, duration: duration)
    }

    /// 热键开始触发（长按达成）
    private func handleLongPressStart(appInfo: ActiveAppInfo?) {
        guard let appInfo = appInfo else {
            print("⚠️ 热键触发，但无法获取前台应用信息")
            return
        }

        print("🔥 长按触发！前台应用: \(appInfo.localizedName) (\(appInfo.bundleIdentifier))")

        // 先读取当前 App 的展示配置，再决定是否需要读取系统菜单
        let config = ConfigStore.shared.loadConfig(for: appInfo.bundleIdentifier)

        let systemGroups: [ShortcutGroup]
        if config.includeSystemShortcuts {
            systemGroups = MenuBarReader.readShortcuts(from: appInfo)
        } else {
            systemGroups = []
        }

        // 组装 HUD 展示内容
        let groups = DisplayContentBuilder.build(systemGroups: systemGroups, config: config)

        // 显示 HUD 悬浮窗
        hudController.show(
            appInfo: appInfo,
            groups: groups,
            onConfigure: { [weak self] in
                ConfigStore.shared.openConfig(for: appInfo)
                self?.hudController.dismiss()
            }
        )
    }
    
    /// 热键释放或被打断回调
    private func handleLongPressEnd() {
        if hudController.isShowing {
            hudController.dismiss()
        }
    }

    // MARK: - 辅助功能权限

    /// 检查辅助功能权限，首次启动时请求授权
    private func checkAccessibilityPermission() {
        if AccessibilityHelper.isAccessibilityGranted() {
            print("✅ 辅助功能权限已授予")
        } else {
            print("⚠️ 辅助功能权限未授予，正在请求...")
            // 弹出系统权限请求对话框
            AccessibilityHelper.requestAccessibility(showPrompt: true)
        }
    }

    // MARK: - 菜单操作

    /// 显示关于窗口
    @objc private func showAbout() {
        // 激活应用窗口到前台
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    /// 显示偏好设置窗口
    @objc private func showPreferences() {
        // 如果窗口已存在且可见，直接激活到前台
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 创建偏好设置窗口
        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeyTip 偏好设置"
        window.contentViewController = hostingController
        window.center()
        window.isReleasedWhenClosed = false

        self.settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 手动检查辅助功能权限
    @objc private func checkAccessibility() {
        if AccessibilityHelper.isAccessibilityGranted() {
            // 已授权 - 显示确认提示
            let alert = NSAlert()
            alert.messageText = "辅助功能权限状态"
            alert.informativeText = "✅ KeyTip 已获得辅助功能权限，可以正常读取快捷键信息。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "好的")
            alert.runModal()
        } else {
            // 未授权 - 引导用户前往设置
            let alert = NSAlert()
            alert.messageText = "需要辅助功能权限"
            alert.informativeText = "KeyTip 需要辅助功能权限才能读取应用的快捷键信息。\n\n请在「系统设置 > 隐私与安全性 > 辅助功能」中添加 KeyTip。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "前往系统设置")
            alert.addButton(withTitle: "稍后")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                AccessibilityHelper.openAccessibilitySettings()
            }
        }
    }

    /// 退出应用
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
