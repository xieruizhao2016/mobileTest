//
//  VersionManager.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

// MARK: - 版本信息结构
struct VersionInfo {
    let major: Int
    let minor: Int
    let patch: Int
    let build: String?
    let releaseDate: Date?
    let description: String?
    
    var versionString: String {
        if let build = build {
            return "\(major).\(minor).\(patch).\(build)"
        } else {
            return "\(major).\(minor).\(patch)"
        }
    }
    
    var shortVersion: String {
        return "\(major).\(minor).\(patch)"
    }
    
    var isStable: Bool {
        return patch == 0 && (build?.isEmpty ?? true)
    }
    
    var isDevelopment: Bool {
        return !isStable
    }
}

// MARK: - 版本兼容性级别
enum CompatibilityLevel {
    case compatible        // 完全兼容
    case backwardCompatible // 向后兼容
    case forwardCompatible  // 向前兼容
    case incompatible      // 不兼容
    case unknown          // 未知兼容性
    
    var displayName: String {
        switch self {
        case .compatible:
            return "完全兼容"
        case .backwardCompatible:
            return "向后兼容"
        case .forwardCompatible:
            return "向前兼容"
        case .incompatible:
            return "不兼容"
        case .unknown:
            return "未知"
        }
    }
    
    var isSupported: Bool {
        switch self {
        case .compatible, .backwardCompatible, .forwardCompatible:
            return true
        case .incompatible, .unknown:
            return false
        }
    }
}

// MARK: - 数据迁移结果
struct MigrationResult {
    let success: Bool
    let migratedData: Data?
    let sourceVersion: VersionInfo
    let targetVersion: VersionInfo
    let migrationSteps: [MigrationStep]
    let warnings: [String]
    let errors: [String]
    
    var isSuccessful: Bool {
        return success && errors.isEmpty
    }
    
    var hasWarnings: Bool {
        return !warnings.isEmpty
    }
}

// MARK: - 迁移步骤
struct MigrationStep {
    let fromVersion: VersionInfo
    let toVersion: VersionInfo
    let description: String
    let migrationFunction: (Data) throws -> Data
    let isRequired: Bool
    let estimatedTime: TimeInterval
    
    init(fromVersion: VersionInfo, toVersion: VersionInfo, description: String, migrationFunction: @escaping (Data) throws -> Data, isRequired: Bool = true, estimatedTime: TimeInterval = 0.1) {
        self.fromVersion = fromVersion
        self.toVersion = toVersion
        self.description = description
        self.migrationFunction = migrationFunction
        self.isRequired = isRequired
        self.estimatedTime = estimatedTime
    }
}

// MARK: - 版本策略
enum VersionStrategy {
    case strict          // 严格模式：只支持当前版本
    case backwardCompatible // 向后兼容：支持当前版本和旧版本
    case forwardCompatible  // 向前兼容：支持当前版本和新版本
    case flexible        // 灵活模式：支持所有兼容版本
    case autoMigrate     // 自动迁移：自动迁移到当前版本
    
    var displayName: String {
        switch self {
        case .strict:
            return "严格模式"
        case .backwardCompatible:
            return "向后兼容"
        case .forwardCompatible:
            return "向前兼容"
        case .flexible:
            return "灵活模式"
        case .autoMigrate:
            return "自动迁移"
        }
    }
}

// MARK: - 版本管理器协议
protocol VersionManagerProtocol {
    /// 获取当前支持的版本
    var currentVersion: VersionInfo { get }
    
    /// 获取支持的最低版本
    var minimumSupportedVersion: VersionInfo { get }
    
    /// 获取支持的最高版本
    var maximumSupportedVersion: VersionInfo { get }
    
    /// 获取版本策略
    var versionStrategy: VersionStrategy { get }
    
    /// 检测数据格式版本
    /// - Parameter data: 要检测的数据
    /// - Returns: 版本信息，如果无法检测则返回nil
    func detectVersion(from data: Data) -> VersionInfo?
    
