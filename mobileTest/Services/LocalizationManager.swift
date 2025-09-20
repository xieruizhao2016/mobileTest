//
//  LocalizationManager.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

// MARK: - 支持的语言
enum SupportedLanguage: String, CaseIterable {
    case english = "en"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case arabic = "ar"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .russian: return "Русский"
        case .arabic: return "العربية"
        }
    }
    
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .chineseSimplified: return "简体中文"
        case .chineseTraditional: return "繁體中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .russian: return "Русский"
        case .arabic: return "العربية"
        }
    }
    
    var isRightToLeft: Bool {
        return self == .arabic
    }
}

// MARK: - 本地化键
enum LocalizationKey: String, CaseIterable {
    // MARK: - 通用消息
    case loading = "common.loading"
    case success = "common.success"
    case error = "common.error"
    case warning = "common.warning"
    case info = "common.info"
    case retry = "common.retry"
    case cancel = "common.cancel"
    case confirm = "common.confirm"
    case save = "common.save"
    case delete = "common.delete"
    case edit = "common.edit"
    case add = "common.add"
    case search = "common.search"
    case filter = "common.filter"
    case sort = "common.sort"
    case refresh = "common.refresh"
    case close = "common.close"
    case back = "common.back"
    case next = "common.next"
    case previous = "common.previous"
    case done = "common.done"
    case ok = "common.ok"
    case yes = "common.yes"
    case no = "common.no"
    
    // MARK: - 错误消息
    case errorGeneric = "error.generic"
    case errorNetwork = "error.network"
    case errorTimeout = "error.timeout"
    case errorUnauthorized = "error.unauthorized"
    case errorForbidden = "error.forbidden"
    case errorNotFound = "error.not_found"
    case errorServerError = "error.server_error"
    case errorValidation = "error.validation"
    case errorFileNotFound = "error.file_not_found"
    case errorFileAccessDenied = "error.file_access_denied"
    case errorFileCorrupted = "error.file_corrupted"
    case errorFileTooLarge = "error.file_too_large"
    case errorDiskSpaceInsufficient = "error.disk_space_insufficient"
    case errorDataCorrupted = "error.data_corrupted"
    case errorInvalidJSON = "error.invalid_json"
    case errorDecodingFailed = "error.decoding_failed"
    case errorEncodingFailed = "error.encoding_failed"
    case errorCacheError = "error.cache_error"
    case errorConfigurationError = "error.configuration_error"
    case errorPermissionDenied = "error.permission_denied"
    case errorResourceUnavailable = "error.resource_unavailable"
    case errorCompatibilityError = "error.compatibility_error"
    case errorInternalError = "error.internal_error"
    case errorUnexpectedError = "error.unexpected_error"
    case errorSystemError = "error.system_error"
    case errorNetworkTimeout = "error.network_timeout"
    case errorNetworkUnavailable = "error.network_unavailable"
    case errorDNSError = "error.dns_error"
    case errorInvalidURL = "error.invalid_url"
    case errorSSLError = "error.ssl_error"
    case errorAuthenticationFailed = "error.authentication_failed"
    case errorAuthorizationFailed = "error.authorization_failed"
    case errorServerErrorWithCode = "error.server_error_with_code"
    case errorDataExpired = "error.data_expired"
    case errorMissingConfiguration = "error.missing_configuration"
    case errorInvalidConfiguration = "error.invalid_configuration"
    case errorFileOperationTimeout = "error.file_operation_timeout"
    case errorFileLocked = "error.file_locked"
    case errorInvalidFilePath = "error.invalid_file_path"
    case errorEncodingError = "error.encoding_error"
    
    // MARK: - 业务相关消息
    case bookingDataLoaded = "booking.data_loaded"
    case bookingDataExpired = "booking.data_expired"
    case bookingDataInvalid = "booking.data_invalid"
    case bookingSegmentNotFound = "booking.segment_not_found"
    case bookingShipReferenceInvalid = "booking.ship_reference_invalid"
    case bookingDurationInvalid = "booking.duration_invalid"
    case bookingPriceInvalid = "booking.price_invalid"
    case bookingSeatsUnavailable = "booking.seats_unavailable"
    case bookingTimeConflict = "booking.time_conflict"
    case bookingRouteInvalid = "booking.route_invalid"
    
    // MARK: - 性能监控消息
    case performanceMetricRecorded = "performance.metric_recorded"
    case performanceStatisticsGenerated = "performance.statistics_generated"
    case performanceDataExported = "performance.data_exported"
    case performanceDataCleared = "performance.data_cleared"
    case performanceMemoryUsage = "performance.memory_usage"
    case performanceExecutionTime = "performance.execution_time"
    case performanceNetworkLatency = "performance.network_latency"
    case performanceCacheHitRate = "performance.cache_hit_rate"
    case performanceErrorRate = "performance.error_rate"
    case performanceThroughput = "performance.throughput"
    case performanceResponseSize = "performance.response_size"
    case performanceRetryCount = "performance.retry_count"
    case performanceValidationTime = "performance.validation_time"
    
