//
//  RetryStrategyTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

// MARK: - 重试策略测试
@MainActor
class RetryStrategyTests: XCTestCase {
    
    // MARK: - 指数退避策略测试
    
    func testExponentialBackoffStrategyShouldRetry() {
        // Given: 指数退避策略
        let strategy = ExponentialBackoffStrategy()
        
        // When & Then: 测试可重试错误
        let retryableError = BookingDataError.networkTimeout("请求超时")
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 1, maxAttempts: 3))
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 2, maxAttempts: 3))
        XCTAssertFalse(strategy.shouldRetry(error: retryableError, attempt: 3, maxAttempts: 3))
        
        // 测试不可重试错误
        let nonRetryableError = BookingDataError.fileNotFound("文件不存在")
        XCTAssertFalse(strategy.shouldRetry(error: nonRetryableError, attempt: 1, maxAttempts: 3))
    }
    
    func testExponentialBackoffStrategyCalculateDelay() {
        // Given: 指数退避策略
        let strategy = ExponentialBackoffStrategy()
        
        // When & Then: 测试延迟计算
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 30.0
        
        let delay1 = strategy.calculateDelay(attempt: 1, baseDelay: baseDelay, maxDelay: maxDelay)
        let delay2 = strategy.calculateDelay(attempt: 2, baseDelay: baseDelay, maxDelay: maxDelay)
        let delay3 = strategy.calculateDelay(attempt: 3, baseDelay: baseDelay, maxDelay: maxDelay)
        
        // 验证指数增长
        XCTAssertLessThan(delay1, delay2)
        XCTAssertLessThan(delay2, delay3)
        
        // 验证不超过最大延迟
        XCTAssertLessThanOrEqual(delay1, maxDelay)
        XCTAssertLessThanOrEqual(delay2, maxDelay)
        XCTAssertLessThanOrEqual(delay3, maxDelay)
    }
    
    // MARK: - 线性退避策略测试
    
    func testLinearBackoffStrategyShouldRetry() {
        // Given: 线性退避策略
        let strategy = LinearBackoffStrategy()
        
        // When & Then: 测试可重试错误
        let retryableError = BookingDataError.networkTimeout("请求超时")
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 1, maxAttempts: 3))
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 2, maxAttempts: 3))
        XCTAssertFalse(strategy.shouldRetry(error: retryableError, attempt: 3, maxAttempts: 3))
    }
    
    func testLinearBackoffStrategyCalculateDelay() {
        // Given: 线性退避策略
        let strategy = LinearBackoffStrategy()
        
        // When & Then: 测试延迟计算
        let baseDelay: TimeInterval = 1.0
        let maxDelay: TimeInterval = 10.0
        
        let delay1 = strategy.calculateDelay(attempt: 1, baseDelay: baseDelay, maxDelay: maxDelay)
        let delay2 = strategy.calculateDelay(attempt: 2, baseDelay: baseDelay, maxDelay: maxDelay)
        let delay3 = strategy.calculateDelay(attempt: 3, baseDelay: baseDelay, maxDelay: maxDelay)
        
        // 验证线性增长
        XCTAssertLessThan(delay1, delay2)
        XCTAssertLessThan(delay2, delay3)
        
        // 验证不超过最大延迟
        XCTAssertLessThanOrEqual(delay1, maxDelay)
        XCTAssertLessThanOrEqual(delay2, maxDelay)
        XCTAssertLessThanOrEqual(delay3, maxDelay)
    }
    
    // MARK: - 固定延迟策略测试
    
    func testFixedDelayStrategyShouldRetry() {
        // Given: 固定延迟策略
        let strategy = FixedDelayStrategy()
        
        // When & Then: 测试可重试错误
        let retryableError = BookingDataError.networkTimeout("请求超时")
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 1, maxAttempts: 3))
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 2, maxAttempts: 3))
        XCTAssertFalse(strategy.shouldRetry(error: retryableError, attempt: 3, maxAttempts: 3))
    }
    
    func testFixedDelayStrategyCalculateDelay() {
        // Given: 固定延迟策略
        let strategy = FixedDelayStrategy()
        
        // When & Then: 测试延迟计算
        let baseDelay: TimeInterval = 2.0
        let maxDelay: TimeInterval = 10.0
        
        let delay1 = strategy.calculateDelay(attempt: 1, baseDelay: baseDelay, maxDelay: maxDelay)
        let delay2 = strategy.calculateDelay(attempt: 2, baseDelay: baseDelay, maxDelay: maxDelay)
        let delay3 = strategy.calculateDelay(attempt: 3, baseDelay: baseDelay, maxDelay: maxDelay)
        
        // 验证延迟基本固定（允许抖动）
        XCTAssertEqual(delay1, delay2, accuracy: 0.5)
        XCTAssertEqual(delay2, delay3, accuracy: 0.5)
        
        // 验证不超过最大延迟
        XCTAssertLessThanOrEqual(delay1, maxDelay)
        XCTAssertLessThanOrEqual(delay2, maxDelay)
        XCTAssertLessThanOrEqual(delay3, maxDelay)
    }
    
    // MARK: - 无重试策略测试
    
    func testNoRetryStrategyShouldRetry() {
        // Given: 无重试策略
        let strategy = NoRetryStrategy()
        
        // When & Then: 测试任何错误都不重试
        let retryableError = BookingDataError.networkTimeout("请求超时")
        XCTAssertFalse(strategy.shouldRetry(error: retryableError, attempt: 1, maxAttempts: 3))
        XCTAssertFalse(strategy.shouldRetry(error: retryableError, attempt: 2, maxAttempts: 3))
    }
    
    func testNoRetryStrategyCalculateDelay() {
        // Given: 无重试策略
        let strategy = NoRetryStrategy()
        
        // When & Then: 测试延迟为0
        let delay = strategy.calculateDelay(attempt: 1, baseDelay: 1.0, maxDelay: 10.0)
        XCTAssertEqual(delay, 0.0)
    }
    
    // MARK: - 自适应重试策略测试
    
    func testAdaptiveRetryStrategyShouldRetry() {
        // Given: 自适应重试策略
        let strategy = AdaptiveRetryStrategy()
        
        // When & Then: 测试可重试错误
        let retryableError = BookingDataError.networkTimeout("请求超时")
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 1, maxAttempts: 3))
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 2, maxAttempts: 3))
        XCTAssertFalse(strategy.shouldRetry(error: retryableError, attempt: 3, maxAttempts: 3))
    }
    
    func testAdaptiveRetryStrategyAdaptation() {
        // Given: 自适应重试策略
        let strategy = AdaptiveRetryStrategy()
        
        // When: 记录多次失败
        for _ in 0..<5 {
            strategy.recordFailure()
        }
        
        // Then: 验证成功率低时减少重试
        let retryableError = BookingDataError.networkTimeout("请求超时")
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 1, maxAttempts: 3))
        XCTAssertFalse(strategy.shouldRetry(error: retryableError, attempt: 2, maxAttempts: 3))
    }
    
    func testAdaptiveRetryStrategySuccessRate() {
        // Given: 自适应重试策略
        let strategy = AdaptiveRetryStrategy()
        
        // When: 记录多次成功
        for _ in 0..<5 {
            strategy.recordSuccess()
        }
        
        // Then: 验证成功率高时正常重试
        let retryableError = BookingDataError.networkTimeout("请求超时")
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 1, maxAttempts: 3))
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 2, maxAttempts: 3))
        XCTAssertFalse(strategy.shouldRetry(error: retryableError, attempt: 3, maxAttempts: 3))
    }
    
    func testAdaptiveRetryStrategyReset() {
        // Given: 自适应重试策略
        let strategy = AdaptiveRetryStrategy()
        
        // When: 记录失败并重置
        strategy.recordFailure()
        strategy.recordFailure()
        strategy.reset()
        
        // Then: 验证重置后恢复正常
        let retryableError = BookingDataError.networkTimeout("请求超时")
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 1, maxAttempts: 3))
        XCTAssertTrue(strategy.shouldRetry(error: retryableError, attempt: 2, maxAttempts: 3))
    }
}

