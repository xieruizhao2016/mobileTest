//
//  ErrorClassificationTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

// MARK: - 错误分类测试
@MainActor
class ErrorClassificationTests: XCTestCase {
    
    // MARK: - 错误分类测试
    
    func testFileSystemErrorClassification() {
        // Given: 文件系统错误
        let fileNotFoundError = BookingDataError.fileNotFound("test.json")
        let fileAccessDeniedError = BookingDataError.fileAccessDenied("/protected/file.json")
        let fileCorruptedError = BookingDataError.fileCorrupted("damaged.json")
        let diskSpaceError = BookingDataError.diskSpaceInsufficient("/full/disk")
        
        // When & Then: 验证错误分类
        XCTAssertEqual(fileNotFoundError.category, .fileSystem)
        XCTAssertEqual(fileAccessDeniedError.category, .fileSystem)
        XCTAssertEqual(fileCorruptedError.category, .fileSystem)
        XCTAssertEqual(diskSpaceError.category, .fileSystem)
    }
    
    func testNetworkErrorClassification() {
        // Given: 网络错误
        let networkError = BookingDataError.networkError("连接失败")
        let timeoutError = BookingDataError.networkTimeout("请求超时")
        let serverError = BookingDataError.serverError(500, "内部服务器错误")
        let sslError = BookingDataError.sslError("证书验证失败")
        
        // When & Then: 验证错误分类
        XCTAssertEqual(networkError.category, .network)
        XCTAssertEqual(timeoutError.category, .network)
        XCTAssertEqual(serverError.category, .network)
        XCTAssertEqual(sslError.category, .network)
    }
    
    func testDataFormatErrorClassification() {
        // Given: 数据格式错误
        let jsonError = BookingDataError.invalidJSON("格式错误")
        let dataCorruptedError = BookingDataError.dataCorrupted("数据损坏")
        let encodingError = BookingDataError.encodingError("编码失败")
        
        // When & Then: 验证错误分类
        XCTAssertEqual(jsonError.category, .dataFormat)
        XCTAssertEqual(dataCorruptedError.category, .dataFormat)
        XCTAssertEqual(encodingError.category, .dataFormat)
    }
    
    func testCacheErrorClassification() {
        // Given: 缓存错误
        let cacheError = BookingDataError.cacheError("缓存失败")
        let cacheExpiredError = BookingDataError.cacheExpired("缓存过期")
        let cacheFullError = BookingDataError.cacheFull("缓存已满")
        
        // When & Then: 验证错误分类
        XCTAssertEqual(cacheError.category, .cache)
        XCTAssertEqual(cacheExpiredError.category, .cache)
        XCTAssertEqual(cacheFullError.category, .cache)
    }
    
    // MARK: - 错误严重程度测试
    
    func testErrorSeverityLevels() {
        // Given: 不同严重程度的错误
        let lowSeverityError = BookingDataError.fileNotFound("test.json")
        let mediumSeverityError = BookingDataError.fileAccessDenied("protected.json")
        let highSeverityError = BookingDataError.fileCorrupted("damaged.json")
        let criticalSeverityError = BookingDataError.unexpectedError("系统崩溃")
        
        // When & Then: 验证严重程度
        XCTAssertEqual(lowSeverityError.severity, .low)
        XCTAssertEqual(mediumSeverityError.severity, .medium)
        XCTAssertEqual(highSeverityError.severity, .high)
        XCTAssertEqual(criticalSeverityError.severity, .critical)
    }
    
    func testErrorSeverityPriority() {
        // Given: 错误严重程度
        let low = ErrorSeverity.low
        let medium = ErrorSeverity.medium
        let high = ErrorSeverity.high
        let critical = ErrorSeverity.critical
        
        // When & Then: 验证优先级
        XCTAssertLessThan(low.priority, medium.priority)
        XCTAssertLessThan(medium.priority, high.priority)
        XCTAssertLessThan(high.priority, critical.priority)
    }
    
    // MARK: - 错误重试性测试
    
    func testRetryableErrors() {
        // Given: 可重试的错误
        let timeoutError = BookingDataError.networkTimeout("请求超时")
        let networkUnavailableError = BookingDataError.networkUnavailable("网络不可用")
        let fileOperationTimeoutError = BookingDataError.fileOperationTimeout("文件操作超时")
        let resourceBusyError = BookingDataError.resourceBusy("资源忙碌")
        
        // When & Then: 验证可重试性
        XCTAssertTrue(timeoutError.isRetryable)
        XCTAssertTrue(networkUnavailableError.isRetryable)
        XCTAssertTrue(fileOperationTimeoutError.isRetryable)
        XCTAssertTrue(resourceBusyError.isRetryable)
    }
    
