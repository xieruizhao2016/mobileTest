//
//  BookingServiceAsyncTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

// MARK: - BookingService异步功能测试
@MainActor
class BookingServiceAsyncTests: XCTestCase {
    
    var bookingService: BookingService!
    var mockFileReader: MockAsyncFileReader!
    var testConfiguration: TestBookingServiceConfiguration!
    
    override func setUp() {
        super.setUp()
        testConfiguration = TestBookingServiceConfiguration(fileName: "booking")
        mockFileReader = MockAsyncFileReader()
        bookingService = BookingService(configuration: testConfiguration, fileReader: mockFileReader)
    }
    
    override func tearDown() {
        bookingService = nil
        mockFileReader = nil
        testConfiguration = nil
        super.tearDown()
    }
    
    // MARK: - 异步文件读取测试
    
    func testFetchBookingDataWithAsyncReader() async throws {
        // Given: 模拟文件读取器返回有效数据
        let testBookingData = createTestBookingData()
        let testData = try JSONEncoder().encode(testBookingData)
        mockFileReader.mockData = testData
        
        // When: 获取预订数据
        let result = try await bookingService.fetchBookingData()
        
        // Then: 应该成功获取数据
        XCTAssertEqual(result.shipReference, testBookingData.shipReference)
        XCTAssertEqual(result.shipToken, testBookingData.shipToken)
        XCTAssertEqual(result.segments.count, testBookingData.segments.count)
        XCTAssertEqual(mockFileReader.readLocalFileCallCount, 1)
    }
    
    func testFetchBookingDataWithAsyncReaderError() async {
        // Given: 模拟文件读取器抛出错误
        mockFileReader.shouldThrowError = true
        mockFileReader.mockError = BookingDataError.fileNotFound
        
        // When & Then: 应该抛出错误
        do {
            _ = try await bookingService.fetchBookingData()
            XCTFail("应该抛出文件未找到错误")
        } catch BookingDataError.fileNotFound {
            // 预期的错误
        } catch {
            XCTFail("应该抛出BookingDataError.fileNotFound，但抛出了: \(error)")
        }
        
        XCTAssertEqual(mockFileReader.readLocalFileCallCount, 1)
    }
    
    // MARK: - 远程文件读取测试
    
    func testFetchBookingDataFromRemote() async throws {
        // Given: 模拟远程文件读取成功
        let testBookingData = createTestBookingData()
        let testData = try JSONEncoder().encode(testBookingData)
        mockFileReader.mockData = testData
        
        let remoteURL = URL(string: "https://example.com/booking.json")!
        
        // When: 从远程URL获取数据
        let result = try await bookingService.fetchBookingDataFromRemote(url: remoteURL)
        
        // Then: 应该成功获取远程数据
        XCTAssertEqual(result.shipReference, testBookingData.shipReference)
        XCTAssertEqual(result.shipToken, testBookingData.shipToken)
        XCTAssertEqual(mockFileReader.readRemoteFileCallCount, 1)
    }
    
    func testFetchBookingDataFromRemoteError() async {
        // Given: 模拟远程文件读取失败
        mockFileReader.shouldThrowError = true
        mockFileReader.mockError = BookingDataError.networkError("网络连接失败")
        
        let remoteURL = URL(string: "https://example.com/booking.json")!
        
        // When & Then: 应该抛出网络错误
        do {
            _ = try await bookingService.fetchBookingDataFromRemote(url: remoteURL)
            XCTFail("应该抛出网络错误")
        } catch BookingDataError.networkError(let message) {
            XCTAssertTrue(message.contains("网络连接失败"))
        } catch {
            XCTFail("应该抛出BookingDataError.networkError，但抛出了: \(error)")
        }
        
        XCTAssertEqual(mockFileReader.readRemoteFileCallCount, 1)
    }
    
    // MARK: - 进度回调测试
    
    func testFetchBookingDataWithProgress() async throws {
        // Given: 模拟文件读取成功和进度回调
        let testBookingData = createTestBookingData()
        let testData = try JSONEncoder().encode(testBookingData)
        mockFileReader.mockData = testData
        
        var progressValues: [Double] = []
        let progressCallback: (Double) -> Void = { progress in
            progressValues.append(progress)
        }
        
        // When: 带进度回调获取数据
        let result = try await bookingService.fetchBookingDataWithProgress(progressCallback: progressCallback)
        
        // Then: 应该成功获取数据并调用进度回调
        XCTAssertEqual(result.shipReference, testBookingData.shipReference)
        XCTAssertFalse(progressValues.isEmpty)
        XCTAssertEqual(progressValues.last, 1.0) // 最后应该是100%
    }
    
    func testFetchBookingDataWithProgressFromCache() async throws {
        // Given: 启用缓存并预先缓存数据
        let testBookingData = createTestBookingData()
        bookingService.warmupCache(with: testBookingData)
        
        var progressValues: [Double] = []
        let progressCallback: (Double) -> Void = { progress in
            progressValues.append(progress)
        }
        
        // When: 带进度回调获取数据（应该从缓存获取）
        let result = try await bookingService.fetchBookingDataWithProgress(progressCallback: progressCallback)
        
        // Then: 应该从缓存获取数据，进度直接为100%
        XCTAssertEqual(result.shipReference, testBookingData.shipReference)
        XCTAssertEqual(progressValues.count, 1)
        XCTAssertEqual(progressValues.first, 1.0)
        XCTAssertEqual(mockFileReader.readFileCallCount, 0) // 不应该调用文件读取
    }
    
    // MARK: - 缓存集成测试
    