// MARK: - 重试配置测试
@MainActor
class RetryConfigurationTests: XCTestCase {
    
    func testDefaultConfiguration() {
        // Given: 默认配置
        let config = RetryConfiguration.default
        
        // When & Then: 验证默认值
        XCTAssertEqual(config.maxAttempts, 3)
        XCTAssertEqual(config.baseDelay, 1.0)
        XCTAssertEqual(config.maxDelay, 30.0)
        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.strategy is ExponentialBackoffStrategy)
    }
    
    func testFastConfiguration() {
        // Given: 快速配置
        let config = RetryConfiguration.fast
        
        // When & Then: 验证快速配置
        XCTAssertEqual(config.maxAttempts, 2)
        XCTAssertEqual(config.baseDelay, 0.5)
        XCTAssertEqual(config.maxDelay, 5.0)
        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.strategy is LinearBackoffStrategy)
    }
    
    func testConservativeConfiguration() {
        // Given: 保守配置
        let config = RetryConfiguration.conservative
        
        // When & Then: 验证保守配置
        XCTAssertEqual(config.maxAttempts, 5)
        XCTAssertEqual(config.baseDelay, 2.0)
        XCTAssertEqual(config.maxDelay, 60.0)
        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.strategy is ExponentialBackoffStrategy)
    }
    
    func testDisabledConfiguration() {
        // Given: 禁用配置
        let config = RetryConfiguration.disabled
        
        // When & Then: 验证禁用配置
        XCTAssertEqual(config.maxAttempts, 1)
        XCTAssertEqual(config.baseDelay, 0.0)
        XCTAssertEqual(config.maxDelay, 0.0)
        XCTAssertFalse(config.enabled)
        XCTAssertTrue(config.strategy is NoRetryStrategy)
    }
}

