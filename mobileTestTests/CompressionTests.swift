//
//  CompressionTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

class CompressionTests: XCTestCase {
    
    var compressionManager: CompressionManager!
    var asyncFileReader: AsyncFileReader!
    var bookingService: BookingService!
    
    override func setUp() {
        super.setUp()
        compressionManager = CompressionManager(enableVerboseLogging: true)
        asyncFileReader = AsyncFileReader(enableVerboseLogging: true, compressionManager: compressionManager)
        
        let configuration = BookingServiceConfigurationFactory.createWithCompression(
            fileName: "booking",
            compressionSupportLevel: .full,
            autoDecompressFiles: true
        )
        bookingService = BookingService(configuration: configuration, fileReader: asyncFileReader)
    }
    
    override func tearDown() {
        compressionManager = nil
        asyncFileReader = nil
        bookingService = nil
        super.tearDown()
    }
    
    // MARK: - CompressionManager Tests
    
    func testCompressionFormatDetection() {
        // 测试GZIP格式检测
        let gzipData = createGzipTestData()
        let gzipInfo = compressionManager.detectCompressionFormat(from: gzipData)
        XCTAssertNotNil(gzipInfo, "应该检测到GZIP格式")
        XCTAssertEqual(gzipInfo?.format, .gzip, "检测到的格式应该是GZIP")
        
        // 测试非压缩数据
        let normalData = "Hello, World!".data(using: .utf8)!
        let normalInfo = compressionManager.detectCompressionFormat(from: normalData)
        XCTAssertNil(normalInfo, "普通数据不应该被识别为压缩格式")
    }
    
    func testGzipCompressionAndDecompression() async throws {
        let originalData = "This is a test string for compression".data(using: .utf8)!
        
        // 压缩数据
        let compressedData = try await compressionManager.compress(data: originalData, format: .gzip)
        XCTAssertLessThan(compressedData.count, originalData.count, "压缩后的数据应该比原始数据小")
        
        // 解压缩数据
        let decompressedData = try await compressionManager.decompress(data: compressedData, format: .gzip)
        XCTAssertEqual(decompressedData, originalData, "解压缩后的数据应该与原始数据相同")
    }
    
    func testLZ4CompressionAndDecompression() async throws {
        let originalData = "This is a test string for LZ4 compression".data(using: .utf8)!
        
        // 压缩数据
        let compressedData = try await compressionManager.compress(data: originalData, format: .lz4)
        XCTAssertLessThan(compressedData.count, originalData.count, "LZ4压缩后的数据应该比原始数据小")
        
        // 解压缩数据
        let decompressedData = try await compressionManager.decompress(data: compressedData, format: .lz4)
        XCTAssertEqual(decompressedData, originalData, "LZ4解压缩后的数据应该与原始数据相同")
    }
    
    func testLZFSECompressionAndDecompression() async throws {
        let originalData = "This is a test string for LZFSE compression".data(using: .utf8)!
        
        // 压缩数据
        let compressedData = try await compressionManager.compress(data: originalData, format: .lzfse)
        XCTAssertLessThan(compressedData.count, originalData.count, "LZFSE压缩后的数据应该比原始数据小")
        
        // 解压缩数据
        let decompressedData = try await compressionManager.decompress(data: compressedData, format: .lzfse)
        XCTAssertEqual(decompressedData, originalData, "LZFSE解压缩后的数据应该与原始数据相同")
    }
    
    func testCompressionValidation() async {
        let originalData = "Test data for validation".data(using: .utf8)!
        
        // 测试GZIP验证
        let gzipData = try! await compressionManager.compress(data: originalData, format: .gzip)
        let isValidGzip = await compressionManager.validateCompression(data: gzipData, format: .gzip)
        XCTAssertTrue(isValidGzip, "GZIP数据应该通过验证")
        
        // 测试无效数据验证
        let invalidData = "Invalid compression data".data(using: .utf8)!
        let isValidInvalid = await compressionManager.validateCompression(data: invalidData, format: .gzip)
        XCTAssertFalse(isValidInvalid, "无效的GZIP数据应该不通过验证")
    }
    
    func testCompressionInfo() async {
        let originalData = "Test data".data(using: .utf8)!
        let compressedData = try! await compressionManager.compress(data: originalData, format: .gzip)
        
        let compressionInfo = CompressionInfo(
            format: .gzip,
            originalSize: originalData.count,
            compressedSize: compressedData.count,
            compressionRatio: Double(compressedData.count) / Double(originalData.count),
            isCompressed: true
        )
        
        XCTAssertEqual(compressionInfo.format, .gzip)
        XCTAssertEqual(compressionInfo.originalSize, originalData.count)
        XCTAssertEqual(compressionInfo.compressedSize, compressedData.count)
        XCTAssertLessThan(compressionInfo.compressionRatio, 1.0)
        XCTAssertTrue(compressionInfo.isCompressed)
        XCTAssertGreaterThan(compressionInfo.compressionPercentage, 0.0)
        XCTAssertGreaterThan(compressionInfo.spaceSaved, 0)
    }
    
