//
//  BookingCacheTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

final class BookingCacheTests: XCTestCase {
    
    private var bookingCache: BookingCache!
    private var sampleBookingData: BookingData!
    
    override func setUpWithError() throws {
        bookingCache = BookingCache()
        
        // 创建测试数据
        let location = Location(
            code: "TEST",
            displayName: "Test Location",
            url: "https://test.com"
        )
        
        let originDestinationPair = OriginDestinationPair(
            destination: location,
            destinationCity: "Test City",
            origin: location,
            originCity: "Origin City"
        )
        
        let segment = Segment(
            id: 1,
            originAndDestinationPair: originDestinationPair
        )
        
        sampleBookingData = BookingData(
            shipReference: "TEST123",
            shipToken: "TOKEN123",
            canIssueTicketChecking: true,
            expiryTime: "1735689600",
            duration: 120,
            segments: [segment]
        )
        
        // 清除之前的缓存
        try? bookingCache.clear()
    }
    
    override func tearDownWithError() throws {
        // 清理测试缓存
        try? bookingCache.clear()
        bookingCache = nil
        sampleBookingData = nil
    }
    
    // MARK: - 缓存保存和加载测试
    
    func testSaveAndLoadCache() throws {
        let timestamp = Date()
        
        // 保存数据到缓存
        try bookingCache.save(sampleBookingData, timestamp: timestamp)
        
        // 加载缓存数据
        let cachedData = try bookingCache.load()
        
        XCTAssertNotNil(cachedData)
        XCTAssertEqual(cachedData?.data.shipReference, sampleBookingData.shipReference)
        XCTAssertEqual(cachedData?.data.shipToken, sampleBookingData.shipToken)
        XCTAssertEqual(cachedData?.data.canIssueTicketChecking, sampleBookingData.canIssueTicketChecking)
        XCTAssertEqual(cachedData?.data.expiryTime, sampleBookingData.expiryTime)
        XCTAssertEqual(cachedData?.data.duration, sampleBookingData.duration)
        XCTAssertEqual(cachedData?.data.segments.count, sampleBookingData.segments.count)
    }
    
    func testLoadEmptyCache() throws {
        // 测试加载空缓存
        let cachedData = try bookingCache.load()
        XCTAssertNil(cachedData)
    }
    
    func testCacheValidity() throws {
        let timestamp = Date()
        
        // 保存数据
        try bookingCache.save(sampleBookingData, timestamp: timestamp)
        
        // 立即检查缓存有效性
        XCTAssertTrue(bookingCache.isCacheValid())
        
        // 加载缓存数据并验证有效性
        let cachedData = try bookingCache.load()
        XCTAssertNotNil(cachedData)
        XCTAssertTrue(cachedData?.isValid ?? false)
    }
    
    func testCacheExpiration() throws {
        // 创建一个过期的缓存数据
        let expiredTimestamp = Date().addingTimeInterval(-400) // 6分40秒前
        try bookingCache.save(sampleBookingData, timestamp: expiredTimestamp)
        
        // 缓存应该已过期
        XCTAssertFalse(bookingCache.isCacheValid())
        
        // 加载应该返回nil
        let cachedData = try bookingCache.load()
        XCTAssertNil(cachedData)
    }
    
    func testClearCache() throws {
        let timestamp = Date()
        
        // 保存数据
        try bookingCache.save(sampleBookingData, timestamp: timestamp)
        XCTAssertTrue(bookingCache.isCacheValid())
        
        // 清除缓存
        try bookingCache.clear()
        
        // 验证缓存已清除
        XCTAssertFalse(bookingCache.isCacheValid())
        let cachedData = try bookingCache.load()
        XCTAssertNil(cachedData)
    }
    
    // MARK: - 缓存信息测试
    
    func testGetCacheInfo() throws {
        // 测试空缓存信息
        let emptyInfo = bookingCache.getCacheInfo()
        XCTAssertFalse(emptyInfo.isValid)
        XCTAssertNil(emptyInfo.timestamp)
        XCTAssertNil(emptyInfo.age)
        
        // 保存数据并测试缓存信息
        let timestamp = Date()
        try bookingCache.save(sampleBookingData, timestamp: timestamp)
        
        let cacheInfo = bookingCache.getCacheInfo()
        XCTAssertTrue(cacheInfo.isValid)
        XCTAssertNotNil(cacheInfo.timestamp)
        XCTAssertNotNil(cacheInfo.age)
        XCTAssertGreaterThanOrEqual(cacheInfo.age ?? 0, 0)
    }
    
    func testGetCacheStatistics() throws {
        // 测试空缓存统计
        let emptyStats = bookingCache.getCacheStatistics()
        XCTAssertTrue(emptyStats.contains("无效/不存在"))
        
        // 保存数据并测试统计信息
        let timestamp = Date()
        try bookingCache.save(sampleBookingData, timestamp: timestamp)
        
        let stats = bookingCache.getCacheStatistics()
        XCTAssertTrue(stats.contains("有效"))
        XCTAssertTrue(stats.contains("缓存时间"))
        XCTAssertTrue(stats.contains("缓存年龄"))
        XCTAssertTrue(stats.contains("缓存有效期"))
    }
    
    // MARK: - 缓存数据模型测试
    
    func testCachedBookingDataModel() throws {
        let timestamp = Date()
        let expiryTime = timestamp.addingTimeInterval(300) // 5分钟后过期
        
        let cachedData = CachedBookingData(
            data: sampleBookingData,
            timestamp: timestamp,
            expiryTime: expiryTime
        )
        
        XCTAssertEqual(cachedData.data.shipReference, sampleBookingData.shipReference)
        XCTAssertEqual(cachedData.timestamp, timestamp)
        XCTAssertEqual(cachedData.expiryTime, expiryTime)
        XCTAssertTrue(cachedData.isValid)
        XCTAssertGreaterThanOrEqual(cachedData.age, 0)
    }
    
    func testCachedBookingDataExpiration() throws {
        let timestamp = Date().addingTimeInterval(-400) // 6分40秒前
        let expiryTime = timestamp.addingTimeInterval(300) // 5分钟后过期（已过期）
        
        let cachedData = CachedBookingData(
            data: sampleBookingData,
            timestamp: timestamp,
            expiryTime: expiryTime
        )
        
        XCTAssertFalse(cachedData.isValid)
        XCTAssertGreaterThan(cachedData.age, 300) // 年龄应该大于5分钟
    }
    
    // MARK: - 协议一致性测试
    
    func testBookingCacheProtocolConformance() throws {
        // 验证BookingCache实现了BookingCacheProtocol
        let cache: BookingCacheProtocol = bookingCache
        XCTAssertNotNil(cache)
    }
    
    // MARK: - 错误处理测试
    
    func testCacheErrorHandling() throws {
        // 测试保存无效数据的错误处理
        // 这里我们测试缓存操作的基本错误处理
        XCTAssertNoThrow(try bookingCache.clear())
        XCTAssertNoThrow(try bookingCache.save(sampleBookingData, timestamp: Date()))
    }
    
    // MARK: - 性能测试
    
    func testCachePerformance() throws {
        measure {
            do {
                let timestamp = Date()
                try bookingCache.save(sampleBookingData, timestamp: timestamp)
                _ = try bookingCache.load()
                try bookingCache.clear()
            } catch {
                XCTFail("缓存操作失败: \(error)")
            }
        }
    }
}