// MARK: - 重试管理器测试
@MainActor
class RetryManagerTests: XCTestCase {
    
    func testRetryManagerSuccessOnFirstAttempt() async throws {
        // Given: 重试管理器和成功操作
        let config = RetryConfiguration.fast
        let retryManager = RetryManager(configuration: config, enableVerboseLogging: false)
        
        var attemptCount = 0
        let operation: () async throws -> String = {
            attemptCount += 1
            return "success"
        }
        
        // When: 执行操作
        let result = try await retryManager.executeWithRetry(operation)
        
        // Then: 验证结果
        XCTAssertEqual(result, "success")
        XCTAssertEqual(attemptCount, 1)
    }
    
    func testRetryManagerSuccessAfterRetries() async throws {
        // Given: 重试管理器和会失败几次的操作
        let config = RetryConfiguration(
            maxAttempts: 3,
            baseDelay: 0.1,
            maxDelay: 1.0,
            strategy: FixedDelayStrategy(),
            enabled: true
        )
        let retryManager = RetryManager(configuration: config, enableVerboseLogging: false)
        
        var attemptCount = 0
        let operation: () async throws -> String = {
            attemptCount += 1
            if attemptCount < 3 {
                throw BookingDataError.networkTimeout("网络超时")
            }
            return "success"
        }
        
        // When: 执行操作
        let result = try await retryManager.executeWithRetry(operation)
        
        // Then: 验证结果
        XCTAssertEqual(result, "success")
        XCTAssertEqual(attemptCount, 3)
    }
    
    func testRetryManagerFailureAfterMaxAttempts() async {
        // Given: 重试管理器和总是失败的操作
        let config = RetryConfiguration(
            maxAttempts: 2,
            baseDelay: 0.1,
            maxDelay: 1.0,
            strategy: FixedDelayStrategy(),
            enabled: true
        )
        let retryManager = RetryManager(configuration: config, enableVerboseLogging: false)
        
        var attemptCount = 0
        let operation: () async throws -> String = {
            attemptCount += 1
            throw BookingDataError.networkTimeout("网络超时")
        }
        
        // When & Then: 执行操作并验证失败
        do {
            _ = try await retryManager.executeWithRetry(operation)
            XCTFail("应该抛出错误")
        } catch {
            XCTAssertTrue(error is BookingDataError)
            XCTAssertEqual(attemptCount, 2)
        }
    }
    
