# KeyTip

KeyTip 是一个 macOS 菜单栏工具，用来快速查看当前前台应用的菜单栏快捷键。

当你长按设定的修饰键时，KeyTip 会读取当前应用的菜单结构，并以 HUD 浮层的形式展示可用快捷键。项目当前基于 SwiftUI + AppKit + Accessibility API 实现，处于可运行原型阶段。

## 特性

- 菜单栏常驻运行，隐藏 Dock 图标
- 长按全局触发键显示 HUD，松开后自动消失
- 自动识别当前前台应用的名称、图标和 Bundle ID
- 通过 Accessibility API 读取应用菜单栏中的快捷键
- 按顶级菜单分组展示快捷键
- 支持特殊按键和修饰键格式化显示
- 支持按应用隐藏系统快捷键
- 支持按应用追加自定义快捷键
- 提供基础偏好设置页，可调整触发修饰键和触发时长

## 当前状态

当前版本已经可以完成以下主流程：

1. 以菜单栏应用启动
2. 请求或检查辅助功能权限
3. 长按触发键
4. 读取当前前台应用的菜单栏快捷键
5. 合并本地自定义配置
6. 以 HUD 面板展示结果

当前版本仍有一些明显未完成项：

- 偏好设置里还不能直接图形化编辑隐藏项和自定义快捷键
- “登录时自动启动”还是占位项
- 自动化测试尚未覆盖核心逻辑

## 运行环境

- macOS 14.0+
- Xcode 16+
- Swift 6

## 快速开始

1. 克隆仓库
2. 用 Xcode 打开 `KeyTip.xcodeproj`
3. 选择 `KeyTip` target
4. 直接运行到本机

首次运行时，应用会请求辅助功能权限。没有这个权限时，KeyTip 无法读取其他应用的菜单栏快捷键，也无法可靠监听全局输入状态。

## 使用方式

默认交互如下：

- 长按 `Command` 键约 `0.6` 秒显示 HUD
- 松开修饰键后关闭 HUD
- 在 HUD 展示期间按下其他按键或点击鼠标，也会中断显示

当前可在偏好设置中调整：

- 触发修饰键：`Command` / `Option` / `Control` / `Shift`
- 长按触发时长：`0.3s` 到 `1.5s`

## 权限说明

KeyTip 依赖 macOS 的 Accessibility API。

应用会使用以下能力：

- 读取前台应用的菜单栏结构
- 提取菜单项标题、快捷键字符、修饰键信息
- 监听全局修饰键状态变化

如果没有授予辅助功能权限，项目的核心能力会失效。

授权入口：

- 系统设置
- 隐私与安全性
- 辅助功能

## 自定义配置

当前版本的自定义配置保存在：

`~/Library/Application Support/KeyTip/config.json`

配置按应用的 Bundle ID 组织，支持两类数据：

- `hiddenItems`: 隐藏系统读取到的快捷键
- `customItems`: 追加用户自定义快捷键

示例：

```json
{
  "appConfigs": {
    "com.apple.Safari": {
      "bundleIdentifier": "com.apple.Safari",
      "hiddenItems": [
        "文件.关闭标签页.⌘W"
      ],
      "customItems": [
        {
          "id": "A6E3B0D0-4A73-4EB9-B155-5F2F2FDF7F7A",
          "title": "切换标签页",
          "menuName": "自定义",
          "modifiersRawValue": 5,
          "keyCharacter": "T"
        }
      ]
    }
  }
}
```

说明：

- `hiddenItems` 里的值需要匹配内部生成的 `ShortcutItem.id`
- `modifiersRawValue` 对应内部 `ShortcutModifiers.rawValue`
- 当前版本虽然已有持久化和合并逻辑，但主要仍通过手动编辑配置文件完成高级定制

## 项目结构

```text
KeyTip/
├── KeyTipApp.swift             # SwiftUI 应用入口
├── AppDelegate.swift           # 菜单栏、生命周期、热键与 HUD 调度
├── HotKeyManager.swift         # 全局长按触发逻辑
├── ActiveAppInfo.swift         # 前台应用信息检测
├── AccessibilityHelper.swift   # 辅助功能权限检查与引导
├── MenuBarReader.swift         # Accessibility 菜单读取引擎
├── ShortcutItem.swift          # 快捷键数据模型
├── ShortcutMerger.swift        # 系统快捷键与自定义配置合并
├── ConfigStore.swift           # JSON 配置读写
├── HUDPanel.swift              # AppKit HUD 面板
├── HUDPanelController.swift    # HUD 展示控制器
├── HUDContentView.swift        # SwiftUI HUD 内容
├── SettingsView.swift          # 偏好设置界面
├── HotKeyConfig.swift          # 触发配置定义
└── CustomShortcutConfig.swift  # 自定义快捷键配置模型
```

## 已知限制

- 依赖 Accessibility API，不同应用暴露出的菜单结构质量不一致
- 某些应用可能没有标准菜单栏，或不会完整暴露快捷键信息
- 当前只覆盖“菜单栏中可读到的快捷键”，不包含应用私有命令、命令面板动作、插件内部快捷键等
- 当前 HUD 仅用于展示，不支持在界面中直接搜索、过滤、编辑或固定排序
- 当前没有缓存和增量刷新策略，每次触发都会实时读取菜单结构

## 路线图

- 完成图形化的应用配置编辑页
- 支持在 HUD 或设置中直接隐藏快捷键
- 支持新增和管理自定义快捷键
- 实现登录启动
- 补充核心单元测试和 UI 测试
- 优化多语言菜单、复杂嵌套菜单和特殊应用兼容性

## 开发说明

项目采用以下组合：

- SwiftUI：偏好设置和 HUD 内容渲染
- AppKit：菜单栏图标、`NSPanel`、全局事件监听
- Accessibility API：读取前台应用菜单栏快捷键
- JSON 文件：持久化每个应用的自定义配置

当前代码重心在“核心链路可跑通”，因此更偏向原型实现，而不是完整产品化状态。

## 贡献

欢迎通过 Issue 或 Pull Request 讨论以下方向：

- 触发方式设计
- HUD 信息架构和交互
- Accessibility 兼容性问题
- 配置编辑体验
- 测试覆盖与稳定性改进

## License

本项目使用 Apache License 2.0，详见 `LICENSE`。
