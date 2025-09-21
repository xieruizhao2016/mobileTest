//
//  BookingCacheTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

final class BookingCacheAdvancedTests: XCTestCase {
    
    private var cacheManager: BookingCache!
    private var testConfiguration: DefaultCacheConfiguration!
    
    override func setUpWithError() throws {
        testConfiguration = DefaultCacheConfiguration(
            maxItems: 5,
            maxMemoryMB: 10,
            expirationTime: 1.0, // 1秒过期，便于测试
            enableLRU: true,
            enableStatistics: true
        )
        cacheManager = BookingCache(configuration: testConfiguration)
    }
    
    override func tearDownWithError() throws {
        cacheManager = nil
        testConfiguration = nil
    }
    
    // MARK: - 基本功能测试
    
    func testCacheSetAndGet() throws {
        // 设置缓存
        cacheManager.set(key: "test_key", value: "test_value")
        
        // 获取缓存
        let value: String? = cacheManager.get(key: "test_key")
        XCTAssertEqual(value, "test_value")
    }
    
    func testCacheMiss() throws {
        // 获取不存在的缓存
        let value: String? = cacheManager.get(key: "non_existent_key")
        XCTAssertNil(value)
    }
    
    func testCacheExpiration() async throws {
        // 设置缓存
        cacheManager.set(key: "expired_key", value: "expired_value")
        
        // 立即获取应该成功
        let immediateValue: String? = cacheManager.get(key: "expired_key")
        XCTAssertEqual(immediateValue, "expired_value")
        
        // 等待过期
        try await Task.sleep(nanoseconds: 1_100_000_000) // 1.1秒
        
        // 过期后获取应该失败
        let expiredValue: String? = cacheManager.get(key: "expired_key")
        XCTAssertNil(expiredValue)
    }
    
    func testCacheClear() throws {
        // 设置多个缓存
        cacheManager.set(key: "key1", value: "value1")
        cacheManager.set(key: "key2", value: "value2")
        
        // 验证缓存存在
        XCTAssertNotNil(cacheManager.get(key: "key1"))
        XCTAssertNotNil(cacheManager.get(key: "key2"))
        
        // 清除所有缓存
        cacheManager.clear()
        
        // 验证缓存已清除
        XCTAssertNil(cacheManager.get(key: "key1"))
        XCTAssertNil(cacheManager.get(key: "key2"))
    }
    
    func testCacheRemove() throws {
        // 设置缓存
        cacheManager.set(key: "remove_key", value: "remove_value")
        XCTAssertNotNil(cacheManager.get(key: "remove_key"))
        
        // 移除特定缓存
        cacheManager.remove(key: "remove_key")
        
        // 验证缓存已移除
        XCTAssertNil(cacheManager.get(key: "remove_key"))
    }
    
    // MARK: - 容量限制测试
    
    func testMaxItemsLimit() throws {
        // 设置超过最大数量的缓存项
        for i in 0..<10 { // 超过maxItems=5
            cacheManager.set(key: "key\(i)", value: "value\(i)")
        }
        
        // 验证缓存项数量不超过限制
        let stats = cacheManager.getStatistics()
        XCTAssertLessThanOrEqual(stats.totalItems, testConfiguration.maxItems)
    }
    
    func testLRUEviction() throws {
        // 设置缓存项直到达到限制
        for i in 0..<testConfiguration.maxItems {
            cacheManager.set(key: "key\(i)", value: "value\(i)")
        }
        
        // 访问一些项以更新LRU信息
        _ = cacheManager.get(key: "key0") as String?
        _ = cacheManager.get(key: "key1") as String?
        
        // 添加新项，应该触发LRU清理
        cacheManager.set(key: "new_key", value: "new_value")
        
        // 验证新项存在
        XCTAssertNotNil(cacheManager.get(key: "new_key"))
        
        // 验证一些旧项被清理（最久未访问的）
        let stats = cacheManager.getStatistics()
        XCTAssertLessThanOrEqual(stats.totalItems, testConfiguration.maxItems)
    }
    
    // MARK: - 统计信息测试
    
    func testCacheStatistics() throws {
        // 初始统计
        let initialStats = cacheManager.getStatistics()
        XCTAssertEqual(initialStats.totalItems, 0)
        XCTAssertEqual(initialStats.hitCount, 0)
        XCTAssertEqual(initialStats.missCount, 0)
        XCTAssertEqual(initialStats.evictionCount, 0)
        XCTAssertEqual(initialStats.hitRate, 0.0)
        
        // 设置缓存
        cacheManager.set(key: "stats_key", value: "stats_value")
        
        // 第一次获取（缓存未命中）
        _ = cacheManager.get(key: "stats_key") as String?
        let afterSetStats = cacheManager.getStatistics()
        XCTAssertGreaterThan(afterSetStats.missCount, 0)
        XCTAssertEqual(afterSetStats.hitCount, 0)
        
        // 第二次获取（缓存命中）
        _ = cacheManager.get(key: "stats_key") as String?
        let afterHitStats = cacheManager.getStatistics()
        XCTAssertGreaterThan(afterHitStats.hitCount, 0)
        XCTAssertGreaterThan(afterHitStats.hitRate, 0.0)
    }
    
