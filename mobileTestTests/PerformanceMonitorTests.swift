//
//  PerformanceMonitorTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

class PerformanceMonitorTests: XCTestCase {
    
    var monitor: PerformanceMonitorProtocol!
    
    override func setUp() {
        super.setUp()
        monitor = PerformanceMonitorFactory.createDefault(enableVerboseLogging: false)
    }
    
    override func tearDown() {
        monitor = nil
        super.tearDown()
    }
    
    // MARK: - 基本功能测试
    
    func testRecordMetric() {
        // Given
        let metric = PerformanceMetric(
            type: .executionTime,
            value: 100.0,
            unit: "ms",
            context: "test"
        )
        
        // When
        monitor.recordMetric(metric)
        
        // Then
        let statistics = monitor.getStatistics(for: .executionTime)
        XCTAssertNotNil(statistics)
        XCTAssertEqual(statistics?.count, 1)
        XCTAssertEqual(statistics?.average, 100.0)
    }
    
    func testGetStatistics() {
        // Given
        let metrics = [
            PerformanceMetric(type: .executionTime, value: 100.0, unit: "ms", context: "test1"),
            PerformanceMetric(type: .executionTime, value: 200.0, unit: "ms", context: "test2"),
            PerformanceMetric(type: .executionTime, value: 300.0, unit: "ms", context: "test3")
        ]
        
        // When
        for metric in metrics {
            monitor.recordMetric(metric)
        }
        
        // Then
        let statistics = monitor.getStatistics(for: .executionTime)
        XCTAssertNotNil(statistics)
        XCTAssertEqual(statistics?.count, 3)
        XCTAssertEqual(statistics?.min, 100.0)
        XCTAssertEqual(statistics?.max, 300.0)
        XCTAssertEqual(statistics?.average, 200.0)
        XCTAssertEqual(statistics?.median, 200.0)
    }
    
    func testGetAllStatistics() {
        // Given
        let metrics = [
            PerformanceMetric(type: .executionTime, value: 100.0, unit: "ms", context: "test1"),
            PerformanceMetric(type: .memoryUsage, value: 50.0, unit: "MB", context: "test2"),
            PerformanceMetric(type: .networkLatency, value: 200.0, unit: "ms", context: "test3")
        ]
        
        // When
        for metric in metrics {
            monitor.recordMetric(metric)
        }
        
        // Then
        let allStatistics = monitor.getAllStatistics()
        XCTAssertEqual(allStatistics.count, 3)
        XCTAssertNotNil(allStatistics[.executionTime])
        XCTAssertNotNil(allStatistics[.memoryUsage])
        XCTAssertNotNil(allStatistics[.networkLatency])
    }
    
    func testClearData() {
        // Given
        let metric = PerformanceMetric(
            type: .executionTime,
            value: 100.0,
            unit: "ms",
            context: "test"
        )
        monitor.recordMetric(metric)
        
        // When
        monitor.clearData()
        
        // Then
        let statistics = monitor.getStatistics(for: .executionTime)
        XCTAssertNil(statistics)
    }
    
    func testClearDataInTimeRange() {
        // Given
        let now = Date()
        let pastMetric = PerformanceMetric(
            type: .executionTime,
            value: 100.0,
            unit: "ms",
            context: "past"
        )
        monitor.recordMetric(pastMetric)
        
        // 等待一小段时间
        Thread.sleep(forTimeInterval: 0.1)
        
        let recentMetric = PerformanceMetric(
            type: .executionTime,
            value: 200.0,
            unit: "ms",
            context: "recent"
        )
        monitor.recordMetric(recentMetric)
        
        // When
        let timeRange = (start: now.addingTimeInterval(0.05), end: Date())
        monitor.clearData(in: timeRange)
        
        // Then
        let statistics = monitor.getStatistics(for: .executionTime)
        XCTAssertNotNil(statistics)
        XCTAssertEqual(statistics?.count, 1)
        XCTAssertEqual(statistics?.average, 100.0)
    }
    
