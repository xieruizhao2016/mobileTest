//
//  CacheOptimizationTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

class CacheOptimizationTests: XCTestCase {
    
    var cache: BookingCache!
    
    override func setUp() {
        super.setUp()
        cache = BookingCacheFactory.createDefault()
    }
    
    override func tearDown() {
        cache = nil
        super.tearDown()
    }
    
    // MARK: - 异步功能测试
    
    func testAsyncGet() async {
        // 设置测试数据
        let testData = "测试数据"
        cache.set(key: "test_key", value: testData)
        
        // 异步获取
        let result: String? = await cache.getAsync(key: "test_key")
        
        XCTAssertEqual(result, testData)
    }
    
    func testAsyncSet() async {
        let testData = "异步测试数据"
        
        // 异步设置
        await cache.setAsync(key: "async_test_key", value: testData)
        
        // 验证设置成功
        let result: String? = cache.get(key: "async_test_key")
        XCTAssertEqual(result, testData)
    }
    
    // MARK: - CacheKey 功能测试
    
    func testCacheKeyValidation() {
        let validKey = CacheKey.booking("test")
        let invalidKey = CacheKey(namespace: "", key: "test")
        
        XCTAssertTrue(validKey.isValid())
        XCTAssertFalse(invalidKey.isValid())
    }
    
    func testCacheKeyUsage() async {
        let bookingKey = CacheKey.booking("booking_123")
        let userKey = CacheKey.user("user_456")
        
        // 设置数据
        cache.set(bookingKey, value: "预订数据")
        cache.set(userKey, value: "用户数据")
        
        // 获取数据
        let bookingData: String? = cache.get(bookingKey)
        let userData: String? = cache.get(userKey)
        
        XCTAssertEqual(bookingData, "预订数据")
        XCTAssertEqual(userData, "用户数据")
    }
    
    func testNamespaceClearing() {
        // 设置不同命名空间的数据
        cache.set(CacheKey.booking("booking_1"), value: "预订1")
        cache.set(CacheKey.booking("booking_2"), value: "预订2")
        cache.set(CacheKey.user("user_1"), value: "用户1")
        
        // 清除预订命名空间
        cache.clearNamespace("booking")
        
        // 验证结果
        let bookingData1: String? = cache.get(CacheKey.booking("booking_1"))
        let bookingData2: String? = cache.get(CacheKey.booking("booking_2"))
        let userData: String? = cache.get(CacheKey.user("user_1"))
        
        XCTAssertNil(bookingData1)
        XCTAssertNil(bookingData2)
        XCTAssertEqual(userData, "用户1")
    }
    
    // MARK: - 性能监控测试
    
    func testPerformanceMetrics() {
        // 执行一些缓存操作
        cache.set(key: "key1", value: "value1")
        cache.set(key: "key2", value: "value2")
        
        let _: String? = cache.get(key: "key1")
        let _: String? = cache.get(key: "key2")
        let _: String? = cache.get(key: "key3") // 未命中
        
        let metrics = cache.getMetrics()
        
        XCTAssertGreaterThan(metrics.hitRate, 0.0)
        XCTAssertGreaterThan(metrics.averageResponseTime, 0.0)
        XCTAssertGreaterThan(metrics.memoryUsage, 0)
    }
    
    func testStatistics() {
        // 执行缓存操作
        cache.set(key: "test_key", value: "test_value")
        let _: String? = cache.get(key: "test_key")
        
        let stats = cache.getStatistics()
        
        XCTAssertEqual(stats.totalItems, 1)
        XCTAssertEqual(stats.hitCount, 1)
        XCTAssertEqual(stats.hitRate, 1.0)
        XCTAssertGreaterThan(stats.memoryUsage, 0)
    }
    
    // MARK: - 智能预热测试
    
