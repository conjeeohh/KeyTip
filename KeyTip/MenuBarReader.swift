//
//  MenuBarReader.swift
//  KeyTip
//
//  Accessibility API 菜单栏快捷键读取引擎
//  使用 AXUIElement 遍历目标应用的菜单栏结构，提取所有带快捷键的菜单项
//
//  ## 工作原理
//  macOS 的无障碍 API (Accessibility API) 将应用的 UI 元素以树状结构暴露：
//  Application → MenuBar → MenuBarItem(文件/编辑/...) → Menu → MenuItem
//  每个 MenuItem 可能有快捷键属性（AXMenuItemCmdChar + AXMenuItemCmdModifiers）
//  本类递归遍历这棵树，收集所有带快捷键的菜单项。
//
//  ## 权限要求
//  需要辅助功能权限 (Accessibility)，否则 AXUIElement API 调用会返回错误
//

import Cocoa

/// 菜单栏快捷键读取器
/// 通过 Accessibility API 从目标应用的菜单栏中提取所有快捷键信息
@MainActor
enum MenuBarReader {

    // MARK: - 公开方法

    /// 读取指定应用的所有菜单栏快捷键
    /// - Parameter appInfo: 目标应用信息（包含 PID 用于定位应用）
    /// - Returns: 按菜单分组的快捷键列表；如果读取失败返回空数组
    ///
    /// ## 调用流程
    /// 1. 通过 PID 创建应用的 AXUIElement
    /// 2. 获取应用的 MenuBar 元素
    /// 3. 遍历 MenuBar 的子项（文件、编辑、视图...）
    /// 4. 对每个子项递归提取带快捷键的菜单项
    /// 5. 按菜单名分组返回结果
    static func readShortcuts(from appInfo: ActiveAppInfo) -> [ShortcutGroup] {
        let pid = appInfo.processIdentifier

        // 1. 通过进程 ID 创建目标应用的 AXUIElement 引用
        // AXUIElementCreateApplication 是 C 函数，接受 pid_t 参数
        // 返回的 AXUIElement 代表目标应用的根元素
        let appElement = AXUIElementCreateApplication(pid)

        // 2. 获取应用的菜单栏 (MenuBar)
        // kAXMenuBarAttribute 是 macOS 无障碍 API 中表示应用菜单栏的属性键
        guard let menuBar = getAttributeValue(element: appElement, attribute: kAXMenuBarAttribute as String) else {
            print("⚠️ 无法获取应用 \(appInfo.localizedName) 的菜单栏")
            print("   可能原因: 1. 未授予辅助功能权限 2. 应用没有菜单栏 3. 应用已退出")
            return []
        }

        // 将获取的值转换为 AXUIElement 类型
        let menuBarElement = menuBar as! AXUIElement

        // 3. 获取菜单栏的所有子项（即顶级菜单：文件、编辑、视图...）
        guard let menuBarItems = getAttributeValue(element: menuBarElement, attribute: kAXChildrenAttribute as String) as? [AXUIElement] else {
            print("⚠️ 菜单栏没有子项")
            return []
        }

        print("📋 发现 \(menuBarItems.count) 个顶级菜单项")

        // 4. 逐个遍历顶级菜单，提取快捷键
        var groups: [ShortcutGroup] = []

        for menuBarItem in menuBarItems {
            // 获取顶级菜单的标题（如 "文件"、"编辑"）
            guard let menuName = getAttributeValue(element: menuBarItem, attribute: kAXTitleAttribute as String) as? String,
                  !menuName.isEmpty else {
                continue
            }

            // 跳过 Apple 菜单（苹果 Logo 菜单，通常不包含用户需要的快捷键）
            if menuName == "Apple" || menuName == "" {
                continue
            }

            // 获取该顶级菜单下的子菜单
            guard let subMenu = getAttributeValue(element: menuBarItem, attribute: kAXChildrenAttribute as String) as? [AXUIElement],
                  let firstSubMenu = subMenu.first else {
                continue
            }

            // 递归提取该菜单下所有带快捷键的菜单项
            var items: [ShortcutItem] = []
            extractShortcuts(from: firstSubMenu, menuName: menuName, items: &items)

            // 只添加有快捷键的菜单分组
            if !items.isEmpty {
                groups.append(ShortcutGroup(menuName: menuName, items: items))
                print("   ✅ \(menuName): 提取到 \(items.count) 个快捷键")
            }
        }

        let totalCount = groups.reduce(0) { $0 + $1.items.count }
        print("📊 总计提取 \(totalCount) 个快捷键，分布在 \(groups.count) 个菜单中")

        return groups
    }

    // MARK: - 私有方法

