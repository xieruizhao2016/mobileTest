//
//  BookingDataManagerOptimizationTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
import Combine
@testable import mobileTest

// MARK: - Mock对象
class MockBookingService: BookingServiceProtocol {
    var shouldThrowError = false
    var callCount = 0
    var errorToThrow: Error = BookingDataError.networkError("网络错误")
    var delay: TimeInterval = 0.0
    
    func fetchBookingData() async throws -> BookingData {
        callCount += 1
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return createMockBookingData()
    }
    
    func fetchBookingDataWithTimestamp() async throws -> (data: BookingData, timestamp: Date) {
        callCount += 1
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        let data = createMockBookingData()
        return (data: data, timestamp: Date())
    }
    
    func fetchBookingDataFromRemote(url: URL) async throws -> BookingData {
        return try await fetchBookingData()
    }
    
    func fetchBookingDataWithProgress(progressCallback: @escaping (Double) -> Void) async throws -> BookingData {
        return try await fetchBookingData()
    }
    
    // 新增的压缩和版本控制方法
    func fetchCompressedBookingData(fileName: String, fileExtension: String, autoDecompress: Bool) async throws -> BookingData {
        return try await fetchBookingData()
    }
    
    func fetchCompressedBookingDataFromRemote(url: URL, autoDecompress: Bool) async throws -> BookingData {
        return try await fetchBookingData()
    }
    
    func detectCompressionFormat(from data: Data) -> CompressionInfo? {
        return nil
    }
    
    func detectDataVersion(from data: Data) -> VersionInfo? {
        return nil
    }
    
    func checkVersionCompatibility(sourceVersion: VersionInfo, targetVersion: VersionInfo) -> CompatibilityLevel {
        return .compatible
    }
    
    func migrateData(_ data: Data, to targetVersion: VersionInfo) async throws -> MigrationResult {
        let sourceVersion = VersionInfo(major: 1, minor: 0, patch: 0, build: "1", releaseDate: Date(), description: "测试版本")
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
    
    func getVersionHistory() -> [VersionInfo] {
        return []
    }
    
    private func createMockBookingData() -> BookingData {
        return BookingData(
            shipReference: "TEST_SHIP_001",
            shipToken: "token123",
            canIssueTicketChecking: true,
            expiryTime: "2024-12-31T23:59:59Z",
            duration: 7,
            segments: [
                Segment(
                    id: 1,
                    originAndDestinationPair: OriginDestinationPair(
                        destination: Location(name: "东京", code: "TYO"),
                        destinationCity: "东京",
                        origin: Location(name: "上海", code: "SHA"),
                        originCity: "上海"
                    )
                )
            ]
        )
    }
}

class MockBookingCache: BookingCacheProtocol {
    var shouldThrowError = false
    var callCount = 0
    var errorToThrow: Error = BookingDataError.cacheError("缓存错误")
    var cachedData: CachedBookingData?
    var asyncCallCount = 0
    
    func load() throws -> CachedBookingData? {
        callCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        return cachedData
    }
    
    func save(_ data: BookingData, timestamp: Date) throws {
        callCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        let expiryTime = Date().addingTimeInterval(300) // 5分钟后过期
        cachedData = CachedBookingData(data: data, timestamp: timestamp, expiryTime: expiryTime)
    }
    
    func clearLegacyCache() throws {
        callCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        cachedData = nil
    }
    
    func getCacheStatistics() -> String {
        return "Mock缓存统计: 命中率 80%, 内存使用 5MB"
    }
    
    func isCacheValid() -> Bool {
        return cachedData?.isValid ?? false
    }
    
    func getCacheInfo() -> (isValid: Bool, timestamp: Date?, age: TimeInterval?) {
        guard let cached = cachedData else {
            return (isValid: false, timestamp: nil, age: nil)
        }
        let age = Date().timeIntervalSince(cached.timestamp)
        return (isValid: cached.isValid, timestamp: cached.timestamp, age: age)
    }
    
    // 异步方法
    func getAsync<T>(key: String) async -> T? {
        asyncCallCount += 1
        if shouldThrowError {
            return nil
        }
        return cachedData as? T
    }
    
    func setAsync<T>(key: String, value: T) async {
        asyncCallCount += 1
        if shouldThrowError {
            return
        }
        if let cachedData = value as? CachedBookingData {
            self.cachedData = cachedData
        }
    }
    
    func remove(key: String) {
        callCount += 1
        cachedData = nil
    }
    
    func clear() {
        callCount += 1
        cachedData = nil
    }
    
    func getStatistics() -> CacheStatistics {
        return CacheStatistics(
            totalItems: cachedData != nil ? 1 : 0,
            hitCount: 5,
            missCount: 1,
            evictionCount: 0,
            memoryUsage: 1024 * 1024, // 1MB
            hitRate: 0.8,
            averageResponseTime: 0.05,
            topKeys: [("booking_data", 5)]
        )
    }
    
