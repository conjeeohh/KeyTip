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

    /// 热键触发开始（长按达到指定时间）回调
    typealias HotKeyStartHandler = @MainActor (ActiveAppInfo?) -> Void
    /// 热键释放（松开修饰键）或被打断时的回调
    typealias HotKeyEndHandler = @MainActor () -> Void

    // MARK: - 属性

    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    
    // 鼠标拦截（确保点击也能打断展示）
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?

    private var startHandler: HotKeyStartHandler?
    private var endHandler: HotKeyEndHandler?

    /// 当前配置的目标修饰键
    private var targetModifier: TriggerModifier = .command
    /// 当前配置的长按触发时长
    private var holdDuration: TimeInterval = 0.6

    private(set) var isListening: Bool = false
    
    // 状态追踪
    private var isPressing = false
    private var isShowingHUD = false
    private var pressTask: Task<Void, Never>?

    // MARK: - 初始化

    init() {}

    // MARK: - 公开方法

    /// 更新配置规则
    func updateConfig(modifier: TriggerModifier, duration: TimeInterval) {
        self.targetModifier = modifier
        self.holdDuration = duration
        print("🎹 热键配置已更新: \(modifier.displayName), 时长: \(duration)s")
    }

    /// 开始监听全局长按热键
    func startListening(
        onStart: @escaping HotKeyStartHandler,
        onEnd: @escaping HotKeyEndHandler
    ) {
        if isListening { stopListening() }

        self.startHandler = onStart
        self.endHandler = onEnd

        // 核心监听 1: 修饰键状态改变 (.flagsChanged)
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated { self?.handleFlagsChanged(event) }
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated { self?.handleFlagsChanged(event) }
            return event
        }

        // 核心监听 2: 其他普通按键 (.keyDown) -- 用于打断长按计时或强制关闭 HUD
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handleInterruption() }
        }
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated { self?.handleInterruption() }
            return event
        }
        
        // 核心监听 3: 鼠标点击 -- 用于打断长按计时或强制关闭 HUD
        let mouseMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseMask) { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouseInterruption() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseMask) { [weak self] event in
            MainActor.assumeIsolated { self?.handleMouseInterruption() }
            return event
        }

        isListening = true
        print("🎹 全局热键长按监听已启动")
    }

    /// 停止监听全局热键
    func stopListening() {
        if let m = globalFlagsMonitor { NSEvent.removeMonitor(m) }
        globalFlagsMonitor = nil
        if let m = localFlagsMonitor { NSEvent.removeMonitor(m) }
        localFlagsMonitor = nil
        
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m) }
        globalKeyMonitor = nil
        if let m = localKeyMonitor { NSEvent.removeMonitor(m) }
        localKeyMonitor = nil
        
        if let m = globalMouseMonitor { NSEvent.removeMonitor(m) }
        globalMouseMonitor = nil
        if let m = localMouseMonitor { NSEvent.removeMonitor(m) }
        localMouseMonitor = nil

        isListening = false
        startHandler = nil
        endHandler = nil
        
        // 强制清理状态
        handleInterruption()
        
        print("🔇 全局热键长按监听已停止")
    }

    // MARK: - 私有逻辑

    private func handleFlagsChanged(_ event: NSEvent) {
        // 仅检查 4 大核心修饰键，忽略 CapsLock 和其他状态
        let relevantMask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let pressedModifiers = event.modifierFlags.intersection(relevantMask)
        
        let isTargetPressed = (pressedModifiers == targetModifier.flags)

        if isTargetPressed {
            // 如果仅按下了目标修饰键
            if !isPressing {
                isPressing = true
                startPressDownTimer()
            }
        } else {
            // 如果松开了，或者同时按下了不止一个修饰键
            if isPressing {
                isPressing = false
                cancelPressTaskAndHideIfNeeded()
            }
        }
    }

    private func handleInterruption() {
        // 用户按下了任何真正的按键，或者点击了鼠标。
        // 不论是正在计时还是正在展示HUD，都需要立刻中断。
        isPressing = false
        cancelPressTaskAndHideIfNeeded()
    }

    private func handleMouseInterruption() {
        // 鼠标点击需要打断“长按计时”，避免用户移动鼠标时误触发 HUD。
        // 但当 HUD 已经显示时，鼠标点击可能是与 HUD 的交互，
        // 此时关闭逻辑交给 HUDPanelController 处理，不能在这里抢先打断。
        if isShowingHUD {
            return
        }

        isPressing = false
        cancelPressTaskAndHideIfNeeded()
    }
    
    // MARK: - 计时器器与状态控制

    private func startPressDownTimer() {
        // 开始新的倒计时任务
        pressTask?.cancel()
        let durationToWait = self.holdDuration
        
        pressTask = Task {
            do {
                // 等待用户设定的秒数 (例如 0.6s)
                try await Task.sleep(nanoseconds: UInt64(durationToWait * 1_000_000_000))
                
                // 如果在 sleep 期间没有被 cancel，则可以展示 HUD
                guard !Task.isCancelled else { return }
                
                self.isShowingHUD = true
                
                print("⚡️ 长按触发！正在检测前台应用...")
                let appInfo = ActiveAppDetector.getCurrentApp()
                
                self.startHandler?(appInfo)
            } catch {
                // Task.sleep 抛出 CancellationError 时会来到此处
            }
        }
    }

    private func cancelPressTaskAndHideIfNeeded() {
        // 取消正在倒计时的任务
        pressTask?.cancel()
        pressTask = nil
        
        // 如果 HUD 已经在展示，必须告知其关闭
        if isShowingHUD {
            isShowingHUD = false
            endHandler?()
        }
    }
}
