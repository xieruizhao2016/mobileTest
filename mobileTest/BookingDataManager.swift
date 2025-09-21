//
//  BookingDataManager.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation
import Combine


enum CacheStrategy {
    case disabled
    case memoryOnly
    case diskOnly
    case hybrid
    case smart
}

enum WarmupStrategy {
    case conservative  // 保守策略
    case aggressive    // 激进策略
    case predictive    // 预测策略
}

struct DataManagerUsagePattern {
    let shouldPreload: Bool
    let confidence: Double
    let reason: String
}

struct ResourceUsageReport {
    let activeRequests: Int
    let isBackgroundRefreshActive: Bool
    let memoryUsage: UInt64
    let availableMemory: UInt64
    let isDestroyed: Bool
    
    var memoryUsagePercent: Double {
        guard memoryUsage > 0 else { return 0 }
        return Double(memoryUsage - availableMemory) / Double(memoryUsage) * 100
    }
    
    var formattedMemoryUsage: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(memoryUsage))
    }
}

struct HealthStatus {
    let isHealthy: Bool
    let issues: [String]
    let timestamp: Date
    
    var summary: String {
        if isHealthy {
            return "✅ 健康状态良好"
        } else {
            return "⚠️ 发现 \(issues.count) 个问题"
        }
    }
}

struct InternalState {
    let currentData: BookingData?
    let dataStatus: DataStatus
    let isDestroyed: Bool
    let activeRequests: Int
    let isBackgroundRefreshActive: Bool
}

// MARK: - 测试工厂
struct BookingDataManagerTestFactory {
    
    /// 创建测试用的数据管理器
    /// - Parameters:
    ///   - mockService: 模拟服务
    ///   - mockCache: 模拟缓存
    ///   - configuration: 测试配置
    /// - Returns: 测试用的数据管理器
    @MainActor
    static func createTestManager(
        mockService: BookingServiceProtocol? = nil,
        mockCache: BookingCacheProtocol? = nil,
        configuration: BookingServiceConfigurationProtocol? = nil
    ) -> BookingDataManager {
        let service = mockService ?? BookingService() // 使用真实的服务
        let cache = mockCache ?? MockBookingCache()
        let config = configuration ?? BookingServiceConfigurationFactory.createTest()
        
        return BookingDataManager(
            bookingService: service,
            bookingCache: cache,
            testConfiguration: config
        )
    }
    
    /// 创建模拟数据
    /// - Returns: 模拟的预订数据
    static func createMockBookingData() -> BookingData {
        let expiryTimestamp = Date().addingTimeInterval(86400).timeIntervalSince1970 // 24小时后过期
        
        return BookingData(
            shipReference: "TEST-SHIP-001",
            shipToken: "test-token-123",
            canIssueTicketChecking: true,
            expiryTime: String(expiryTimestamp),
            duration: 480, // 8小时，以分钟为单位
            segments: [
                Segment(
                    id: 1,
                    originAndDestinationPair: OriginDestinationPair(
                        destination: Location(code: "NRT", displayName: "成田国际机场", url: "https://example.com/nrt"),
                        destinationCity: "东京",
                        origin: Location(code: "PVG", displayName: "浦东国际机场", url: "https://example.com/pvg"),
                        originCity: "上海"
                    )
                ),
                Segment(
                    id: 2,
                    originAndDestinationPair: OriginDestinationPair(
                        destination: Location(code: "LAX", displayName: "洛杉矶国际机场", url: "https://example.com/lax"),
                        destinationCity: "洛杉矶",
                        origin: Location(code: "NRT", displayName: "成田国际机场", url: "https://example.com/nrt"),
                        originCity: "东京"
                    )
                )
            ]
        )
    }
    
    /// 创建过期的模拟数据
    /// - Returns: 过期的模拟数据
    static func createExpiredMockBookingData() -> BookingData {
        let expiredTimestamp = Date().addingTimeInterval(-86400).timeIntervalSince1970 // 24小时前过期
        
        return BookingData(
            shipReference: "EXPIRED-SHIP-001",
            shipToken: "expired-token-456",
            canIssueTicketChecking: false,
            expiryTime: String(expiredTimestamp),
            duration: 480, // 8小时，以分钟为单位
            segments: [
                Segment(
                    id: 1,
                    originAndDestinationPair: OriginDestinationPair(
                        destination: Location(code: "NRT", displayName: "成田国际机场", url: "https://example.com/nrt"),
                        destinationCity: "东京",
                        origin: Location(code: "PVG", displayName: "浦东国际机场", url: "https://example.com/pvg"),
                        originCity: "上海"
                    )
                )
            ]
        )
    }
}

// Mock类已移动到测试文件中

class MockBookingCache: BookingCacheProtocol {
    private var cache: [String: Any] = [:]
    private var diskData: CachedBookingData?
    var shouldSucceed = true
    var mockError: BookingDataError?
    
    func get<T>(key: String) -> T? {
        return cache[key] as? T
    }
    
    func getAsync<T>(key: String) async -> T? {
        return cache[key] as? T
    }
    
    func set<T>(key: String, value: T) {
        cache[key] = value
    }
    
    func setAsync<T>(key: String, value: T) async throws {
        if !shouldSucceed {
            throw mockError ?? BookingDataError.cacheError("模拟缓存错误")
        }
        cache[key] = value
    }
    