    /// 检查版本兼容性
    /// - Parameters:
    ///   - sourceVersion: 源版本
    ///   - targetVersion: 目标版本
    /// - Returns: 兼容性级别
    func checkCompatibility(sourceVersion: VersionInfo, targetVersion: VersionInfo) -> CompatibilityLevel
    
    /// 检查版本是否支持
    /// - Parameter version: 要检查的版本
    /// - Returns: 是否支持
    func isVersionSupported(_ version: VersionInfo) -> Bool
    
    /// 迁移数据到目标版本
    /// - Parameters:
    ///   - data: 要迁移的数据
    ///   - targetVersion: 目标版本
    /// - Returns: 迁移结果
    func migrateData(_ data: Data, to targetVersion: VersionInfo) async throws -> MigrationResult
    
    /// 获取迁移路径
    /// - Parameters:
    ///   - fromVersion: 源版本
    ///   - toVersion: 目标版本
    /// - Returns: 迁移步骤列表
    func getMigrationPath(from fromVersion: VersionInfo, to toVersion: VersionInfo) -> [MigrationStep]
    
    /// 验证数据格式
    /// - Parameters:
    ///   - data: 要验证的数据
    ///   - version: 版本信息
    /// - Returns: 验证结果
    func validateDataFormat(_ data: Data, for version: VersionInfo) async -> Bool
    
    /// 获取版本历史
    /// - Returns: 版本历史列表
    func getVersionHistory() -> [VersionInfo]
    
    /// 注册迁移步骤
    /// - Parameter step: 迁移步骤
    func registerMigrationStep(_ step: MigrationStep)
}

// MARK: - 版本管理器实现
class VersionManager: VersionManagerProtocol {
    
    // MARK: - 属性
    private let enableVerboseLogging: Bool
    private var migrationSteps: [String: MigrationStep] = [:]
    private var versionHistory: [VersionInfo] = []
    
    // MARK: - 版本信息
    let currentVersion: VersionInfo
    let minimumSupportedVersion: VersionInfo
    let maximumSupportedVersion: VersionInfo
    let versionStrategy: VersionStrategy
    
    // MARK: - 初始化器
    
    init(
        currentVersion: VersionInfo,
        minimumSupportedVersion: VersionInfo,
        maximumSupportedVersion: VersionInfo,
        versionStrategy: VersionStrategy = .autoMigrate,
        enableVerboseLogging: Bool = false
    ) {
        self.currentVersion = currentVersion
        self.minimumSupportedVersion = minimumSupportedVersion
        self.maximumSupportedVersion = maximumSupportedVersion
        self.versionStrategy = versionStrategy
        self.enableVerboseLogging = enableVerboseLogging
        
        // 初始化版本历史
        self.versionHistory = [
            VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: Date(timeIntervalSince1970: 1609459200), description: "初始版本"),
            VersionInfo(major: 1, minor: 1, patch: 0, build: nil, releaseDate: Date(timeIntervalSince1970: 1640995200), description: "添加航段信息"),
            VersionInfo(major: 1, minor: 2, patch: 0, build: nil, releaseDate: Date(timeIntervalSince1970: 1672531200), description: "添加价格信息"),
            VersionInfo(major: 2, minor: 0, patch: 0, build: nil, releaseDate: Date(timeIntervalSince1970: 1704067200), description: "重构数据格式"),
            currentVersion
        ]
        
