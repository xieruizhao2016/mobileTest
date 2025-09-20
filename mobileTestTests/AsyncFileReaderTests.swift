//
//  AsyncFileReaderTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

// MARK: - 模拟文件读取器
class MockAsyncFileReader: AsyncFileReaderProtocol {
    var shouldThrowError = false
    var mockData = Data("test data".utf8)
    var mockError = BookingDataError.fileNotFound
    var readLocalFileCallCount = 0
    var readRemoteFileCallCount = 0
    var readFileCallCount = 0
    
    func readLocalFile(fileName: String, fileExtension: String, bundle: Bundle) async throws -> Data {
        readLocalFileCallCount += 1
        if shouldThrowError {
            throw mockError
        }
        return mockData
    }
    
    func readRemoteFile(url: URL, timeout: TimeInterval) async throws -> Data {
        readRemoteFileCallCount += 1
        if shouldThrowError {
            throw mockError
        }
        return mockData
    }
    
    func readFile(source: String, fileExtension: String?, timeout: TimeInterval?) async throws -> Data {
        readFileCallCount += 1
        if shouldThrowError {
            throw mockError
        }
        return mockData
    }
    
    func readFileWithProgress(
        source: String,
        fileExtension: String?,
        timeout: TimeInterval?,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> Data {
        readFileCallCount += 1
        if shouldThrowError {
            throw mockError
        }
        // 模拟进度更新
        progressCallback(0.5)
        progressCallback(1.0)
        return mockData
    }
}

// MARK: - AsyncFileReader测试类
@MainActor
class AsyncFileReaderTests: XCTestCase {
    
    var fileReader: AsyncFileReader!
    var mockFileReader: MockAsyncFileReader!
    
    override func setUp() {
        super.setUp()
        fileReader = AsyncFileReaderFactory.createForTesting(enableVerboseLogging: false)
        mockFileReader = MockAsyncFileReader()
    }
    
    override func tearDown() {
        fileReader = nil
        mockFileReader = nil
        super.tearDown()
    }
    
    // MARK: - 本地文件读取测试
    
    func testReadLocalFileSuccess() async throws {
        // Given: 存在有效的本地文件
        let testData = """
        {
            "shipReference": "TEST123",
            "shipToken": "token123",
            "canIssueTicketChecking": true,
            "expiryTime": "1735689600",
            "duration": 120,
            "segments": []
        }
        """.data(using: .utf8)!
        
        // 创建临时测试文件
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_booking.json")
        try testData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // When: 读取本地文件
        let result = try await fileReader.readLocalFile(
            fileName: "test_booking",
            fileExtension: "json",
            bundle: Bundle(for: type(of: self))
        )
        
        // Then: 应该成功读取数据
        XCTAssertEqual(result, testData)
    }
    
    func testReadLocalFileNotFound() async {
        // Given: 不存在的文件
        // When & Then: 应该抛出文件未找到错误
        do {
            _ = try await fileReader.readLocalFile(
                fileName: "nonexistent",
                fileExtension: "json"
            )
            XCTFail("应该抛出文件未找到错误")
        } catch BookingDataError.fileNotFound {
            // 预期的错误
        } catch {
            XCTFail("应该抛出BookingDataError.fileNotFound，但抛出了: \(error)")
        }
    }
    
    // MARK: - 远程文件读取测试
    
