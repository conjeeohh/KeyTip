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

    /// 全局热键管理器
    private let hotKeyManager = HotKeyManager()

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
    /// 默认热键为 Option+Z，触发时获取前台应用信息
    private func setupHotKey() {
        hotKeyManager.startListening(modifiers: .option, key: "z") { [weak self] appInfo in
            self?.handleHotKeyTriggered(appInfo: appInfo)
        }
    }

    /// 热键触发回调
    /// - Parameter appInfo: 当前前台应用信息
    private func handleHotKeyTriggered(appInfo: ActiveAppInfo?) {
        guard let appInfo = appInfo else {
            print("⚠️ 热键触发，但无法获取前台应用信息")
            return
        }

        print("═══════════════════════════════════")
        print("🔥 热键触发！前台应用信息：")
        print("   名称: \(appInfo.localizedName)")
        print("   Bundle ID: \(appInfo.bundleIdentifier)")
        print("   PID: \(appInfo.processIdentifier)")
        print("═══════════════════════════════════")

        // TODO: Step 3/5 - 这里将调用 Accessibility API 读取快捷键并显示 HUD
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

    /// 显示偏好设置窗口（Step 5 实现）
    @objc private func showPreferences() {
        print("📋 偏好设置 - 将在 Step 5 实现")
        // TODO: Step 5 中实现偏好设置窗口
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