    // MARK: - AsyncFileReader Compression Tests
    
    func testAsyncFileReaderCompressionDetection() {
        let gzipData = createGzipTestData()
        let compressionInfo = asyncFileReader.detectCompressionFormat(from: gzipData)
        XCTAssertNotNil(compressionInfo, "AsyncFileReader应该能够检测压缩格式")
        XCTAssertEqual(compressionInfo?.format, .gzip, "检测到的格式应该是GZIP")
    }
    
    func testAsyncFileReaderCompressedFileReading() async throws {
        // 这个测试需要实际的压缩文件，这里我们模拟测试
        let testData = "Test compressed data".data(using: .utf8)!
        let compressedData = try await compressionManager.compress(data: testData, format: .gzip)
        
        // 模拟文件读取（实际测试中需要真实的压缩文件）
        XCTAssertNotNil(compressedData, "压缩数据不应该为nil")
        XCTAssertLessThan(compressedData.count, testData.count, "压缩数据应该比原始数据小")
    }
    
    // MARK: - BookingService Compression Tests
    
    func testBookingServiceCompressionDetection() {
        let gzipData = createGzipTestData()
        let compressionInfo = bookingService.detectCompressionFormat(from: gzipData)
        XCTAssertNotNil(compressionInfo, "BookingService应该能够检测压缩格式")
        XCTAssertEqual(compressionInfo?.format, .gzip, "检测到的格式应该是GZIP")
    }
    
    func testBookingServiceCompressionDisabled() async {
        let disabledConfiguration = BookingServiceConfigurationFactory.createTest(fileName: "booking")
        let disabledService = BookingService(configuration: disabledConfiguration, fileReader: asyncFileReader)
        
        do {
            _ = try await disabledService.fetchCompressedBookingData(
                fileName: "test",
                fileExtension: "gz",
                autoDecompress: true
            )
            XCTFail("禁用压缩功能时应该抛出错误")
        } catch let error as BookingDataError {
            XCTAssertEqual(error, BookingDataError.unsupportedOperation("压缩功能已禁用"))
        } catch {
            XCTFail("应该抛出BookingDataError.unsupportedOperation错误")
        }
    }
    
    func testBookingServiceCompressionEnabled() async {
        let enabledConfiguration = BookingServiceConfigurationFactory.createWithCompression(
            fileName: "booking",
            compressionSupportLevel: .full,
            autoDecompressFiles: true
        )
        let enabledService = BookingService(configuration: enabledConfiguration, fileReader: asyncFileReader)
        
        // 测试压缩功能是否启用
        XCTAssertTrue(enabledConfiguration.enableCompression, "压缩功能应该启用")
        XCTAssertEqual(enabledConfiguration.compressionSupportLevel, .full, "压缩支持级别应该是完整")
        XCTAssertTrue(enabledConfiguration.autoDecompressFiles, "自动解压缩应该启用")
        XCTAssertFalse(enabledConfiguration.supportedCompressionFormats.isEmpty, "支持的压缩格式列表不应该为空")
    }
    
    // MARK: - Compression Format Tests
    
    func testCompressionFormatProperties() {
        let formats: [CompressionFormat] = [.zip, .gzip, .deflate, .lz4, .lzfse, .lzma, .zlib]
        
        for format in formats {
            XCTAssertFalse(format.displayName.isEmpty, "\(format)的显示名称不应该为空")
            XCTAssertFalse(format.mimeType.isEmpty, "\(format)的MIME类型不应该为空")
            XCTAssertFalse(format.fileExtensions.isEmpty, "\(format)的文件扩展名列表不应该为空")
        }
    }
    
    func testCompressionFormatFileExtensions() {
        XCTAssertEqual(CompressionFormat.zip.fileExtensions, ["zip"])
        XCTAssertEqual(CompressionFormat.gzip.fileExtensions, ["gz", "gzip"])
        XCTAssertEqual(CompressionFormat.deflate.fileExtensions, ["deflate"])
        XCTAssertEqual(CompressionFormat.lz4.fileExtensions, ["lz4"])
        XCTAssertEqual(CompressionFormat.lzfse.fileExtensions, ["lzfse"])
        XCTAssertEqual(CompressionFormat.lzma.fileExtensions, ["lzma", "xz"])
        XCTAssertEqual(CompressionFormat.zlib.fileExtensions, ["zlib"])
    }
    
    func testCompressionFormatMimeTypes() {
        XCTAssertEqual(CompressionFormat.zip.mimeType, "application/zip")
        XCTAssertEqual(CompressionFormat.gzip.mimeType, "application/gzip")
        XCTAssertEqual(CompressionFormat.deflate.mimeType, "application/deflate")
        XCTAssertEqual(CompressionFormat.lz4.mimeType, "application/lz4")
        XCTAssertEqual(CompressionFormat.lzfse.mimeType, "application/lzfse")
        XCTAssertEqual(CompressionFormat.lzma.mimeType, "application/x-lzma")
        XCTAssertEqual(CompressionFormat.zlib.mimeType, "application/zlib")
    }
    
