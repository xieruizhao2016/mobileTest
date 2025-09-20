//
//  VersionControlTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

class VersionControlTests: XCTestCase {
    
    var versionManager: VersionManager!
    var bookingService: BookingService!
    
    override func setUp() {
        super.setUp()
        
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
        
        versionManager = VersionManager(
            currentVersion: currentVersion,
            minimumSupportedVersion: minimumVersion,
            maximumSupportedVersion: maximumVersion,
            versionStrategy: .autoMigrate,
            enableVerboseLogging: true
        )
        
        let configuration = BookingServiceConfigurationFactory.createWithVersionControl(
            fileName: "booking",
            versionControlLevel: .full,
            versionStrategy: .autoMigrate,
            autoMigrateData: true
        )
        
        bookingService = BookingService(configuration: configuration)
    }
    
    override func tearDown() {
        versionManager = nil
        bookingService = nil
        super.tearDown()
    }
    
    // MARK: - VersionInfo Tests
    
    func testVersionInfoProperties() {
        let version = VersionInfo(
            major: 2,
            minor: 1,
            patch: 3,
            build: "beta",
            releaseDate: Date(),
            description: "测试版本"
        )
        
        XCTAssertEqual(version.major, 2)
        XCTAssertEqual(version.minor, 1)
        XCTAssertEqual(version.patch, 3)
        XCTAssertEqual(version.build, "beta")
        XCTAssertEqual(version.versionString, "2.1.3.beta")
        XCTAssertEqual(version.shortVersion, "2.1.3")
        XCTAssertFalse(version.isStable)
        XCTAssertTrue(version.isDevelopment)
    }
    
    func testVersionInfoStableVersion() {
        let version = VersionInfo(
            major: 2,
            minor: 0,
            patch: 0,
            build: nil,
            releaseDate: Date(),
            description: "稳定版本"
        )
        
        XCTAssertTrue(version.isStable)
        XCTAssertFalse(version.isDevelopment)
        XCTAssertEqual(version.versionString, "2.0.0")
    }
    
    // MARK: - CompatibilityLevel Tests
    
    func testCompatibilityLevel() {
        XCTAssertEqual(CompatibilityLevel.compatible.displayName, "完全兼容")
        XCTAssertEqual(CompatibilityLevel.backwardCompatible.displayName, "向后兼容")
        XCTAssertEqual(CompatibilityLevel.forwardCompatible.displayName, "向前兼容")
        XCTAssertEqual(CompatibilityLevel.incompatible.displayName, "不兼容")
        XCTAssertEqual(CompatibilityLevel.unknown.displayName, "未知")
        
        XCTAssertTrue(CompatibilityLevel.compatible.isSupported)
        XCTAssertTrue(CompatibilityLevel.backwardCompatible.isSupported)
        XCTAssertTrue(CompatibilityLevel.forwardCompatible.isSupported)
        XCTAssertFalse(CompatibilityLevel.incompatible.isSupported)
        XCTAssertFalse(CompatibilityLevel.unknown.isSupported)
    }
    
    // MARK: - VersionManager Tests
    
    func testVersionDetection() {
        // 测试带版本字段的JSON数据
        let jsonData = """
        {
            "version": "1.2.0",
            "shipReference": "TEST123",
            "segments": []
        }
        """.data(using: .utf8)!
        
        let detectedVersion = versionManager.detectVersion(from: jsonData)
        XCTAssertNotNil(detectedVersion)
        XCTAssertEqual(detectedVersion?.major, 1)
        XCTAssertEqual(detectedVersion?.minor, 2)
        XCTAssertEqual(detectedVersion?.patch, 0)
    }
    
    func testVersionDetectionWithSchemaVersion() {
        // 测试带schemaVersion字段的JSON数据
        let jsonData = """
        {
            "schemaVersion": "2.0.0",
            "shipReference": "TEST123",
            "metadata": {}
        }
        """.data(using: .utf8)!
        
        let detectedVersion = versionManager.detectVersion(from: jsonData)
        XCTAssertNotNil(detectedVersion)
        XCTAssertEqual(detectedVersion?.major, 2)
        XCTAssertEqual(detectedVersion?.minor, 0)
        XCTAssertEqual(detectedVersion?.patch, 0)
    }
    