    func testHitRateCalculation() throws {
        // 设置缓存
        cacheManager.set(key: "hit_rate_key", value: "hit_rate_value")
        
        // 多次访问
        for _ in 0..<5 {
            _ = cacheManager.get(key: "hit_rate_key") as String?
        }
        
        // 访问不存在的键
        for _ in 0..<2 {
            _ = cacheManager.get(key: "non_existent") as String?
        }
        
        let stats = cacheManager.getStatistics()
        XCTAssertEqual(stats.hitCount, 5)
        XCTAssertEqual(stats.missCount, 2)
        XCTAssertEqual(stats.hitRate, 5.0 / 7.0, accuracy: 0.01)
    }
    
    // MARK: - 预热功能测试
    
    func testCacheWarmup() throws {
        // 预热缓存
        let warmupItems = [
            (key: "warmup1", value: "value1"),
            (key: "warmup2", value: "value2"),
            (key: "warmup3", value: "value3")
        ]
        cacheManager.warmup(items: warmupItems)
        
        // 验证预热的数据可以立即获取
        for (key, expectedValue) in warmupItems {
            let value: String? = cacheManager.get(key: key)
            XCTAssertEqual(value, expectedValue)
        }
        
        // 验证统计信息
        let stats = cacheManager.getStatistics()
        XCTAssertEqual(stats.totalItems, warmupItems.count)
    }
    
    func testWarmupWithExistingItems() throws {
        // 先设置一些缓存
        cacheManager.set(key: "existing_key", value: "existing_value")
        
        // 预热包含已存在键的数据
        let warmupItems = [
            (key: "existing_key", value: "new_value"), // 已存在的键
            (key: "new_key", value: "new_value")       // 新键
        ]
        cacheManager.warmup(items: warmupItems)
        
        // 验证已存在的键没有被覆盖
        let existingValue: String? = cacheManager.get(key: "existing_key")
        XCTAssertEqual(existingValue, "existing_value")
        
        // 验证新键被添加
        let newValue: String? = cacheManager.get(key: "new_key")
        XCTAssertEqual(newValue, "new_value")
    }
    
    // MARK: - 并发测试
    
    func testConcurrentAccess() async throws {
        // 并发设置缓存
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    self.cacheManager.set(key: "concurrent_key\(i)", value: "concurrent_value\(i)")
                }
            }
        }
        
        // 并发获取缓存
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    _ = self.cacheManager.get(key: "concurrent_key\(i)") as String?
                }
            }
        }
        
        // 验证没有崩溃，统计信息合理
        let stats = cacheManager.getStatistics()
        XCTAssertGreaterThanOrEqual(stats.totalItems, 0)
        XCTAssertLessThanOrEqual(stats.totalItems, testConfiguration.maxItems)
    }
    
    // MARK: - 配置测试
    
    func testDifferentConfigurations() throws {
        // 测试高性能配置
        let highPerfConfig = DefaultCacheConfiguration(
            maxItems: 100,
            maxMemoryMB: 50,
            expirationTime: 600.0,
            enableLRU: true,
            enableStatistics: true
        )
        let highPerfCache = BookingCache(configuration: highPerfConfig)
        
        // 设置大量缓存项
        for i in 0..<50 {
            highPerfCache.set(key: "high_perf_key\(i)", value: "high_perf_value\(i)")
        }
        
        let stats = highPerfCache.getStatistics()
        XCTAssertEqual(stats.totalItems, 50)
        
        // 测试内存优化配置
        let memoryOptConfig = DefaultCacheConfiguration(
            maxItems: 10,
            maxMemoryMB: 5,
            expirationTime: 60.0,
            enableLRU: true,
            enableStatistics: true
        )
        let memoryOptCache = BookingCache(configuration: memoryOptConfig)
        
        // 设置超过限制的缓存项
        for i in 0..<20 {
            memoryOptCache.set(key: "memory_opt_key\(i)", value: "memory_opt_value\(i)")
        }
        
        let memoryStats = memoryOptCache.getStatistics()
        XCTAssertLessThanOrEqual(memoryStats.totalItems, 10)
    }
    
    // MARK: - 边界条件测试
    
    func testEmptyKey() throws {
        // 测试空键
        cacheManager.set(key: "", value: "empty_key_value")
        let value: String? = cacheManager.get(key: "")
        XCTAssertEqual(value, "empty_key_value")
    }
    
    func testVeryLongKey() throws {
        // 测试很长的键
        let longKey = String(repeating: "a", count: 1000)
        cacheManager.set(key: longKey, value: "long_key_value")
        let value: String? = cacheManager.get(key: longKey)
        XCTAssertEqual(value, "long_key_value")
    }
    
    func testZeroExpirationTime() throws {
        // 测试零过期时间
        let zeroExpConfig = DefaultCacheConfiguration(
            maxItems: 10,
            maxMemoryMB: 10,
            expirationTime: 0.0, // 立即过期
            enableLRU: true,
            enableStatistics: true
        )
        let zeroExpCache = BookingCache(configuration: zeroExpConfig)
        
        zeroExpCache.set(key: "zero_exp_key", value: "zero_exp_value")
        let value: String? = zeroExpCache.get(key: "zero_exp_key")
        XCTAssertNil(value) // 应该立即过期
    }
}