    func testReadRemoteFileSuccess() async throws {
        // Given: 模拟成功的网络请求
        let mockData = Data("remote data".utf8)
        let mockURL = URL(string: "https://example.com/data.json")!
        
        // 创建模拟的URLSession
        let mockSession = MockURLSession()
        mockSession.mockData = mockData
        mockSession.mockResponse = HTTPURLResponse(
            url: mockURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let reader = AsyncFileReader(urlSession: mockSession, enableVerboseLogging: false)
        
        // When: 读取远程文件
        let result = try await reader.readRemoteFile(url: mockURL, timeout: 10.0)
        
        // Then: 应该成功读取数据
        XCTAssertEqual(result, mockData)
        XCTAssertEqual(mockSession.dataCallCount, 1)
    }
    
    func testReadRemoteFileHTTPError() async {
        // Given: 模拟HTTP错误响应
        let mockURL = URL(string: "https://example.com/data.json")!
        let mockSession = MockURLSession()
        mockSession.mockResponse = HTTPURLResponse(
            url: mockURL,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        
        let reader = AsyncFileReader(urlSession: mockSession, enableVerboseLogging: false)
        
        // When & Then: 应该抛出网络错误
        do {
            _ = try await reader.readRemoteFile(url: mockURL, timeout: 10.0)
            XCTFail("应该抛出网络错误")
        } catch BookingDataError.networkError(let message) {
            XCTAssertTrue(message.contains("HTTP错误: 404"))
        } catch {
            XCTFail("应该抛出BookingDataError.networkError，但抛出了: \(error)")
        }
    }
    
    func testReadRemoteFileNetworkError() async {
        // Given: 模拟网络错误
        let mockURL = URL(string: "https://example.com/data.json")!
        let mockSession = MockURLSession()
        mockSession.mockError = URLError(.notConnectedToInternet)
        
        let reader = AsyncFileReader(urlSession: mockSession, enableVerboseLogging: false)
        
        // When & Then: 应该抛出网络错误
        do {
            _ = try await reader.readRemoteFile(url: mockURL, timeout: 10.0)
            XCTFail("应该抛出网络错误")
        } catch BookingDataError.networkError(let message) {
            XCTAssertTrue(message.contains("网络错误"))
        } catch {
            XCTFail("应该抛出BookingDataError.networkError，但抛出了: \(error)")
        }
    }
    
    // MARK: - 自动检测文件源测试
    
    func testReadFileWithLocalSource() async throws {
        // Given: 本地文件源
        let testData = Data("local test data".utf8)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("local_test.json")
        try testData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // When: 使用本地文件源读取
        let result = try await fileReader.readFile(
            source: "local_test",
            fileExtension: "json",
            timeout: nil
        )
        
        // Then: 应该成功读取本地文件
        XCTAssertEqual(result, testData)
    }
    
    func testReadFileWithRemoteSource() async throws {
        // Given: 远程URL源
        let mockData = Data("remote test data".utf8)
        let mockURL = URL(string: "https://example.com/remote.json")!
        let mockSession = MockURLSession()
        mockSession.mockData = mockData
        mockSession.mockResponse = HTTPURLResponse(
            url: mockURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        let reader = AsyncFileReader(urlSession: mockSession, enableVerboseLogging: false)
        
        // When: 使用远程URL源读取
        let result = try await reader.readFile(
            source: "https://example.com/remote.json",
            fileExtension: nil,
            timeout: 10.0
        )
        
        // Then: 应该成功读取远程文件
        XCTAssertEqual(result, mockData)
        XCTAssertEqual(mockSession.dataCallCount, 1)
    }
    
    // MARK: - 进度回调测试
    
    func testReadFileWithProgressCallback() async throws {
        // Given: 本地文件和进度回调
        let testData = Data("progress test data".utf8)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("progress_test.json")
        try testData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        var progressValues: [Double] = []
        let progressCallback: (Double) -> Void = { progress in
            progressValues.append(progress)
        }
        
        // When: 带进度回调读取文件
        let result = try await fileReader.readFileWithProgress(
            source: "progress_test",
            fileExtension: "json",
            timeout: nil,
            progressCallback: progressCallback
        )
        
        // Then: 应该成功读取并调用进度回调
        XCTAssertEqual(result, testData)
        XCTAssertFalse(progressValues.isEmpty)
        XCTAssertEqual(progressValues.last, 1.0) // 最后应该是100%
    }
    
    // MARK: - 批量读取测试
    
    func testReadMultipleFiles() async throws {
        // Given: 多个测试文件
        let testData1 = Data("file1 data".utf8)
        let testData2 = Data("file2 data".utf8)
        
        let tempURL1 = FileManager.default.temporaryDirectory.appendingPathComponent("multi_test1.json")
        let tempURL2 = FileManager.default.temporaryDirectory.appendingPathComponent("multi_test2.json")
        
        try testData1.write(to: tempURL1)
        try testData2.write(to: tempURL2)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL1)
            try? FileManager.default.removeItem(at: tempURL2)
        }
        
        let sources = [
            (source: "multi_test1", fileExtension: "json", timeout: nil),
            (source: "multi_test2", fileExtension: "json", timeout: nil)
        ]
        
        // When: 批量读取文件
        let results = try await fileReader.readMultipleFiles(sources: sources)
        
        // Then: 应该成功读取所有文件
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0], testData1)
        XCTAssertEqual(results[1], testData2)
    }
    
    // MARK: - 工厂方法测试
    
    func testCreateDefaultReader() {
        // When: 创建默认读取器
        let reader = AsyncFileReaderFactory.createDefault(enableVerboseLogging: true)
        
        // Then: 应该创建成功
        XCTAssertNotNil(reader)
    }
    
    func testCreateForTestingReader() {
        // When: 创建测试用读取器
        let reader = AsyncFileReaderFactory.createForTesting(enableVerboseLogging: false)
        
        // Then: 应该创建成功
        XCTAssertNotNil(reader)
    }
    
    func testCreateForProductionReader() {
        // When: 创建生产环境读取器
        let reader = AsyncFileReaderFactory.createForProduction(enableVerboseLogging: false)
        
        // Then: 应该创建成功
        XCTAssertNotNil(reader)
    }
}

// MARK: - 模拟URLSession
class MockURLSession: URLSession {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var dataCallCount = 0
    
    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        dataCallCount += 1
        
        if let error = mockError {
            throw error
        }
        
        let data = mockData ?? Data()
        let response = mockResponse ?? URLResponse()
        return (data, response)
    }
}

// MARK: - 扩展URLSession以支持模拟
extension URLSession {
    @objc func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        // 默认实现，子类可以重写
        return try await withCheckedThrowingContinuation { continuation in
            dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (data ?? Data(), response ?? URLResponse()))
                }
            }.resume()
        }
    }
}
