//
//  DisplayConfigParser.swift
//  KeyTip
//
//  面向当前配置格式的轻量 TOML 解析器
//  仅支持本项目需要的字段和语法
//

import Foundation

enum DisplayConfigParser {

    static func parse(_ source: String) throws -> AppDisplayConfig {
        var config = AppDisplayConfig()
        let lines = source.components(separatedBy: .newlines)

        var currentItem: DisplayItemBuilder?
        var lineIndex = 0

        while lineIndex < lines.count {
            let lineNumber = lineIndex + 1
            var line = stripComments(from: lines[lineIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            lineIndex += 1

            if line.isEmpty {
                continue
            }

            if line == "[[items]]" {
                if let currentItem {
                    config.items.append(try currentItem.build())
                }
                currentItem = DisplayItemBuilder(startLine: lineNumber)
                continue
            }

            guard let separator = line.firstIndex(of: "=") else {
                throw DisplayConfigParseError.invalidSyntax(line: lineNumber, content: line)
            }

            let key = line[..<separator].trimmingCharacters(in: .whitespacesAndNewlines)
            line = line[line.index(after: separator)...].trimmingCharacters(in: .whitespacesAndNewlines)

            if startsArray(line), arrayBracketBalance(for: line) > 0 {
                while lineIndex < lines.count && arrayBracketBalance(for: line) > 0 {
                    let nextLine = stripComments(from: lines[lineIndex])
                    line += "\n" + nextLine
                    lineIndex += 1
                }
            }

            if var itemBuilder = currentItem {
                try assignItemValue(key: key, rawValue: line, to: &itemBuilder, line: lineNumber)
                currentItem = itemBuilder
            } else {
                try assignTopLevelValue(key: key, rawValue: line, to: &config, line: lineNumber)
            }
        }

        if let currentItem {
            config.items.append(try currentItem.build())
        }

        return config
    }

    // MARK: - 赋值

    private static func assignTopLevelValue(key: String, rawValue: String, to config: inout AppDisplayConfig, line: Int) throws {
        switch key {
        case "include_system_shortcuts":
            config.includeSystemShortcuts = try parseBool(rawValue, line: line)
        case "hide":
            config.hiddenSystemItems = try parseStringArray(rawValue, line: line)
        default:
            throw DisplayConfigParseError.unsupportedKey(line: line, key: key)
        }
    }

    private static func assignItemValue(key: String, rawValue: String, to builder: inout DisplayItemBuilder, line: Int) throws {
        switch key {
        case "title":
            builder.title = try parseString(rawValue, line: line)
        case "group":
            builder.group = try parseString(rawValue, line: line)
        case "shortcut":
            builder.shortcut = try parseString(rawValue, line: line)
        case "command":
            builder.command = try parseString(rawValue, line: line)
        default:
            throw DisplayConfigParseError.unsupportedKey(line: line, key: key)
        }
    }

    // MARK: - 值解析

    private static func parseBool(_ rawValue: String, line: Int) throws -> Bool {
        switch rawValue {
        case "true":
            return true
        case "false":
            return false
        default:
            throw DisplayConfigParseError.invalidBoolean(line: line, value: rawValue)
        }
    }

    private static func parseString(_ rawValue: String, line: Int) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "\"", trimmed.last == "\"" else {
            throw DisplayConfigParseError.invalidString(line: line, value: rawValue)
        }

        do {
            let data = Data(trimmed.utf8)
            return try JSONDecoder().decode(String.self, from: data)
        } catch {
            throw DisplayConfigParseError.invalidString(line: line, value: rawValue)
        }
    }

    private static func parseStringArray(_ rawValue: String, line: Int) throws -> [String] {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.first == "[", trimmed.last == "]" else {
            throw DisplayConfigParseError.invalidArray(line: line, value: rawValue)
        }

        let inner = String(trimmed.dropFirst().dropLast())
        var result: [String] = []
        var buffer = ""
        var inString = false
        var escaped = false

        for character in inner {
            if escaped {
                buffer.append(character)
                escaped = false
                continue
            }

            if inString && character == "\\" {
                buffer.append(character)
                escaped = true
                continue
            }

            if character == "\"" {
                buffer.append(character)
                inString.toggle()
                continue
            }

            if character == "," && !inString {
                let token = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !token.isEmpty {
                    result.append(try parseString(token, line: line))
                }
                buffer = ""
                continue
            }

            buffer.append(character)
        }

        let trailingToken = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailingToken.isEmpty {
            result.append(try parseString(trailingToken, line: line))
        }

        return result
    }

    // MARK: - 辅助方法

    private static func stripComments(from line: String) -> String {
        var result = ""
        var inString = false
        var escaped = false

        for character in line {
            if escaped {
                result.append(character)
                escaped = false
                continue
            }

            if inString && character == "\\" {
                result.append(character)
                escaped = true
                continue
            }

            if character == "\"" {
                inString.toggle()
                result.append(character)
                continue
            }

            if character == "#", !inString {
                break
            }

            result.append(character)
        }

        return result
    }

    private static func startsArray(_ rawValue: String) -> Bool {
        rawValue.trimmingCharacters(in: .whitespacesAndNewlines).first == "["
    }

    private static func arrayBracketBalance(for rawValue: String) -> Int {
        var balance = 0
        var inString = false
        var escaped = false

        for character in rawValue {
            if escaped {
                escaped = false
                continue
            }

            if inString && character == "\\" {
                escaped = true
                continue
            }

            if character == "\"" {
                inString.toggle()
                continue
            }

            if inString {
                continue
            }

            if character == "[" {
                balance += 1
            } else if character == "]" {
                balance -= 1
            }
        }

        return balance
    }
}

// MARK: - 内部 Builder

private struct DisplayItemBuilder {
    let startLine: Int
    var title: String?
    var group: String?
    var shortcut: String?
    var command: String?