    func testSmartWarmup() async {
        // 创建使用模式
        let usagePatterns: [String: UsagePattern] = [
            "high_priority": UsagePattern(
                accessFrequency: 0.8,
                timePattern: .always,
                priority: 90
            ),
            "low_priority": UsagePattern(
                accessFrequency: 0.2,
                timePattern: .businessHours,
                priority: 30
            )
        ]
        
        // 创建数据提供者
        let dataProvider: (String) async throws -> Any = { key in
            return "预热数据_\(key)"
        }
        
        // 创建预热策略
        let strategy = PredictiveWarmup(
            usagePatterns: usagePatterns,
            dataProvider: dataProvider
        )
        
        // 执行智能预热
        await cache.smartWarmup(strategy: strategy)
        
        // 验证预热结果
        let highPriorityData: String? = cache.get(key: "high_priority")
        let lowPriorityData: String? = cache.get(key: "low_priority")
        
        XCTAssertEqual(highPriorityData, "预热数据_high_priority")
        XCTAssertNil(lowPriorityData) // 低优先级不应该被预热
    }
    
    // MARK: - 内存估算测试
    
    func testMemoryEstimation() {
        // 设置不同大小的数据
        cache.set(key: "small", value: "小数据")
        cache.set(key: "large", value: "这是一个比较大的数据字符串，用于测试内存估算的准确性")
        
        let stats = cache.getStatistics()
        
        // 验证内存使用量大于0
        XCTAssertGreaterThan(stats.memoryUsage, 0)
        XCTAssertGreaterThan(stats.memoryUsageMB, 0.0)
    }
    
    // MARK: - 性能测试
    
    func testAsyncPerformance() async {
        self.measure {
            Task {
                for i in 0..<1000 {
                    await cache.setAsync(key: "perf_key_\(i)", value: "value_\(i)")
                }
            }
        }
    }
    
    func testGetPerformance() {
        // 预热缓存
        for i in 0..<100 {
            cache.set(key: "perf_key_\(i)", value: "value_\(i)")
        }
        
        self.measure {
            for i in 0..<1000 {
                let _: String? = cache.get(key: "perf_key_\(i % 100)")
            }
        }
    }
    
    // MARK: - 错误处理测试
    
    func testInvalidCacheKey() {
        let invalidKey = CacheKey(namespace: "", key: "")
        
        // 应该返回nil而不是崩溃
        let result: String? = cache.get(invalidKey)
        XCTAssertNil(result)
    }
    
    func testConcurrentAccess() async {
        // 并发设置
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await self.cache.setAsync(key: "concurrent_\(i)", value: "value_\(i)")
                }
            }
        }
        
        // 验证所有数据都设置成功
        for i in 0..<100 {
            let result: String? = cache.get(key: "concurrent_\(i)")
            XCTAssertEqual(result, "value_\(i)")
        }
    }
    
    // MARK: - 缓存清理测试
    
    func testEviction() {
        // 创建小容量缓存
        let smallCache = BookingCacheFactory.createCustom(
            maxItems: 5,
            maxMemoryMB: 1,
            expirationTime: 1.0
        )
        
        // 添加超过容量的数据
        for i in 0..<10 {
            smallCache.set(key: "eviction_key_\(i)", value: "value_\(i)")
        }
        
        let stats = smallCache.getStatistics()
        
        // 验证清理发生
        XCTAssertLessThanOrEqual(stats.totalItems, 5)
        XCTAssertGreaterThan(stats.evictionCount, 0)
    }
    
    // MARK: - 命名空间统计测试
    
    func testNamespaceStatistics() {
        // 设置不同命名空间的数据
        cache.set(CacheKey.booking("booking_1"), value: "预订1")
        cache.set(CacheKey.booking("booking_2"), value: "预订2")
        cache.set(CacheKey.user("user_1"), value: "用户1")
        
        // 访问数据
        let _: String? = cache.get(CacheKey.booking("booking_1"))
        let _: String? = cache.get(CacheKey.user("user_1"))
        
        let metrics = cache.getMetrics()
        
        // 验证命名空间统计
        XCTAssertEqual(metrics.namespaceStats["booking"], 1)
        XCTAssertEqual(metrics.namespaceStats["user"], 1)
    }
}