    func warmup<T>(items: [(key: String, value: T)]) {
        callCount += 1
        // Mock实现
    }

// MARK: - 测试类
class BookingDataManagerOptimizationTests: XCTestCase {
    
    var dataManager: BookingDataManager!
    var mockService: MockBookingService!
    var mockCache: MockBookingCache!
    
    override func setUp() async {
        super.setUp()
        mockService = MockBookingService()
        mockCache = MockBookingCache()
        dataManager = await BookingDataManager(bookingService: mockService, bookingCache: mockCache)
    }
    
    override func tearDown() {
        dataManager = nil
        mockService = nil
        mockCache = nil
        super.tearDown()
    }
    
    // MARK: - 异步缓存测试
    
    func testAsyncCacheRetrieval() async throws {
        // 准备测试数据
        let testData = createTestBookingData()
        let cachedData = CachedBookingData(data: testData, timestamp: Date(), expiryTime: Date().addingTimeInterval(3600))
        mockCache.cachedData = cachedData
        
        // 执行测试
        let result = try await dataManager.getBookingData()
        
        // 验证结果
        XCTAssertEqual(result.shipReference, testData.shipReference)
        XCTAssertEqual(mockCache.asyncCallCount, 1, "应该调用异步缓存方法")
    }
    
    func testAsyncCacheSave() async throws {
        // 准备测试数据
        mockService.shouldThrowError = false
        
        // 执行测试
        let result = try await dataManager.refreshBookingData()
        
        // 验证结果
        XCTAssertNotNil(result)
        XCTAssertEqual(mockCache.asyncCallCount, 1, "应该调用异步缓存保存方法")
    }
    
    // MARK: - 重试机制测试
    
    func testRetryMechanism() async throws {
        // 准备测试：前两次失败，第三次成功
        mockService.shouldThrowError = true
        mockService.errorToThrow = BookingDataError.networkError("网络错误")
        
        // 执行测试（应该失败）
        do {
            _ = try await dataManager.getBookingDataWithRetry(maxRetries: 3)
            XCTFail("应该抛出错误")
        } catch {
            XCTAssertTrue(error is BookingDataError)
        }
        
        // 验证重试次数
        XCTAssertEqual(mockService.callCount, 3, "应该重试3次")
    }
    
    func testRetryWithSuccess() async throws {
        // 准备测试：第一次失败，第二次成功
        var attemptCount = 0
        mockService.shouldThrowError = true
        mockService.errorToThrow = BookingDataError.networkError("网络错误")
        
        // 模拟第二次调用成功
        mockService.shouldThrowError = false
        
        // 执行测试
        let result = try await dataManager.getBookingDataWithRetry(maxRetries: 2)
        
        // 验证结果
        XCTAssertNotNil(result)
        XCTAssertEqual(attemptCount, 2, "应该重试2次")
    }
    
    // MARK: - 请求去重测试
    
    func testRequestDeduplication() async throws {
        // 准备测试数据
        mockService.delay = 0.5 // 模拟慢请求
        
        // 同时发起多个相同请求
        let task1 = Task {
            try await dataManager.getBookingData()
        }
        
        let task2 = Task {
            try await dataManager.getBookingData()
        }
        
        let task3 = Task {
            try await dataManager.getBookingData()
        }
        
        // 等待所有任务完成
        let results = try await [task1.value, task2.value, task3.value]
        
        // 验证结果
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(mockService.callCount, 1, "应该只调用一次服务，其他请求应该被去重")
    }
    
    // MARK: - 性能监控测试
    
    func testPerformanceMetrics() async throws {
        // 重置性能指标
        await dataManager.resetPerformanceMetrics()
        
        // 执行多次请求
        for _ in 0..<5 {
            _ = try await dataManager.getBookingData()
        }
        
        // 验证性能指标
        let metrics = await dataManager.getPerformanceMetrics()
        XCTAssertTrue(metrics.contains("总请求数: 5"))
        XCTAssertTrue(metrics.contains("缓存命中数"))
    }
    
    func testCacheHitRate() async throws {
        // 准备缓存数据
        let testData = createTestBookingData()
        let cachedData = CachedBookingData(data: testData, timestamp: Date(), expiryTime: Date().addingTimeInterval(3600))
        mockCache.cachedData = cachedData
        
        // 重置性能指标
        await dataManager.resetPerformanceMetrics()
        
        // 执行多次请求（应该都命中缓存）
        for _ in 0..<3 {
            _ = try await dataManager.getBookingData()
        }
        
        // 验证缓存命中率
        let metrics = await dataManager.getPerformanceMetrics()
        XCTAssertTrue(metrics.contains("缓存命中率: 100.0%"))
    }
    