    // MARK: - 统计计算测试
    
    func testStatisticsCalculation() {
        // Given
        let values = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
        let metrics = values.map { value in
            PerformanceMetric(type: .executionTime, value: value, unit: "ms", context: "test")
        }
        
        // When
        for metric in metrics {
            monitor.recordMetric(metric)
        }
        
        // Then
        let statistics = monitor.getStatistics(for: .executionTime)
        XCTAssertNotNil(statistics)
        XCTAssertEqual(statistics?.count, 10)
        XCTAssertEqual(statistics?.min, 10.0)
        XCTAssertEqual(statistics?.max, 100.0)
        XCTAssertEqual(statistics?.average, 55.0)
        XCTAssertEqual(statistics?.median, 55.0)
        XCTAssertEqual(statistics?.p95, 95.0)
        XCTAssertEqual(statistics?.p99, 99.0)
    }
    
    // MARK: - 导出功能测试
    
    func testExportAsJSON() {
        // Given
        let metric = PerformanceMetric(
            type: .executionTime,
            value: 100.0,
            unit: "ms",
            context: "test"
        )
        monitor.recordMetric(metric)
        
        // When
        let jsonData = monitor.exportData(format: .json)
        
        // Then
        XCTAssertNotNil(jsonData)
        
        let json = try? JSONSerialization.jsonObject(with: jsonData!, options: [])
        XCTAssertNotNil(json)
        
        if let jsonDict = json as? [String: Any] {
            XCTAssertTrue(jsonDict.keys.contains("exportTime"))
            XCTAssertTrue(jsonDict.keys.contains("metricsCount"))
            XCTAssertTrue(jsonDict.keys.contains("metrics"))
        }
    }
    
    func testExportAsCSV() {
        // Given
        let metric = PerformanceMetric(
            type: .executionTime,
            value: 100.0,
            unit: "ms",
            context: "test"
        )
        monitor.recordMetric(metric)
        
        // When
        let csvData = monitor.exportData(format: .csv)
        
        // Then
        XCTAssertNotNil(csvData)
        
        let csvString = String(data: csvData!, encoding: .utf8)
        XCTAssertNotNil(csvString)
        XCTAssertTrue(csvString!.contains("ID,Type,Value,Unit,Timestamp,Context,Metadata"))
        XCTAssertTrue(csvString!.contains("executionTime"))
        XCTAssertTrue(csvString!.contains("100.0"))
    }
    