    func testRetryManagerNonRetryableError() async {
        // Given: 重试管理器和不可重试的错误
        let config = RetryConfiguration.fast
        let retryManager = RetryManager(configuration: config, enableVerboseLogging: false)
        
        var attemptCount = 0
        let operation: () async throws -> String = {
            attemptCount += 1
            throw BookingDataError.fileNotFound("文件不存在")
        }
        
        // When & Then: 执行操作并验证失败
        do {
            _ = try await retryManager.executeWithRetry(operation)
            XCTFail("应该抛出错误")
        } catch {
            XCTAssertTrue(error is BookingDataError)
            XCTAssertEqual(attemptCount, 1) // 不可重试错误只尝试一次
        }
    }
    
    func testRetryManagerDisabled() async throws {
        // Given: 禁用重试的管理器
        let config = RetryConfiguration.disabled
        let retryManager = RetryManager(configuration: config, enableVerboseLogging: false)
        
        var attemptCount = 0
        let operation: () async throws -> String = {
            attemptCount += 1
            return "success"
        }
        
        // When: 执行操作
        let result = try await retryManager.executeWithRetry(operation)
        
        // Then: 验证结果
        XCTAssertEqual(result, "success")
        XCTAssertEqual(attemptCount, 1)
    }
    
    func testRetryManagerWithProgressCallback() async throws {
        // Given: 重试管理器和带进度回调的操作
        let config = RetryConfiguration(
            maxAttempts: 3,
            baseDelay: 0.1,
            maxDelay: 1.0,
            strategy: FixedDelayStrategy(),
            enabled: true
        )
        let retryManager = RetryManager(configuration: config, enableVerboseLogging: false)
        
        var attemptCount = 0
        var progressValues: [Double] = []
        
        let operation: () async throws -> String = {
            attemptCount += 1
            if attemptCount < 3 {
                throw BookingDataError.networkTimeout("网络超时")
            }
            return "success"
        }
        
        let progressCallback: (Double) -> Void = { progress in
            progressValues.append(progress)
        }
        
        // When: 执行操作
        let result = try await retryManager.executeWithRetry(operation, progressCallback: progressCallback)
        
        // Then: 验证结果
        XCTAssertEqual(result, "success")
        XCTAssertEqual(attemptCount, 3)
        XCTAssertFalse(progressValues.isEmpty)
        XCTAssertEqual(progressValues.last, 1.0) // 最后应该是100%
    }
}

// MARK: - 重试策略工厂测试
@MainActor
class RetryStrategyFactoryTests: XCTestCase {
    
    func testCreateExponentialBackoff() {
        // When: 创建指数退避策略
        let strategy = RetryStrategyFactory.createExponentialBackoff()
        
        // Then: 验证策略类型
        XCTAssertTrue(strategy is ExponentialBackoffStrategy)
        XCTAssertEqual(strategy.name, "指数退避")
    }
    
    func testCreateLinearBackoff() {
        // When: 创建线性退避策略
        let strategy = RetryStrategyFactory.createLinearBackoff()
        
        // Then: 验证策略类型
        XCTAssertTrue(strategy is LinearBackoffStrategy)
        XCTAssertEqual(strategy.name, "线性退避")
    }
    
    func testCreateFixedDelay() {
        // When: 创建固定延迟策略
        let strategy = RetryStrategyFactory.createFixedDelay()
        
        // Then: 验证策略类型
        XCTAssertTrue(strategy is FixedDelayStrategy)
        XCTAssertEqual(strategy.name, "固定延迟")
    }
    
