//
//  BookingModels.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

// MARK: - 主预订数据模型
struct BookingData: Codable {
    let shipReference: String
    let shipToken: String
    let canIssueTicketChecking: Bool
    let expiryTime: String
    let duration: Int
    let segments: [Segment]
    
    /// 检查数据是否过期
    var isExpired: Bool {
        guard let expiryTimestamp = Double(expiryTime) else { return true }
        let expiryDate = Date(timeIntervalSince1970: expiryTimestamp)
        return Date() > expiryDate
    }
    
    /// 获取格式化的过期时间
    var formattedExpiryTime: String {
        guard let expiryTimestamp = Double(expiryTime) else { return "未知" }
        let expiryDate = Date(timeIntervalSince1970: expiryTimestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: expiryDate)
    }
    
    /// 获取格式化的持续时间
    var formattedDuration: String {
        let hours = duration / 60
        let minutes = duration % 60
        return "\(hours)小时\(minutes)分钟"
    }
}

// MARK: - 航段数据模型
struct Segment: Codable, Identifiable {
    let id: Int
    let originAndDestinationPair: OriginDestinationPair
    
    /// 获取航段描述
    var description: String {
        return "\(originAndDestinationPair.origin.displayName) → \(originAndDestinationPair.destination.displayName)"
    }
}

// MARK: - 起终点对模型
struct OriginDestinationPair: Codable {
    let destination: Location
    let destinationCity: String
    let origin: Location
    let originCity: String
    
    /// 获取完整的路线描述
    var routeDescription: String {
        return "\(origin.displayName) (\(originCity)) → \(destination.displayName) (\(destinationCity))"
    }
}

// MARK: - 地点信息模型
struct Location: Codable {
    let code: String
    let displayName: String
    let url: String
    
    /// 获取格式化的地点信息
    var formattedInfo: String {
        return "\(displayName) (\(code))"
    }
}

// MARK: - 数据状态枚举
enum DataStatus: Equatable {
    case loading      // 加载中
    case loaded       // 已加载
    case expired      // 已过期
    case error(String) // 错误状态
}

// MARK: - 数据管理器错误类型
enum BookingDataError: Error, LocalizedError, Equatable {
    // MARK: - 文件系统错误
    case fileNotFound(String)                    // 文件不存在
    case fileAccessDenied(String)                // 文件访问权限不足
    case fileCorrupted(String)                   // 文件损坏
    case fileTooLarge(String)                    // 文件过大
    case fileSystemError(String)                 // 文件系统错误
    case diskSpaceInsufficient(String)           // 磁盘空间不足
    case fileLocked(String)                      // 文件被锁定
    case invalidFilePath(String)                 // 无效的文件路径
    case fileOperationTimeout(String)            // 文件操作超时
    
    // MARK: - 网络错误
    case networkError(String)                    // 通用网络错误
    case networkTimeout(String)                  // 网络超时
    case networkUnavailable(String)              // 网络不可用
    case serverError(Int, String)                // 服务器错误（状态码，消息）
    case invalidURL(String)                      // 无效的URL
    case sslError(String)                        // SSL/TLS错误
    case dnsError(String)                        // DNS解析错误
    
    // MARK: - 数据格式错误
    case invalidJSON(String)                     // JSON格式错误
    case dataCorrupted(String)                   // 数据损坏
    case dataExpired(String)                     // 数据过期
    case unsupportedDataFormat(String)           // 不支持的数据格式
    case encodingError(String)                   // 编码错误
    case decodingError(String)                   // 解码错误
    
    // MARK: - 缓存错误
    case cacheError(String)                      // 通用缓存错误
    case cacheExpired(String)                    // 缓存过期
    case cacheCorrupted(String)                  // 缓存损坏
    case cacheFull(String)                       // 缓存已满
    case cacheKeyNotFound(String)                // 缓存键不存在
    
    // MARK: - 配置错误
    case configurationError(String)              // 配置错误
    case invalidConfiguration(String)            // 无效配置
    case missingConfiguration(String)            // 缺少配置
    
    // MARK: - 权限错误
    case permissionDenied(String)                // 权限被拒绝
    case authenticationFailed(String)            // 认证失败
    case authorizationFailed(String)             // 授权失败
    
    // MARK: - 资源错误
    case resourceUnavailable(String)             // 资源不可用
    case resourceBusy(String)                    // 资源忙碌
    case resourceLimitExceeded(String)           // 资源限制超出
    