    // MARK: - Compression Support Level Tests
    
    func testCompressionSupportLevel() {
        let levels: [CompressionSupportLevel] = [.full, .basic, .disabled]
        
        for level in levels {
            XCTAssertFalse(level.rawValue.isEmpty, "\(level)的原始值不应该为空")
        }
        
        XCTAssertEqual(CompressionSupportLevel.full.rawValue, "完整")
        XCTAssertEqual(CompressionSupportLevel.basic.rawValue, "基础")
        XCTAssertEqual(CompressionSupportLevel.disabled.rawValue, "禁用")
    }
    
    // MARK: - Compression Utils Tests
    
    func testCompressionUtils() {
        let originalSize = 1000
        let compressedSize = 300
        
        let ratio = CompressionUtils.calculateCompressionRatio(originalSize: originalSize, compressedSize: compressedSize)
        XCTAssertEqual(ratio, 0.3, accuracy: 0.01, "压缩比应该是0.3")
        
        let percentage = CompressionUtils.calculateCompressionPercentage(originalSize: originalSize, compressedSize: compressedSize)
        XCTAssertEqual(percentage, 70.0, accuracy: 0.01, "压缩百分比应该是70%")
        
        let formattedSize = CompressionUtils.formatFileSize(1024)
        XCTAssertFalse(formattedSize.isEmpty, "格式化的文件大小不应该为空")
    }
    
    // MARK: - Error Handling Tests
    
    func testCompressionErrorHandling() async {
        let invalidData = Data()
        
        do {
            _ = try await compressionManager.decompress(data: invalidData, format: .gzip)
            XCTFail("解压缩无效数据应该抛出错误")
        } catch {
            XCTAssertTrue(error is BookingDataError, "应该抛出BookingDataError")
        }
    }
    
    func testUnsupportedCompressionFormat() async {
        let testData = "Test data".data(using: .utf8)!
        
        do {
            _ = try await compressionManager.compress(data: testData, format: .zip)
            XCTFail("ZIP压缩应该抛出不支持的错误")
        } catch let error as BookingDataError {
            XCTAssertEqual(error, BookingDataError.unsupportedOperation("ZIP压缩需要第三方库支持"))
        } catch {
            XCTFail("应该抛出BookingDataError.unsupportedOperation错误")
        }
    }
    
    // MARK: - Performance Tests
    
    func testCompressionPerformance() throws {
        let largeData = String(repeating: "This is a test string for compression performance testing. ", count: 1000).data(using: .utf8)!
        
        self.measure {
            let expectation = XCTestExpectation(description: "Compression performance test")
            
            Task {
                do {
                    let compressedData = try await compressionManager.compress(data: largeData, format: .gzip)
                    let decompressedData = try await compressionManager.decompress(data: compressedData, format: .gzip)
                    XCTAssertEqual(decompressedData, largeData)
                    expectation.fulfill()
                } catch {
                    XCTFail("压缩性能测试失败: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createGzipTestData() -> Data {
        let testString = "This is a test string for GZIP compression"
        let originalData = testString.data(using: .utf8)!
        
        // 使用Data扩展创建GZIP数据
        do {
            return try originalData.gzipped()
        } catch {
            // 如果压缩失败，返回一个模拟的GZIP头部
            var gzipData = Data()
            gzipData.append(0x1F) // GZIP magic number
            gzipData.append(0x8B)
            gzipData.append(contentsOf: originalData)
            return gzipData
        }
    }
}

// MARK: - Mock Compression Manager for Testing
class MockCompressionManager: CompressionManagerProtocol {
    
    var shouldDetectCompression = true
    var detectedFormat: CompressionFormat = .gzip
    var shouldCompress = true
    var shouldDecompress = true
    var shouldValidate = true
    
    func detectCompressionFormat(from data: Data) -> CompressionInfo? {
        if shouldDetectCompression {
            return CompressionInfo(
                format: detectedFormat,
                originalSize: data.count * 2,
                compressedSize: data.count,
                compressionRatio: 0.5,
                isCompressed: true
            )
        }
        return nil
    }
    
    func decompress(data: Data, format: CompressionFormat) async throws -> Data {
        if shouldDecompress {
            return data // 模拟解压缩，返回相同数据
        } else {
            throw BookingDataError.dataCorrupted("模拟解压缩失败")
        }
    }
    
    func compress(data: Data, format: CompressionFormat) async throws -> Data {
        if shouldCompress {
            return data // 模拟压缩，返回相同数据
        } else {
            throw BookingDataError.encodingError("模拟压缩失败")
        }
    }
    
    func getZipEntries(from data: Data) async throws -> [CompressedFileEntry] {
        return []
    }
    
    func extractFileFromZip(data: Data, fileName: String) async throws -> Data {
        throw BookingDataError.unsupportedOperation("ZIP文件提取需要第三方库支持")
    }
    
    func validateCompression(data: Data, format: CompressionFormat) async -> Bool {
        return shouldValidate
    }
}