    // MARK: - 数据验证消息
    case validationRequiredFieldMissing = "validation.required_field_missing"
    case validationInvalidFormat = "validation.invalid_format"
    case validationInvalidValue = "validation.invalid_value"
    case validationBusinessRuleViolation = "validation.business_rule_violation"
    case validationDataInconsistency = "validation.data_inconsistency"
    case validationConstraintViolation = "validation.constraint_violation"
    case validationDataCorruption = "validation.data_corruption"
    case validationReferenceIntegrity = "validation.reference_integrity"
    case validationDuplicateData = "validation.duplicate_data"
    case validationInvalidDate = "validation.invalid_date"
    case validationDateOutOfRange = "validation.date_out_of_range"
    case validationExpiredData = "validation.expired_data"
    case validationInvalidURL = "validation.invalid_url"
    case validationNetworkDataError = "validation.network_data_error"
    
    // MARK: - 重试机制消息
    case retryAttemptFailed = "retry.attempt_failed"
    case retryMaxAttemptsReached = "retry.max_attempts_reached"
    case retryExponentialBackoff = "retry.exponential_backoff"
    case retryLinearBackoff = "retry.linear_backoff"
    case retryFixedDelay = "retry.fixed_delay"
    case retryAdaptiveStrategy = "retry.adaptive_strategy"
    case retryNoRetry = "retry.no_retry"
    case retryDelayCalculated = "retry.delay_calculated"
    case retryStrategyChanged = "retry.strategy_changed"
    case retrySuccessAfterRetry = "retry.success_after_retry"
    
    // MARK: - 缓存消息
    case cacheHit = "cache.hit"
    case cacheMiss = "cache.miss"
    case cacheExpired = "cache.expired"
    case cacheInvalidated = "cache.invalidated"
    case cacheCleared = "cache.cleared"
    case cacheWarmedUp = "cache.warmed_up"
    case cacheStatisticsUpdated = "cache.statistics_updated"
    case cacheMemoryLimitReached = "cache.memory_limit_reached"
    case cacheItemEvicted = "cache.item_evicted"
    case cacheSizeExceeded = "cache.size_exceeded"
}

// MARK: - 本地化管理器协议
protocol LocalizationManagerProtocol {
    /// 获取当前语言
    var currentLanguage: SupportedLanguage { get }
    
    /// 设置当前语言
    /// - Parameter language: 要设置的语言
    func setLanguage(_ language: SupportedLanguage)
    
    /// 获取本地化字符串
    /// - Parameters:
    ///   - key: 本地化键
    ///   - arguments: 格式化参数
    /// - Returns: 本地化字符串
    func localizedString(for key: LocalizationKey, arguments: CVarArg...) -> String
    
    /// 获取本地化字符串（带默认值）
    /// - Parameters:
    ///   - key: 本地化键
    ///   - defaultValue: 默认值
    ///   - arguments: 格式化参数
    /// - Returns: 本地化字符串
    func localizedString(for key: LocalizationKey, defaultValue: String, arguments: CVarArg...) -> String
    
    /// 检查是否支持指定语言
    /// - Parameter language: 语言代码
    /// - Returns: 是否支持
    func isLanguageSupported(_ language: String) -> Bool
    
    /// 获取系统语言
    /// - Returns: 系统语言
    func getSystemLanguage() -> SupportedLanguage
    
    /// 获取可用语言列表
    /// - Returns: 可用语言列表
    func getAvailableLanguages() -> [SupportedLanguage]
}

// MARK: - 本地化管理器实现
class LocalizationManager: LocalizationManagerProtocol {
    
    private var currentLanguageCode: String
    private let bundle: Bundle
    private let enableVerboseLogging: Bool
    
    init(initialLanguage: SupportedLanguage? = nil, enableVerboseLogging: Bool = true) {
        self.bundle = Bundle.main
        self.enableVerboseLogging = enableVerboseLogging
        
        // 确定初始语言
        if let initialLanguage = initialLanguage {
            self.currentLanguageCode = initialLanguage.rawValue
        } else {
            self.currentLanguageCode = Self.detectSystemLanguage()
        }
        
        log("🌍 [LocalizationManager] 初始化，当前语言: \(currentLanguageCode)")
    }
    
    var currentLanguage: SupportedLanguage {
        return SupportedLanguage(rawValue: currentLanguageCode) ?? .english
    }
    