    func remove(key: String) {
        cache.removeValue(forKey: key)
    }
    
    func clearLegacyCache() throws {
        if !shouldSucceed {
            throw mockError ?? BookingDataError.cacheError("模拟缓存清理错误")
        }
        cache.removeAll()
        diskData = nil
    }
    
    func save(_ data: BookingData, timestamp: Date) throws {
        if !shouldSucceed {
            throw mockError ?? BookingDataError.cacheError("模拟保存错误")
        }
        let expiryTime = Date().addingTimeInterval(300) // 5分钟后过期
        diskData = CachedBookingData(data: data, timestamp: timestamp, expiryTime: expiryTime)
    }
    
    func load() throws -> CachedBookingData? {
        if !shouldSucceed {
            throw mockError ?? BookingDataError.cacheError("模拟加载错误")
        }
        return diskData
    }
    
    func getStatistics() -> CacheStatistics {
        return CacheStatistics(
            totalItems: cache.count,
            hitCount: 10,
            missCount: 2,
            evictionCount: 0,
            memoryUsage: 1024,
            hitRate: 0.8,
            averageResponseTime: 0.1,
            topKeys: Array(cache.keys.prefix(5)).map { ($0, 1) }
        )
    }
    
    func getCacheStatistics() -> String {
        return "模拟缓存统计"
    }
    
    func isCacheValid() -> Bool {
        return diskData?.isValid ?? false
    }
    
    func getCacheInfo() -> (isValid: Bool, timestamp: Date?, age: TimeInterval?) {
        guard let diskData = diskData else {
            return (isValid: false, timestamp: nil, age: nil)
        }
        let age = Date().timeIntervalSince(diskData.timestamp)
        return (isValid: diskData.isValid, timestamp: diskData.timestamp, age: age)
    }
}

// MARK: - 数据管理器协议
protocol BookingDataManagerProtocol {
    func getBookingData() async throws -> BookingData
    func refreshBookingData() async throws -> BookingData
    func getDataStatus() async -> DataStatus
    var dataPublisher: AnyPublisher<BookingData, Never> { get }
    
    // 新增的优化方法
    func getBookingDataWithRetry(maxRetries: Int) async throws -> BookingData
    func getCacheStatistics() -> CacheStatistics
    func warmupCache() async
}

// MARK: - 数据管理器实现
@MainActor
class BookingDataManager: ObservableObject, @preconcurrency BookingDataManagerProtocol {
    
    // MARK: - 属性
    @Published private(set) var currentData: BookingData?
    @Published private(set) var dataStatus: DataStatus = .loading
    
    private let bookingService: BookingServiceProtocol
    private let bookingCache: BookingCacheProtocol
    private let dataSubject = PassthroughSubject<BookingData, Never>()
    
    // 并发控制和请求去重
    private var ongoingRequests: Set<String> = []
    private let requestQueue = DispatchQueue(label: "com.booking.requests", attributes: .concurrent)
    private var requestContinuations: [String: [CheckedContinuation<BookingData, Error>]] = [:]
    
    // 性能监控
    private let performanceMonitor: PerformanceMonitorProtocol
    
    // 配置
    private let configuration: BookingServiceConfigurationProtocol
    
    // 资源管理
    private var backgroundRefreshTimer: Timer?
    private var isDestroyed = false
    
    // MARK: - 初始化
    
    /// 初始化数据管理器
    /// - Parameters:
    ///   - bookingService: 预订服务
    ///   - bookingCache: 预订缓存
    ///   - configuration: 预订服务配置
    ///   - performanceMonitor: 性能监控器
    init(bookingService: BookingServiceProtocol = BookingService(), 
         bookingCache: BookingCacheProtocol = BookingCache(),
         configuration: BookingServiceConfigurationProtocol = BookingServiceConfigurationFactory.createDefault(),
         performanceMonitor: PerformanceMonitorProtocol? = nil) {
        self.bookingService = bookingService
        self.bookingCache = bookingCache
        self.configuration = configuration
        self.performanceMonitor = performanceMonitor ?? PerformanceMonitorFactory.createDefault(enableVerboseLogging: configuration.enableVerboseLogging)
        
        print("🚀 [BookingDataManager] 数据管理器已初始化 - 配置: \(configuration.cacheStrategy)")
    }
    
    /// 便利初始化器（用于测试）
    /// - Parameters:
    ///   - bookingService: 预订服务
    ///   - bookingCache: 预订缓存
    convenience init(bookingService: BookingServiceProtocol, bookingCache: BookingCacheProtocol) {
        self.init(bookingService: bookingService, bookingCache: bookingCache, configuration: BookingServiceConfigurationFactory.createTest())
    }
    
    /// 测试专用初始化器
    /// - Parameters:
    ///   - bookingService: 预订服务
    ///   - bookingCache: 预订缓存
    ///   - configuration: 测试配置
    convenience init(
        bookingService: BookingServiceProtocol,
        bookingCache: BookingCacheProtocol,
        testConfiguration: BookingServiceConfigurationProtocol
    ) {
        self.init(bookingService: bookingService, bookingCache: bookingCache, configuration: testConfiguration)
    }
    
    /// 资源清理
    deinit {
        Task { await cleanup() }
    }
    