    func testExportAsXML() {
        // Given
        let metric = PerformanceMetric(
            type: .executionTime,
            value: 100.0,
            unit: "ms",
            context: "test"
        )
        monitor.recordMetric(metric)
        
        // When
        let xmlData = monitor.exportData(format: .xml)
        
        // Then
        XCTAssertNotNil(xmlData)
        
        let xmlString = String(data: xmlData!, encoding: .utf8)
        XCTAssertNotNil(xmlString)
        XCTAssertTrue(xmlString!.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        XCTAssertTrue(xmlString!.contains("<PerformanceData>"))
        XCTAssertTrue(xmlString!.contains("<Metric>"))
    }
    
    // MARK: - 性能监控装饰器测试
    
    func testPerformanceMonitoringDecorator() {
        // Given
        let decorator = PerformanceMonitorFactory.createDecorator(monitor: monitor, enableVerboseLogging: false)
        
        // When
        decorator.recordMemoryUsage(context: "test")
        decorator.recordNetworkLatency(150.0, context: "test")
        decorator.recordCacheHitRate(85.0, context: "test")
        decorator.recordErrorRate(5.0, context: "test")
        decorator.recordThroughput(100.0, context: "test")
        decorator.recordResponseSize(1024, context: "test")
        decorator.recordRetryCount(2, context: "test")
        decorator.recordValidationTime(50.0, context: "test")
        
        // Then
        let memoryStats = monitor.getStatistics(for: .memoryUsage)
        XCTAssertNotNil(memoryStats)
        
        let latencyStats = monitor.getStatistics(for: .networkLatency)
        XCTAssertNotNil(latencyStats)
        XCTAssertEqual(latencyStats?.average, 150.0)
        
        let cacheStats = monitor.getStatistics(for: .cacheHitRate)
        XCTAssertNotNil(cacheStats)
        XCTAssertEqual(cacheStats?.average, 85.0)
        
        let errorStats = monitor.getStatistics(for: .errorRate)
        XCTAssertNotNil(errorStats)
        XCTAssertEqual(errorStats?.average, 5.0)
        
        let throughputStats = monitor.getStatistics(for: .throughput)
        XCTAssertNotNil(throughputStats)
        XCTAssertEqual(throughputStats?.average, 100.0)
        
        let responseStats = monitor.getStatistics(for: .responseSize)
        XCTAssertNotNil(responseStats)
        XCTAssertEqual(responseStats?.average, 1024.0)
        
        let retryStats = monitor.getStatistics(for: .retryCount)
        XCTAssertNotNil(retryStats)
        XCTAssertEqual(retryStats?.average, 2.0)
        
        let validationStats = monitor.getStatistics(for: .validationTime)
        XCTAssertNotNil(validationStats)
        XCTAssertEqual(validationStats?.average, 50.0)
    }
    
    func testMonitorSyncOperation() {
        // Given
        let decorator = PerformanceMonitorFactory.createDecorator(monitor: monitor, enableVerboseLogging: false)
        
        // When
        do {
            let result = try decorator.monitorSyncOperation({
                Thread.sleep(forTimeInterval: 0.1) // 模拟100ms的操作
                return "success"
            }, context: "test")
            
            // Then
            XCTAssertEqual(result, "success")
            
            let stats = monitor.getStatistics(for: .executionTime)
            XCTAssertNotNil(stats)
            XCTAssertEqual(stats?.count, 1)
            XCTAssertGreaterThan(stats?.average ?? 0, 90.0) // 应该大于90ms
            XCTAssertLessThan(stats?.average ?? 0, 200.0) // 应该小于200ms
        } catch {
            XCTFail("操作不应该失败")
        }
    }
    
    func testMonitorSyncOperationWithError() {
        // Given
        let decorator = PerformanceMonitorFactory.createDecorator(monitor: monitor, enableVerboseLogging: false)
        
        // When
        do {
            _ = try decorator.monitorSyncOperation({
                throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "测试错误"])
            }, context: "test")
            XCTFail("应该抛出错误")
        } catch {
            // Then
            let stats = monitor.getStatistics(for: .executionTime)
            XCTAssertNotNil(stats)
            XCTAssertEqual(stats?.count, 1)
        }
    }
    
    // MARK: - 工厂测试
    
    func testPerformanceMonitorFactory() {
        // When
        let defaultMonitor = PerformanceMonitorFactory.createDefault()
        let highPerformanceMonitor = PerformanceMonitorFactory.createHighPerformance()
        let lightweightMonitor = PerformanceMonitorFactory.createLightweight()
        let decorator = PerformanceMonitorFactory.createDecorator(monitor: defaultMonitor)
        
        // Then
        XCTAssertNotNil(defaultMonitor)
        XCTAssertNotNil(highPerformanceMonitor)
        XCTAssertNotNil(lightweightMonitor)
        XCTAssertNotNil(decorator)
    }
    
    // MARK: - 空监控器测试
    
    func testEmptyPerformanceMonitor() {
        // Given
        let emptyMonitor = EmptyPerformanceMonitor()
        let metric = PerformanceMetric(
            type: .executionTime,
            value: 100.0,
            unit: "ms",
            context: "test"
        )
        
        // When
        emptyMonitor.recordMetric(metric)
        let statistics = emptyMonitor.getStatistics(for: .executionTime)
        let allStatistics = emptyMonitor.getAllStatistics()
        let exportData = emptyMonitor.exportData(format: .json)
        
        // Then
        XCTAssertNil(statistics)
        XCTAssertTrue(allStatistics.isEmpty)
        XCTAssertNil(exportData)
    }
    
    // MARK: - 边界情况测试
    
    func testEmptyStatistics() {
        // When
        let statistics = monitor.getStatistics(for: .executionTime)
        
        // Then
        XCTAssertNil(statistics)
    }
    
    func testSingleMetricStatistics() {
        // Given
        let metric = PerformanceMetric(
            type: .executionTime,
            value: 100.0,
            unit: "ms",
            context: "test"
        )
        
        // When
        monitor.recordMetric(metric)
        let statistics = monitor.getStatistics(for: .executionTime)
        
        // Then
        XCTAssertNotNil(statistics)
        XCTAssertEqual(statistics?.count, 1)
        XCTAssertEqual(statistics?.min, 100.0)
        XCTAssertEqual(statistics?.max, 100.0)
        XCTAssertEqual(statistics?.average, 100.0)
        XCTAssertEqual(statistics?.median, 100.0)
        XCTAssertEqual(statistics?.p95, 100.0)
        XCTAssertEqual(statistics?.p99, 100.0)
    }
    
    func testLargeDataset() {
        // Given
        let largeDataset = (1...1000).map { value in
            PerformanceMetric(
                type: .executionTime,
                value: Double(value),
                unit: "ms",
                context: "test"
            )
        }
        
        // When
        for metric in largeDataset {
            monitor.recordMetric(metric)
        }
        
        // Then
        let statistics = monitor.getStatistics(for: .executionTime)
        XCTAssertNotNil(statistics)
        XCTAssertEqual(statistics?.count, 1000)
        XCTAssertEqual(statistics?.min, 1.0)
        XCTAssertEqual(statistics?.max, 1000.0)
        XCTAssertEqual(statistics?.average, 500.5)
    }
}

