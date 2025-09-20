//
//  BookingServiceTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

final class BookingServiceTests: XCTestCase {
    
    private var bookingService: BookingService!
    private var testConfiguration: BookingServiceConfigurationProtocol!
    
    override func setUpWithError() throws {
        testConfiguration = BookingServiceConfigurationFactory.createTest()
        bookingService = BookingService(configuration: testConfiguration)
    }
    
    override func tearDownWithError() throws {
        bookingService = nil
        testConfiguration = nil
    }
    
    // MARK: - 数据获取测试
    
    func testFetchBookingDataSuccess() async throws {
        // 由于我们使用真实的JSON文件，这个测试会验证实际的数据获取
        let bookingData = try await bookingService.fetchBookingData()
        
        // 验证基本字段
        XCTAssertFalse(bookingData.shipReference.isEmpty)
        XCTAssertFalse(bookingData.shipToken.isEmpty)
        XCTAssertNotNil(bookingData.expiryTime)
        XCTAssertGreaterThan(bookingData.duration, 0)
        XCTAssertGreaterThan(bookingData.segments.count, 0)
        
        // 验证航段数据
        for segment in bookingData.segments {
            XCTAssertGreaterThan(segment.id, 0)
            XCTAssertFalse(segment.originAndDestinationPair.origin.code.isEmpty)
            XCTAssertFalse(segment.originAndDestinationPair.destination.code.isEmpty)
            XCTAssertFalse(segment.originAndDestinationPair.origin.displayName.isEmpty)
            XCTAssertFalse(segment.originAndDestinationPair.destination.displayName.isEmpty)
        }
    }
    
    func testFetchBookingDataWithTimestamp() async throws {
        let result = try await bookingService.fetchBookingDataWithTimestamp()
        
        XCTAssertNotNil(result.data)
        XCTAssertNotNil(result.timestamp)
        
        // 验证时间戳是最近的时间
        let timeDifference = Date().timeIntervalSince(result.timestamp)
        XCTAssertLessThan(timeDifference, 5.0) // 应该在5秒内
    }
    
    func testFetchBookingDataWithDelay() async throws {
        let startTime = Date()
        let bookingData = try await bookingService.fetchBookingDataWithDelay()
        let endTime = Date()
        
        // 验证数据获取成功
        XCTAssertFalse(bookingData.shipReference.isEmpty)
        
        // 验证延迟时间（应该大约0.5秒）
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertGreaterThan(duration, 0.4)
        XCTAssertLessThan(duration, 1.0)
    }
    
    // MARK: - 错误处理测试
    
    func testBookingServiceProtocolConformance() throws {
        // 验证BookingService实现了BookingServiceProtocol
        let service: BookingServiceProtocol = bookingService
        XCTAssertNotNil(service)
    }
    
    // MARK: - 性能测试
    
