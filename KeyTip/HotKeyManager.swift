//
//  HotKeyManager.swift
//  KeyTip
//
//  全局热键监听管理器
//  使用 NSEvent.addGlobalMonitorForEvents 监听系统级键盘事件
//  初期配置为 Option+Z 触发
//

import Cocoa

/// 全局热键监听管理器
/// 负责注册和管理全局键盘快捷键监听，当用户按下指定的热键组合时触发回调
///
/// ## 工作原理
/// - 使用 `NSEvent.addGlobalMonitorForEvents` 监听全局键盘事件
/// - 该 API 可以捕获其他应用激活时的键盘事件（需要辅助功能权限）
/// - 使用 `NSEvent.addLocalMonitorForEvents` 监听本应用内的键盘事件
/// - 两者结合确保无论焦点在哪个应用，都能响应热键
///
/// ## 注意事项
/// - 全局监听需要辅助功能权限（Accessibility）
/// - 如果未授权，全局监听器将静默失效（不会崩溃，但也不会触发回调）
@MainActor
class HotKeyManager {

    // MARK: - 类型定义

    /// 热键触发时的回调闭包
    /// 传入触发热键时检测到的前台应用信息（可能为 nil）
    typealias HotKeyHandler = @MainActor (ActiveAppInfo?) -> Void

    // MARK: - 属性

    /// 全局事件监听器引用，用于后续移除
    private var globalMonitor: Any?

    /// 本地事件监听器引用，用于后续移除
    private var localMonitor: Any?

    /// 热键触发时的回调
    private var handler: HotKeyHandler?

    /// 当前配置的触发修饰键（默认为 Option/Alt）
    private var triggerModifiers: NSEvent.ModifierFlags = .option

    /// 当前配置的触发按键字符（默认为 "z"）
    private var triggerKeyChar: String = "z"

    /// 是否正在监听
    private(set) var isListening: Bool = false

    // MARK: - 初始化

    init() {}

    // 注意：资源清理（停止监听）由调用方（AppDelegate.applicationWillTerminate）负责
    // deinit 在 Swift 6 中是 nonisolated 的，不能调用 @MainActor 隔离方法

    // MARK: - 公开方法

    /// 开始监听全局热键
    /// - Parameters:
    ///   - modifiers: 修饰键组合（如 .option, .command, .control 等），默认为 .option
    ///   - key: 触发按键字符（如 "z"），默认为 "z"
    ///   - handler: 热键触发时的回调，参数为当前前台应用信息
    func startListening(
        modifiers: NSEvent.ModifierFlags = .option,
        key: String = "z",
        handler: @escaping HotKeyHandler
    ) {
        // 如果已经在监听，先停止旧的监听器
        if isListening {
            stopListening()
        }

        self.triggerModifiers = modifiers
        self.triggerKeyChar = key
        self.handler = handler

        // 注册全局事件监听器
        // addGlobalMonitorForEvents 可以捕获其他应用处于前台时的键盘事件
        // 注意：这需要辅助功能权限，否则回调不会触发
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // 全局监听回调在主线程执行，但闭包捕获需要通过 MainActor 调度
            MainActor.assumeIsolated {
                self?.handleKeyEvent(event)
            }
        }

        // 注册本地事件监听器
        // addLocalMonitorForEvents 捕获本应用处于前台时的键盘事件
        // 两者结合确保无论哪个应用在前台都能响应热键
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleKeyEvent(event)
            }
            // 返回 event 表示不吞掉该事件，让事件继续传递
            return event
        }

        isListening = true

        // 构建修饰键描述字符串
        let modifierStr = modifierDescription(modifiers)
        print("🎹 全局热键监听已启动: \(modifierStr)+\(key.uppercased())")
    }

    /// 停止监听全局热键
    func stopListening() {
        // 移除全局事件监听器
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }

        // 移除本地事件监听器
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        isListening = false
        handler = nil
        print("🔇 全局热键监听已停止")
    }

    // MARK: - 私有方法

    /// 处理键盘事件，判断是否匹配热键配置
    /// - Parameter event: NSEvent 键盘事件
    private func handleKeyEvent(_ event: NSEvent) {
        // 获取按键字符（不含修饰键影响的原始字符）
        // charactersIgnoringModifiers 返回忽略修饰键后的字符
        // 例如：Option+Z 在某些键盘布局下可能产生特殊字符，但 ignoring 版本始终返回 "z"
        guard let chars = event.charactersIgnoringModifiers?.lowercased() else {
            return
        }

        // 检查按键字符是否匹配
        guard chars == triggerKeyChar else {
            return
        }

        // 检查修饰键是否匹配
        // event.modifierFlags 包含当前按下的所有修饰键
        // .intersection(.deviceIndependentFlagsMask) 过滤掉设备相关的标志位，只保留修饰键信息
        // 这确保我们只检查 Command/Option/Control/Shift 等标准修饰键
        let pressedModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard pressedModifiers == triggerModifiers else {
            return
        }

        // 热键匹配成功！获取当前前台应用信息并触发回调
        print("⚡️ 热键触发！正在检测前台应用...")

        let appInfo = ActiveAppDetector.getCurrentApp()
        if let appInfo = appInfo {
            print("   → 前台应用: \(appInfo)")
        } else {
            print("   → 无法检测到前台应用")
        }

        // 触发回调
        handler?(appInfo)
    }

    // MARK: - 辅助方法

    /// 将修饰键标志转换为可读的描述字符串
    /// - Parameter flags: 修饰键组合
    /// - Returns: 如 "⌥" (Option), "⌘⇧" (Command+Shift) 等
    private func modifierDescription(_ flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option)  { parts.append("⌥") }
        if flags.contains(.shift)   { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        return parts.joined()
    }
}