    /// 执行资源清理
    private func cleanup() {
        isDestroyed = true
        
        print("🧹 [BookingDataManager] 开始资源清理...")
        
        // 停止后台刷新
        stopBackgroundRefresh()
        
        // 清理请求continuations
        cleanupRequestContinuations()
        
        // 清理性能指标
        performanceMonitor.clearData(in: nil)
        
        // 清理缓存（可选）
        if configuration.cacheStrategy == .memoryOnly {
            cleanupMemoryCache()
        }
        
        print("✅ [BookingDataManager] 资源清理完成")
    }
    
    /// 清理请求continuations
    private func cleanupRequestContinuations() {
        requestQueue.async(flags: .barrier) {
            let continuationCount = self.requestContinuations.values.flatMap { $0 }.count
            print("🧹 [BookingDataManager] 清理 \(continuationCount) 个待处理的请求...")
            
            for (_, continuations) in self.requestContinuations {
                for continuation in continuations {
                    continuation.resume(throwing: BookingDataError.internalError("管理器已销毁"))
                }
            }
            self.requestContinuations.removeAll()
        }
    }
    
    
    /// 清理内存缓存
    private func cleanupMemoryCache() {
        // 这里可以添加清理内存缓存的逻辑
        print("🧹 [BookingDataManager] 内存缓存已清理")
    }
    
    // MARK: - 公共方法
    
    /// 获取预订数据（优先从缓存获取，缓存无效时从服务获取）
    /// - Returns: 预订数据
    /// - Throws: BookingDataError
    func getBookingData() async throws -> BookingData {
        return try await getBookingDataWithRetry(maxRetries: 1)
    }
    
    /// 获取预订数据（带重试机制）
    /// - Parameter maxRetries: 最大重试次数（可选，默认使用配置中的值）
    /// - Returns: 预订数据
    /// - Throws: BookingDataError
    func getBookingDataWithRetry(maxRetries: Int) async throws -> BookingData {
        let requestId = "getBookingData"
        let startTime = CFAbsoluteTimeGetCurrent()
        let actualMaxRetries = maxRetries
        
        print("📋 [BookingDataManager] 开始获取预订数据... (最大重试: \(actualMaxRetries))")
        
        // 请求去重：如果已启用且已有相同请求在进行，等待其完成
        if configuration.enableRequestDeduplication {
            let isInProgress = await isRequestInProgress(requestId: requestId)
            if isInProgress {
                print("⏳ [BookingDataManager] 等待现有请求完成...")
                return try await waitForRequest(requestId: requestId)
            }
        }
        
        // 标记请求开始
        if configuration.enableRequestDeduplication {
            await markRequestStarted(requestId: requestId)
        }
        
        defer {
            if configuration.enableRequestDeduplication {
                Task { await markRequestCompleted(requestId: requestId) }
            }
        }
        
        dataStatus = .loading
        if configuration.enablePerformanceMonitoring {
            performanceMonitor.recordMetric(PerformanceMetric(
                type: .throughput,
                value: 1.0,
                unit: "count",
                context: "getBookingData"
            ))
        }
        
        do {
            // 根据缓存策略获取数据
            if let cachedData = try await getCachedDataWithStrategy() {
                print("✅ [BookingDataManager] 使用缓存数据")
                if configuration.enablePerformanceMonitoring {
                    performanceMonitor.recordMetric(PerformanceMetric(
                        type: .cacheHitRate,
                        value: 1.0,
                        unit: "count",
                        context: "cacheHit"
                    ))
                }
                currentData = cachedData.data
                dataStatus = .loaded
                dataSubject.send(cachedData.data)
                
                // 记录响应时间
                if configuration.enablePerformanceMonitoring {
                    let responseTime = CFAbsoluteTimeGetCurrent() - startTime
                    performanceMonitor.recordMetric(PerformanceMetric(
                        type: .executionTime,
                        value: responseTime,
                        unit: "seconds",
                        context: "cacheResponse"
                    ))
                }
                
                let result = cachedData.data
                // 通知等待的请求
                notifyWaitingRequests(requestId: requestId, result: .success(result))
                return result
            }
            
            // 缓存无效，从服务获取新数据（带重试）
            print("🔄 [BookingDataManager] 缓存无效，从服务获取新数据")
            let result = try await fetchAndCacheNewDataWithRetry(maxRetries: actualMaxRetries, startTime: startTime)
            // 通知等待的请求
            notifyWaitingRequests(requestId: requestId, result: .success(result))
            return result
            
        } catch {
            print("❌ [BookingDataManager] 获取数据失败: \(error.localizedDescription)")
            dataStatus = .error(error.localizedDescription)
            // 通知等待的请求
            notifyWaitingRequests(requestId: requestId, result: .failure(error))
            throw error
        }
    }
    