    func testVersionDetectionFromDataFeatures() {
        // 测试根据数据特征推断版本
        let v1Data = """
        {
            "shipReference": "TEST123"
        }
        """.data(using: .utf8)!
        
        let detectedVersion = versionManager.detectVersion(from: v1Data)
        XCTAssertNotNil(detectedVersion)
        // 应该推断为1.0版本
        XCTAssertEqual(detectedVersion?.major, 1)
        XCTAssertEqual(detectedVersion?.minor, 0)
    }
    
    func testVersionCompatibilityCheck() {
        let v1_0 = VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
        let v1_1 = VersionInfo(major: 1, minor: 1, patch: 0, build: nil, releaseDate: nil, description: nil)
        let v2_0 = VersionInfo(major: 2, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
        
        // 相同版本
        XCTAssertEqual(versionManager.checkCompatibility(sourceVersion: v1_0, targetVersion: v1_0), .compatible)
        
        // 次版本号升级
        XCTAssertEqual(versionManager.checkCompatibility(sourceVersion: v1_0, targetVersion: v1_1), .forwardCompatible)
        XCTAssertEqual(versionManager.checkCompatibility(sourceVersion: v1_1, targetVersion: v1_0), .backwardCompatible)
        
        // 主版本号不同
        XCTAssertEqual(versionManager.checkCompatibility(sourceVersion: v1_0, targetVersion: v2_0), .backwardCompatible)
    }
    
    func testVersionSupportCheck() {
        let supportedVersion = VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
        let unsupportedVersion = VersionInfo(major: 3, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
        
        XCTAssertTrue(versionManager.isVersionSupported(supportedVersion))
        XCTAssertFalse(versionManager.isVersionSupported(unsupportedVersion))
    }
    
    func testDataMigration() async throws {
        let v1Data = """
        {
            "shipReference": "TEST123"
        }
        """.data(using: .utf8)!
        
        let targetVersion = VersionInfo(major: 1, minor: 1, patch: 0, build: nil, releaseDate: nil, description: nil)
        
        let result = try await versionManager.migrateData(v1Data, to: targetVersion)
        
        XCTAssertTrue(result.isSuccessful)
        XCTAssertEqual(result.sourceVersion.major, 1)
        XCTAssertEqual(result.sourceVersion.minor, 0)
        XCTAssertEqual(result.targetVersion.major, 1)
        XCTAssertEqual(result.targetVersion.minor, 1)
        XCTAssertNotNil(result.migratedData)
    }
    
    func testDataValidation() async {
        let validV1Data = """
        {
            "shipReference": "TEST123"
        }
        """.data(using: .utf8)!
        
        let invalidData = """
        {
            "invalidField": "test"
        }
        """.data(using: .utf8)!
        
        let v1Version = VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
        
        let isValidV1 = await versionManager.validateDataFormat(validV1Data, for: v1Version)
        XCTAssertTrue(isValidV1)
        
        let isValidInvalid = await versionManager.validateDataFormat(invalidData, for: v1Version)
        XCTAssertFalse(isValidInvalid)
    }
    
    func testVersionHistory() {
        let history = versionManager.getVersionHistory()
        XCTAssertFalse(history.isEmpty)
        XCTAssertTrue(history.contains { $0.major == 1 && $0.minor == 0 && $0.patch == 0 })
        XCTAssertTrue(history.contains { $0.major == 2 && $0.minor == 0 && $0.patch == 0 })
    }
    
    func testMigrationStepRegistration() {
        let step = MigrationStep(
            fromVersion: VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil),
            toVersion: VersionInfo(major: 1, minor: 1, patch: 0, build: nil, releaseDate: nil, description: nil),
            description: "测试迁移步骤",
            migrationFunction: { data in
                return data // 简单的迁移：返回相同数据
            }
        )
        
        versionManager.registerMigrationStep(step)
        
        // 验证迁移步骤已注册
        let migrationPath = versionManager.getMigrationPath(
            from: VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil),
            to: VersionInfo(major: 1, minor: 1, patch: 0, build: nil, releaseDate: nil, description: nil)
        )
        
        XCTAssertFalse(migrationPath.isEmpty)
    }
    
    // MARK: - VersionStrategy Tests
    
    func testVersionStrategy() {
        let strategies: [VersionStrategy] = [.strict, .backwardCompatible, .forwardCompatible, .flexible, .autoMigrate]
        
        for strategy in strategies {
            XCTAssertFalse(strategy.displayName.isEmpty)
        }
        
        XCTAssertEqual(VersionStrategy.strict.displayName, "严格模式")
        XCTAssertEqual(VersionStrategy.backwardCompatible.displayName, "向后兼容")
        XCTAssertEqual(VersionStrategy.forwardCompatible.displayName, "向前兼容")
        XCTAssertEqual(VersionStrategy.flexible.displayName, "灵活模式")
        XCTAssertEqual(VersionStrategy.autoMigrate.displayName, "自动迁移")
    }
    