    func testNonRetryableErrors() {
        // Given: 不可重试的错误
        let fileNotFoundError = BookingDataError.fileNotFound("文件不存在")
        let fileAccessDeniedError = BookingDataError.fileAccessDenied("访问被拒绝")
        let fileCorruptedError = BookingDataError.fileCorrupted("文件损坏")
        let invalidJSONError = BookingDataError.invalidJSON("JSON格式错误")
        
        // When & Then: 验证不可重试性
        XCTAssertFalse(fileNotFoundError.isRetryable)
        XCTAssertFalse(fileAccessDeniedError.isRetryable)
        XCTAssertFalse(fileCorruptedError.isRetryable)
        XCTAssertFalse(invalidJSONError.isRetryable)
    }
    
    // MARK: - 错误描述测试
    
    func testErrorDescriptions() {
        // Given: 不同类型的错误
        let fileNotFoundError = BookingDataError.fileNotFound("test.json")
        let networkTimeoutError = BookingDataError.networkTimeout("请求超时")
        let serverError = BookingDataError.serverError(404, "资源未找到")
        let invalidJSONError = BookingDataError.invalidJSON("格式错误")
        
        // When & Then: 验证错误描述
        XCTAssertTrue(fileNotFoundError.localizedDescription.contains("文件未找到"))
        XCTAssertTrue(fileNotFoundError.localizedDescription.contains("test.json"))
        
        XCTAssertTrue(networkTimeoutError.localizedDescription.contains("网络超时"))
        XCTAssertTrue(networkTimeoutError.localizedDescription.contains("请求超时"))
        
        XCTAssertTrue(serverError.localizedDescription.contains("服务器错误"))
        XCTAssertTrue(serverError.localizedDescription.contains("404"))
        XCTAssertTrue(serverError.localizedDescription.contains("资源未找到"))
        
        XCTAssertTrue(invalidJSONError.localizedDescription.contains("JSON格式错误"))
        XCTAssertTrue(invalidJSONError.localizedDescription.contains("格式错误"))
    }
    
    // MARK: - 错误分类枚举测试
    
    func testErrorCategoryEnum() {
        // Given: 所有错误分类
        let categories = ErrorCategory.allCases
        
        // When & Then: 验证分类数量
        XCTAssertEqual(categories.count, 9)
        
        // 验证特定分类
        XCTAssertTrue(categories.contains(.fileSystem))
        XCTAssertTrue(categories.contains(.network))
        XCTAssertTrue(categories.contains(.dataFormat))
        XCTAssertTrue(categories.contains(.cache))
        XCTAssertTrue(categories.contains(.configuration))
        XCTAssertTrue(categories.contains(.permission))
        XCTAssertTrue(categories.contains(.resource))
        XCTAssertTrue(categories.contains(.compatibility))
        XCTAssertTrue(categories.contains(.internal))
    }
    
    func testErrorSeverityEnum() {
        // Given: 所有错误严重程度
        let severities = ErrorSeverity.allCases
        
        // When & Then: 验证严重程度数量
        XCTAssertEqual(severities.count, 4)
        
        // 验证特定严重程度
        XCTAssertTrue(severities.contains(.low))
        XCTAssertTrue(severities.contains(.medium))
        XCTAssertTrue(severities.contains(.high))
        XCTAssertTrue(severities.contains(.critical))
    }
}

// MARK: - ErrorHandler测试
@MainActor
class ErrorHandlerTests: XCTestCase {
    
    // MARK: - 文件系统错误处理测试
    
    func testHandleFileSystemErrorWithCocoaError() {
        // Given: Cocoa错误
        let nsError = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [
            NSLocalizedDescriptionKey: "文件不存在"
        ])
        
        // When: 处理文件系统错误
        let bookingError = ErrorHandler.handleFileSystemError(nsError, filePath: "/test/file.json")
        