    func testFetchBookingDataPerformance() throws {
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation(description: "数据获取完成")
            
            Task {
                do {
                    _ = try await bookingService.fetchBookingData()
                    expectation.fulfill()
                } catch {
                    XCTFail("数据获取失败: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testFetchBookingDataMemoryUsage() throws {
        measure(metrics: [XCTMemoryMetric()]) {
            let expectation = XCTestExpectation(description: "内存使用测试")
            
            Task {
                do {
                    _ = try await bookingService.fetchBookingData()
                    expectation.fulfill()
                } catch {
                    XCTFail("数据获取失败: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - 并发测试
    
    func testConcurrentDataFetching() async throws {
        // 测试并发数据获取
        async let data1 = bookingService.fetchBookingData()
        async let data2 = bookingService.fetchBookingData()
        async let data3 = bookingService.fetchBookingData()
        
        let results = try await [data1, data2, data3]
        
        // 验证所有请求都成功
        XCTAssertEqual(results.count, 3)
        for result in results {
            XCTAssertFalse(result.shipReference.isEmpty)
        }
        
        // 验证数据一致性
        XCTAssertEqual(results[0].shipReference, results[1].shipReference)
        XCTAssertEqual(results[1].shipReference, results[2].shipReference)
    }
    
    // MARK: - 配置化测试
    
    func testDefaultConfiguration() throws {
        let service = BookingService()
        XCTAssertNotNil(service)
    }
    
    func testCustomConfiguration() throws {
        let customConfig = BookingServiceConfigurationFactory.createCustom(
            fileName: "test_booking",
            enableVerboseLogging: false,
            enableCaching: false
        )
        let service = BookingService(configuration: customConfig)
        XCTAssertNotNil(service)
    }
    
    func testProductionConfiguration() throws {
        let productionConfig = BookingServiceConfigurationFactory.createProduction()
        let service = BookingService(configuration: productionConfig)
        XCTAssertNotNil(service)
    }
    
    // MARK: - 缓存测试
    
    func testCacheFunctionality() async throws {
        // 使用启用缓存的配置
        let cacheConfig = BookingServiceConfigurationFactory.createCustom(
            fileName: "booking",
            enableCaching: true,
            cacheExpirationTime: 60.0
        )
        let cacheService = BookingService(configuration: cacheConfig)
        
        // 第一次获取数据
        let data1 = try await cacheService.fetchBookingData()
        XCTAssertFalse(data1.shipReference.isEmpty)
        
        // 第二次获取数据（应该从缓存获取）
        let data2 = try await cacheService.fetchBookingData()
        XCTAssertEqual(data1.shipReference, data2.shipReference)
        
        // 验证缓存统计
        let stats = cacheService.getCacheStats()
        XCTAssertGreaterThan(stats.totalItems, 0)
    }
    
    func testCacheExpiration() async throws {
        // 使用短缓存过期时间的配置
        let shortCacheConfig = BookingServiceConfigurationFactory.createCustom(
            fileName: "booking",
            enableCaching: true,
            cacheExpirationTime: 0.1 // 100ms
        )
        let cacheService = BookingService(configuration: shortCacheConfig)
        
        // 第一次获取数据
        _ = try await cacheService.fetchBookingData()
        
        // 等待缓存过期
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // 第二次获取数据（应该重新从文件读取）
        _ = try await cacheService.fetchBookingData()
    }
    
    func testClearCache() async throws {
        let cacheConfig = BookingServiceConfigurationFactory.createCustom(
            fileName: "booking",
            enableCaching: true
        )
        let cacheService = BookingService(configuration: cacheConfig)
        
        // 获取数据并缓存
        _ = try await cacheService.fetchBookingData()
        
        // 验证缓存存在
        let statsBefore = cacheService.getCacheStats()
        XCTAssertGreaterThan(statsBefore.totalItems, 0)
        
        // 清除缓存
        cacheService.clearCache()
        
        // 验证缓存已清除
        let statsAfter = cacheService.getCacheStats()
        XCTAssertEqual(statsAfter.totalItems, 0)
    }
    
    // MARK: - 重试机制测试
    
    func testRetryMechanism() async throws {
        let retryConfig = BookingServiceConfigurationFactory.createCustom(
            fileName: "booking",
            maxRetryAttempts: 2,
            retryDelay: 0.1
        )
        let retryService = BookingService(configuration: retryConfig)
        
        // 测试重试机制（正常情况下应该成功）
        let data = try await retryService.fetchBookingDataWithRetry()
        XCTAssertFalse(data.shipReference.isEmpty)
    }
    
    // MARK: - 高级缓存功能测试
    
    func testCacheStatistics() async throws {
        let cacheConfig = BookingServiceConfigurationFactory.createCustom(
            fileName: "booking",
            enableCaching: true
        )
        let cacheService = BookingService(configuration: cacheConfig)
        
        // 获取初始统计
        let initialStats = cacheService.getCacheStats()
        XCTAssertEqual(initialStats.totalItems, 0)
        XCTAssertEqual(initialStats.hitCount, 0)
        XCTAssertEqual(initialStats.missCount, 0)
        
        // 第一次获取数据（应该缓存未命中）
        _ = try await cacheService.fetchBookingData()
        let afterFirstStats = cacheService.getCacheStats()
        XCTAssertGreaterThan(afterFirstStats.missCount, 0)
        
        // 第二次获取数据（应该缓存命中）
        _ = try await cacheService.fetchBookingData()
        let afterSecondStats = cacheService.getCacheStats()
        XCTAssertGreaterThan(afterSecondStats.hitCount, 0)
        XCTAssertGreaterThan(afterSecondStats.hitRate, 0.0)
    }
    
    func testCacheWarmup() async throws {
        let cacheConfig = BookingServiceConfigurationFactory.createCustom(
            fileName: "booking",
            enableCaching: true
        )
        let cacheService = BookingService(configuration: cacheConfig)
        
        // 获取数据用于预热
        let data = try await cacheService.fetchBookingData()
        
        // 清除缓存
        cacheService.clearCache()
        XCTAssertEqual(cacheService.getCacheStats().totalItems, 0)
        
        // 预热缓存
        cacheService.warmupCache(with: data)
        XCTAssertGreaterThan(cacheService.getCacheStats().totalItems, 0)
        
        // 验证预热的数据可以立即获取
        let cachedData = try await cacheService.fetchBookingData()
        XCTAssertEqual(data.shipReference, cachedData.shipReference)
    }
    
    func testCacheRemoval() async throws {
        let cacheConfig = BookingServiceConfigurationFactory.createCustom(
            fileName: "booking",
            enableCaching: true
        )
        let cacheService = BookingService(configuration: cacheConfig)
        
        // 获取数据并缓存
        _ = try await cacheService.fetchBookingData()
        XCTAssertGreaterThan(cacheService.getCacheStats().totalItems, 0)
        
        // 移除特定缓存
        let cacheKey = "booking.json"
        cacheService.removeCache(key: cacheKey)
        
        // 验证缓存已移除
        let stats = cacheService.getCacheStats()
        XCTAssertEqual(stats.totalItems, 0)
    }
    
    func testCacheHitRate() async throws {
        let cacheConfig = BookingServiceConfigurationFactory.createCustom(
            fileName: "booking",
            enableCaching: true
        )
        let cacheService = BookingService(configuration: cacheConfig)
        
        // 多次获取数据以测试命中率
        for _ in 0..<5 {
            _ = try await cacheService.fetchBookingData()
        }
        
        let stats = cacheService.getCacheStats()
        XCTAssertGreaterThan(stats.hitRate, 0.0)
        XCTAssertLessThanOrEqual(stats.hitRate, 1.0)
        
        // 验证命中率计算正确
        let expectedHitRate = Double(stats.hitCount) / Double(stats.hitCount + stats.missCount)
        XCTAssertEqual(stats.hitRate, expectedHitRate, accuracy: 0.01)
    }
}