    func testAsyncFileReadingWithCache() async throws {
        // Given: 启用缓存
        let testBookingData = createTestBookingData()
        let testData = try JSONEncoder().encode(testBookingData)
        mockFileReader.mockData = testData
        
        // When: 第一次获取数据
        let result1 = try await bookingService.fetchBookingData()
        
        // Then: 应该从文件读取并缓存
        XCTAssertEqual(result1.shipReference, testBookingData.shipReference)
        XCTAssertEqual(mockFileReader.readLocalFileCallCount, 1)
        
        // When: 第二次获取数据
        let result2 = try await bookingService.fetchBookingData()
        
        // Then: 应该从缓存获取，不再次读取文件
        XCTAssertEqual(result2.shipReference, testBookingData.shipReference)
        XCTAssertEqual(mockFileReader.readLocalFileCallCount, 1) // 计数不变
    }
    
    func testAsyncFileReadingWithoutCache() async throws {
        // Given: 禁用缓存
        let noCacheConfig = TestBookingServiceConfiguration(fileName: "booking")
        let noCacheService = BookingService(configuration: noCacheConfig, fileReader: mockFileReader)
        
        let testBookingData = createTestBookingData()
        let testData = try JSONEncoder().encode(testBookingData)
        mockFileReader.mockData = testData
        
        // When: 第一次获取数据
        let result1 = try await noCacheService.fetchBookingData()
        
        // Then: 应该从文件读取
        XCTAssertEqual(result1.shipReference, testBookingData.shipReference)
        XCTAssertEqual(mockFileReader.readLocalFileCallCount, 1)
        
        // When: 第二次获取数据
        let result2 = try await noCacheService.fetchBookingData()
        
        // Then: 应该再次从文件读取
        XCTAssertEqual(result2.shipReference, testBookingData.shipReference)
        XCTAssertEqual(mockFileReader.readLocalFileCallCount, 2) // 计数增加
    }
    
    // MARK: - 重试机制测试
    
    func testAsyncFileReadingWithRetry() async throws {
        // Given: 配置重试机制
        let retryConfig = TestBookingServiceConfiguration(fileName: "booking")
        let retryService = BookingService(configuration: retryConfig, fileReader: mockFileReader)
        
        let testBookingData = createTestBookingData()
        let testData = try JSONEncoder().encode(testBookingData)
        mockFileReader.mockData = testData
        
        // When: 使用重试机制获取数据
        let result = try await retryService.fetchBookingDataWithRetry()
        
        // Then: 应该成功获取数据
        XCTAssertEqual(result.shipReference, testBookingData.shipReference)
        XCTAssertEqual(mockFileReader.readLocalFileCallCount, 1)
    }
    
    func testAsyncFileReadingWithRetryFailure() async {
        // Given: 模拟持续失败
        mockFileReader.shouldThrowError = true
        mockFileReader.mockError = BookingDataError.networkError("持续失败")
        
        let retryConfig = TestBookingServiceConfiguration(fileName: "booking")
        let retryService = BookingService(configuration: retryConfig, fileReader: mockFileReader)
        
        // When & Then: 应该最终失败
        do {
            _ = try await retryService.fetchBookingDataWithRetry()
            XCTFail("应该抛出网络错误")
        } catch BookingDataError.networkError(let message) {
            XCTAssertTrue(message.contains("持续失败"))
        } catch {
            XCTFail("应该抛出BookingDataError.networkError，但抛出了: \(error)")
        }
        
        // 应该尝试了配置的最大重试次数
        XCTAssertEqual(mockFileReader.readLocalFileCallCount, retryConfig.maxRetryAttempts)
    }
    
    // MARK: - 性能测试
    
    func testAsyncFileReadingPerformance() async throws {
        // Given: 大量数据
        let largeBookingData = createLargeTestBookingData()
        let testData = try JSONEncoder().encode(largeBookingData)
        mockFileReader.mockData = testData
        
        // When: 测量异步读取性能
        let startTime = Date()
        let result = try await bookingService.fetchBookingData()
        let endTime = Date()
        
        // Then: 应该成功读取并在合理时间内完成
        XCTAssertEqual(result.shipReference, largeBookingData.shipReference)
        XCTAssertEqual(result.segments.count, largeBookingData.segments.count)
        
        let executionTime = endTime.timeIntervalSince(startTime)
        XCTAssertLessThan(executionTime, 1.0) // 应该在1秒内完成
    }
    
    // MARK: - 辅助方法
    
    private func createTestBookingData() -> BookingData {
        return BookingData(
            shipReference: "TEST123",
            shipToken: "token123",
            canIssueTicketChecking: true,
            expiryTime: "1735689600", // 2025-01-01
            duration: 120,
            segments: [
                Segment(
                    id: 1,
                    originAndDestinationPair: OriginDestinationPair(
                        destination: Location(code: "DEST", displayName: "目的地", url: "https://dest.com"),
                        destinationCity: "目的地城市",
                        origin: Location(code: "ORIG", displayName: "出发地", url: "https://orig.com"),
                        originCity: "出发地城市"
                    )
                )
            ]
        )
    }
    
    private func createLargeTestBookingData() -> BookingData {
        var segments: [Segment] = []
        for i in 1...100 {
            segments.append(
                Segment(
                    id: i,
                    originAndDestinationPair: OriginDestinationPair(
                        destination: Location(code: "DEST\(i)", displayName: "目的地\(i)", url: "https://dest\(i).com"),
                        destinationCity: "目的地城市\(i)",
                        origin: Location(code: "ORIG\(i)", displayName: "出发地\(i)", url: "https://orig\(i).com"),
                        originCity: "出发地城市\(i)"
                    )
                )
            )
        }
        
        return BookingData(
            shipReference: "LARGE_TEST123",
            shipToken: "large_token123",
            canIssueTicketChecking: true,
            expiryTime: "1735689600",
            duration: 240,
            segments: segments
        )
    }
}