        // Then: 验证错误类型
        if case .fileNotFound(let details) = bookingError {
            XCTAssertTrue(details.contains("文件不存在"))
            XCTAssertTrue(details.contains("/test/file.json"))
        } else {
            XCTFail("应该是文件未找到错误")
        }
    }
    
    func testHandleFileSystemErrorWithPOSIXError() {
        // Given: POSIX错误
        let nsError = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOENT), userInfo: [
            NSLocalizedDescriptionKey: "No such file or directory"
        ])
        
        // When: 处理文件系统错误
        let bookingError = ErrorHandler.handleFileSystemError(nsError, filePath: "/test/file.json")
        
        // Then: 验证错误类型
        if case .fileNotFound(let details) = bookingError {
            XCTAssertTrue(details.contains("文件或目录不存在"))
            XCTAssertTrue(details.contains("/test/file.json"))
        } else {
            XCTFail("应该是文件未找到错误")
        }
    }
    
    func testHandleFileSystemErrorWithURLError() {
        // Given: URL错误
        let nsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorFileDoesNotExist, userInfo: [
            NSLocalizedDescriptionKey: "文件不存在"
        ])
        
        // When: 处理文件系统错误
        let bookingError = ErrorHandler.handleFileSystemError(nsError, filePath: "/test/file.json")
        
        // Then: 验证错误类型
        if case .fileNotFound(let details) = bookingError {
            XCTAssertTrue(details.contains("文件不存在"))
            XCTAssertTrue(details.contains("/test/file.json"))
        } else {
            XCTFail("应该是文件未找到错误")
        }
    }
    
    // MARK: - 网络错误处理测试
    
    func testHandleNetworkErrorWithURLError() {
        // Given: URL错误
        let nsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [
            NSLocalizedDescriptionKey: "请求超时"
        ])
        
        // When: 处理网络错误
        let bookingError = ErrorHandler.handleNetworkError(nsError, url: "https://example.com/api")
        
        // Then: 验证错误类型
        if case .networkTimeout(let details) = bookingError {
            XCTAssertTrue(details.contains("请求超时"))
            XCTAssertTrue(details.contains("https://example.com/api"))
        } else {
            XCTFail("应该是网络超时错误")
        }
    }
    
    func testHandleNetworkErrorWithPOSIXError() {
        // Given: POSIX网络错误
        let nsError = NSError(domain: NSPOSIXErrorDomain, code: Int(ECONNREFUSED), userInfo: [
            NSLocalizedDescriptionKey: "Connection refused"
        ])
        
        // When: 处理网络错误
        let bookingError = ErrorHandler.handleNetworkError(nsError, url: "https://example.com/api")
        
        // Then: 验证错误类型
        if case .networkError(let details) = bookingError {
            XCTAssertTrue(details.contains("连接被拒绝"))
            XCTAssertTrue(details.contains("https://example.com/api"))
        } else {
            XCTFail("应该是网络错误")
        }
    }
    
    // MARK: - HTTP状态码处理测试
    
    func testHandleHTTPStatusCodeSuccess() {
        // Given: 成功状态码
        let statusCode = 200
        
        // When: 处理HTTP状态码
        let bookingError = ErrorHandler.handleHTTPStatusCode(statusCode, url: "https://example.com/api")
        
        // Then: 验证错误类型
        if case .networkError(let details) = bookingError {
            XCTAssertTrue(details.contains("意外的成功状态码"))
            XCTAssertTrue(details.contains("200"))
        } else {
            XCTFail("应该是网络错误")
        }
    }
    
    func testHandleHTTPStatusCodeClientError() {
        // Given: 客户端错误状态码
        let statusCode = 404
        
        // When: 处理HTTP状态码
        let bookingError = ErrorHandler.handleHTTPStatusCode(statusCode, url: "https://example.com/api")
        
        // Then: 验证错误类型
        if case .fileNotFound(let details) = bookingError {
            XCTAssertTrue(details.contains("资源未找到"))
            XCTAssertTrue(details.contains("https://example.com/api"))
        } else {
            XCTFail("应该是文件未找到错误")
        }
    }
    
    func testHandleHTTPStatusCodeServerError() {
        // Given: 服务器错误状态码
        let statusCode = 500
        
        // When: 处理HTTP状态码
        let bookingError = ErrorHandler.handleHTTPStatusCode(statusCode, url: "https://example.com/api")
        
        // Then: 验证错误类型
        if case .serverError(let code, let details) = bookingError {
            XCTAssertEqual(code, 500)
            XCTAssertTrue(details.contains("内部服务器错误"))
            XCTAssertTrue(details.contains("https://example.com/api"))
        } else {
            XCTFail("应该是服务器错误")
        }
    }
    
    func testHandleHTTPStatusCodeAuthenticationError() {
        // Given: 认证错误状态码
        let statusCode = 401
        
        // When: 处理HTTP状态码
        let bookingError = ErrorHandler.handleHTTPStatusCode(statusCode, url: "https://example.com/api")
        
        // Then: 验证错误类型
        if case .authenticationFailed(let details) = bookingError {
            XCTAssertTrue(details.contains("未授权"))
            XCTAssertTrue(details.contains("https://example.com/api"))
        } else {
            XCTFail("应该是认证失败错误")
        }
    }
    
    func testHandleHTTPStatusCodeAuthorizationError() {
        // Given: 授权错误状态码
        let statusCode = 403
        
        // When: 处理HTTP状态码
        let bookingError = ErrorHandler.handleHTTPStatusCode(statusCode, url: "https://example.com/api")
        
        // Then: 验证错误类型
        if case .authorizationFailed(let details) = bookingError {
            XCTAssertTrue(details.contains("禁止访问"))
            XCTAssertTrue(details.contains("https://example.com/api"))
        } else {
            XCTFail("应该是授权失败错误")
        }
    }
    
    // MARK: - 错误日志记录测试
    
    func testLogError() {
        // Given: 错误和上下文
        let error = BookingDataError.fileNotFound("test.json")
        let context = "TestContext"
        
        // When: 记录错误（这里只是验证方法可以调用，不验证输出）
        ErrorHandler.logError(error, context: context, enableVerboseLogging: true)
        
        // Then: 验证没有崩溃
        XCTAssertTrue(true)
    }
    
    func testLogErrorWithDisabledLogging() {
        // Given: 错误和上下文，禁用日志
        let error = BookingDataError.fileNotFound("test.json")
        let context = "TestContext"
        
        // When: 记录错误（禁用日志）
        ErrorHandler.logError(error, context: context, enableVerboseLogging: false)
        
        // Then: 验证没有崩溃
        XCTAssertTrue(true)
    }
}

