//
//  BookingDataManagerTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
import Combine
@testable import mobileTest

final class BookingDataManagerTests: XCTestCase {
    
    private var dataManager: BookingDataManager!
    private var mockService: MockBookingService!
    private var mockCache: MockBookingCache!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        mockService = MockBookingService()
        mockCache = MockBookingCache()
        cancellables = Set<AnyCancellable>()
    }
    
    @MainActor
    private func setupDataManager() {
        dataManager = BookingDataManager(bookingService: mockService, bookingCache: mockCache)
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        dataManager = nil
        mockService = nil
        mockCache = nil
    }
    
    // MARK: - 数据获取测试
    
    @MainActor
    func testGetBookingDataFromCache() async throws {
        setupDataManager()
        
        // 设置缓存中有有效数据
        let testData = createTestBookingData()
        let cachedData = CachedBookingData(
            data: testData,
            timestamp: Date(),
            expiryTime: Date().addingTimeInterval(300)
        )
        mockCache.cachedData = cachedData
        
        // 获取数据
        let result = try await dataManager.getBookingData()
        
        // 验证返回缓存数据
        XCTAssertEqual(result.shipReference, testData.shipReference)
        XCTAssertTrue(mockCache.loadCalled)
        XCTAssertFalse(mockService.fetchCalled)
    }
    
    @MainActor
    func testGetBookingDataFromServiceWhenCacheInvalid() async throws {
        setupDataManager()
        
        // 设置缓存无效
        mockCache.cachedData = nil
        let testData = createTestBookingData()
        mockService.bookingData = testData
        
        // 获取数据
        let result = try await dataManager.getBookingData()
        
        // 验证从服务获取数据
        XCTAssertEqual(result.shipReference, testData.shipReference)
        XCTAssertTrue(mockCache.loadCalled)
        XCTAssertTrue(mockService.fetchCalled)
        XCTAssertTrue(mockCache.saveCalled)
    }
    
    @MainActor
    func testRefreshBookingData() async throws {
        setupDataManager()
        
        // 设置服务返回新数据
        let testData = createTestBookingData()
        mockService.bookingData = testData
        
        // 强制刷新数据
        let result = try await dataManager.refreshBookingData()
        
        // 验证强制刷新
        XCTAssertEqual(result.shipReference, testData.shipReference)
        XCTAssertTrue(mockService.fetchCalled)
        XCTAssertTrue(mockCache.saveCalled)
    }
    
    // MARK: - 错误处理测试
    
    @MainActor
    func testGetBookingDataWithServiceError() async throws {
        setupDataManager()
        
        // 设置服务抛出错误
        mockService.shouldThrowError = true
        mockService.error = BookingDataError.networkError("网络错误")
        mockCache.cachedData = nil
        
        // 验证抛出错误
        do {
            _ = try await dataManager.getBookingData()
            XCTFail("应该抛出错误")
        } catch {
            XCTAssertTrue(error is BookingDataError)
        }
    }
    
    @MainActor
    func testGetBookingDataWithExpiredData() async throws {
        setupDataManager()
        
        // 设置服务返回过期数据
        let expiredData = createExpiredBookingData()
        mockService.bookingData = expiredData
        mockCache.cachedData = nil
        
        // 验证抛出过期错误
        do {
            _ = try await dataManager.refreshBookingData()
            XCTFail("应该抛出过期错误")
        } catch {
            XCTAssertTrue(error is BookingDataError)
        }
    }
    
    // MARK: - 数据状态测试
    
    @MainActor
    func testDataStatusLoading() async throws {
        setupDataManager()
        
        // 设置服务延迟
        mockService.delay = 0.2 // 增加延迟时间
        mockCache.cachedData = nil
        
        // 启动数据获取
        let task = Task {
            try await dataManager.getBookingData()
        }
        
        // 短暂等待，检查状态
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms，确保在延迟期间
        let status = await dataManager.getDataStatus()
        XCTAssertEqual(status, .loading, "在数据获取期间状态应该是loading")
        
        // 等待完成
        _ = try await task.value
        
        // 验证最终状态
        let finalStatus = await dataManager.getDataStatus()
        XCTAssertEqual(finalStatus, .loaded, "数据获取完成后状态应该是loaded")
    }
    
    @MainActor
    func testDataStatusLoaded() async throws {
        setupDataManager()
        
        // 设置有效数据
        let testData = createTestBookingData()
        mockService.bookingData = testData
        mockCache.cachedData = nil
        
        // 获取数据
        _ = try await dataManager.getBookingData()
        
        // 验证状态
        let status = await dataManager.getDataStatus()
        XCTAssertEqual(status, .loaded)
    }
    
    @MainActor
    func testDataStatusError() async throws {
        setupDataManager()
        
        // 设置错误
        mockService.shouldThrowError = true
        mockService.error = BookingDataError.fileNotFound
        mockCache.cachedData = nil
        
        // 尝试获取数据
        do {
            _ = try await dataManager.getBookingData()
        } catch {
            // 忽略错误，检查状态
        }
        
        // 验证错误状态
        let status = await dataManager.getDataStatus()
        if case .error(let message) = status {
            XCTAssertTrue(message.contains("找不到数据文件"))
        } else {
            XCTFail("应该是错误状态")
        }
    }
    
    // MARK: - 数据发布者测试
    
    @MainActor
    func testDataPublisher() async throws {
        setupDataManager()
        
        let testData = createTestBookingData()
        mockService.bookingData = testData
        mockCache.cachedData = nil
        
        let expectation = XCTestExpectation(description: "数据发布")
        expectation.expectedFulfillmentCount = 1
        
        // 订阅数据发布者
        dataManager.dataPublisher
            .sink { data in
                XCTAssertEqual(data.shipReference, testData.shipReference)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // 获取数据
        _ = try await dataManager.getBookingData()
        
        // 等待发布
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - 缓存管理测试
    
    @MainActor
    func testGetCacheStatistics() async throws {
        setupDataManager()
        
        // 设置缓存统计信息
        mockCache.statistics = "测试统计信息"
        
        let statistics = dataManager.getCacheStatistics()
        XCTAssertEqual(statistics, "测试统计信息")
    }
    
    @MainActor
    func testClearCache() async throws {
        setupDataManager()
        
        // 清除缓存
        try dataManager.clearCache()
        
        // 验证清除被调用
        XCTAssertTrue(mockCache.clearCalled)
    }
    
    @MainActor
    func testGetCurrentDataInfo() async throws {
        setupDataManager()
        
        // 设置当前数据
        let testData = createTestBookingData()
        mockService.bookingData = testData
        mockCache.cachedData = nil
        
        // 获取数据
        _ = try await dataManager.getBookingData()
        
        // 获取数据信息
        let info = dataManager.getCurrentDataInfo()
        XCTAssertTrue(info.contains("TEST123"))
        XCTAssertTrue(info.contains("已加载"))
    }
    
    // MARK: - 边界情况测试
    
    @MainActor
    func testConcurrentDataAccess() async throws {
        setupDataManager()
        
        let testData = createTestBookingData()
        mockService.bookingData = testData
        mockCache.cachedData = nil
        
        // 并发访问数据
        async let result1 = dataManager.getBookingData()
        async let result2 = dataManager.getBookingData()
        async let result3 = dataManager.getBookingData()
        
        let results = try await [result1, result2, result3]
        
        // 验证所有结果一致
        for result in results {
            XCTAssertEqual(result.shipReference, testData.shipReference)
        }
    }
    
    @MainActor
    func testDataManagerWithNilService() async throws {
        // 测试服务为nil的情况 - 使用默认服务
        let dataManager = BookingDataManager(
            bookingService: BookingService(), // 使用默认的真实服务
            bookingCache: mockCache
        )
        
        mockCache.cachedData = nil
        
        do {
            _ = try await dataManager.getBookingData()
            // 应该成功，因为会使用默认的BookingService
        } catch {
            XCTFail("使用默认服务应该成功: \(error)")
        }
    }
    
    @MainActor
    func testDataManagerWithNilCache() async throws {
        // 测试缓存为nil的情况
        let nilCache: BookingCacheProtocol? = nil
        let dataManager = BookingDataManager(
            bookingService: mockService,
            bookingCache: nilCache ?? BookingCache()
        )
        
        let testData = createTestBookingData()
        mockService.bookingData = testData
        
        do {
            let result = try await dataManager.getBookingData()
            XCTAssertEqual(result.shipReference, testData.shipReference)
        } catch {
            XCTFail("使用默认缓存应该成功: \(error)")
        }
    }
    
    // MARK: - 辅助方法
    
    private func createTestBookingData() -> BookingData {
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
        
        return BookingData(
            shipReference: "TEST123",
            shipToken: "TOKEN123",
            canIssueTicketChecking: true,
            expiryTime: "2000000000", // 2033年时间戳，确保不过期
            duration: 120,
            segments: [segment]
        )
    }
    
    private func createExpiredBookingData() -> BookingData {
        let location = Location(
            code: "EXPIRED",
            displayName: "Expired Location",
            url: "https://expired.com"
        )
        
        let originDestinationPair = OriginDestinationPair(
            destination: location,
            destinationCity: "Expired City",
            origin: location,
            originCity: "Origin City"
        )
        
        let segment = Segment(
            id: 1,
            originAndDestinationPair: originDestinationPair
        )
        
        return BookingData(
            shipReference: "EXPIRED123",
            shipToken: "EXPIRED_TOKEN",
            canIssueTicketChecking: false,
            expiryTime: "1000000000", // 过去时间
            duration: 60,
            segments: [segment]
        )
    }
}

// MARK: - Mock 类

class MockBookingService: BookingServiceProtocol {
    var bookingData: BookingData?
    var shouldThrowError = false
    var error: Error?
    var fetchCalled = false
    var delay: TimeInterval = 0
    
    func fetchBookingData() async throws -> BookingData {
        fetchCalled = true
        
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw error ?? BookingDataError.networkError("模拟错误")
        }
        
        guard let data = bookingData else {
            throw BookingDataError.fileNotFound
        }
        
        return data
    }
    
    func fetchBookingDataWithTimestamp() async throws -> (data: BookingData, timestamp: Date) {
        let data = try await fetchBookingData()
        return (data: data, timestamp: Date())
    }
}

class MockBookingCache: BookingCacheProtocol {
    var cachedData: CachedBookingData?
    var loadCalled = false
    var saveCalled = false
    var clearCalled = false
    var statistics = "模拟缓存统计信息"
    
    func save(_ data: BookingData, timestamp: Date) throws {
        saveCalled = true
        cachedData = CachedBookingData(
            data: data,
            timestamp: timestamp,
            expiryTime: timestamp.addingTimeInterval(300)
        )
    }
    
    func load() throws -> CachedBookingData? {
        loadCalled = true
        return cachedData
    }
    
    func clear() throws {
        clearCalled = true
        cachedData = nil
    }
    
    func isCacheValid() -> Bool {
        return cachedData?.isValid ?? false
    }
    
    func getCacheInfo() -> (isValid: Bool, timestamp: Date?, age: TimeInterval?) {
        guard let cached = cachedData else {
            return (isValid: false, timestamp: nil, age: nil)
        }
        return (isValid: cached.isValid, timestamp: cached.timestamp, age: cached.age)
    }
    
    func getCacheStatistics() -> String {
        return statistics
    }
}
