//
//  BookingModelsTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

final class BookingModelsTests: XCTestCase {
    
    // MARK: - 测试数据
    private var sampleBookingData: BookingData!
    private var sampleSegment: Segment!
    private var sampleLocation: Location!
    
    override func setUpWithError() throws {
        // 创建测试数据
        sampleLocation = Location(
            code: "TEST",
            displayName: "Test Location",
            url: "https://test.com"
        )
        
        let originDestinationPair = OriginDestinationPair(
            destination: sampleLocation,
            destinationCity: "Test City",
            origin: sampleLocation,
            originCity: "Origin City"
        )
        
        sampleSegment = Segment(
            id: 1,
            originAndDestinationPair: originDestinationPair
        )
        
        sampleBookingData = BookingData(
            shipReference: "TEST123",
            shipToken: "TOKEN123",
            canIssueTicketChecking: true,
            expiryTime: "2000000000", // 2033年的时间戳，确保不过期
            duration: 120, // 2小时
            segments: [sampleSegment]
        )
    }
    
    override func tearDownWithError() throws {
        sampleBookingData = nil
        sampleSegment = nil
        sampleLocation = nil
    }
    
    // MARK: - BookingData 测试
    
    func testBookingDataInitialization() throws {
        XCTAssertEqual(sampleBookingData.shipReference, "TEST123")
        XCTAssertEqual(sampleBookingData.shipToken, "TOKEN123")
        XCTAssertTrue(sampleBookingData.canIssueTicketChecking)
        XCTAssertEqual(sampleBookingData.expiryTime, "1735689600")
        XCTAssertEqual(sampleBookingData.duration, 120)
        XCTAssertEqual(sampleBookingData.segments.count, 1)
    }
    
    func testBookingDataIsExpired() throws {
        // 测试过期数据 - 使用更早的时间戳确保过期
        let expiredData = BookingData(
            shipReference: "EXPIRED",
            shipToken: "TOKEN",
            canIssueTicketChecking: false,
            expiryTime: "946684800", // 2000-01-01 00:00:00 UTC
            duration: 60,
            segments: []
        )
        
        XCTAssertTrue(expiredData.isExpired, "过期数据应该被正确识别为过期 - 过期时间: \(expiredData.formattedExpiryTime)")
        
        // 测试未来时间的数据
        let futureData = BookingData(
            shipReference: "FUTURE",
            shipToken: "TOKEN",
            canIssueTicketChecking: false,
            expiryTime: "2000000000", // 2033年的时间戳
            duration: 60,
            segments: []
        )
        
        XCTAssertFalse(futureData.isExpired, "未来时间的数据不应该被识别为过期 - 过期时间: \(futureData.formattedExpiryTime)")
        
        // 测试当前时间附近的数据
        let currentTimestamp = Int(Date().timeIntervalSince1970)
        let currentData = BookingData(
            shipReference: "CURRENT",
            shipToken: "TOKEN",
            canIssueTicketChecking: false,
            expiryTime: String(currentTimestamp + 3600), // 1小时后过期
            duration: 60,
            segments: []
        )
        
        XCTAssertFalse(currentData.isExpired, "当前时间附近的数据不应该被识别为过期 - 过期时间: \(currentData.formattedExpiryTime)")
        XCTAssertFalse(sampleBookingData.isExpired, "测试数据不应该过期 - 过期时间: \(sampleBookingData.formattedExpiryTime)")
    }
    
    func testBookingDataFormattedExpiryTime() throws {
        let formattedTime = sampleBookingData.formattedExpiryTime
        XCTAssertFalse(formattedTime.isEmpty)
        XCTAssertNotEqual(formattedTime, "未知")
    }
    
    func testBookingDataFormattedDuration() throws {
        let formattedDuration = sampleBookingData.formattedDuration
        XCTAssertEqual(formattedDuration, "2小时0分钟")
        
        // 测试带分钟的持续时间
        let dataWithMinutes = BookingData(
            shipReference: "TEST",
            shipToken: "TOKEN",
            canIssueTicketChecking: false,
            expiryTime: "2000000000", // 使用未来时间戳
            duration: 90, // 1小时30分钟
            segments: []
        )
        
        XCTAssertEqual(dataWithMinutes.formattedDuration, "1小时30分钟")
    }
    
    // MARK: - Segment 测试
    
    func testSegmentInitialization() throws {
        XCTAssertEqual(sampleSegment.id, 1)
        XCTAssertNotNil(sampleSegment.originAndDestinationPair)
    }
    
    func testSegmentDescription() throws {
        let description = sampleSegment.description
        XCTAssertTrue(description.contains("Test Location"))
        XCTAssertTrue(description.contains("→"))
    }
    
    // MARK: - OriginDestinationPair 测试
    
    func testOriginDestinationPairRouteDescription() throws {
        let routeDescription = sampleSegment.originAndDestinationPair.routeDescription
        XCTAssertTrue(routeDescription.contains("Test Location"))
        XCTAssertTrue(routeDescription.contains("Test City"))
        XCTAssertTrue(routeDescription.contains("Origin City"))
    }
    
    // MARK: - Location 测试
    
    func testLocationInitialization() throws {
        XCTAssertEqual(sampleLocation.code, "TEST")
        XCTAssertEqual(sampleLocation.displayName, "Test Location")
        XCTAssertEqual(sampleLocation.url, "https://test.com")
    }
    
    func testLocationFormattedInfo() throws {
        let formattedInfo = sampleLocation.formattedInfo
        XCTAssertEqual(formattedInfo, "Test Location (TEST)")
    }
    
    // MARK: - DataStatus 测试
    
    func testDataStatusDescription() throws {
        XCTAssertEqual(DataStatus.loading.description, "加载中")
        XCTAssertEqual(DataStatus.loaded.description, "已加载")
        XCTAssertEqual(DataStatus.expired.description, "已过期")
        XCTAssertEqual(DataStatus.error("测试错误").description, "错误: 测试错误")
    }
    
    // MARK: - BookingDataError 测试
    
    func testBookingDataErrorDescriptions() throws {
        XCTAssertEqual(BookingDataError.fileNotFound.errorDescription, "找不到数据文件")
        XCTAssertEqual(BookingDataError.invalidJSON.errorDescription, "JSON数据格式无效")
        XCTAssertEqual(BookingDataError.dataExpired.errorDescription, "数据已过期")
        XCTAssertEqual(BookingDataError.networkError("网络问题").errorDescription, "网络错误: 网络问题")
        XCTAssertEqual(BookingDataError.cacheError("缓存问题").errorDescription, "缓存错误: 缓存问题")
    }
    
    // MARK: - JSON 编码解码测试
    
    func testBookingDataJSONEncoding() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(sampleBookingData)
        XCTAssertFalse(data.isEmpty)
    }
    
    func testBookingDataJSONDecoding() throws {
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(sampleBookingData)
        
        let decoder = JSONDecoder()
        let decodedData = try decoder.decode(BookingData.self, from: encodedData)
        
        XCTAssertEqual(decodedData.shipReference, sampleBookingData.shipReference)
        XCTAssertEqual(decodedData.shipToken, sampleBookingData.shipToken)
        XCTAssertEqual(decodedData.canIssueTicketChecking, sampleBookingData.canIssueTicketChecking)
        XCTAssertEqual(decodedData.expiryTime, sampleBookingData.expiryTime)
        XCTAssertEqual(decodedData.duration, sampleBookingData.duration)
        XCTAssertEqual(decodedData.segments.count, sampleBookingData.segments.count)
    }
}