// MARK: - 错误处理集成测试
@MainActor
class ErrorHandlingIntegrationTests: XCTestCase {
    
    func testErrorHandlingFlow() {
        // Given: 模拟文件系统错误
        let nsError = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError, userInfo: [
            NSLocalizedDescriptionKey: "Permission denied"
        ])
        
        // When: 处理错误
        let bookingError = ErrorHandler.handleFileSystemError(nsError, filePath: "/protected/file.json")
        
        // Then: 验证完整的错误处理流程
        XCTAssertEqual(bookingError.category, .fileSystem)
        XCTAssertEqual(bookingError.severity, .medium)
        XCTAssertFalse(bookingError.isRetryable)
        
        if case .fileAccessDenied(let details) = bookingError {
            XCTAssertTrue(details.contains("没有读取权限"))
            XCTAssertTrue(details.contains("/protected/file.json"))
        } else {
            XCTFail("应该是文件访问被拒绝错误")
        }
        
        // 验证错误描述
        let description = bookingError.localizedDescription
        XCTAssertTrue(description.contains("文件访问被拒绝"))
        XCTAssertTrue(description.contains("没有读取权限"))
        XCTAssertTrue(description.contains("/protected/file.json"))
    }
    
    func testNetworkErrorHandlingFlow() {
        // Given: 模拟网络错误
        let nsError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: [
            NSLocalizedDescriptionKey: "The Internet connection appears to be offline"
        ])
        
        // When: 处理错误
        let bookingError = ErrorHandler.handleNetworkError(nsError, url: "https://api.example.com/data")
        
        // Then: 验证完整的错误处理流程
        XCTAssertEqual(bookingError.category, .network)
        XCTAssertEqual(bookingError.severity, .medium)
        XCTAssertTrue(bookingError.isRetryable)
        
        if case .networkUnavailable(let details) = bookingError {
            XCTAssertTrue(details.contains("网络不可用"))
            XCTAssertTrue(details.contains("https://api.example.com/data"))
        } else {
            XCTFail("应该是网络不可用错误")
        }
    }
    
    func testHTTPErrorHandlingFlow() {
        // Given: HTTP错误状态码
        let statusCode = 503
        
        // When: 处理错误
        let bookingError = ErrorHandler.handleHTTPStatusCode(statusCode, url: "https://api.example.com/service")
        
        // Then: 验证完整的错误处理流程
        XCTAssertEqual(bookingError.category, .network)
        XCTAssertEqual(bookingError.severity, .medium)
        XCTAssertTrue(bookingError.isRetryable)
        
        if case .resourceUnavailable(let details) = bookingError {
            XCTAssertTrue(details.contains("资源不可用"))
            XCTAssertTrue(details.contains("https://api.example.com/service"))
        } else {
            XCTFail("应该是资源不可用错误")
        }
    }
}