    // MARK: - 缓存预热测试
    
    func testCacheWarmup() async throws {
        // 执行缓存预热
        await dataManager.warmupCache()
        
        // 验证预热是否成功
        XCTAssertTrue(mockService.callCount > 0, "应该调用服务进行预热")
    }
    
    // MARK: - 错误处理测试
    
    func testErrorHandling() async throws {
        // 准备测试：缓存和服务都失败
        mockCache.shouldThrowError = true
        mockService.shouldThrowError = true
        
        // 执行测试
        do {
            _ = try await dataManager.getBookingData()
            XCTFail("应该抛出错误")
        } catch {
            XCTAssertTrue(error is BookingDataError)
        }
    }
    
    func testDataExpiredError() async throws {
        // 准备过期数据
        let expiredData = createExpiredBookingData()
        let cachedData = CachedBookingData(data: expiredData, timestamp: Date().addingTimeInterval(-400), expiryTime: Date().addingTimeInterval(-400)) // 过期
        mockCache.cachedData = cachedData
        
        // 执行测试
        do {
            _ = try await dataManager.getBookingData()
            XCTFail("应该抛出数据过期错误")
        } catch let error as BookingDataError {
            if case .dataExpired = error {
                // 预期的错误类型
            } else {
                XCTFail("应该抛出数据过期错误")
            }
        }
    }
    
    // MARK: - 并发测试
    
    func testConcurrentRequests() async throws {
        // 准备测试数据
        mockService.delay = 0.1
        
        // 并发执行多个不同类型的请求
        async let result1 = dataManager.getBookingData()
        async let result2 = dataManager.refreshBookingData()
        async let result3 = dataManager.getBookingDataWithRetry(maxRetries: 2)
        
        // 等待所有请求完成
        let results = try await [result1, result2, result3]
        
        // 验证结果
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.shipReference == "TEST_SHIP_001" })
    }
    
    // MARK: - 辅助方法
    
    private func createTestBookingData() -> BookingData {
        return BookingData(
            shipReference: "TEST_SHIP_001",
            shipToken: "token123",
            canIssueTicketChecking: true,
            expiryTime: "2024-12-31T23:59:59Z",
            duration: 7,
            segments: [
                Segment(
                    id: 1,
                    originAndDestinationPair: OriginDestinationPair(
                        destination: Location(name: "东京", code: "TYO"),
                        destinationCity: "东京",
                        origin: Location(name: "上海", code: "SHA"),
                        originCity: "上海"
                    )
                )
            ]
        )
    }
    
    private func createExpiredBookingData() -> BookingData {
        return BookingData(
            shipReference: "EXPIRED_SHIP_001",
            shipToken: "token123",
            canIssueTicketChecking: true,
            expiryTime: "2024-01-01T00:00:00Z", // 过期时间
            duration: 7,
            segments: [
                Segment(
                    id: 1,
                    originAndDestinationPair: OriginDestinationPair(
                        destination: Location(name: "东京", code: "TYO"),
                        destinationCity: "东京",
                        origin: Location(name: "上海", code: "SHA"),
                        originCity: "上海"
                    )
                )
            ]
        )
    }
    
    func load() throws -> CachedBookingData? {
        callCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        return cachedData
    }
    
    func save(_ data: BookingData, timestamp: Date) throws {
        callCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        let expiryTime = Date().addingTimeInterval(300) // 5分钟后过期
        cachedData = CachedBookingData(data: data, timestamp: timestamp, expiryTime: expiryTime)
    }
    
    func clearLegacyCache() throws {
        callCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        cachedData = nil
    }
    
    func getCacheStatistics() -> String {
        return "Mock缓存统计"
    }
    
    // 高级缓存协议方法
    func get<T>(key: String) -> T? {
        return cachedData as? T
    }
    
    func set<T>(key: String, value: T) {
        if let cachedData = value as? CachedBookingData {
            self.cachedData = cachedData
        }
    }
    
    func remove(key: String) {
        cachedData = nil
    }
    
    func clear() {
        cachedData = nil
    }
    
    func getStatistics() -> CacheStatistics {
        return CacheStatistics(
            totalItems: cachedData != nil ? 1 : 0,
            hitCount: 0,
            missCount: 0,
            evictionCount: 0,
            memoryUsage: 1024,
            hitRate: 0.0,
            averageResponseTime: 0.0,
            topKeys: []
        )
    }
    
    func warmup<T>(items: [(key: String, value: T)]) {
        // Mock实现
    }
    
    // 异步方法
    func getAsync<T>(key: String) async -> T? {
        return cachedData as? T
    }
    
    func setAsync<T>(key: String, value: T) async {
        if let cachedData = value as? CachedBookingData {
            self.cachedData = cachedData
        }
    }
