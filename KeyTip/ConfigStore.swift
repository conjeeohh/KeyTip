//
//  ConfigStore.swift
//  KeyTip
//
//  配置持久化存储
//  按 App 读写 TOML 配置文件
//

import AppKit
import Foundation

/// 配置持久化管理器
/// 负责按应用读写 TOML 展示配置
@MainActor
class ConfigStore {

    // MARK: - 单例

    /// 共享实例
    static let shared = ConfigStore()

    // MARK: - 属性

    /// 配置文件目录
    private let appsDirectoryURL: URL

    // MARK: - 初始化

    private init() {
        // 构建配置目录：~/Library/Application Support/KeyTip/apps
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("KeyTip", isDirectory: true)
        self.appsDirectoryURL = appDir.appendingPathComponent("apps", isDirectory: true)

        // 确保目录存在
        try? FileManager.default.createDirectory(at: appsDirectoryURL, withIntermediateDirectories: true)

        print("💾 配置存储初始化完成: \(appsDirectoryURL.path)")
    }

    // MARK: - 公开方法

    /// 获取配置目录 URL
    var configDirectoryURL: URL {
        ensureConfigDirectoryExists()
        return appsDirectoryURL
    }

    /// 获取指定应用的配置文件路径
    func configFileURL(for bundleID: String) -> URL {
        ensureConfigDirectoryExists()
        let encodedFileName = encodeBundleID(bundleID)
        return appsDirectoryURL.appendingPathComponent(encodedFileName).appendingPathExtension("toml")
    }

    /// 加载指定应用的配置
    /// 文件不存在时返回默认配置；解析失败时也回落到默认配置
    func loadConfig(for bundleID: String) -> AppDisplayConfig {
        do {
            guard let config = try loadExistingConfig(for: bundleID) else {
                return AppDisplayConfig()
            }
            return config
        } catch {
            print("⚠️ 读取配置失败 [\(bundleID)]: \(error.localizedDescription)")
            print("   将回退到默认展示配置")
            return AppDisplayConfig()
        }
    }

    /// 获取配置摘要，配置文件不存在或无法读取时返回 nil
    func summary(for bundleID: String) -> AppDisplayConfigSummary? {
        do {
            guard let config = try loadExistingConfig(for: bundleID) else { return nil }
            return config.summary
        } catch {
            print("⚠️ 读取配置摘要失败 [\(bundleID)]: \(error.localizedDescription)")
            return nil
        }
    }

    /// 获取所有已有配置文件的 Bundle ID 列表
    func availableBundleIDs() -> [String] {
        ensureConfigDirectoryExists()

        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: appsDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return fileURLs
            .filter { $0.pathExtension == "toml" }
            .map { decodeBundleID($0.deletingPathExtension().lastPathComponent) }
            .sorted()
    }

    /// 确保配置文件存在，不存在则创建模板
    @discardableResult
    func ensureConfigFile(for bundleID: String) throws -> URL {
        let fileURL = configFileURL(for: bundleID)

        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            return fileURL
        }

        guard let data = AppDisplayConfig.fileTemplate.data(using: .utf8) else {
            throw NSError(
                domain: "KeyTip.ConfigStore",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "无法生成默认配置模板"]
            )
        }

        try data.write(to: fileURL, options: .atomic)
        print("📝 已创建配置模板: \(fileURL.path)")
        return fileURL
    }

    /// 用系统默认编辑器打开指定应用的配置文件
    func openConfig(for bundleID: String) {
        do {
            let fileURL = try ensureConfigFile(for: bundleID)
            NSWorkspace.shared.open(fileURL)
        } catch {
            print("⚠️ 打开配置文件失败 [\(bundleID)]: \(error.localizedDescription)")
        }
    }

    /// 用系统默认编辑器打开当前应用的配置文件
    func openConfig(for appInfo: ActiveAppInfo) {
        openConfig(for: appInfo.bundleIdentifier)
    }

    /// 将系统项添加到隐藏列表
    func addHiddenSystemItem(_ itemID: String, for bundleID: String) throws {
        var config: AppDisplayConfig

        if let existingConfig = try loadExistingConfig(for: bundleID) {
            config = existingConfig
        } else {
            config = AppDisplayConfig()
        }

        guard !config.hiddenSystemItems.contains(itemID) else {
            return
        }

        config.hiddenSystemItems.append(itemID)
        try saveConfig(config, for: bundleID)
        print("🙈 已隐藏系统项 [\(bundleID)]: \(itemID)")
    }

    /// 打开配置文件目录
    func openConfigDirectory() {
        ensureConfigDirectoryExists()
        NSWorkspace.shared.open(appsDirectoryURL)
    }

    /// 删除指定应用的配置文件
    func removeConfig(for bundleID: String) {
        let fileURL = configFileURL(for: bundleID)

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            try FileManager.default.removeItem(at: fileURL)
            print("🗑️ 已删除配置: \(fileURL.lastPathComponent)")
        } catch {
            print("⚠️ 删除配置失败 [\(bundleID)]: \(error.localizedDescription)")
        }
    }

    // MARK: - 私有方法

    private func loadExistingConfig(for bundleID: String) throws -> AppDisplayConfig? {
        let fileURL = configFileURL(for: bundleID)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let source = try String(contentsOf: fileURL, encoding: .utf8)
        return try DisplayConfigParser.parse(source)
    }

    private func saveConfig(_ config: AppDisplayConfig, for bundleID: String) throws {
        let fileURL = configFileURL(for: bundleID)
        let source = DisplayConfigSerializer.serialize(config)

        guard let data = source.data(using: .utf8) else {
            throw NSError(
                domain: "KeyTip.ConfigStore",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "无法序列化配置文件内容"]
            )
        }

        try data.write(to: fileURL, options: .atomic)
    }

    private func ensureConfigDirectoryExists() {
        try? FileManager.default.createDirectory(at: appsDirectoryURL, withIntermediateDirectories: true)
    }

    private func encodeBundleID(_ bundleID: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return bundleID.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? bundleID
    }

    private func decodeBundleID(_ fileName: String) -> String {
        fileName.removingPercentEncoding ?? fileName
    }
}
