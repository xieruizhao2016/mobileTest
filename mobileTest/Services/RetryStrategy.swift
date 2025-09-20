//
//  RetryStrategy.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

// MARK: - 重试策略协议
protocol RetryStrategyProtocol {
    /// 是否应该重试
    /// - Parameters:
    ///   - error: 错误
    ///   - attempt: 当前尝试次数
    ///   - maxAttempts: 最大尝试次数
    /// - Returns: 是否应该重试
    func shouldRetry(error: Error, attempt: Int, maxAttempts: Int) -> Bool
    
    /// 计算重试延迟时间
    /// - Parameters:
    ///   - attempt: 当前尝试次数
    ///   - baseDelay: 基础延迟时间
    ///   - maxDelay: 最大延迟时间
    /// - Returns: 延迟时间（秒）
    func calculateDelay(attempt: Int, baseDelay: TimeInterval, maxDelay: TimeInterval) -> TimeInterval
    
    /// 获取重试策略名称
    var name: String { get }
}

// MARK: - 重试配置
struct RetryConfiguration {
    /// 最大重试次数
    let maxAttempts: Int
    
    /// 基础延迟时间（秒）
    let baseDelay: TimeInterval
    
    /// 最大延迟时间（秒）
    let maxDelay: TimeInterval
    
    /// 重试策略
    let strategy: RetryStrategyProtocol
    
    /// 是否启用重试
    let enabled: Bool
    
    /// 默认配置
    static let `default` = RetryConfiguration(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        strategy: ExponentialBackoffStrategy(),
        enabled: true
    )
    
    /// 快速重试配置
    static let fast = RetryConfiguration(
        maxAttempts: 2,
        baseDelay: 0.5,
        maxDelay: 5.0,
        strategy: LinearBackoffStrategy(),
        enabled: true
    )
    
    /// 保守重试配置
    static let conservative = RetryConfiguration(
        maxAttempts: 5,
        baseDelay: 2.0,
        maxDelay: 60.0,
        strategy: ExponentialBackoffStrategy(),
        enabled: true
    )
    
    /// 禁用重试配置
    static let disabled = RetryConfiguration(
        maxAttempts: 1,
        baseDelay: 0.0,
        maxDelay: 0.0,
        strategy: NoRetryStrategy(),
        enabled: false
    )
}

// MARK: - 指数退避重试策略
class ExponentialBackoffStrategy: RetryStrategyProtocol {
    let name = "指数退避"
    
    func shouldRetry(error: Error, attempt: Int, maxAttempts: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        
        // 基于错误类型决定是否重试
        if let bookingError = error as? BookingDataError {
            return bookingError.isRetryable
        }
        
        // 对于系统错误，检查常见的可重试错误
        let nsError = error as NSError
        return isRetryableSystemError(nsError)
    }
    
    func calculateDelay(attempt: Int, baseDelay: TimeInterval, maxDelay: TimeInterval) -> TimeInterval {
        // 指数退避：delay = baseDelay * (2 ^ (attempt - 1))
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt - 1))
        
        // 添加随机抖动，避免雷群效应
        let jitter = Double.random(in: 0.1...0.3) * exponentialDelay
        let finalDelay = exponentialDelay + jitter
        
        return min(finalDelay, maxDelay)
    }
    
    private func isRetryableSystemError(_ error: NSError) -> Bool {
        switch error.domain {
        case NSURLErrorDomain:
            return isRetryableURLError(error.code)
        case NSPOSIXErrorDomain:
            return isRetryablePOSIXError(error.code)
        case NSCocoaErrorDomain:
            return isRetryableCocoaError(error.code)
        default:
            return false
        }
    }
    
    private func isRetryableURLError(_ code: Int) -> Bool {
        switch code {
        case NSURLErrorTimedOut,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorResourceUnavailable:
            return true
        default:
            return false
        }
    }
    
    private func isRetryablePOSIXError(_ code: Int) -> Bool {
        switch code {
        case Int(ETIMEDOUT),
             Int(ECONNREFUSED),
             Int(ECONNRESET),
             Int(EAGAIN),
             Int(EWOULDBLOCK),
             Int(EINTR):
            return true
        default:
            return false
        }
    }
    
    private func isRetryableCocoaError(_ code: Int) -> Bool {
        switch code {
        case NSFileReadNoPermissionError,
             NSFileWriteNoPermissionError:
            return false // 权限错误通常不可重试
        default:
            return false
        }
    }
}

// MARK: - 线性退避重试策略
class LinearBackoffStrategy: RetryStrategyProtocol {
    let name = "线性退避"
    
    func shouldRetry(error: Error, attempt: Int, maxAttempts: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        
        if let bookingError = error as? BookingDataError {
            return bookingError.isRetryable
        }
        
        let nsError = error as NSError
        return isRetryableSystemError(nsError)
    }
    
