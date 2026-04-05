//
//  ActiveAppInfo.swift
//  KeyTip
//
//  前台活跃应用信息模型与检测工具
//  使用 NSWorkspace 和 NSRunningApplication 获取当前最前端应用的详细信息
//

import Cocoa

/// 前台活跃应用的信息模型
/// 包含应用的 Bundle ID、名称、图标等关键信息
struct ActiveAppInfo {

    /// 应用的 Bundle Identifier（如 "com.apple.Safari"）
    let bundleIdentifier: String

    /// 应用的本地化显示名称（如 "Safari"）
    let localizedName: String

    /// 应用的图标（NSImage 类型，可直接用于 UI 显示）
    let icon: NSImage

    /// 应用的可执行文件路径
    let executableURL: URL?

    /// 应用的 Bundle 路径
    let bundleURL: URL?

    /// 应用的进程 ID
    let processIdentifier: pid_t
}

// MARK: - 前台应用检测

/// 前台应用检测工具
/// 封装 NSWorkspace API，获取当前活跃（最前端）应用的信息
@MainActor
enum ActiveAppDetector {

    /// 获取当前最前端应用的信息
    /// - Returns: 如果成功获取返回 ActiveAppInfo，否则返回 nil
    ///
    /// 使用 NSWorkspace.shared.frontmostApplication 获取当前激活的应用程序
    /// 该 API 返回的是用户当前正在交互的前台应用（不包括本应用自身的状态栏菜单）
    static func getCurrentApp() -> ActiveAppInfo? {
        // NSWorkspace.shared.frontmostApplication 返回当前最前端的应用
        // 如果没有前台应用（极少情况），返回 nil
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            print("⚠️ 无法获取前台应用")
            return nil
        }

        // 获取 Bundle ID，这是标识应用的唯一键
        // 某些系统进程可能没有 Bundle ID
        let bundleID = frontApp.bundleIdentifier ?? "unknown"

        // 获取应用的本地化名称
        let name = frontApp.localizedName ?? "未知应用"

        // 获取应用图标
        // 优先从应用的 Bundle URL 获取高质量图标
        let icon: NSImage
        if let bundleURL = frontApp.bundleURL {
            // NSWorkspace.shared.icon(forFile:) 可以获取应用的高分辨率图标
            icon = NSWorkspace.shared.icon(forFile: bundleURL.path)
        } else {
            // 降级方案：使用 NSRunningApplication 自带的 icon 属性
            icon = frontApp.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: "应用图标") ?? NSImage()
        }

        return ActiveAppInfo(
            bundleIdentifier: bundleID,
            localizedName: name,
            icon: icon,
            executableURL: frontApp.executableURL,
            bundleURL: frontApp.bundleURL,
            processIdentifier: frontApp.processIdentifier
        )
    }
}

// MARK: - CustomStringConvertible

extension ActiveAppInfo: CustomStringConvertible {
    var description: String {
        return "📱 \(localizedName) (\(bundleIdentifier)) [PID: \(processIdentifier)]"
    }
}