        // 注册默认迁移步骤
        registerDefaultMigrationSteps()
    }
    
    // MARK: - 版本检测
    
    func detectVersion(from data: Data) -> VersionInfo? {
        log("🔍 [VersionManager] 开始检测数据格式版本...")
        
        do {
            // 尝试解析JSON数据
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                log("❌ [VersionManager] 无法解析JSON数据")
                return nil
            }
            
            // 检查版本字段
            if let versionString = json["version"] as? String {
                log("📋 [VersionManager] 检测到版本字段: \(versionString)")
                return parseVersionString(versionString)
            }
            
            // 检查schemaVersion字段
            if let schemaVersion = json["schemaVersion"] as? String {
                log("📋 [VersionManager] 检测到schema版本字段: \(schemaVersion)")
                return parseVersionString(schemaVersion)
            }
            
            // 检查数据格式特征来推断版本
            let inferredVersion = inferVersionFromData(json)
            if let version = inferredVersion {
                log("🔍 [VersionManager] 根据数据特征推断版本: \(version.versionString)")
                return version
            }
            
            log("⚠️ [VersionManager] 无法检测数据版本，使用默认版本")
            return minimumSupportedVersion
            
        } catch {
            log("❌ [VersionManager] 版本检测失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - 兼容性检查
    
    func checkCompatibility(sourceVersion: VersionInfo, targetVersion: VersionInfo) -> CompatibilityLevel {
        log("🔍 [VersionManager] 检查版本兼容性: \(sourceVersion.versionString) -> \(targetVersion.versionString)")
        
        // 相同版本
        if sourceVersion.major == targetVersion.major &&
           sourceVersion.minor == targetVersion.minor &&
           sourceVersion.patch == targetVersion.patch {
            return .compatible
        }
        
        // 主版本号不同
        if sourceVersion.major != targetVersion.major {
            // 检查是否有迁移路径
            if hasMigrationPath(from: sourceVersion, to: targetVersion) {
                return .backwardCompatible
            } else {
                return .incompatible
            }
        }
        
        // 次版本号不同
        if sourceVersion.minor != targetVersion.minor {
            if sourceVersion.minor < targetVersion.minor {
                return .forwardCompatible
            } else {
                return .backwardCompatible
            }
        }
        
        // 补丁版本号不同
        if sourceVersion.patch != targetVersion.patch {
            if sourceVersion.patch < targetVersion.patch {
                return .forwardCompatible
            } else {
                return .backwardCompatible
            }
        }
        
        return .unknown
    }
    
    func isVersionSupported(_ version: VersionInfo) -> Bool {
        let compatibility = checkCompatibility(sourceVersion: version, targetVersion: currentVersion)
        return compatibility.isSupported
    }
    
    // MARK: - 数据迁移
    
    func migrateData(_ data: Data, to targetVersion: VersionInfo) async throws -> MigrationResult {
        log("🔄 [VersionManager] 开始数据迁移到版本: \(targetVersion.versionString)")
        
        guard let sourceVersion = detectVersion(from: data) else {
            throw BookingDataError.versionMismatch("无法检测源数据版本")
        }
        
        log("📋 [VersionManager] 源版本: \(sourceVersion.versionString), 目标版本: \(targetVersion.versionString)")
        
        // 检查是否需要迁移
        if sourceVersion.major == targetVersion.major &&
           sourceVersion.minor == targetVersion.minor &&
           sourceVersion.patch == targetVersion.patch {
            log("✅ [VersionManager] 版本相同，无需迁移")
            return MigrationResult(
                success: true,
                migratedData: data,
                sourceVersion: sourceVersion,
                targetVersion: targetVersion,
                migrationSteps: [],
                warnings: [],
                errors: []
            )
        }
        
        // 获取迁移路径
        let migrationPath = getMigrationPath(from: sourceVersion, to: targetVersion)
        
        if migrationPath.isEmpty {
            throw BookingDataError.versionMismatch("没有可用的迁移路径从 \(sourceVersion.versionString) 到 \(targetVersion.versionString)")
        }
        
        log("🛤️ [VersionManager] 找到迁移路径，包含 \(migrationPath.count) 个步骤")
        
        var currentData = data
        var warnings: [String] = []
        var errors: [String] = []
        
        // 执行迁移步骤
        for (index, step) in migrationPath.enumerated() {
            log("🔄 [VersionManager] 执行迁移步骤 \(index + 1)/\(migrationPath.count): \(step.description)")
            
            do {
                currentData = try step.migrationFunction(currentData)
                log("✅ [VersionManager] 迁移步骤 \(index + 1) 完成")
            } catch {
                let errorMessage = "迁移步骤 \(index + 1) 失败: \(error.localizedDescription)"
                log("❌ [VersionManager] \(errorMessage)")
                
                if step.isRequired {
                    errors.append(errorMessage)
                } else {
                    warnings.append(errorMessage)
                }
            }
        }
        
        let success = errors.isEmpty
        log(success ? "✅ [VersionManager] 数据迁移成功" : "❌ [VersionManager] 数据迁移失败")
        
        return MigrationResult(
            success: success,
            migratedData: success ? currentData : nil,
            sourceVersion: sourceVersion,
            targetVersion: targetVersion,
            migrationSteps: migrationPath,
            warnings: warnings,
            errors: errors
        )
    }
    
    func getMigrationPath(from fromVersion: VersionInfo, to toVersion: VersionInfo) -> [MigrationStep] {
        var path: [MigrationStep] = []
        var currentVersion = fromVersion
        
        // 简单的迁移路径算法：逐步升级到目标版本
        while currentVersion.major != toVersion.major ||
              currentVersion.minor != toVersion.minor ||
              currentVersion.patch != toVersion.patch {
            
            let nextVersion = getNextVersion(from: currentVersion, to: toVersion)
            let stepKey = "\(currentVersion.versionString)->\(nextVersion.versionString)"
            
            if let step = migrationSteps[stepKey] {
                path.append(step)
                currentVersion = nextVersion
            } else {
                // 没有找到迁移步骤，尝试直接迁移
                if let directStep = migrationSteps["\(fromVersion.versionString)->\(toVersion.versionString)"] {
                    path.append(directStep)
                    break
                } else {
                    break
                }
            }
        }
        
        return path
    }
    
    // MARK: - 数据验证
    
    func validateDataFormat(_ data: Data, for version: VersionInfo) async -> Bool {
        log("🔍 [VersionManager] 验证数据格式，版本: \(version.versionString)")
        
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                log("❌ [VersionManager] 数据不是有效的JSON格式")
                return false
            }
            
            // 根据版本验证数据格式
            switch version.major {
            case 1:
                return validateV1Format(json)
            case 2:
                return validateV2Format(json)
            default:
                log("⚠️ [VersionManager] 未知的主版本号: \(version.major)")
                return false
            }
            
        } catch {
            log("❌ [VersionManager] 数据验证失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 版本历史
    
    func getVersionHistory() -> [VersionInfo] {
        return versionHistory
    }
    
    // MARK: - 迁移步骤注册
    
    func registerMigrationStep(_ step: MigrationStep) {
        let key = "\(step.fromVersion.versionString)->\(step.toVersion.versionString)"
        migrationSteps[key] = step
        log("📝 [VersionManager] 注册迁移步骤: \(key)")
    }
    
    // MARK: - 私有方法
    
    private func parseVersionString(_ versionString: String) -> VersionInfo? {
        let components = versionString.components(separatedBy: ".")
        
        guard components.count >= 3 else {
            return nil
        }
        
        guard let major = Int(components[0]),
              let minor = Int(components[1]),
              let patch = Int(components[2]) else {
            return nil
        }
        
        let build = components.count > 3 ? components[3] : nil
        
        return VersionInfo(
            major: major,
            minor: minor,
            patch: patch,
            build: build,
            releaseDate: nil,
            description: nil
        )
    }
    
    private func inferVersionFromData(_ json: [String: Any]) -> VersionInfo? {
        // 根据数据字段推断版本
        if json["segments"] != nil && json["shipReference"] != nil {
            // 包含航段信息，可能是1.1+版本
            if json["pricing"] != nil {
                return VersionInfo(major: 1, minor: 2, patch: 0, build: nil, releaseDate: nil, description: "推断版本")
            } else {
                return VersionInfo(major: 1, minor: 1, patch: 0, build: nil, releaseDate: nil, description: "推断版本")
            }
        } else if json["shipReference"] != nil {
            // 只有基本信息，可能是1.0版本
            return VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: "推断版本")
        }
        
        return nil
    }
    
    private func hasMigrationPath(from fromVersion: VersionInfo, to toVersion: VersionInfo) -> Bool {
        let path = getMigrationPath(from: fromVersion, to: toVersion)
        return !path.isEmpty
    }
    
    private func getNextVersion(from currentVersion: VersionInfo, to targetVersion: VersionInfo) -> VersionInfo {
        // 简单的版本升级策略
        if currentVersion.major < targetVersion.major {
            return VersionInfo(major: currentVersion.major + 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
        } else if currentVersion.minor < targetVersion.minor {
            return VersionInfo(major: currentVersion.major, minor: currentVersion.minor + 1, patch: 0, build: nil, releaseDate: nil, description: nil)
        } else if currentVersion.patch < targetVersion.patch {
            return VersionInfo(major: currentVersion.major, minor: currentVersion.minor, patch: currentVersion.patch + 1, build: nil, releaseDate: nil, description: nil)
        }
        
        return targetVersion
    }
    
    private func validateV1Format(_ json: [String: Any]) -> Bool {
        // 验证v1格式的基本字段
        guard json["shipReference"] != nil else {
            return false
        }
        
        // 检查可选字段
        if let segments = json["segments"] as? [[String: Any]] {
            for segment in segments {
                guard segment["id"] != nil else {
                    return false
                }
            }
        }
        
        return true
    }
    
    private func validateV2Format(_ json: [String: Any]) -> Bool {
        // 验证v2格式的基本字段
        guard json["shipReference"] != nil,
              json["metadata"] != nil else {
            return false
        }
        
        return true
    }
    
    private func registerDefaultMigrationSteps() {
        // 注册默认的迁移步骤
        let v1_0_to_v1_1 = MigrationStep(
            fromVersion: VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil),
            toVersion: VersionInfo(major: 1, minor: 1, patch: 0, build: nil, releaseDate: nil, description: nil),
            description: "添加航段信息支持",
            migrationFunction: { data in
                // 简单的迁移：添加空的segments数组
                var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                if json["segments"] == nil {
                    json["segments"] = []
                }
                return try JSONSerialization.data(withJSONObject: json)
            }
        )
        
        let v1_1_to_v1_2 = MigrationStep(
            fromVersion: VersionInfo(major: 1, minor: 1, patch: 0, build: nil, releaseDate: nil, description: nil),
            toVersion: VersionInfo(major: 1, minor: 2, patch: 0, build: nil, releaseDate: nil, description: nil),
            description: "添加价格信息支持",
            migrationFunction: { data in
                // 简单的迁移：添加价格信息
                var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                if json["pricing"] == nil {
                    json["pricing"] = ["totalPrice": 0, "currency": "USD"]
                }
                return try JSONSerialization.data(withJSONObject: json)
            }
        )
        
        let v1_2_to_v2_0 = MigrationStep(
            fromVersion: VersionInfo(major: 1, minor: 2, patch: 0, build: nil, releaseDate: nil, description: nil),
            toVersion: VersionInfo(major: 2, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil),
            description: "重构数据格式",
            migrationFunction: { data in
                // 复杂的迁移：重构整个数据格式
                var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                
                // 添加元数据
                json["metadata"] = [
                    "version": "2.0.0",
                    "createdAt": ISO8601DateFormatter().string(from: Date()),
                    "migratedFrom": "1.2.0"
                ]
                
                return try JSONSerialization.data(withJSONObject: json)
            }
        )
        
        registerMigrationStep(v1_0_to_v1_1)
        registerMigrationStep(v1_1_to_v1_2)
        registerMigrationStep(v1_2_to_v2_0)
    }
    
    // MARK: - 日志方法
    
    private func log(_ message: String) {
        if enableVerboseLogging {
            print(message)
        }
    }
}

// MARK: - 空版本管理器（用于禁用版本控制）
class EmptyVersionManager: VersionManagerProtocol {
    
    let currentVersion: VersionInfo
    let minimumSupportedVersion: VersionInfo
    let maximumSupportedVersion: VersionInfo
    let versionStrategy: VersionStrategy = .strict
    
    init() {
        self.currentVersion = VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: "默认版本")
        self.minimumSupportedVersion = self.currentVersion
        self.maximumSupportedVersion = self.currentVersion
    }
    
    func detectVersion(from data: Data) -> VersionInfo? {
        return currentVersion
    }
    
    func checkCompatibility(sourceVersion: VersionInfo, targetVersion: VersionInfo) -> CompatibilityLevel {
        return sourceVersion.major == targetVersion.major && 
               sourceVersion.minor == targetVersion.minor && 
               sourceVersion.patch == targetVersion.patch ? .compatible : .incompatible
    }
    
    func isVersionSupported(_ version: VersionInfo) -> Bool {
        return version.major == currentVersion.major && 
               version.minor == currentVersion.minor && 
               version.patch == currentVersion.patch
    }
    
    func migrateData(_ data: Data, to targetVersion: VersionInfo) async throws -> MigrationResult {
        throw BookingDataError.unsupportedOperation("版本控制功能已禁用")
    }
    
    func getMigrationPath(from fromVersion: VersionInfo, to toVersion: VersionInfo) -> [MigrationStep] {
        return []
    }
    
    func validateDataFormat(_ data: Data, for version: VersionInfo) async -> Bool {
        return true
    }
    
    func getVersionHistory() -> [VersionInfo] {
        return [currentVersion]
    }
    
    func registerMigrationStep(_ step: MigrationStep) {
        // 空实现
    }
}

