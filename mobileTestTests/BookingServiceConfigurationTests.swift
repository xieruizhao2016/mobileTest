//
//  BookingServiceConfigurationTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

final class BookingServiceConfigurationTests: XCTestCase {
    
    // MARK: - 配置工厂测试
    
    func testCreateDefaultConfiguration() throws {
        let config = BookingServiceConfigurationFactory.createDefault()
        
        XCTAssertEqual(config.fileName, "booking")
        XCTAssertEqual(config.fileExtension, "json")
        XCTAssertTrue(config.enableVerboseLogging)
        XCTAssertEqual(config.requestTimeout, 30.0)
        XCTAssertTrue(config.enableCaching)
        XCTAssertEqual(config.cacheExpirationTime, 300.0)
        XCTAssertEqual(config.maxRetryAttempts, 3)
        XCTAssertEqual(config.retryConfiguration.baseDelay, 1.0)
    }
    
    func testCreateProductionConfiguration() throws {
        let config = BookingServiceConfigurationFactory.createProduction()
        
        XCTAssertEqual(config.fileName, "booking")
        XCTAssertEqual(config.fileExtension, "json")
        XCTAssertFalse(config.enableVerboseLogging)
        XCTAssertEqual(config.requestTimeout, 15.0)
        XCTAssertTrue(config.enableCaching)
        XCTAssertEqual(config.cacheExpirationTime, 600.0)
        XCTAssertEqual(config.maxRetryAttempts, 2)
        XCTAssertEqual(config.retryConfiguration.baseDelay, 2.0)
    }
    
    func testCreateTestConfiguration() throws {
        let config = BookingServiceConfigurationFactory.createTest()
        
        XCTAssertEqual(config.fileName, "booking")
        XCTAssertEqual(config.fileExtension, "json")
        XCTAssertTrue(config.enableVerboseLogging)
        XCTAssertEqual(config.requestTimeout, 5.0)
        XCTAssertFalse(config.enableCaching)
        XCTAssertEqual(config.cacheExpirationTime, 60.0)
        XCTAssertEqual(config.maxRetryAttempts, 1)
        XCTAssertEqual(config.retryConfiguration.baseDelay, 0.5)
    }
    
    func testCreateTestConfigurationWithCustomFileName() throws {
        let customFileName = "custom_test_booking"
        let config = BookingServiceConfigurationFactory.createTest(fileName: customFileName)
        
        XCTAssertEqual(config.fileName, customFileName)
        XCTAssertEqual(config.fileExtension, "json")
        XCTAssertTrue(config.enableVerboseLogging)
        XCTAssertFalse(config.enableCaching)
    }
    
    func testCreateCustomConfiguration() throws {
        let config = BookingServiceConfigurationFactory.createCustom(
            fileName: "custom_booking",
            fileExtension: "xml",
            enableVerboseLogging: false,
            requestTimeout: 60.0,
            enableCaching: false,
            cacheExpirationTime: 120.0,
            maxRetryAttempts: 5,
            retryConfiguration: RetryConfiguration(baseDelay: 3.0, maxDelay: 10.0, maxAttempts: 5, strategy: .exponential)
        )
        
        XCTAssertEqual(config.fileName, "custom_booking")
        XCTAssertEqual(config.fileExtension, "xml")
        XCTAssertFalse(config.enableVerboseLogging)
        XCTAssertEqual(config.requestTimeout, 60.0)
        XCTAssertFalse(config.enableCaching)
        XCTAssertEqual(config.cacheExpirationTime, 120.0)
        XCTAssertEqual(config.maxRetryAttempts, 5)
        XCTAssertEqual(config.retryConfiguration.baseDelay, 3.0)
    }
    
    // MARK: - 配置实现测试
    
    func testDefaultBookingServiceConfiguration() throws {
        let config = DefaultBookingServiceConfiguration()
        
        XCTAssertEqual(config.fileName, "booking")
        XCTAssertEqual(config.fileExtension, "json")
        XCTAssertTrue(config.enableVerboseLogging)
        XCTAssertTrue(config.enableCaching)
    }
    
    func testDefaultBookingServiceConfigurationWithCustomValues() throws {
        let config = DefaultBookingServiceConfiguration(
            fileName: "test_file",
            fileExtension: "txt",
            enableVerboseLogging: false,
            requestTimeout: 45.0,
            enableCaching: false,
            cacheExpirationTime: 180.0,
            maxRetryAttempts: 4,
            retryConfiguration: RetryConfiguration(baseDelay: 1.5, maxDelay: 5.0, maxAttempts: 4, strategy: .exponential)
        )
        
        XCTAssertEqual(config.fileName, "test_file")
        XCTAssertEqual(config.fileExtension, "txt")
        XCTAssertFalse(config.enableVerboseLogging)
        XCTAssertEqual(config.requestTimeout, 45.0)
        XCTAssertFalse(config.enableCaching)
        XCTAssertEqual(config.cacheExpirationTime, 180.0)
        XCTAssertEqual(config.maxRetryAttempts, 4)
        XCTAssertEqual(config.retryConfiguration.baseDelay, 1.5)
    }
    