// MARK: - 性能统计测试
class PerformanceStatisticsTests: XCTestCase {
    
    func testFormattedSummary() {
        // Given
        let statistics = PerformanceStatistics(
            metricType: .executionTime,
            count: 100,
            min: 10.0,
            max: 1000.0,
            average: 500.0,
            median: 450.0,
            p95: 900.0,
            p99: 950.0,
            standardDeviation: 200.0,
            timeRange: (start: Date(), end: Date())
        )
        
        // When
        let summary = statistics.formattedSummary
        
        // Then
        XCTAssertTrue(summary.contains("执行时间统计"))
        XCTAssertTrue(summary.contains("样本数量: 100"))
        XCTAssertTrue(summary.contains("最小值: 10.00 ms"))
        XCTAssertTrue(summary.contains("最大值: 1000.00 ms"))
        XCTAssertTrue(summary.contains("平均值: 500.00 ms"))
        XCTAssertTrue(summary.contains("中位数: 450.00 ms"))
        XCTAssertTrue(summary.contains("95分位数: 900.00 ms"))
        XCTAssertTrue(summary.contains("99分位数: 950.00 ms"))
        XCTAssertTrue(summary.contains("标准差: 200.00"))
    }
    
    func testDifferentMetricTypes() {
        // Given
        let executionTimeStats = PerformanceStatistics(
            metricType: .executionTime,
            count: 1,
            min: 100.0,
            max: 100.0,
            average: 100.0,
            median: 100.0,
            p95: 100.0,
            p99: 100.0,
            standardDeviation: 0.0,
            timeRange: (start: Date(), end: Date())
        )
        
        let memoryStats = PerformanceStatistics(
            metricType: .memoryUsage,
            count: 1,
            min: 50.0,
            max: 50.0,
            average: 50.0,
            median: 50.0,
            p95: 50.0,
            p99: 50.0,
            standardDeviation: 0.0,
            timeRange: (start: Date(), end: Date())
        )
        
        // When
        let executionSummary = executionTimeStats.formattedSummary
        let memorySummary = memoryStats.formattedSummary
        
        // Then
        XCTAssertTrue(executionSummary.contains("ms"))
        XCTAssertTrue(memorySummary.contains("MB"))
    }
}
