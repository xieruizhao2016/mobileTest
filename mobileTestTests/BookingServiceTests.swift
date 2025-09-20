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
    
    override func setUpWithError() throws {
        bookingService = BookingService()
    }
    
    override func tearDownWithError() throws {
        bookingService = nil
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
}