    func testProductionBookingServiceConfiguration() throws {
        let config = ProductionBookingServiceConfiguration()
        
        XCTAssertEqual(config.fileName, "booking")
        XCTAssertEqual(config.fileExtension, "json")
        XCTAssertFalse(config.enableVerboseLogging)
        XCTAssertEqual(config.requestTimeout, 15.0)
        XCTAssertTrue(config.enableCaching)
        XCTAssertEqual(config.cacheExpirationTime, 600.0)
        XCTAssertEqual(config.maxRetryAttempts, 2)
        XCTAssertEqual(config.retryConfiguration.baseDelay, 2.0)
    }
    
    func testTestBookingServiceConfiguration() throws {
        let config = TestBookingServiceConfiguration()
        
        XCTAssertEqual(config.fileName, "booking")
        XCTAssertEqual(config.fileExtension, "json")
        XCTAssertTrue(config.enableVerboseLogging)
        XCTAssertEqual(config.requestTimeout, 5.0)
        XCTAssertFalse(config.enableCaching)
        XCTAssertEqual(config.cacheExpirationTime, 60.0)
        XCTAssertEqual(config.maxRetryAttempts, 1)
        XCTAssertEqual(config.retryConfiguration.baseDelay, 0.5)
    }
    
    func testTestBookingServiceConfigurationWithCustomFileName() throws {
        let customFileName = "my_test_file"
        let config = TestBookingServiceConfiguration(fileName: customFileName)
        
        XCTAssertEqual(config.fileName, customFileName)
        XCTAssertEqual(config.fileExtension, "json")
        XCTAssertTrue(config.enableVerboseLogging)
        XCTAssertFalse(config.enableCaching)
    }
    
    // MARK: - 配置协议一致性测试
    
    func testConfigurationProtocolConformance() throws {
        let defaultConfig: BookingServiceConfigurationProtocol = DefaultBookingServiceConfiguration()
        let productionConfig: BookingServiceConfigurationProtocol = ProductionBookingServiceConfiguration()
        let testConfig: BookingServiceConfigurationProtocol = TestBookingServiceConfiguration()
        
        // 验证所有配置都实现了协议
        XCTAssertNotNil(defaultConfig)
        XCTAssertNotNil(productionConfig)
        XCTAssertNotNil(testConfig)
        
        // 验证基本属性存在
        XCTAssertFalse(defaultConfig.fileName.isEmpty)
        XCTAssertFalse(productionConfig.fileName.isEmpty)
        XCTAssertFalse(testConfig.fileName.isEmpty)
        
        XCTAssertFalse(defaultConfig.fileExtension.isEmpty)
        XCTAssertFalse(productionConfig.fileExtension.isEmpty)
        XCTAssertFalse(testConfig.fileExtension.isEmpty)
    }
    
    // MARK: - 边界值测试
    
    func testConfigurationBoundaryValues() throws {
        let config = BookingServiceConfigurationFactory.createCustom(
            fileName: "a", // 最小长度
            fileExtension: "x", // 最小长度
            enableVerboseLogging: false,
            requestTimeout: 0.1, // 最小超时时间
            enableCaching: false,
            cacheExpirationTime: 0.1, // 最小缓存时间
            maxRetryAttempts: 1, // 最小重试次数
            retryConfiguration: RetryConfiguration(baseDelay: 0.1, maxDelay: 1.0, maxAttempts: 1, strategy: .exponential)
        )
        
        XCTAssertEqual(config.fileName, "a")
        XCTAssertEqual(config.fileExtension, "x")
        XCTAssertEqual(config.requestTimeout, 0.1)
        XCTAssertEqual(config.cacheExpirationTime, 0.1)
        XCTAssertEqual(config.maxRetryAttempts, 1)
        XCTAssertEqual(config.retryConfiguration.baseDelay, 0.1)
    }
    
    func testConfigurationLargeValues() throws {
        let config = BookingServiceConfigurationFactory.createCustom(
            fileName: "very_long_file_name_for_testing_purposes",
            fileExtension: "very_long_extension",
            enableVerboseLogging: true,
            requestTimeout: 3600.0, // 1小时
            enableCaching: true,
            cacheExpirationTime: 86400.0, // 24小时
            maxRetryAttempts: 10,
            retryConfiguration: RetryConfiguration(baseDelay: 60.0, maxDelay: 300.0, maxAttempts: 10, strategy: .exponential)
        )
        
        XCTAssertEqual(config.fileName, "very_long_file_name_for_testing_purposes")
        XCTAssertEqual(config.fileExtension, "very_long_extension")
        XCTAssertEqual(config.requestTimeout, 3600.0)
        XCTAssertEqual(config.cacheExpirationTime, 86400.0)
        XCTAssertEqual(config.maxRetryAttempts, 10)
        XCTAssertEqual(config.retryConfiguration.baseDelay, 60.0)
    }
}