    // MARK: - MigrationResult Tests
    
    func testMigrationResult() {
        let sourceVersion = VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
        let targetVersion = VersionInfo(major: 1, minor: 1, patch: 0, build: nil, releaseDate: nil, description: nil)
        
        let successfulResult = MigrationResult(
            success: true,
            migratedData: "test".data(using: .utf8),
            sourceVersion: sourceVersion,
            targetVersion: targetVersion,
            migrationSteps: [],
            warnings: ["测试警告"],
            errors: []
        )
        
        XCTAssertTrue(successfulResult.isSuccessful)
        XCTAssertTrue(successfulResult.hasWarnings)
        XCTAssertFalse(successfulResult.errors.isEmpty == false)
        
        let failedResult = MigrationResult(
            success: false,
            migratedData: nil,
            sourceVersion: sourceVersion,
            targetVersion: targetVersion,
            migrationSteps: [],
            warnings: [],
            errors: ["测试错误"]
        )
        
        XCTAssertFalse(failedResult.isSuccessful)
        XCTAssertFalse(failedResult.hasWarnings)
    }
    
    // MARK: - BookingService Version Control Tests
    
    func testBookingServiceVersionDetection() {
        let jsonData = """
        {
            "version": "1.2.0",
            "shipReference": "TEST123"
        }
        """.data(using: .utf8)!
        
        let detectedVersion = bookingService.detectDataVersion(from: jsonData)
        XCTAssertNotNil(detectedVersion)
        XCTAssertEqual(detectedVersion?.major, 1)
        XCTAssertEqual(detectedVersion?.minor, 2)
    }
    