    /// 递归提取菜单中的所有快捷键
    /// - Parameters:
    ///   - menuElement: 当前要遍历的菜单 AXUIElement
    ///   - menuName: 所属的顶级菜单名称
    ///   - items: 收集快捷键的数组（inout 引用传递）
    ///   - depth: 当前递归深度（防止无限递归，最大 5 层）
    private static func extractShortcuts(
        from menuElement: AXUIElement,
        menuName: String,
        items: inout [ShortcutItem],
        depth: Int = 0
    ) {
        // 防止无限递归（正常菜单嵌套不超过 5 层）
        guard depth < 5 else { return }

        // 获取当前菜单的所有子项
        guard let children = getAttributeValue(element: menuElement, attribute: kAXChildrenAttribute as String) as? [AXUIElement] else {
            return
        }

        for child in children {
            // 获取菜单项的标题
            let title = getAttributeValue(element: child, attribute: kAXTitleAttribute as String) as? String ?? ""

            // 跳过分隔线（标题为空的菜单项通常是分隔线）
            if title.isEmpty {
                continue
            }

            // 检查是否有子菜单（嵌套菜单）
            if let subMenuChildren = getAttributeValue(element: child, attribute: kAXChildrenAttribute as String) as? [AXUIElement],
               let subMenu = subMenuChildren.first {
                // 递归进入子菜单
                extractShortcuts(from: subMenu, menuName: menuName, items: &items, depth: depth + 1)
                continue
            }

            // 尝试获取快捷键字符
            // kAXMenuItemCmdCharAttribute 返回快捷键对应的按键字符（如 "c", "v"）
            guard let cmdChar = getAttributeValue(element: child, attribute: kAXMenuItemCmdCharAttribute as String) as? String,
                  !cmdChar.isEmpty else {
                // 没有快捷键的菜单项，跳过
                continue
            }

            // 获取快捷键修饰符
            // kAXMenuItemCmdModifiersAttribute 返回一个整数，表示修饰键组合
            // AX 修饰符的位定义与 NSEvent.ModifierFlags 不同，需要转换
            let axModifiers = getAttributeValue(element: child, attribute: kAXMenuItemCmdModifiersAttribute as String) as? Int ?? 0

            // 转换 AX 修饰符为自定义的 ShortcutModifiers
            let modifiers = convertAXModifiers(axModifiers)

            // 将原始按键字符转换为用户可读的显示格式
            let displayKey = SpecialKeyMapping.displayString(for: cmdChar)

            // 创建快捷键条目并添加到结果数组
            let item = ShortcutItem(
                title: title,
                menuName: menuName,
                modifiers: modifiers,
                keyCharacter: displayKey
            )
            items.append(item)
        }
    }

    /// 将 Accessibility API 返回的修饰符整数转换为 ShortcutModifiers
    /// - Parameter axModifiers: AX API 返回的修饰符值
    /// - Returns: 转换后的 ShortcutModifiers
    ///
    /// ## AX 修饰符位定义
    /// AX API 的修饰符与 NSEvent.ModifierFlags 不同：
    /// - 默认情况下，Command (⌘) **总是包含**（除非设置了 NoCommand 位）
    /// - kAXMenuItemModifierShift     = 1 << 0 = 1  （额外包含 ⇧）
    /// - kAXMenuItemModifierOption    = 1 << 1 = 2  （额外包含 ⌥）
    /// - kAXMenuItemModifierControl   = 1 << 2 = 4  （额外包含 ⌃）
    /// - kAXMenuItemModifierNoCommand = 1 << 3 = 8  （不包含 ⌘）
    private static func convertAXModifiers(_ axModifiers: Int) -> ShortcutModifiers {
        var result: ShortcutModifiers = []

        // 检查是否包含 Command 键
        // AX API 默认包含 Command，只有设置了 NoCommand 位（bit 3）才排除
        let noCommand = (axModifiers & (1 << 3)) != 0
        if !noCommand {
            result.insert(.command)
        }

        // 检查 Shift 键（bit 0）
        if (axModifiers & (1 << 0)) != 0 {
            result.insert(.shift)
        }

        // 检查 Option 键（bit 1）
        if (axModifiers & (1 << 1)) != 0 {
            result.insert(.option)
        }

        // 检查 Control 键（bit 2）
        if (axModifiers & (1 << 2)) != 0 {
            result.insert(.control)
        }

        return result
    }

    // MARK: - AXUIElement 辅助方法

    /// 安全地获取 AXUIElement 的属性值
    /// - Parameters:
    ///   - element: 目标 AXUIElement
    ///   - attribute: 属性名称（如 kAXChildrenAttribute）
    /// - Returns: 属性值（CFTypeRef），获取失败返回 nil
    ///
    /// ## 错误处理
    /// AXUIElementCopyAttributeValue 可能返回多种错误：
    /// - .attributeUnsupported: 元素不支持该属性
    /// - .apiDisabled: 辅助功能 API 被禁用
    /// - .invalidUIElement: 元素已失效（如窗口已关闭）
    /// - .notImplemented: 属性未实现
    /// 这些错误在菜单遍历中是常见且正常的，不需要特别处理
    private static func getAttributeValue(element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)

        // 只有 .success 才返回值，其他情况静默返回 nil
        guard result == .success else {
            return nil
        }

        return value
    }
}
