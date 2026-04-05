//
//  AccessibilityHelper.swift
//  KeyTip
//
//  辅助功能权限管理工具类
//  负责检测和引导用户授予 Accessibility 权限
//

import Cocoa

/// 辅助功能权限管理器
/// 封装了 macOS Accessibility API 权限的检测与请求逻辑
enum AccessibilityHelper {

    // MARK: - 权限检测

    /// 检查当前应用是否已获得辅助功能权限
    /// - Returns: 如果已授权返回 true，否则返回 false
    static func isAccessibilityGranted() -> Bool {
        // AXIsProcessTrusted() 是 macOS 提供的 API，用于检测当前进程是否被授予辅助功能权限
        // 返回 true 表示已授权，false 表示未授权
        return AXIsProcessTrusted()
    }

    // MARK: - 权限请求

    /// 请求辅助功能权限
    /// 如果尚未授权，将弹出系统提示框引导用户前往「系统设置 > 隐私与安全性 > 辅助功能」进行授权
    /// - Parameter showPrompt: 是否显示系统权限请求提示框，默认为 true
    /// - Returns: 当前是否已授权
    @discardableResult
    static func requestAccessibility(showPrompt: Bool = true) -> Bool {
        // 使用 kAXTrustedCheckOptionPrompt 选项：
        // 当值为 true 时，如果应用未被授权，系统会自动弹出对话框
        // 引导用户前往「系统设置 > 隐私与安全性 > 辅助功能」添加本应用
        // 注意：Swift 6 严格并发模式下，kAXTrustedCheckOptionPrompt 被视为不安全的共享可变状态
        // 因此直接使用其底层字符串值 "AXTrustedCheckOptionPrompt" 来构建选项字典
        let options = ["AXTrustedCheckOptionPrompt": showPrompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - 打开系统设置

    /// 直接打开系统设置中的辅助功能页面
    /// 适用于用户已经拒绝过权限弹窗后，手动引导用户前往设置
    static func openAccessibilitySettings() {
        // macOS 13+ 使用新的 URL scheme 打开系统设置
        // 直接定位到「隐私与安全性 > 辅助功能」面板
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