    func testBookingServiceVersionCompatibility() {
        let v1_0 = VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
        let v2_0 = VersionInfo(major: 2, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
        
        let compatibility = bookingService.checkVersionCompatibility(sourceVersion: v1_0, targetVersion: v2_0)
        XCTAssertTrue(compatibility.isSupported)
    }
    
    func testBookingServiceDataMigration() async throws {
        let v1Data = """
        {
            "shipReference": "TEST123"
        }
        """.data(using: .utf8)!
        
        let targetVersion = VersionInfo(major: 1, minor: 1, patch: 0, build: nil, releaseDate: nil, description: nil)
        
        let result = try await bookingService.migrateData(v1Data, to: targetVersion)
        
        XCTAssertTrue(result.isSuccessful)
        XCTAssertNotNil(result.migratedData)
    }
    
    func testBookingServiceVersionHistory() {
        let history = bookingService.getVersionHistory()
        XCTAssertFalse(history.isEmpty)
    }
    
    func testBookingServiceVersionControlDisabled() async {
        let disabledConfiguration = BookingServiceConfigurationFactory.createTest(fileName: "booking")
        let disabledService = BookingService(configuration: disabledConfiguration)
        
        do {
            let testData = "test".data(using: .utf8)!
            let targetVersion = VersionInfo(major: 2, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
            _ = try await disabledService.migrateData(testData, to: targetVersion)
            XCTFail("禁用版本控制时应该抛出错误")
        } catch let error as BookingDataError {
            XCTAssertEqual(error, BookingDataError.unsupportedOperation("版本控制功能已禁用"))
        } catch {
            XCTFail("应该抛出BookingDataError.unsupportedOperation错误")
        }
    }
    
    // MARK: - VersionControlLevel Tests
    
    func testVersionControlLevel() {
        let levels: [VersionControlLevel] = [.full, .basic, .disabled]
        
        for level in levels {
            XCTAssertFalse(level.rawValue.isEmpty)
        }
        
        XCTAssertEqual(VersionControlLevel.full.rawValue, "完整")
        XCTAssertEqual(VersionControlLevel.basic.rawValue, "基础")
        XCTAssertEqual(VersionControlLevel.disabled.rawValue, "禁用")
    }
    
    // MARK: - VersionManagerFactory Tests
    
    func testVersionManagerFactory() {
        let defaultManager = VersionManagerFactory.createDefault()
        XCTAssertNotNil(defaultManager)
        XCTAssertEqual(defaultManager.currentVersion.major, 2)
        
        let disabledManager = VersionManagerFactory.createDisabled()
        XCTAssertNotNil(disabledManager)
        
        let customVersion = VersionInfo(major: 3, minor: 0, patch: 0, build: nil, releaseDate: nil, description: "自定义版本")
        let customManager = VersionManagerFactory.createCustom(
            currentVersion: customVersion,
            minimumSupportedVersion: customVersion,
            maximumSupportedVersion: customVersion,
            versionStrategy: .strict
        )
        XCTAssertNotNil(customManager)
        XCTAssertEqual(customManager.currentVersion.major, 3)
    }
    
    // MARK: - Error Handling Tests
    
    func testVersionDetectionError() {
        let invalidData = "invalid json".data(using: .utf8)!
        let detectedVersion = versionManager.detectVersion(from: invalidData)
        XCTAssertNil(detectedVersion)
    }
    
    func testMigrationError() async {
        let invalidData = "invalid json".data(using: .utf8)!
        let targetVersion = VersionInfo(major: 2, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
        
        do {
            _ = try await versionManager.migrateData(invalidData, to: targetVersion)
            XCTFail("无效数据迁移应该抛出错误")
        } catch {
            XCTAssertTrue(error is BookingDataError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testVersionDetectionPerformance() throws {
        let jsonData = """
        {
            "version": "1.2.0",
            "shipReference": "TEST123",
            "segments": []
        }
        """.data(using: .utf8)!
        
        self.measure {
            for _ in 0..<1000 {
                _ = versionManager.detectVersion(from: jsonData)
            }
        }
    }
    
    func testCompatibilityCheckPerformance() throws {
        let v1_0 = VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
        let v2_0 = VersionInfo(major: 2, minor: 0, patch: 0, build: nil, releaseDate: nil, description: nil)
        
        self.measure {
            for _ in 0..<1000 {
                _ = versionManager.checkCompatibility(sourceVersion: v1_0, targetVersion: v2_0)
            }
        }
    }
}

// MARK: - Mock Version Manager for Testing
class MockVersionManager: VersionManagerProtocol {
    
    var shouldDetectVersion = true
    var detectedVersion: VersionInfo = VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: "模拟版本")
    var shouldMigrate = true
    var shouldValidate = true
    
    let currentVersion: VersionInfo = VersionInfo(major: 2, minor: 0, patch: 0, build: nil, releaseDate: nil, description: "当前版本")
    let minimumSupportedVersion: VersionInfo = VersionInfo(major: 1, minor: 0, patch: 0, build: nil, releaseDate: nil, description: "最低版本")
    let maximumSupportedVersion: VersionInfo = VersionInfo(major: 2, minor: 0, patch: 0, build: nil, releaseDate: nil, description: "最高版本")
    let versionStrategy: VersionStrategy = .autoMigrate
    
    func detectVersion(from data: Data) -> VersionInfo? {
        return shouldDetectVersion ? detectedVersion : nil
    }
    
    func checkCompatibility(sourceVersion: VersionInfo, targetVersion: VersionInfo) -> CompatibilityLevel {
        if sourceVersion.major == targetVersion.major && sourceVersion.minor == targetVersion.minor && sourceVersion.patch == targetVersion.patch {
            return .compatible
        } else if sourceVersion.major < targetVersion.major {
            return .forwardCompatible
        } else {
            return .backwardCompatible
        }
    }
    
    func isVersionSupported(_ version: VersionInfo) -> Bool {
        return version.major >= minimumSupportedVersion.major && version.major <= maximumSupportedVersion.major
    }
    
    func migrateData(_ data: Data, to targetVersion: VersionInfo) async throws -> MigrationResult {
        if shouldMigrate {
            return MigrationResult(
                success: true,
                migratedData: data,
                sourceVersion: detectedVersion,
                targetVersion: targetVersion,
                migrationSteps: [],
                warnings: [],
                errors: []
            )
        } else {
            throw BookingDataError.versionMismatch("模拟迁移失败")
        }
    }
    
    func getMigrationPath(from fromVersion: VersionInfo, to toVersion: VersionInfo) -> [MigrationStep] {
        return []
    }
    
    func validateDataFormat(_ data: Data, for version: VersionInfo) async -> Bool {
        return shouldValidate
    }
    
    func getVersionHistory() -> [VersionInfo] {
        return [minimumSupportedVersion, currentVersion]
    }
    
    func registerMigrationStep(_ step: MigrationStep) {
        // 空实现
    }
}