    func setLanguage(_ language: SupportedLanguage) {
        let oldLanguage = currentLanguageCode
        currentLanguageCode = language.rawValue
        log("🌍 [LocalizationManager] 语言已切换: \(oldLanguage) -> \(currentLanguageCode)")
        
        // 发送语言变更通知
        NotificationCenter.default.post(
            name: .languageDidChange,
            object: nil,
            userInfo: ["newLanguage": language, "oldLanguage": oldLanguage]
        )
    }
    
    func localizedString(for key: LocalizationKey, arguments: CVarArg...) -> String {
        return localizedString(for: key, defaultValue: key.rawValue, arguments: arguments)
    }
    
    func localizedString(for key: LocalizationKey, defaultValue: String, arguments: CVarArg...) -> String {
        let localizedString = getLocalizedString(for: key.rawValue, defaultValue: defaultValue)
        
        if arguments.isEmpty {
            return localizedString
        } else {
            return String(format: localizedString, arguments: arguments)
        }
    }
    
    func isLanguageSupported(_ language: String) -> Bool {
        return SupportedLanguage(rawValue: language) != nil
    }
    
    func getSystemLanguage() -> SupportedLanguage {
        let systemLanguageCode = Self.detectSystemLanguage()
        return SupportedLanguage(rawValue: systemLanguageCode) ?? .english
    }
    
    func getAvailableLanguages() -> [SupportedLanguage] {
        return SupportedLanguage.allCases
    }
    
    // MARK: - 私有方法
    
    private func getLocalizedString(for key: String, defaultValue: String) -> String {
        // 首先尝试从当前语言的bundle中获取
        let localizedString = bundle.localizedString(forKey: key, value: nil, table: nil)
        if localizedString != key {
            return localizedString
        }
        
        // 如果当前语言没有找到，尝试从英语bundle中获取
        if currentLanguageCode != "en" {
            if let englishBundle = getBundle(for: "en") {
                let englishLocalizedString = englishBundle.localizedString(forKey: key, value: nil, table: nil)
                if englishLocalizedString != key {
                    return englishLocalizedString
                }
            }
        }
        
        // 如果都没有找到，返回默认值
        if enableVerboseLogging {
            log("⚠️ [LocalizationManager] 未找到本地化字符串: \(key)，使用默认值: \(defaultValue)")
        }
        return defaultValue
    }
    
    private func getBundle(for languageCode: String) -> Bundle? {
        guard let path = bundle.path(forResource: languageCode, ofType: "lproj"),
              let languageBundle = Bundle(path: path) else {
            return nil
        }
        return languageBundle
    }
    
    private func log(_ message: String) {
        if enableVerboseLogging {
            print(message)
        }
    }
    