    func calculateDelay(attempt: Int, baseDelay: TimeInterval, maxDelay: TimeInterval) -> TimeInterval {
        // 线性退避：delay = baseDelay * attempt
        let linearDelay = baseDelay * Double(attempt)
        
        // 添加随机抖动
        let jitter = Double.random(in: 0.1...0.2) * linearDelay
        let finalDelay = linearDelay + jitter
        
        return min(finalDelay, maxDelay)
    }
    
    private func isRetryableSystemError(_ error: NSError) -> Bool {
        switch error.domain {
        case NSURLErrorDomain:
            return isRetryableURLError(error.code)
        case NSPOSIXErrorDomain:
            return isRetryablePOSIXError(error.code)
        default:
            return false
        }
    }
    
    private func isRetryableURLError(_ code: Int) -> Bool {
        switch code {
        case NSURLErrorTimedOut,
             NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost:
            return true
        default:
            return false
        }
    }
    
    private func isRetryablePOSIXError(_ code: Int) -> Bool {
        switch code {
        case Int(ETIMEDOUT),
             Int(ECONNREFUSED),
             Int(EAGAIN):
            return true
        default:
            return false
        }
    }
}

// MARK: - 固定延迟重试策略
class FixedDelayStrategy: RetryStrategyProtocol {
    let name = "固定延迟"
    
    func shouldRetry(error: Error, attempt: Int, maxAttempts: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        
        if let bookingError = error as? BookingDataError {
            return bookingError.isRetryable
        }
        
        return false
    }
    
    func calculateDelay(attempt: Int, baseDelay: TimeInterval, maxDelay: TimeInterval) -> TimeInterval {
        // 固定延迟，添加少量随机抖动
        let jitter = Double.random(in: 0.05...0.15) * baseDelay
        return min(baseDelay + jitter, maxDelay)
    }
}

// MARK: - 无重试策略
class NoRetryStrategy: RetryStrategyProtocol {
    let name = "无重试"
    
    func shouldRetry(error: Error, attempt: Int, maxAttempts: Int) -> Bool {
        return false
    }
    
    func calculateDelay(attempt: Int, baseDelay: TimeInterval, maxDelay: TimeInterval) -> TimeInterval {
        return 0.0
    }
}

// MARK: - 自适应重试策略
class AdaptiveRetryStrategy: RetryStrategyProtocol {
    let name = "自适应重试"
    
    private var successCount = 0
    private var failureCount = 0
    private let adaptationThreshold = 5
    
    func shouldRetry(error: Error, attempt: Int, maxAttempts: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        
        // 更新统计信息
        failureCount += 1
        
        // 基于历史成功率调整重试策略
        let totalAttempts = successCount + failureCount
        if totalAttempts >= adaptationThreshold {
            let successRate = Double(successCount) / Double(totalAttempts)
            
            // 如果成功率低，减少重试次数
            if successRate < 0.3 && attempt >= 2 {
                return false
            }
        }
        
        if let bookingError = error as? BookingDataError {
            return bookingError.isRetryable
        }
        
        return false
    }
    
    func calculateDelay(attempt: Int, baseDelay: TimeInterval, maxDelay: TimeInterval) -> TimeInterval {
        // 基于历史成功率调整延迟
        let totalAttempts = successCount + failureCount
        var adjustedBaseDelay = baseDelay
        
        if totalAttempts >= adaptationThreshold {
            let successRate = Double(successCount) / Double(totalAttempts)
            
            if successRate < 0.3 {
                // 成功率低，增加延迟
                adjustedBaseDelay *= 1.5
            } else if successRate > 0.8 {
                // 成功率高，减少延迟
                adjustedBaseDelay *= 0.8
            }
        }
        
        // 使用指数退避
        let exponentialDelay = adjustedBaseDelay * pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0.1...0.3) * exponentialDelay
        
        return min(exponentialDelay + jitter, maxDelay)
    }
    
    func recordSuccess() {
        successCount += 1
    }
    
    func recordFailure() {
        failureCount += 1
    }
    
    func reset() {
        successCount = 0
        failureCount = 0
    }
}

// MARK: - 重试管理器
class RetryManager {
    private let configuration: RetryConfiguration
    private let enableVerboseLogging: Bool
    
    init(configuration: RetryConfiguration = .default, enableVerboseLogging: Bool = true) {
        self.configuration = configuration
        self.enableVerboseLogging = enableVerboseLogging
    }
    
    /// 执行带重试的操作
    /// - Parameter operation: 要执行的操作
    /// - Returns: 操作结果
    /// - Throws: 最终错误
    func executeWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        guard configuration.enabled else {
            return try await operation()
        }
        
        var lastError: Error?
        
