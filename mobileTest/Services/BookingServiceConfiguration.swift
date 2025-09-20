//
//  BookingServiceConfiguration.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

// MARK: - 数据验证严格程度
enum ValidationStrictness: String, CaseIterable {
    case strict = "严格"
    case normal = "标准"
    case lenient = "宽松"
    case disabled = "禁用"
}

// MARK: - 性能监控详细程度
enum PerformanceMonitoringLevel: String, CaseIterable {
    case detailed = "详细"
    case standard = "标准"
    case minimal = "最小"
    case disabled = "禁用"
}

// MARK: - 预订服务配置协议
protocol BookingServiceConfigurationProtocol {
    /// 数据文件名（不包含扩展名）
    var fileName: String { get }
    
    /// 文件扩展名
    var fileExtension: String { get }
    
    /// 是否启用详细日志
    var enableVerboseLogging: Bool { get }
    
    /// 网络请求超时时间（秒）
    var requestTimeout: TimeInterval { get }
    
    /// 是否启用缓存
    var enableCaching: Bool { get }
    
    /// 缓存过期时间（秒）
    var cacheExpirationTime: TimeInterval { get }
    
    /// 最大重试次数
    var maxRetryAttempts: Int { get }
    
    /// 重试延迟时间（秒）
    var retryDelay: TimeInterval { get }
    
    /// 重试配置
    var retryConfiguration: RetryConfiguration { get }
    
    /// 是否启用数据验证
    var enableDataValidation: Bool { get }
    
    /// 数据验证严格程度
    var validationStrictness: ValidationStrictness { get }
    
    /// 是否启用性能监控
    var enablePerformanceMonitoring: Bool { get }
    
    /// 性能监控详细程度
    var performanceMonitoringLevel: PerformanceMonitoringLevel { get }
}

// MARK: - 默认配置实现
struct DefaultBookingServiceConfiguration: BookingServiceConfigurationProtocol {
    let fileName: String
    let fileExtension: String
    let enableVerboseLogging: Bool
    let requestTimeout: TimeInterval
    let enableCaching: Bool
    let cacheExpirationTime: TimeInterval
    let maxRetryAttempts: Int
    let retryDelay: TimeInterval
    let retryConfiguration: RetryConfiguration
    let enableDataValidation: Bool
    let validationStrictness: ValidationStrictness
    let enablePerformanceMonitoring: Bool
    let performanceMonitoringLevel: PerformanceMonitoringLevel
    
    /// 默认初始化器
    init(
        fileName: String = "booking",
        fileExtension: String = "json",
        enableVerboseLogging: Bool = true,
        requestTimeout: TimeInterval = 30.0,
        enableCaching: Bool = true,
        cacheExpirationTime: TimeInterval = 300.0, // 5分钟
        maxRetryAttempts: Int = 3,
        retryDelay: TimeInterval = 1.0,
        retryConfiguration: RetryConfiguration = .default,
        enableDataValidation: Bool = true,
        validationStrictness: ValidationStrictness = .normal,
        enablePerformanceMonitoring: Bool = true,
        performanceMonitoringLevel: PerformanceMonitoringLevel = .standard
    ) {
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.enableVerboseLogging = enableVerboseLogging
        self.requestTimeout = requestTimeout
        self.enableCaching = enableCaching
        self.cacheExpirationTime = cacheExpirationTime
        self.maxRetryAttempts = maxRetryAttempts
        self.retryDelay = retryDelay
        self.retryConfiguration = retryConfiguration
        self.enableDataValidation = enableDataValidation
        self.validationStrictness = validationStrictness
        self.enablePerformanceMonitoring = enablePerformanceMonitoring
        self.performanceMonitoringLevel = performanceMonitoringLevel
    }
}

// MARK: - 生产环境配置
struct ProductionBookingServiceConfiguration: BookingServiceConfigurationProtocol {
    let fileName: String = "booking"
    let fileExtension: String = "json"
    let enableVerboseLogging: Bool = false
    let requestTimeout: TimeInterval = 15.0
    let enableCaching: Bool = true
    let cacheExpirationTime: TimeInterval = 600.0 // 10分钟
    let maxRetryAttempts: Int = 2
    let retryDelay: TimeInterval = 2.0
    let retryConfiguration: RetryConfiguration = .conservative
    let enableDataValidation: Bool = true
    let validationStrictness: ValidationStrictness = .strict
    let enablePerformanceMonitoring: Bool = true
    let performanceMonitoringLevel: PerformanceMonitoringLevel = .detailed
}

// MARK: - 测试环境配置
struct TestBookingServiceConfiguration: BookingServiceConfigurationProtocol {
    let fileName: String
    let fileExtension: String = "json"
    let enableVerboseLogging: Bool = true
    let requestTimeout: TimeInterval = 5.0
    let enableCaching: Bool = false
    let cacheExpirationTime: TimeInterval = 60.0
    let maxRetryAttempts: Int = 1
    let retryDelay: TimeInterval = 0.5
    let retryConfiguration: RetryConfiguration = .fast
    let enableDataValidation: Bool = false
    let validationStrictness: ValidationStrictness = .disabled
    let enablePerformanceMonitoring: Bool = false
    let performanceMonitoringLevel: PerformanceMonitoringLevel = .disabled
    
    init(fileName: String = "booking") {
        self.fileName = fileName
    }
}

// MARK: - 配置工厂
enum BookingServiceConfigurationFactory {
    /// 创建默认配置
    static func createDefault() -> BookingServiceConfigurationProtocol {
        return DefaultBookingServiceConfiguration()
    }
    
    /// 创建生产环境配置
    static func createProduction() -> BookingServiceConfigurationProtocol {
        return ProductionBookingServiceConfiguration()
    }
    
    /// 创建测试环境配置
    static func createTest(fileName: String = "booking") -> BookingServiceConfigurationProtocol {
        return TestBookingServiceConfiguration(fileName: fileName)
    }
    
    /// 创建自定义配置
    static func createCustom(
        fileName: String,
        fileExtension: String = "json",
        enableVerboseLogging: Bool = true,
        requestTimeout: TimeInterval = 30.0,
        enableCaching: Bool = true,
        cacheExpirationTime: TimeInterval = 300.0,
        maxRetryAttempts: Int = 3,
        retryDelay: TimeInterval = 1.0,
        retryConfiguration: RetryConfiguration = .default,
        enableDataValidation: Bool = true,
        validationStrictness: ValidationStrictness = .normal,
        enablePerformanceMonitoring: Bool = true,
        performanceMonitoringLevel: PerformanceMonitoringLevel = .standard
    ) -> BookingServiceConfigurationProtocol {
        return DefaultBookingServiceConfiguration(
            fileName: fileName,
            fileExtension: fileExtension,
            enableVerboseLogging: enableVerboseLogging,
            requestTimeout: requestTimeout,
            enableCaching: enableCaching,
            cacheExpirationTime: cacheExpirationTime,
            maxRetryAttempts: maxRetryAttempts,
            retryDelay: retryDelay,
            retryConfiguration: retryConfiguration,
            enableDataValidation: enableDataValidation,
            validationStrictness: validationStrictness,
            enablePerformanceMonitoring: enablePerformanceMonitoring,
            performanceMonitoringLevel: performanceMonitoringLevel
        )
    }
}