// MARK: - 版本管理器工厂
class VersionManagerFactory {
    
    static func createDefault(enableVerboseLogging: Bool = false) -> VersionManagerProtocol {
        let currentVersion = VersionInfo(
            major: 2,
            minor: 0,
            patch: 0,
            build: nil,
            releaseDate: Date(),
            description: "当前版本"
        )
        
        let minimumVersion = VersionInfo(
            major: 1,
            minor: 0,
            patch: 0,
            build: nil,
            releaseDate: nil,
            description: "最低支持版本"
        )
        
        let maximumVersion = VersionInfo(
            major: 2,
            minor: 0,
            patch: 0,
            build: nil,
            releaseDate: nil,
            description: "最高支持版本"
        )
        
        return VersionManager(
            currentVersion: currentVersion,
            minimumSupportedVersion: minimumVersion,
            maximumSupportedVersion: maximumVersion,
            versionStrategy: .autoMigrate,
            enableVerboseLogging: enableVerboseLogging
        )
    }
    
    static func createDisabled() -> VersionManagerProtocol {
        return EmptyVersionManager()
    }
    
    static func createCustom(
        currentVersion: VersionInfo,
        minimumSupportedVersion: VersionInfo,
        maximumSupportedVersion: VersionInfo,
        versionStrategy: VersionStrategy = .autoMigrate,
        enableVerboseLogging: Bool = false
    ) -> VersionManagerProtocol {
        return VersionManager(
            currentVersion: currentVersion,
            minimumSupportedVersion: minimumSupportedVersion,
            maximumSupportedVersion: maximumSupportedVersion,
            versionStrategy: versionStrategy,
            enableVerboseLogging: enableVerboseLogging
        )
    }
}