        for attempt in 1...configuration.maxAttempts {
            do {
                let result = try await operation()
                
                // 记录成功（如果是自适应策略）
                if let adaptiveStrategy = configuration.strategy as? AdaptiveRetryStrategy {
                    adaptiveStrategy.recordSuccess()
                }
                
                if attempt > 1 {
                    log("✅ [RetryManager] 操作在第\(attempt)次尝试后成功")
                }
                
                return result
                
            } catch {
                lastError = error
                
                // 检查是否应该重试
                if !configuration.strategy.shouldRetry(
                    error: error,
                    attempt: attempt,
                    maxAttempts: configuration.maxAttempts
                ) {
                    log("❌ [RetryManager] 错误不可重试: \(error.localizedDescription)")
                    throw error
                }
                
                // 记录失败（如果是自适应策略）
                if let adaptiveStrategy = configuration.strategy as? AdaptiveRetryStrategy {
                    adaptiveStrategy.recordFailure()
                }
                
                if attempt < configuration.maxAttempts {
                    let delay = configuration.strategy.calculateDelay(
                        attempt: attempt,
                        baseDelay: configuration.baseDelay,
                        maxDelay: configuration.maxDelay
                    )
                    
                    log("🔄 [RetryManager] 第\(attempt)次尝试失败，\(String(format: "%.2f", delay))秒后重试...")
                    log("   - 错误: \(error.localizedDescription)")
                    log("   - 策略: \(configuration.strategy.name)")
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    log("💥 [RetryManager] 所有\(configuration.maxAttempts)次尝试都失败了")
                }
            }
        }
        
        throw lastError ?? BookingDataError.unexpectedError("重试失败")
    }
    
    /// 执行带重试的操作（带进度回调）
    /// - Parameters:
    ///   - operation: 要执行的操作
    ///   - progressCallback: 进度回调
    /// - Returns: 操作结果
    /// - Throws: 最终错误
    func executeWithRetry<T>(
        _ operation: @escaping () async throws -> T,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> T {
        guard configuration.enabled else {
            progressCallback(1.0)
            return try await operation()
        }
        
        var lastError: Error?
        
        for attempt in 1...configuration.maxAttempts {
            do {
                let result = try await operation()
                
                // 记录成功
                if let adaptiveStrategy = configuration.strategy as? AdaptiveRetryStrategy {
                    adaptiveStrategy.recordSuccess()
                }
                
                progressCallback(1.0)
                
                if attempt > 1 {
                    log("✅ [RetryManager] 操作在第\(attempt)次尝试后成功")
                }
                
                return result
                
            } catch {
                lastError = error
                
                // 更新进度
                let progress = Double(attempt) / Double(configuration.maxAttempts)
                progressCallback(progress)
                
                // 检查是否应该重试
                if !configuration.strategy.shouldRetry(
                    error: error,
                    attempt: attempt,
                    maxAttempts: configuration.maxAttempts
                ) {
                    log("❌ [RetryManager] 错误不可重试: \(error.localizedDescription)")
                    throw error
                }
                
                // 记录失败
                if let adaptiveStrategy = configuration.strategy as? AdaptiveRetryStrategy {
                    adaptiveStrategy.recordFailure()
                }
                
                if attempt < configuration.maxAttempts {
                    let delay = configuration.strategy.calculateDelay(
                        attempt: attempt,
                        baseDelay: configuration.baseDelay,
                        maxDelay: configuration.maxDelay
                    )
                    
                    log("🔄 [RetryManager] 第\(attempt)次尝试失败，\(String(format: "%.2f", delay))秒后重试...")
                    log("   - 错误: \(error.localizedDescription)")
                    log("   - 策略: \(configuration.strategy.name)")
                    
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    log("💥 [RetryManager] 所有\(configuration.maxAttempts)次尝试都失败了")
                }
            }
        }
        
        throw lastError ?? BookingDataError.unexpectedError("重试失败")
    }
    
    /// 条件日志输出
    private func log(_ message: String) {
        if enableVerboseLogging {
            print(message)
        }
    }
}

// MARK: - 重试策略工厂
enum RetryStrategyFactory {
    /// 创建指数退避策略
    static func createExponentialBackoff() -> RetryStrategyProtocol {
        return ExponentialBackoffStrategy()
    }
    
    /// 创建线性退避策略
    static func createLinearBackoff() -> RetryStrategyProtocol {
        return LinearBackoffStrategy()
    }
    
    /// 创建固定延迟策略
    static func createFixedDelay() -> RetryStrategyProtocol {
        return FixedDelayStrategy()
    }
    
    /// 创建自适应策略
    static func createAdaptive() -> RetryStrategyProtocol {
        return AdaptiveRetryStrategy()
    }
    
    /// 创建无重试策略
    static func createNoRetry() -> RetryStrategyProtocol {
        return NoRetryStrategy()
    }
    
    /// 根据错误类型创建合适的策略
    static func createStrategyForError(_ error: Error) -> RetryStrategyProtocol {
        if let bookingError = error as? BookingDataError {
            switch bookingError.category {
            case .network:
                return ExponentialBackoffStrategy()
            case .fileSystem:
                return LinearBackoffStrategy()
            case .cache:
                return FixedDelayStrategy()
            default:
                return NoRetryStrategy()
            }
        }
        
        return ExponentialBackoffStrategy()
    }
}
