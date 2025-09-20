//
//  ErrorHandler.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

/// 错误处理工具类
struct ErrorHandler {
    
    /// 记录错误并根据详细日志设置决定是否打印
    static func logError(_ error: BookingDataError, context: String, enableVerboseLogging: Bool) {
        if enableVerboseLogging {
            let localizationManager = LocalizationManager()
            let retryText = error.isRetryable ? 
                localizationManager.localizedString(for: .yes) : 
                localizationManager.localizedString(for: .no)
            print("❌ [\(context)] \(localizationManager.localizedString(for: .error)): \(error.localizedDescription) (分类: \(error.category.rawValue), 严重程度: \(error.severity.rawValue), 可重试: \(retryText))")
        }
    }
    
    /// 处理网络相关的URLError并映射到BookingDataError
    static func handleNetworkError(_ error: Error, url: String) -> BookingDataError {
        let localizationManager = LocalizationManager()
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .networkTimeout(localizationManager.localizedString(for: .errorNetworkTimeout, arguments: url))
            case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
                return .networkUnavailable(localizationManager.localizedString(for: .errorNetworkUnavailable, arguments: url))
            case .cannotFindHost, .cannotConnectToHost:
                return .dnsError(localizationManager.localizedString(for: .errorDNSError, arguments: url))
            case .badURL:
                return .invalidURL(localizationManager.localizedString(for: .errorInvalidURL, arguments: url))
            case .cancelled:
                return .networkError(localizationManager.localizedString(for: .errorNetwork, arguments: url))
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot:
                return .sslError(localizationManager.localizedString(for: .errorSSLError, arguments: url))
            default:
                return .networkError(localizationManager.localizedString(for: .errorNetwork, arguments: "\(urlError.code.rawValue): \(urlError.localizedDescription) - \(url)"))
            }
        }
        
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .networkTimeout(localizationManager.localizedString(for: .errorNetworkTimeout, arguments: url))
            case NSURLErrorNotConnectedToInternet:
                return .networkUnavailable(localizationManager.localizedString(for: .errorNetworkUnavailable, arguments: url))
            case NSURLErrorCannotFindHost:
                return .dnsError(localizationManager.localizedString(for: .errorDNSError, arguments: url))
            case NSURLErrorCannotConnectToHost:
                return .networkError(localizationManager.localizedString(for: .errorNetwork, arguments: url))
            case NSURLErrorBadURL:
                return .invalidURL(localizationManager.localizedString(for: .errorInvalidURL, arguments: url))
            default:
                return .networkError(localizationManager.localizedString(for: .errorNetwork, arguments: "\(nsError.code): \(url)"))
            }
        }
        
        return .networkError(localizationManager.localizedString(for: .errorNetwork, arguments: "\(error.localizedDescription) - \(url)"))
    }
    
    /// 处理HTTP状态码并映射到BookingDataError
    static func handleHTTPStatusCode(_ statusCode: Int, url: String) -> BookingDataError {
        let localizationManager = LocalizationManager()
        
        switch statusCode {
        case 200...299:
            return .networkError(localizationManager.localizedString(for: .errorServerErrorWithCode, arguments: statusCode, url))
        case 400:
            return .serverError(statusCode, localizationManager.localizedString(for: .errorServerError, arguments: url))
        case 401:
            return .authenticationFailed(localizationManager.localizedString(for: .errorAuthenticationFailed, arguments: url))
        case 403:
            return .authorizationFailed(localizationManager.localizedString(for: .errorAuthorizationFailed, arguments: url))
        case 404:
            return .fileNotFound(localizationManager.localizedString(for: .errorFileNotFound, arguments: url))
        case 408:
            return .networkTimeout(localizationManager.localizedString(for: .errorNetworkTimeout, arguments: url))
        case 500...599:
            return .serverError(statusCode, localizationManager.localizedString(for: .errorServerError, arguments: url))
        default:
            return .networkError(localizationManager.localizedString(for: .errorServerErrorWithCode, arguments: statusCode, url))
        }
    }
    
    /// 处理文件系统相关的错误并映射到BookingDataError
    static func handleFileSystemError(_ error: Error, filePath: String) -> BookingDataError {
        let nsError = error as NSError
        let localizationManager = LocalizationManager()
        
        // 处理Cocoa错误域
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileReadNoSuchFileError, NSFileReadCorruptFileError:
                return .fileNotFound(localizationManager.localizedString(for: .errorFileNotFound, arguments: filePath))
            case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                return .fileAccessDenied(localizationManager.localizedString(for: .errorFileAccessDenied, arguments: filePath))
            case NSFileWriteOutOfSpaceError:
                return .diskSpaceInsufficient(localizationManager.localizedString(for: .errorDiskSpaceInsufficient, arguments: filePath))
            case NSFileWriteVolumeReadOnlyError:
                return .fileAccessDenied(localizationManager.localizedString(for: .errorFileAccessDenied, arguments: filePath))
            case NSFileReadUnknownError, NSFileWriteUnknownError:
                return .fileSystemError(localizationManager.localizedString(for: .errorSystemError, arguments: "\(filePath) - \(nsError.localizedDescription)"))
            case NSFileLockingError:
                return .fileLocked(localizationManager.localizedString(for: .errorFileLocked, arguments: filePath))
            case NSFileReadInapplicableStringEncodingError, NSFileWriteInapplicableStringEncodingError:
                return .encodingError(localizationManager.localizedString(for: .errorEncodingError, arguments: filePath))
            default:
                return .fileSystemError(localizationManager.localizedString(for: .errorSystemError, arguments: "\(nsError.code): \(filePath) - \(nsError.localizedDescription)"))
            }
        }
        
        // 处理POSIX错误域
        if nsError.domain == NSPOSIXErrorDomain {
            let posixCode = Int32(nsError.code)
            switch posixCode {
            case ENOENT:
                return .fileNotFound(localizationManager.localizedString(for: .errorFileNotFound, arguments: filePath))
            case EACCES, EPERM:
                return .fileAccessDenied(localizationManager.localizedString(for: .errorFileAccessDenied, arguments: filePath))
            case ENOSPC:
                return .diskSpaceInsufficient(localizationManager.localizedString(for: .errorDiskSpaceInsufficient, arguments: filePath))
            case ETIMEDOUT:
                return .fileOperationTimeout(localizationManager.localizedString(for: .errorFileOperationTimeout, arguments: filePath))
            default:
                return .fileSystemError(localizationManager.localizedString(for: .errorSystemError, arguments: "\(posixCode): \(filePath) - \(nsError.localizedDescription)"))
            }
        }
        
        // 处理URL错误域
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorFileDoesNotExist:
                return .fileNotFound(localizationManager.localizedString(for: .errorFileNotFound, arguments: filePath))
            case NSURLErrorNoPermissionsToReadFile:
                return .fileAccessDenied(localizationManager.localizedString(for: .errorFileAccessDenied, arguments: filePath))
            default:
                return .fileSystemError(localizationManager.localizedString(for: .errorSystemError, arguments: "\(nsError.code): \(filePath) - \(nsError.localizedDescription)"))
            }
        }
        
        // 默认处理
        if nsError.localizedDescription.contains("timed out") {
            return .fileOperationTimeout(localizationManager.localizedString(for: .errorFileOperationTimeout, arguments: filePath))
        }
        
        return .fileSystemError(localizationManager.localizedString(for: .errorSystemError, arguments: "\(nsError.domain):\(nsError.code): \(filePath) - \(nsError.localizedDescription)"))
    }
    
    /// 处理JSON解码错误并映射到BookingDataError
    static func handleDecodingError(_ error: Error) -> BookingDataError {
        let localizationManager = LocalizationManager()
        
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .dataCorrupted(let context):
                return .dataCorrupted(localizationManager.localizedString(for: .errorDataCorrupted, arguments: context.debugDescription))
            case .keyNotFound(let key, let context):
                return .invalidJSON(localizationManager.localizedString(for: .errorInvalidJSON, arguments: "缺少键 '\(key.stringValue)': \(context.debugDescription)"))
            case .valueNotFound(let type, let context):
                return .invalidJSON(localizationManager.localizedString(for: .errorInvalidJSON, arguments: "缺少值 '\(type)': \(context.debugDescription)"))
            case .typeMismatch(let type, let context):
                return .invalidJSON(localizationManager.localizedString(for: .errorInvalidJSON, arguments: "类型不匹配 '\(type)': \(context.debugDescription)"))
            @unknown default:
                return .decodingError(localizationManager.localizedString(for: .errorDecodingFailed, arguments: decodingError.localizedDescription))
            }
        } else {
            return .decodingError(localizationManager.localizedString(for: .errorDecodingFailed, arguments: error.localizedDescription))
        }
    }
    
    /// 处理缓存错误并映射到BookingDataError
    static func handleCacheError(_ error: Error, key: String? = nil) -> BookingDataError {
        let localizationManager = LocalizationManager()
        
        // 可以在这里添加更具体的缓存错误判断逻辑
        if let bookingError = error as? BookingDataError {
            return bookingError // 如果已经是BookingDataError，直接返回
        }
        
        let details = key != nil ? "键: \(key!) - \(error.localizedDescription)" : error.localizedDescription
        return .cacheError(localizationManager.localizedString(for: .errorCacheError, arguments: details))
    }
    
    /// 处理通用错误并映射到BookingDataError
    static func handleGenericError(_ error: Error, context: String) -> BookingDataError {
        let localizationManager = LocalizationManager()
        
        if let bookingError = error as? BookingDataError {
            return bookingError
        }
        
        let nsError = error as NSError
        // 尝试根据NSError的domain和code进行更细致的分类
        if nsError.domain == NSURLErrorDomain {
            return handleNetworkError(error, url: context)
        } else if nsError.domain == NSCocoaErrorDomain {
            // 针对文件操作的CocoaError
            return handleFileSystemError(nsError, filePath: context)
        }
        
        return .unexpectedError(localizationManager.localizedString(for: .errorUnexpectedError, arguments: "在 \(context) 发生意外错误: \(error.localizedDescription)"))
    }
}