    // MARK: - 兼容性错误
    case versionMismatch(String)                 // 版本不匹配
    case unsupportedOperation(String)            // 不支持的操作
    case deprecatedAPI(String)                   // 已弃用的API
    
    // MARK: - 内部错误
    case internalError(String)                   // 内部错误
    case unexpectedError(String)                 // 意外错误
    case systemError(String)                     // 系统错误
    
    // MARK: - 错误描述
    var errorDescription: String? {
        let localizationManager = LocalizationManager()
        
        switch self {
        // 文件系统错误
        case .fileNotFound(let details):
            return localizationManager.localizedString(for: .errorFileNotFound, arguments: details)
        case .fileAccessDenied(let details):
            return localizationManager.localizedString(for: .errorFileAccessDenied, arguments: details)
        case .fileCorrupted(let details):
            return localizationManager.localizedString(for: .errorFileCorrupted, arguments: details)
        case .fileTooLarge(let details):
            return localizationManager.localizedString(for: .errorFileTooLarge, arguments: details)
        case .fileSystemError(let details):
            return localizationManager.localizedString(for: .errorSystemError, arguments: details)
        case .diskSpaceInsufficient(let details):
            return localizationManager.localizedString(for: .errorDiskSpaceInsufficient, arguments: details)
        case .fileLocked(let details):
            return localizationManager.localizedString(for: .errorFileLocked, arguments: details)
        case .invalidFilePath(let details):
            return localizationManager.localizedString(for: .errorInvalidFilePath, arguments: details)
        case .fileOperationTimeout(let details):
            return localizationManager.localizedString(for: .errorFileOperationTimeout, arguments: details)
            
        // 网络错误
        case .networkError(let details):
            return localizationManager.localizedString(for: .errorNetwork, arguments: details)
        case .networkTimeout(let details):
            return localizationManager.localizedString(for: .errorNetworkTimeout, arguments: details)
        case .networkUnavailable(let details):
            return localizationManager.localizedString(for: .errorNetworkUnavailable, arguments: details)
        case .serverError(let code, let details):
            return localizationManager.localizedString(for: .errorServerErrorWithCode, arguments: code, details)
        case .invalidURL(let details):
            return localizationManager.localizedString(for: .errorInvalidURL, arguments: details)
        case .sslError(let details):
            return localizationManager.localizedString(for: .errorSSLError, arguments: details)
        case .dnsError(let details):
            return localizationManager.localizedString(for: .errorDNSError, arguments: details)
            
        // 数据格式错误
        case .invalidJSON(let details):
            return localizationManager.localizedString(for: .errorInvalidJSON, arguments: details)
        case .dataCorrupted(let details):
            return localizationManager.localizedString(for: .errorDataCorrupted, arguments: details)
        case .dataExpired(let details):
            return localizationManager.localizedString(for: .errorDataExpired, arguments: details)
        case .unsupportedDataFormat(let details):
            return localizationManager.localizedString(for: .errorValidation, arguments: details)
        case .encodingError(let details):
            return localizationManager.localizedString(for: .errorEncodingError, arguments: details)
        case .decodingError(let details):
            return localizationManager.localizedString(for: .errorDecodingFailed, arguments: details)
            
        // 缓存错误
        case .cacheError(let details):
            return localizationManager.localizedString(for: .errorCacheError, arguments: details)
        case .cacheExpired(let details):
            return localizationManager.localizedString(for: .errorCacheError, arguments: details)
        case .cacheCorrupted(let details):
            return localizationManager.localizedString(for: .errorDataCorrupted, arguments: details)
        case .cacheFull(let details):
            return localizationManager.localizedString(for: .errorCacheError, arguments: details)
        case .cacheKeyNotFound(let details):
            return localizationManager.localizedString(for: .errorCacheError, arguments: details)
            
        // 配置错误
        case .configurationError(let details):
            return localizationManager.localizedString(for: .errorConfigurationError, arguments: details)
        case .invalidConfiguration(let details):
            return localizationManager.localizedString(for: .errorInvalidConfiguration, arguments: details)
        case .missingConfiguration(let details):
            return localizationManager.localizedString(for: .errorMissingConfiguration, arguments: details)
            
        // 权限错误
        case .permissionDenied(let details):
            return localizationManager.localizedString(for: .errorPermissionDenied, arguments: details)
        case .authenticationFailed(let details):
            return localizationManager.localizedString(for: .errorAuthenticationFailed, arguments: details)
        case .authorizationFailed(let details):
            return localizationManager.localizedString(for: .errorAuthorizationFailed, arguments: details)
            
        // 资源错误
        case .resourceUnavailable(let details):
            return localizationManager.localizedString(for: .errorResourceUnavailable, arguments: details)
        case .resourceBusy(let details):
            return localizationManager.localizedString(for: .errorResourceUnavailable, arguments: details)
        case .resourceLimitExceeded(let details):
            return localizationManager.localizedString(for: .errorResourceUnavailable, arguments: details)
            
        // 兼容性错误
        case .versionMismatch(let details):
            return localizationManager.localizedString(for: .errorCompatibilityError, arguments: details)
        case .unsupportedOperation(let details):
            return localizationManager.localizedString(for: .errorCompatibilityError, arguments: details)
        case .deprecatedAPI(let details):
            return localizationManager.localizedString(for: .errorCompatibilityError, arguments: details)
            
        // 内部错误
        case .internalError(let details):
            return localizationManager.localizedString(for: .errorInternalError, arguments: details)
        case .unexpectedError(let details):
            return localizationManager.localizedString(for: .errorUnexpectedError, arguments: details)
        case .systemError(let details):
            return localizationManager.localizedString(for: .errorSystemError, arguments: details)
        }
    }
    