    func testCreateAdaptive() {
        // When: 创建自适应策略
        let strategy = RetryStrategyFactory.createAdaptive()
        
        // Then: 验证策略类型
        XCTAssertTrue(strategy is AdaptiveRetryStrategy)
        XCTAssertEqual(strategy.name, "自适应重试")
    }
    
    func testCreateNoRetry() {
        // When: 创建无重试策略
        let strategy = RetryStrategyFactory.createNoRetry()
        
        // Then: 验证策略类型
        XCTAssertTrue(strategy is NoRetryStrategy)
        XCTAssertEqual(strategy.name, "无重试")
    }
    
    func testCreateStrategyForError() {
        // Given: 不同类型的错误
        let networkError = BookingDataError.networkTimeout("网络超时")
        let fileSystemError = BookingDataError.fileNotFound("文件不存在")
        let cacheError = BookingDataError.cacheError("缓存错误")
        let unknownError = NSError(domain: "TestDomain", code: 1, userInfo: nil)
        
        // When: 为不同错误创建策略
        let networkStrategy = RetryStrategyFactory.createStrategyForError(networkError)
        let fileSystemStrategy = RetryStrategyFactory.createStrategyForError(fileSystemError)
        let cacheStrategy = RetryStrategyFactory.createStrategyForError(cacheError)
        let unknownStrategy = RetryStrategyFactory.createStrategyForError(unknownError)
        
        // Then: 验证策略类型
        XCTAssertTrue(networkStrategy is ExponentialBackoffStrategy)
        XCTAssertTrue(fileSystemStrategy is LinearBackoffStrategy)
        XCTAssertTrue(cacheStrategy is FixedDelayStrategy)
        XCTAssertTrue(unknownStrategy is ExponentialBackoffStrategy)
    }
}

// MARK: - 重试机制集成测试
@MainActor
class RetryMechanismIntegrationTests: XCTestCase {
    
    func testAsyncFileReaderWithRetry() async throws {
        // Given: 带重试配置的AsyncFileReader
        let retryConfig = RetryConfiguration(
            maxAttempts: 2,
            baseDelay: 0.1,
            maxDelay: 1.0,
            strategy: FixedDelayStrategy(),
            enabled: true
        )
        let fileReader = AsyncFileReaderFactory.createForTesting(
            enableVerboseLogging: false,
            retryConfiguration: retryConfig
        )
        
        // When: 尝试读取不存在的文件
        do {
            _ = try await fileReader.readLocalFile(fileName: "nonexistent", fileExtension: "json")
            XCTFail("应该抛出错误")
        } catch {
            // Then: 验证错误类型
            XCTAssertTrue(error is BookingDataError)
        }
    }
    
    func testBookingServiceWithRetryConfiguration() {
        // Given: 带重试配置的BookingService配置
        let retryConfig = RetryConfiguration.fast
        let config = BookingServiceConfigurationFactory.createCustom(
            fileName: "test",
            retryConfiguration: retryConfig
        )
        
        // When: 创建BookingService
        let service = BookingService(configuration: config)
        
        // Then: 验证服务创建成功
        XCTAssertNotNil(service)
    }
    
    func testRetryConfigurationInDifferentEnvironments() {
        // Given: 不同环境的配置
        let defaultConfig = BookingServiceConfigurationFactory.createDefault()
        let productionConfig = BookingServiceConfigurationFactory.createProduction()
        let testConfig = BookingServiceConfigurationFactory.createTest()
        
        // When & Then: 验证不同环境的重试配置
        XCTAssertTrue(defaultConfig.retryConfiguration.enabled)
        XCTAssertTrue(productionConfig.retryConfiguration.enabled)
        XCTAssertTrue(testConfig.retryConfiguration.enabled)
        
        // 验证重试次数
        XCTAssertEqual(defaultConfig.retryConfiguration.maxAttempts, 3)
        XCTAssertEqual(productionConfig.retryConfiguration.maxAttempts, 2)
        XCTAssertEqual(testConfig.retryConfiguration.maxAttempts, 1)
    }
}
