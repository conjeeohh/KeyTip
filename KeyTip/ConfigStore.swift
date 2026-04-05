//
//  ConfigStore.swift
//  KeyTip
//
//  配置持久化存储
//  使用 JSON 文件存储用户的自定义快捷键配置
//  存储位置：~/Library/Application Support/KeyTip/config.json
//

import Foundation

/// 配置持久化管理器
/// 负责将 ShortcutConfiguration 序列化为 JSON 并读写到磁盘
@MainActor
class ConfigStore {

    // MARK: - 单例

    /// 共享实例
    static let shared = ConfigStore()

    // MARK: - 属性

    /// 当前加载的配置
    private(set) var configuration: ShortcutConfiguration

    /// 配置文件路径
    private let configFileURL: URL

    // MARK: - 初始化

    private init() {
        // 构建配置文件路径：~/Library/Application Support/KeyTip/config.json
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("KeyTip", isDirectory: true)
        self.configFileURL = appDir.appendingPathComponent("config.json")

        // 确保目录存在
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        // 加载已有配置
        self.configuration = ShortcutConfiguration()
        loadConfiguration()

        print("💾 配置存储初始化完成: \(configFileURL.path)")
    }

    // MARK: - 公开方法

    /// 获取指定应用的配置
    /// - Parameter bundleID: 应用的 Bundle ID
    /// - Returns: 应用配置，如果未配置返回 nil
    func config(for bundleID: String) -> AppShortcutConfig? {
        return configuration.config(for: bundleID)
    }

    /// 保存/更新指定应用的配置
    /// - Parameter config: 应用配置
    func saveConfig(_ config: AppShortcutConfig) {
        configuration.updateConfig(config)
        saveConfiguration()
    }

    /// 添加隐藏项
    /// - Parameters:
    ///   - itemID: 要隐藏的快捷键 ID
    ///   - bundleID: 目标应用的 Bundle ID
    func addHiddenItem(_ itemID: String, for bundleID: String) {
        var config = configuration.getOrCreateConfig(for: bundleID)
        if !config.hiddenItems.contains(itemID) {
            config.hiddenItems.append(itemID)
            configuration.updateConfig(config)
            saveConfiguration()
        }
    }

    /// 移除隐藏项
    /// - Parameters:
    ///   - itemID: 要恢复显示的快捷键 ID
    ///   - bundleID: 目标应用的 Bundle ID
    func removeHiddenItem(_ itemID: String, for bundleID: String) {
        guard var config = configuration.config(for: bundleID) else { return }
        config.hiddenItems.removeAll { $0 == itemID }
        configuration.updateConfig(config)
        saveConfiguration()
    }

    /// 添加自定义快捷键
    /// - Parameters:
    ///   - entry: 自定义快捷键条目
    ///   - bundleID: 目标应用的 Bundle ID
    func addCustomItem(_ entry: CustomShortcutEntry, for bundleID: String) {
        var config = configuration.getOrCreateConfig(for: bundleID)
        config.customItems.append(entry)
        configuration.updateConfig(config)
        saveConfiguration()
    }

    /// 移除自定义快捷键
    /// - Parameters:
    ///   - entryID: 自定义快捷键的 ID
    ///   - bundleID: 目标应用的 Bundle ID
    func removeCustomItem(_ entryID: String, for bundleID: String) {
        guard var config = configuration.config(for: bundleID) else { return }
        config.customItems.removeAll { $0.id == entryID }
        configuration.updateConfig(config)
        saveConfiguration()
    }

    /// 重置指定应用的所有自定义配置
    /// - Parameter bundleID: 目标应用的 Bundle ID
    func resetConfig(for bundleID: String) {
        configuration.removeConfig(for: bundleID)
        saveConfiguration()
    }

    // MARK: - 私有方法

    /// 从磁盘加载配置
    private func loadConfiguration() {
        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            print("📂 配置文件不存在，使用默认配置")
            return
        }

        do {
            let data = try Data(contentsOf: configFileURL)
            let decoder = JSONDecoder()
            configuration = try decoder.decode(ShortcutConfiguration.self, from: data)
            let appCount = configuration.appConfigs.count
            print("📂 已加载 \(appCount) 个应用的自定义配置")
        } catch {
            print("⚠️ 配置文件读取失败: \(error.localizedDescription)")
            print("   将使用默认配置")
        }
    }

    /// 将配置保存到磁盘
    private func saveConfiguration() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(configuration)
            try data.write(to: configFileURL, options: .atomic)
            print("💾 配置已保存")
        } catch {
            print("⚠️ 配置保存失败: \(error.localizedDescription)")
        }
    }
}