    // MARK: - 错误分类
    var category: ErrorCategory {
        switch self {
        case .fileNotFound, .fileAccessDenied, .fileCorrupted, .fileTooLarge, 
             .fileSystemError, .diskSpaceInsufficient, .fileLocked, 
             .invalidFilePath, .fileOperationTimeout:
            return .fileSystem
        case .networkError, .networkTimeout, .networkUnavailable, .serverError, 
             .invalidURL, .sslError, .dnsError:
            return .network
        case .invalidJSON, .dataCorrupted, .dataExpired, .unsupportedDataFormat, 
             .encodingError, .decodingError:
            return .dataFormat
        case .cacheError, .cacheExpired, .cacheCorrupted, .cacheFull, .cacheKeyNotFound:
            return .cache
        case .configurationError, .invalidConfiguration, .missingConfiguration:
            return .configuration
        case .permissionDenied, .authenticationFailed, .authorizationFailed:
            return .permission
        case .resourceUnavailable, .resourceBusy, .resourceLimitExceeded:
            return .resource
        case .versionMismatch, .unsupportedOperation, .deprecatedAPI:
            return .compatibility
        case .internalError, .unexpectedError, .systemError:
            return .`internal`
        }
    }
    
    // MARK: - 错误严重程度
    var severity: ErrorSeverity {
        switch self {
        case .fileNotFound, .cacheKeyNotFound, .dataExpired, .cacheExpired:
            return .low
        case .fileAccessDenied, .permissionDenied, .authenticationFailed, 
             .authorizationFailed, .networkTimeout, .fileOperationTimeout:
            return .medium
        case .fileCorrupted, .dataCorrupted, .cacheCorrupted, .diskSpaceInsufficient, 
             .fileSystemError, .systemError, .internalError:
            return .high
        case .unexpectedError, .sslError, .serverError:
            return .critical
        default:
            return .medium
        }
    }
    
    // MARK: - 是否可重试
    var isRetryable: Bool {
        switch self {
        case .networkTimeout, .networkUnavailable, .fileOperationTimeout, 
             .resourceBusy, .fileLocked, .serverError:
            return true
        case .fileNotFound, .fileAccessDenied, .fileCorrupted, .dataCorrupted, 
             .invalidJSON, .permissionDenied, .authenticationFailed:
            return false
        default:
            return false
        }
    }
}

// MARK: - 错误分类枚举
enum ErrorCategory: String, CaseIterable {
    case fileSystem = "文件系统"
    case network = "网络"
    case dataFormat = "数据格式"
    case cache = "缓存"
    case configuration = "配置"
    case permission = "权限"
    case resource = "资源"
    case compatibility = "兼容性"
    case `internal` = "内部"
}

// MARK: - 错误严重程度枚举
enum ErrorSeverity: String, CaseIterable {
    case low = "低"
    case medium = "中"
    case high = "高"
    case critical = "严重"
    
    var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}
