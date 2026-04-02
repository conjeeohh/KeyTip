//
//  HUDPanel.swift
//  KeyTip
//
//  自定义 HUD 悬浮窗面板
//  基于 NSPanel 实现无标题栏、透明背景、浮动层级的悬浮窗
//  毛玻璃效果由 SwiftUI 层的 .background(.regularMaterial) 提供
//

import Cocoa

/// 自定义 HUD 悬浮窗面板
class HUDPanel: NSPanel {

    // MARK: - 初始化

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

        setupPanel()
    }

    // MARK: - 配置

    private func setupPanel() {
        // 透明背景 — 由 SwiftUI 层提供毛玻璃材质
        isOpaque = false
        backgroundColor = .clear

        // 浮动层级（始终在普通窗口之上）
        level = .floating

        // 不在 Dock / Mission Control 中显示
        isExcludedFromWindowsMenu = true
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient
        ]

        // 隐藏标题栏
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        // 关闭时隐藏而非销毁
        isReleasedWhenClosed = false

        // 精致阴影
        hasShadow = true
    }

    // MARK: - 事件处理

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            dismissAnimated()
        } else {
            super.keyDown(with: event)
        }
    }

    /// 居中显示（带淡入 + 微缩放动画）
    func showCentered() {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        let panelFrame = frame

        let x = screenFrame.midX - panelFrame.width / 2
        let y = screenFrame.midY - panelFrame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))

        // 初始状态：透明 + 略微缩小
        alphaValue = 0
        setFrame(
            NSRect(
                x: frame.origin.x + 8,
                y: frame.origin.y + 8,
                width: frame.width - 16,
                height: frame.height - 16
            ),
            display: false
        )

        makeKeyAndOrderFront(nil)

        // 动画到最终状态
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
            self.animator().setFrame(
                NSRect(x: x, y: y, width: panelFrame.width, height: panelFrame.height),
                display: true
            )
        }
    }

    /// 带动画关闭
    func dismissAnimated() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
        })
    }
}