    /// 强制刷新预订数据
    /// - Returns: 新的预订数据
    /// - Throws: BookingDataError
    func refreshBookingData() async throws -> BookingData {
        let requestId = "refreshBookingData"
        let startTime = CFAbsoluteTimeGetCurrent()
        
        print("🔄 [BookingDataManager] 强制刷新数据...")
        
        // 请求去重
        if configuration.enableRequestDeduplication {
            let isInProgress = await isRequestInProgress(requestId: requestId)
            if isInProgress {
                print("⏳ [BookingDataManager] 等待现有刷新请求完成...")
                return try await waitForRequest(requestId: requestId)
            }
        }
        
        if configuration.enableRequestDeduplication {
            await markRequestStarted(requestId: requestId)
        }
        
        defer {
            if configuration.enableRequestDeduplication {
                Task { await markRequestCompleted(requestId: requestId) }
            }
        }
        
        dataStatus = .loading
        if configuration.enablePerformanceMonitoring {
            performanceMonitor.recordMetric(PerformanceMetric(
                type: .throughput,
                value: 1.0,
                unit: "count",
                context: "getBookingData"
            ))
        }
        
        do {
            // 刷新时使用更多的重试次数
            let refreshRetries = configuration.maxRetryAttempts > 1 ? configuration.maxRetryAttempts + 2 : 1
            return try await fetchAndCacheNewDataWithRetry(maxRetries: refreshRetries, startTime: startTime)
        } catch {
            print("❌ [BookingDataManager] 刷新数据失败: \(error.localizedDescription)")
            dataStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    /// 获取当前数据状态
    /// - Returns: 数据状态
    func getDataStatus() async -> DataStatus {
        return dataStatus
    }
    
    /// 数据发布者
    var dataPublisher: AnyPublisher<BookingData, Never> {
        return dataSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 私有方法
    
    /// 根据缓存策略获取缓存数据
    /// - Returns: 缓存的预订数据，如果无效则返回nil
    /// - Throws: BookingDataError
    private func getCachedDataWithStrategy() async throws -> CachedBookingData? {
        // 如果bookingCache实现了CacheStrategyProtocol，则调用其方法
        if let strategyCache = bookingCache as? CacheStrategyProtocol {
            return try await strategyCache.getCachedDataWithStrategy(strategy: configuration.cacheStrategy)
        }
        
        // 否则使用默认的磁盘缓存策略
        return try await getCachedDataFromDisk()
    }
    
    /// 从内存获取缓存数据
    /// - Returns: 缓存的预订数据，如果无效则返回nil
    /// - Throws: BookingDataError
    private func getCachedDataFromMemory() async throws -> CachedBookingData? {
        // 如果bookingCache实现了CacheStrategyProtocol，则调用其方法
        if let strategyCache = bookingCache as? CacheStrategyProtocol {
            return try await strategyCache.getCachedDataFromMemory()
        }
        
        // 否则返回nil
        return nil
    }
    
    /// 从磁盘获取缓存数据
    /// - Returns: 缓存的预订数据，如果无效则返回nil
    /// - Throws: BookingDataError
    private func getCachedDataFromDisk() async throws -> CachedBookingData? {
        // 如果bookingCache实现了CacheStrategyProtocol，则调用其方法
        if let strategyCache = bookingCache as? CacheStrategyProtocol {
            return try await strategyCache.getCachedDataFromDisk()
        }
        
        // 否则使用默认的load方法
        return try bookingCache.load()
    }
    
    /// 智能缓存策略
    /// - Returns: 缓存的预订数据，如果无效则返回nil
    /// - Throws: BookingDataError
    private func getCachedDataSmart() async throws -> CachedBookingData? {
        // 如果bookingCache实现了CacheStrategyProtocol，则调用其方法
        if let strategyCache = bookingCache as? CacheStrategyProtocol {
            return try await strategyCache.getCachedDataSmart()
        }
        
        // 否则使用默认的磁盘缓存策略
        return try await getCachedDataFromDisk()
    }
    
    /// 获取有效的缓存数据（异步版本，保持向后兼容）
    /// - Returns: 缓存的预订数据，如果无效则返回nil
    /// - Throws: BookingDataError
    private func getCachedDataIfValidAsync() async throws -> CachedBookingData? {
        return try await getCachedDataWithStrategy()
    }
    
    /// 获取有效的缓存数据（同步版本，保持向后兼容）
    /// - Returns: 缓存的预订数据，如果无效则返回nil
    /// - Throws: BookingDataError
    private func getCachedDataIfValid() async throws -> CachedBookingData? {
        print("🔍 [BookingDataManager] 检查缓存数据...")
        
        let cachedData = try bookingCache.load()
        
        if let cachedData = cachedData {
            if cachedData.isValid {
                print("✅ [BookingDataManager] 找到有效缓存数据")
                return cachedData
            } else {
                print("⚠️ [BookingDataManager] 缓存数据已过期")
                return nil
            }
        } else {
            print("ℹ️ [BookingDataManager] 无缓存数据")
            return nil
        }
    }
    
    /// 获取新数据并缓存（带重试机制）
    /// - Parameters:
    ///   - maxRetries: 最大重试次数
    ///   - startTime: 请求开始时间
    /// - Returns: 新的预订数据
    /// - Throws: BookingDataError
    private func fetchAndCacheNewDataWithRetry(maxRetries: Int, startTime: CFAbsoluteTime) async throws -> BookingData {
        print("🌐 [BookingDataManager] 从服务获取新数据...")
        
        // 直接使用BookingService，它已经有内置的重试机制
        // BookingDataManager层面的重试主要用于处理缓存和验证失败
        do {
            let (newData, timestamp) = try await bookingService.fetchBookingDataWithTimestamp()
            
            // 数据验证
            if configuration.enableDataValidation {
                try validateBookingData(newData)
            }
            
            // 检查数据是否过期
            if newData.isExpired {
                print("⚠️ [BookingDataManager] 获取的数据已过期")
                dataStatus = .expired
                throw BookingDataError.dataExpired("数据已过期")
            }
            
            // 根据缓存策略保存到缓存
            try await saveDataWithStrategy(newData, timestamp: timestamp)
            
            // 更新状态
            currentData = newData
            dataStatus = .loaded
            dataSubject.send(newData)
            
            // 记录响应时间
            if configuration.enablePerformanceMonitoring {
                let responseTime = CFAbsoluteTimeGetCurrent() - startTime
                performanceMonitor.recordMetric(PerformanceMetric(
                    type: .executionTime,
                    value: responseTime,
                    unit: "seconds",
                    context: "serviceResponse"
                ))
            }
            
            print("✅ [BookingDataManager] 成功获取并缓存新数据")
            return newData
            
        } catch {
            print("❌ [BookingDataManager] 获取数据失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 获取新数据并缓存（保持向后兼容）
    /// - Returns: 新的预订数据
    /// - Throws: BookingDataError
    private func fetchAndCacheNewData() async throws -> BookingData {
        return try await fetchAndCacheNewDataWithRetry(maxRetries: 1, startTime: CFAbsoluteTimeGetCurrent())
    }
    
    /// 根据缓存策略保存数据
    /// - Parameters:
    ///   - data: 预订数据
    ///   - timestamp: 时间戳
    /// - Throws: BookingDataError
    private func saveDataWithStrategy(_ data: BookingData, timestamp: Date) async throws {
        // 如果bookingCache实现了CacheStrategyProtocol，则调用其方法
        if let strategyCache = bookingCache as? CacheStrategyProtocol {
            try await strategyCache.saveDataWithStrategy(data, timestamp: timestamp, strategy: configuration.cacheStrategy)
        } else {
            // 否则使用默认的save方法
            try bookingCache.save(data, timestamp: timestamp)
        }
    }
    
    /// 智能保存策略
    /// - Parameters:
    ///   - data: 预订数据
    ///   - timestamp: 时间戳
    /// - Throws: BookingDataError
    private func saveDataSmart(_ data: BookingData, timestamp: Date) async throws {
        let expiryTime = Date().addingTimeInterval(300) // 5分钟后过期
        let cachedData = CachedBookingData(data: data, timestamp: timestamp, expiryTime: expiryTime)
        
        // 获取准确的数据大小和系统内存信息
        let dataSize: Int
        let memoryInfo: (totalMemory: UInt64, availableMemory: UInt64)
        let decision: CacheStrategy
        
        if let strategyCache = bookingCache as? CacheStrategyProtocol {
            dataSize = strategyCache.calculateAccurateDataSize(data)
            memoryInfo = strategyCache.getMemoryInfo()
            decision = strategyCache.makeSmartCacheDecision(
                dataSize: dataSize,
                availableMemory: memoryInfo.availableMemory,
                totalMemory: memoryInfo.totalMemory
            )
        } else {
            // 使用默认值
            dataSize = 1024
            memoryInfo = (totalMemory: 1024 * 1024 * 1024, availableMemory: 512 * 1024 * 1024)
            decision = .diskOnly
        }
        
        let formattedSize: String
        if let strategyCache = bookingCache as? CacheStrategyProtocol {
            formattedSize = strategyCache.formatBytes(dataSize)
        } else {
            formattedSize = "\(dataSize) bytes"
        }
        
        switch decision {
        case .memoryOnly:
            // 暂时禁用异步内存缓存
            print("💾 [BookingDataManager] 智能选择：内存缓存已暂时禁用 (数据大小: \(formattedSize))")
            
        case .diskOnly:
            try bookingCache.save(data, timestamp: timestamp)
            print("💾 [BookingDataManager] 智能选择：磁盘缓存 (数据大小: \(formattedSize))")
            
        case .hybrid:
            // 暂时禁用异步内存缓存，只保存到磁盘
            try bookingCache.save(data, timestamp: timestamp)
            print("💾 [BookingDataManager] 智能选择：混合缓存已暂时禁用内存部分 (数据大小: \(formattedSize))")
            
        case .smart:
            // 智能策略暂时只保存到磁盘
            try bookingCache.save(data, timestamp: timestamp)
            print("💾 [BookingDataManager] 智能选择：智能缓存暂时只保存到磁盘 (数据大小: \(formattedSize))")
            
        case .disabled:
            print("💾 [BookingDataManager] 缓存已禁用，跳过保存 (数据大小: \(formattedSize))")
        }
    }
    
    
    
    
    
    
    
    
    
    /// 验证预订数据
    /// - Parameter data: 预订数据
    /// - Throws: BookingDataError
    private func validateBookingData(_ data: BookingData) throws {
        // 基本验证
        guard !data.shipReference.isEmpty else {
            throw BookingDataError.invalidJSON("船舶参考号不能为空")
        }
        
        guard !data.segments.isEmpty else {
            throw BookingDataError.invalidJSON("航段信息不能为空")
        }
        
        // 暂时禁用航段数据验证
        print("ℹ️ [BookingDataManager] 航段数据验证功能已暂时禁用")
        
        print("✅ [BookingDataManager] 数据验证通过")
    }
    
    /// 智能错误分类（使用ErrorHandler）
    /// - Parameter error: 错误对象
    /// - Returns: 错误处理建议（是否应该重试，重试延迟）
    private func classifyError(_ error: Error) -> (shouldRetry: Bool, retryDelay: TimeInterval, errorType: String) {
        // 使用ErrorHandler处理错误并获取BookingDataError
        let bookingError: BookingDataError
        if let existingBookingError = error as? BookingDataError {
            bookingError = existingBookingError
        } else {
            bookingError = ErrorHandler.handleGenericError(error, context: "BookingDataManager")
        }
        
        // 根据BookingDataError的属性决定重试策略
        let shouldRetry = bookingError.isRetryable
        let retryDelay: TimeInterval
        
        switch bookingError.category {
        case .network:
            retryDelay = 2.0
        case .fileSystem:
            retryDelay = 1.0
        case .cache:
            retryDelay = 0.5
        case .dataFormat:
            retryDelay = shouldRetry ? 1.0 : 0
        case .internal:
            retryDelay = 0
        case .configuration:
            retryDelay = 0
        case .permission:
            retryDelay = 0
        case .resource:
            retryDelay = 1.0
        case .compatibility:
            retryDelay = 0
        }
        
        return (shouldRetry: shouldRetry, retryDelay: retryDelay, errorType: bookingError.category.rawValue)
    }
    
    
    
    // MARK: - 请求去重支持方法
    
    /// 检查请求是否正在进行
    /// - Parameter requestId: 请求ID
    /// - Returns: 是否正在进行
    private func isRequestInProgress(requestId: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            requestQueue.async {
                let isInProgress = self.ongoingRequests.contains(requestId)
                continuation.resume(returning: isInProgress)
            }
        }
    }
    
    /// 标记请求开始
    /// - Parameter requestId: 请求ID
    private func markRequestStarted(requestId: String) async {
        await withCheckedContinuation { continuation in
            requestQueue.async(flags: .barrier) {
                self.ongoingRequests.insert(requestId)
                continuation.resume()
            }
        }
    }
    
    /// 标记请求完成
    /// - Parameter requestId: 请求ID
    private func markRequestCompleted(requestId: String) async {
        await withCheckedContinuation { continuation in
            requestQueue.async(flags: .barrier) {
                self.ongoingRequests.remove(requestId)
                continuation.resume()
            }
        }
    }
    
    /// 等待现有请求完成
    /// - Parameter requestId: 请求ID
    /// - Returns: 请求结果
    /// - Throws: BookingDataError
    private func waitForRequest(requestId: String) async throws -> BookingData {
        return try await withCheckedThrowingContinuation { continuation in
            requestQueue.async(flags: .barrier) {
                if self.requestContinuations[requestId] == nil {
                    self.requestContinuations[requestId] = []
                }
                self.requestContinuations[requestId]?.append(continuation)
            }
        }
    }
    
    /// 通知等待的请求
    /// - Parameters:
    ///   - requestId: 请求ID
    ///   - result: 请求结果
    private func notifyWaitingRequests(requestId: String, result: Result<BookingData, Error>) {
        requestQueue.async(flags: .barrier) {
            guard let continuations = self.requestContinuations[requestId] else { return }
            
            for continuation in continuations {
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            
            self.requestContinuations.removeValue(forKey: requestId)
        }
    }
}

// MARK: - 数据管理器扩展
extension BookingDataManager {
    
    /// 获取缓存统计信息（同步版本，保持向后兼容）
    /// - Returns: 缓存统计信息字符串
    func getCacheStatistics() -> String {
        return bookingCache.getCacheStatistics()
    }
    
    /// 获取详细的缓存统计信息
    /// - Returns: 缓存统计信息
    func getCacheStatistics() -> CacheStatistics {
        // 如果bookingCache实现了AdvancedCacheProtocol，则调用其getStatistics方法
        if let advancedCache = bookingCache as? AdvancedCacheProtocol {
            return advancedCache.getStatistics()
        }
        
        // 否则返回默认统计信息
        return CacheStatistics(
            totalItems: 0,
            hitCount: 0,
            missCount: 0,
            evictionCount: 0,
            memoryUsage: 0,
            hitRate: 0.0,
            averageResponseTime: 0.0,
            topKeys: []
        )
    }
    
    /// 清除缓存（同步版本，保持向后兼容）
    /// - Throws: BookingDataError
    func clearCache() throws {
        print("🗑️ [BookingDataManager] 清除缓存...")
        try bookingCache.clearLegacyCache()
        print("✅ [BookingDataManager] 缓存已清除")
    }
    
    /// 缓存预热
    func warmupCache() async {
        print("🔥 [BookingDataManager] 开始缓存预热...")
        
        do {
            // 尝试获取数据并缓存
            let _ = try await getBookingDataWithRetry(maxRetries: 1)
            print("✅ [BookingDataManager] 缓存预热完成")
        } catch {
            print("⚠️ [BookingDataManager] 缓存预热失败: \(error.localizedDescription)")
        }
    }
    
    /// 智能缓存预热
    /// - Parameter strategy: 预热策略
    func smartWarmupCache(strategy: WarmupStrategy = .aggressive) async {
        print("🔥 [BookingDataManager] 开始智能缓存预热 (策略: \(strategy))...")
        
        switch strategy {
        case .conservative:
            // 保守策略：只预热当前数据
            await warmupCache()
            
        case .aggressive:
            // 激进策略：预热当前数据并预测性加载
            await performAggressiveWarmup()
            
        case .predictive:
            // 预测策略：基于使用模式预测性加载
            await performPredictiveWarmup()
        }
    }
    
    /// 执行激进预热
    private func performAggressiveWarmup() async {
        // 预热当前数据
        await warmupCache()
        
        // 预热相关数据（如果有的话）
        // 这里可以添加更多预热逻辑
        print("🚀 [BookingDataManager] 激进预热完成")
    }
    
    /// 执行预测性预热
    private func performPredictiveWarmup() async {
        // 基于历史使用模式进行预测性预热
        let usagePattern = analyzeUsagePattern()
        
        if usagePattern.shouldPreload {
            print("🔮 [BookingDataManager] 基于使用模式进行预测性预热...")
            await warmupCache()
        } else {
            print("ℹ️ [BookingDataManager] 使用模式显示无需预热")
        }
    }
    
    /// 分析使用模式
    /// - Returns: 使用模式分析结果
    private func analyzeUsagePattern() -> DataManagerUsagePattern {
        // 简化的使用模式分析
        let currentHour = Calendar.current.component(.hour, from: Date())
        let isBusinessHours = currentHour >= 9 && currentHour <= 17
        
        return DataManagerUsagePattern(
            shouldPreload: isBusinessHours,
            confidence: isBusinessHours ? 0.8 : 0.3,
            reason: isBusinessHours ? "工作时间高使用率" : "非工作时间低使用率"
        )
    }
    
    /// 启动后台刷新
    func startBackgroundRefresh() {
        guard configuration.enableBackgroundRefresh else {
            print("ℹ️ [BookingDataManager] 后台刷新已禁用")
            return
        }
        
        guard !isDestroyed else {
            print("⚠️ [BookingDataManager] 管理器已销毁，无法启动后台刷新")
            return
        }
        
        print("🔄 [BookingDataManager] 启动后台刷新...")
        
        // 每5分钟检查一次数据是否需要刷新
        backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performBackgroundRefresh()
            }
        }
    }
    
    /// 停止后台刷新
    func stopBackgroundRefresh() {
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
        print("⏹️ [BookingDataManager] 后台刷新已停止")
    }
    
    /// 获取资源使用情况
    /// - Returns: 资源使用报告
    func getResourceUsage() -> ResourceUsageReport {
        let memoryInfo: (totalMemory: UInt64, availableMemory: UInt64)
        if let strategyCache = bookingCache as? CacheStrategyProtocol {
            memoryInfo = strategyCache.getMemoryInfo()
        } else {
            memoryInfo = (totalMemory: 1024 * 1024 * 1024, availableMemory: 512 * 1024 * 1024)
        }
        
        let activeRequests = requestContinuations.values.flatMap { $0 }.count
        let isBackgroundRefreshActive = backgroundRefreshTimer != nil
        
        return ResourceUsageReport(
            activeRequests: activeRequests,
            isBackgroundRefreshActive: isBackgroundRefreshActive,
            memoryUsage: memoryInfo.totalMemory,
            availableMemory: memoryInfo.availableMemory,
            isDestroyed: isDestroyed
        )
    }
    
    /// 健康检查
    /// - Returns: 健康状态
    func healthCheck() -> HealthStatus {
        var issues: [String] = []
        
        // 检查是否已销毁
        if isDestroyed {
            issues.append("管理器已销毁")
        }
        
        // 检查内存使用
        let memoryInfo: (totalMemory: UInt64, availableMemory: UInt64)
        if let strategyCache = bookingCache as? CacheStrategyProtocol {
            memoryInfo = strategyCache.getMemoryInfo()
        } else {
            memoryInfo = (totalMemory: 1024 * 1024 * 1024, availableMemory: 512 * 1024 * 1024)
        }
        let memoryUsagePercent = Double(memoryInfo.totalMemory - memoryInfo.availableMemory) / Double(memoryInfo.totalMemory) * 100
        
        if memoryUsagePercent > 90 {
            issues.append("内存使用率过高: \(String(format: "%.1f", memoryUsagePercent))%")
        }
        
        // 检查活跃请求数量
        let activeRequests = requestContinuations.values.flatMap { $0 }.count
        if activeRequests > 10 {
            issues.append("活跃请求过多: \(activeRequests)")
        }
        
        // 检查后台刷新状态
        if configuration.enableBackgroundRefresh && !isDestroyed && backgroundRefreshTimer == nil {
            issues.append("后台刷新未启动")
        }
        
        let isHealthy = issues.isEmpty
        return HealthStatus(
            isHealthy: isHealthy,
            issues: issues,
            timestamp: Date()
        )
    }
    
    /// 强制清理资源
    func forceCleanup() {
        print("🧹 [BookingDataManager] 执行强制资源清理...")
        cleanup()
    }
    
    // MARK: - 测试支持方法
    
    /// 设置测试数据（仅用于测试）
    /// - Parameter testData: 测试数据
    func setTestData(_ testData: BookingData) {
        #if DEBUG
        currentData = testData
        dataStatus = .loaded
        dataSubject.send(testData)
        print("🧪 [BookingDataManager] 测试数据已设置")
        #else
        print("⚠️ [BookingDataManager] setTestData 仅在调试模式下可用")
        #endif
    }
    
    /// 模拟网络错误（仅用于测试）
    /// - Parameter error: 模拟错误
    func simulateNetworkError(_ error: BookingDataError) {
        #if DEBUG
        dataStatus = .error(error.localizedDescription)
        print("🧪 [BookingDataManager] 模拟网络错误: \(error.localizedDescription)")
        #else
        print("⚠️ [BookingDataManager] simulateNetworkError 仅在调试模式下可用")
        #endif
    }
    
    /// 重置为初始状态（仅用于测试）
    func resetToInitialState() {
        #if DEBUG
        currentData = nil
        dataStatus = .loading
        resetPerformanceMetrics()
        print("🧪 [BookingDataManager] 已重置为初始状态")
        #else
        print("⚠️ [BookingDataManager] resetToInitialState 仅在调试模式下可用")
        #endif
    }
    
    /// 获取内部状态（仅用于测试）
    /// - Returns: 内部状态信息
    func getInternalState() -> InternalState {
        #if DEBUG
        return InternalState(
            currentData: currentData,
            dataStatus: dataStatus,
            isDestroyed: isDestroyed,
            activeRequests: requestContinuations.values.flatMap { $0 }.count,
            isBackgroundRefreshActive: backgroundRefreshTimer != nil
        )
        #else
        return InternalState(
            currentData: nil,
            dataStatus: .loading,
            isDestroyed: false,
            activeRequests: 0,
            isBackgroundRefreshActive: false
        )
        #endif
    }
    
    /// 执行后台刷新
    private func performBackgroundRefresh() async {
        guard !isDestroyed else {
            print("⚠️ [BookingDataManager] 管理器已销毁，停止后台刷新")
            return
        }
        
        guard let currentData = currentData else {
            print("ℹ️ [BookingDataManager] 无当前数据，跳过后台刷新")
            return
        }
        
        // 检查数据是否即将过期（提前1小时刷新）
        let expiryDate = ISO8601DateFormatter().date(from: currentData.expiryTime)
        let refreshThreshold = Date().addingTimeInterval(3600) // 1小时后
        
        if let expiryDate = expiryDate, expiryDate < refreshThreshold {
            print("🔄 [BookingDataManager] 数据即将过期，执行后台刷新...")
            
            do {
                let _ = try await refreshBookingData()
                print("✅ [BookingDataManager] 后台刷新完成")
            } catch {
                print("⚠️ [BookingDataManager] 后台刷新失败: \(error.localizedDescription)")
            }
        } else {
            print("ℹ️ [BookingDataManager] 数据未过期，跳过后台刷新")
        }
    }
    
    /// 获取当前数据的详细信息
    /// - Returns: 数据详细信息字符串
    func getCurrentDataInfo() -> String {
        guard let data = currentData else {
            return "无当前数据"
        }
        
        var info = "📊 当前数据信息:\n"
        info += "   - 船舶参考号: \(data.shipReference)\n"
        info += "   - 过期时间: \(data.formattedExpiryTime)\n"
        info += "   - 持续时间: \(data.formattedDuration)\n"
        info += "   - 航段数量: \(data.segments.count)\n"
        info += "   - 数据状态: \(dataStatus)\n"
        info += "   - 是否过期: \(data.isExpired ? "是" : "否")"
        
        return info
    }
    
    /// 获取性能指标
    /// - Returns: 性能指标信息
    func getPerformanceMetrics() -> String {
        let allStats = performanceMonitor.getAllStatistics(in: nil)
        
        var metrics = "📈 性能指标:\n"
        
        // 请求数统计
        if let requestStats = allStats[.throughput] {
            metrics += "   - 总请求数: \(Int(requestStats.count))\n"
        }
        
        // 缓存命中统计
        if let cacheHitStats = allStats[.cacheHitRate] {
            metrics += "   - 缓存命中数: \(Int(cacheHitStats.count))\n"
            
            // 计算命中率
            if let requestStats = allStats[.throughput], requestStats.count > 0 {
                let hitRate = cacheHitStats.count / requestStats.count
                metrics += "   - 缓存命中率: \(String(format: "%.1f%%", hitRate * 100))\n"
            }
        }
        
        // 响应时间统计
        if let responseStats = allStats[.executionTime] {
            metrics += "   - 平均响应时间: \(String(format: "%.3f秒", responseStats.average))\n"
            metrics += "   - 最大响应时间: \(String(format: "%.3f秒", responseStats.max))\n"
            metrics += "   - 最小响应时间: \(String(format: "%.3f秒", responseStats.min))\n"
        }
        
        return metrics
    }
    
    /// 重置性能指标
    func resetPerformanceMetrics() {
        performanceMonitor.clearData(in: nil)
        print("🔄 [BookingDataManager] 性能指标已重置")
    }
    
}

// MARK: - 数据状态扩展
extension DataStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .loading:
            return "加载中"
        case .loaded:
            return "已加载"
        case .expired:
            return "已过期"
        case .error(let message):
            return "错误: \(message)"
        }
    }
}