    private static func detectSystemLanguage() -> String {
        let preferredLanguages = Locale.preferredLanguages
        let systemLanguage = preferredLanguages.first ?? "en"
        
        // 提取语言代码（去掉地区代码）
        let languageCode = String(systemLanguage.prefix(2))
        
        // 检查是否支持该语言
        if SupportedLanguage(rawValue: languageCode) != nil {
            return languageCode
        }
        
        // 检查是否支持完整的语言代码
        if SupportedLanguage(rawValue: systemLanguage) != nil {
            return systemLanguage
        }
        
        // 默认返回英语
        return "en"
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - 本地化扩展
extension LocalizationManager {
    
    /// 获取错误消息的本地化字符串
    /// - Parameters:
    ///   - error: 错误类型
    ///   - context: 上下文信息
    /// - Returns: 本地化错误消息
    func localizedErrorMessage(for error: BookingDataError, context: String? = nil) -> String {
        let key: LocalizationKey
        
        switch error {
        case .fileNotFound:
            key = .errorFileNotFound
        case .fileAccessDenied:
            key = .errorFileAccessDenied
        case .fileCorrupted:
            key = .errorFileCorrupted
        case .fileTooLarge:
            key = .errorFileTooLarge
        case .fileSystemError:
            key = .errorGeneric
        case .diskSpaceInsufficient:
            key = .errorDiskSpaceInsufficient
        case .fileLocked:
            key = .errorFileLocked
        case .invalidFilePath:
            key = .errorInvalidFilePath
        case .fileOperationTimeout:
            key = .errorFileOperationTimeout
        case .networkError:
            key = .errorNetwork
        case .networkTimeout:
            key = .errorNetworkTimeout
        case .networkUnavailable:
            key = .errorNetworkUnavailable
        case .dnsError:
            key = .errorDNSError
        case .invalidURL:
            key = .errorInvalidURL
        case .sslError:
            key = .errorSSLError
        case .authenticationFailed:
            key = .errorAuthenticationFailed
        case .authorizationFailed:
            key = .errorAuthorizationFailed
        case .serverError:
            key = .errorServerError
        case .resourceUnavailable:
            key = .errorResourceUnavailable
        case .dataCorrupted:
            key = .errorDataCorrupted
        case .invalidJSON:
            key = .errorInvalidJSON
        case .decodingError:
            key = .errorDecodingFailed
        case .encodingError:
            key = .errorEncodingError
        case .cacheError:
            key = .errorCacheError
        case .configurationError:
            key = .errorConfigurationError
        case .permissionDenied:
            key = .errorPermissionDenied
        case .versionMismatch:
            key = .errorCompatibilityError
        case .unsupportedOperation:
            key = .errorCompatibilityError
        case .deprecatedAPI:
            key = .errorCompatibilityError
        case .internalError:
            key = .errorInternalError
        case .unexpectedError:
            key = .errorUnexpectedError
        case .systemError:
            key = .errorSystemError
        case .dataExpired:
            key = .errorDataExpired
        case .unsupportedDataFormat:
            key = .errorValidation
        case .cacheExpired:
            key = .errorCacheError
        case .cacheCorrupted:
            key = .errorDataCorrupted
        case .cacheFull:
            key = .errorCacheError
        case .cacheKeyNotFound:
            key = .errorCacheError
        case .resourceBusy:
            key = .errorResourceUnavailable
        case .resourceLimitExceeded:
            key = .errorResourceUnavailable
        case .missingConfiguration:
            key = .errorMissingConfiguration
        case .invalidConfiguration:
            key = .errorInvalidConfiguration
        }
        
        if let context = context {
            return localizedString(for: key, arguments: context)
        } else {
            return localizedString(for: key)
        }
    }
    
    /// 获取性能指标类型的本地化名称
    /// - Parameter metricType: 性能指标类型
    /// - Returns: 本地化名称
    func localizedName(for metricType: PerformanceMetricType) -> String {
        let key: LocalizationKey
        
        switch metricType {
        case .executionTime:
            key = .performanceExecutionTime
        case .memoryUsage:
            key = .performanceMemoryUsage
        case .cpuUsage:
            key = .performanceExecutionTime // 可以添加专门的CPU使用率键
        case .networkLatency:
            key = .performanceNetworkLatency
        case .cacheHitRate:
            key = .performanceCacheHitRate
        case .errorRate:
            key = .performanceErrorRate
        case .throughput:
            key = .performanceThroughput
        case .responseSize:
            key = .performanceResponseSize
        case .retryCount:
            key = .performanceRetryCount
        case .validationTime:
            key = .performanceValidationTime
        }
        
        return localizedString(for: key)
    }
    
    /// 获取验证错误消息的本地化字符串
    /// - Parameter validationError: 验证错误
    /// - Returns: 本地化错误消息
    func localizedValidationErrorMessage(for validationError: ValidationError) -> String {
        let key: LocalizationKey
        
        switch validationError.code {
        case .missingField:
            key = .validationRequiredFieldMissing
        case .invalidType, .invalidFormat:
            key = .validationInvalidFormat
        case .invalidValue:
            key = .validationInvalidValue
        case .businessRuleViolation:
            key = .validationBusinessRuleViolation
        case .dataInconsistency:
            key = .validationDataInconsistency
        case .constraintViolation:
            key = .validationConstraintViolation
        case .dataCorruption:
            key = .validationDataCorruption
        case .referenceIntegrity:
            key = .validationReferenceIntegrity
        case .duplicateData:
            key = .validationDuplicateData
        case .invalidDate:
            key = .validationInvalidDate
        case .dateOutOfRange:
            key = .validationDateOutOfRange
        case .expiredData:
            key = .validationExpiredData
        case .invalidURL:
            key = .validationInvalidURL
        case .networkDataError:
            key = .validationNetworkDataError
        }
        
        return localizedString(for: key, arguments: validationError.field, validationError.message)
    }
}

// MARK: - 本地化管理器工厂
enum LocalizationManagerFactory {
    /// 创建默认本地化管理器
    static func createDefault(enableVerboseLogging: Bool = true) -> LocalizationManagerProtocol {
        return LocalizationManager(enableVerboseLogging: enableVerboseLogging)
    }
    
    /// 创建指定语言的本地化管理器
    static func createWithLanguage(_ language: SupportedLanguage, enableVerboseLogging: Bool = true) -> LocalizationManagerProtocol {
        return LocalizationManager(initialLanguage: language, enableVerboseLogging: enableVerboseLogging)
    }
    
    /// 创建系统语言的本地化管理器
    static func createWithSystemLanguage(enableVerboseLogging: Bool = true) -> LocalizationManagerProtocol {
        let systemLanguage = LocalizationManager().getSystemLanguage()
        return LocalizationManager(initialLanguage: systemLanguage, enableVerboseLogging: enableVerboseLogging)
    }
}