    func build() throws -> CustomDisplayItem {
        guard let title, !title.isEmpty else {
            throw DisplayConfigParseError.missingRequiredField(line: startLine, field: "title")
        }

        let resolvedGroup = (group?.isEmpty == false ? group! : AppDisplayConfig.defaultGroupName)

        switch (shortcut, command) {
        case let (shortcut?, nil):
            return CustomDisplayItem(title: title, group: resolvedGroup, kind: .shortcut(shortcut))
        case let (nil, command?):
            return CustomDisplayItem(title: title, group: resolvedGroup, kind: .command(command))
        case (nil, nil):
            throw DisplayConfigParseError.invalidItem(line: startLine, reason: "缺少 shortcut 或 command")
        case (_?, _?):
            throw DisplayConfigParseError.invalidItem(line: startLine, reason: "shortcut 和 command 不能同时存在")
        }
    }
}

// MARK: - 错误定义

enum DisplayConfigParseError: LocalizedError {
    case invalidSyntax(line: Int, content: String)
    case unsupportedKey(line: Int, key: String)
    case invalidBoolean(line: Int, value: String)
    case invalidString(line: Int, value: String)
    case invalidArray(line: Int, value: String)
    case missingRequiredField(line: Int, field: String)
    case invalidItem(line: Int, reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidSyntax(let line, let content):
            return "第 \(line) 行语法无效: \(content)"
        case .unsupportedKey(let line, let key):
            return "第 \(line) 行包含不支持的字段: \(key)"
        case .invalidBoolean(let line, let value):
            return "第 \(line) 行布尔值无效: \(value)"
        case .invalidString(let line, let value):
            return "第 \(line) 行字符串无效: \(value)"
        case .invalidArray(let line, let value):
            return "第 \(line) 行数组无效: \(value)"
        case .missingRequiredField(let line, let field):
            return "第 \(line) 行缺少必填字段: \(field)"
        case .invalidItem(let line, let reason):
            return "第 \(line) 行的自定义项无效: \(reason)"
        }
    }
}
