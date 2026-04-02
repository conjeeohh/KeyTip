//
//  HUDPanel.swift
//  KeyTip
//
//  自定义 HUD 悬浮窗面板
//  基于 NSPanel 实现无标题栏、毛玻璃背景、浮动层级的悬浮窗
//

import Cocoa

/// 自定义 HUD 悬浮窗面板
/// 特性：
/// - 无标题栏，纯内容区域
/// - 毛玻璃（Vibrancy）背景，融入系统视觉风格
/// - 浮动在所有窗口之上
/// - 不在 Dock 或 Mission Control 中显示
/// - 点击外部或按 Escape 自动关闭
class HUDPanel: NSPanel {

    // MARK: - 初始化

    /// 创建 HUD 面板
    /// - Parameter contentRect: 面板的初始尺寸和位置
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [
                .nonactivatingPanel,    // 不夺取焦点（保持前台应用的活跃状态）
                .fullSizeContentView,   // 内容区域扩展到标题栏区域
                .borderless             // 无边框
            ],
            backing: .buffered,
            defer: false
        )

        // 配置面板属性
        setupPanel()

        // 添加毛玻璃背景
        setupVisualEffect()
    }

    // MARK: - 配置

    /// 配置面板基础属性
    private func setupPanel() {
        // 设置窗口层级为浮动（始终在普通窗口之上）
        level = .floating

        // 启用圆角
        isOpaque = false
        backgroundColor = .clear

        // 不在 Dock 最近使用中显示
        isExcludedFromWindowsMenu = true

        // 允许在所有 Space 中显示
        collectionBehavior = [
            .canJoinAllSpaces,          // 在所有桌面空间显示
            .fullScreenAuxiliary,       // 支持全屏辅助窗口
            .transient                  // 临时窗口，不在 Mission Control 中显示
        ]

        // 隐藏标题栏
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        // 关闭时自动隐藏而非销毁
        isReleasedWhenClosed = false

        // 启用阴影
        hasShadow = true
    }

    /// 添加毛玻璃背景视效层
    private func setupVisualEffect() {
        let visualEffect = NSVisualEffectView(frame: contentView!.bounds)
        // 使用 HUD 材质，提供深色半透明毛玻璃效果
        visualEffect.material = .hudWindow
        // 始终激活模糊效果（而非仅在窗口活跃时）
        visualEffect.state = .active
        // 幕后混合模式
        visualEffect.blendingMode = .behindWindow
        // 自动适应尺寸变化
        visualEffect.autoresizingMask = [.width, .height]
        // 圆角
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true

        // 将毛玻璃视图设置为面板的内容视图
        contentView = visualEffect
    }

    // MARK: - 事件处理

    /// 允许面板成为 Key Window（接收键盘事件），以便响应 Escape 退出
    override var canBecomeKey: Bool {
        return true
    }

    /// 监听键盘事件，按 Escape 关闭面板
    override func keyDown(with event: NSEvent) {
        // Escape 键的 keyCode 是 53
        if event.keyCode == 53 {
            close()
        } else {
            super.keyDown(with: event)
        }
    }

    /// 显示面板并居中到屏幕
    func showCentered() {
        // 获取当前活跃屏幕（鼠标所在屏幕）
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame

        // 计算居中位置
        let panelFrame = frame
        let x = screenFrame.midX - panelFrame.width / 2
        let y = screenFrame.midY - panelFrame.height / 2

        setFrameOrigin(NSPoint(x: x, y: y))

        // 显示面板
        makeKeyAndOrderFront(nil)

        // 添加淡入动画
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }

    /// 带动画关闭面板
    func dismissAnimated() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1  // 重置透明度以便下次显示
        })
    }
}
