//
//  PerformanceMonitor.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

// MARK: - 性能指标类型
enum PerformanceMetricType: String, CaseIterable {
    case executionTime = "执行时间"
    case memoryUsage = "内存使用"
    case cpuUsage = "CPU使用率"
    case networkLatency = "网络延迟"
    case cacheHitRate = "缓存命中率"
    case errorRate = "错误率"
    case throughput = "吞吐量"
    case responseSize = "响应大小"
    case retryCount = "重试次数"
    case validationTime = "验证时间"
}

// MARK: - 性能指标数据
struct PerformanceMetric {
    let id: String
    let type: PerformanceMetricType
    let value: Double
    let unit: String
    let timestamp: Date
    let context: String
    let metadata: [String: Any]
    
    init(
        type: PerformanceMetricType,
        value: Double,
        unit: String,
        context: String,
        metadata: [String: Any] = [:]
    ) {
        self.id = UUID().uuidString
        self.type = type
        self.value = value
        self.unit = unit
        self.timestamp = Date()
        self.context = context
        self.metadata = metadata
    }
}

// MARK: - 性能统计信息
struct PerformanceStatistics {
    let metricType: PerformanceMetricType
    let count: Int
    let min: Double
    let max: Double
    let average: Double
    let median: Double
    let p95: Double
    let p99: Double
    let standardDeviation: Double
    let timeRange: (start: Date, end: Date)
    
    var formattedSummary: String {
        return """
        \(metricType.rawValue)统计:
        - 样本数量: \(count)
        - 最小值: \(String(format: "%.2f", min)) \(getUnit())
        - 最大值: \(String(format: "%.2f", max)) \(getUnit())
        - 平均值: \(String(format: "%.2f", average)) \(getUnit())
        - 中位数: \(String(format: "%.2f", median)) \(getUnit())
        - 95分位数: \(String(format: "%.2f", p95)) \(getUnit())
        - 99分位数: \(String(format: "%.2f", p99)) \(getUnit())
        - 标准差: \(String(format: "%.2f", standardDeviation))
        - 时间范围: \(formatDateRange())
        """
    }
    
    private func getUnit() -> String {
        switch metricType {
        case .executionTime, .networkLatency, .validationTime:
            return "ms"
        case .memoryUsage:
            return "MB"
        case .cpuUsage:
            return "%"
        case .cacheHitRate, .errorRate:
            return "%"
        case .throughput:
            return "req/s"
        case .responseSize:
            return "bytes"
        case .retryCount:
            return "次"
        }
    }
    
    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "\(formatter.string(from: timeRange.start)) - \(formatter.string(from: timeRange.end))"
    }
}

// MARK: - 性能监控协议
protocol PerformanceMonitorProtocol {
    /// 记录性能指标
    /// - Parameter metric: 性能指标
    func recordMetric(_ metric: PerformanceMetric)
    
    /// 获取指定类型的性能统计
    /// - Parameters:
    ///   - type: 指标类型
    ///   - timeRange: 时间范围
    /// - Returns: 性能统计信息
    func getStatistics(for type: PerformanceMetricType, in timeRange: (start: Date, end: Date)?) -> PerformanceStatistics?
    
    /// 获取所有指标类型的统计
    /// - Parameter timeRange: 时间范围
    /// - Returns: 所有指标类型的统计信息
    func getAllStatistics(in timeRange: (start: Date, end: Date)?) -> [PerformanceMetricType: PerformanceStatistics]
    
    /// 清除指定时间范围的数据
    /// - Parameter timeRange: 时间范围
    func clearData(in timeRange: (start: Date, end: Date)?)
    
    /// 导出性能数据
    /// - Parameter format: 导出格式
    /// - Returns: 导出的数据
    func exportData(format: ExportFormat) -> Data?
}

// MARK: - 导出格式
enum ExportFormat {
    case json
    case csv
    case xml
}

// MARK: - 性能监控器实现
class PerformanceMonitor: PerformanceMonitorProtocol {
    
    private var metrics: [PerformanceMetric] = []
    private let queue = DispatchQueue(label: "com.mobiletest.performance", attributes: .concurrent)
    private let enableVerboseLogging: Bool
    private let maxMetricsCount: Int
    
    init(enableVerboseLogging: Bool = true, maxMetricsCount: Int = 10000) {
        self.enableVerboseLogging = enableVerboseLogging
        self.maxMetricsCount = maxMetricsCount
    }
    
    func recordMetric(_ metric: PerformanceMetric) {
        queue.async(flags: .barrier) {
            self.metrics.append(metric)
            
            // 保持指标数量在限制范围内
            if self.metrics.count > self.maxMetricsCount {
                self.metrics.removeFirst(self.metrics.count - self.maxMetricsCount)
            }
            
            if self.enableVerboseLogging {
                print("📊 [PerformanceMonitor] 记录指标: \(metric.type.rawValue) = \(metric.value) \(metric.unit) [\(metric.context)]")
            }
        }
    }
    
    func getStatistics(for type: PerformanceMetricType, in timeRange: (start: Date, end: Date)? = nil) -> PerformanceStatistics? {
        return queue.sync {
            let filteredMetrics = filterMetrics(by: type, in: timeRange)
            guard !filteredMetrics.isEmpty else { return nil }
            
            return calculateStatistics(for: filteredMetrics, type: type)
        }
    }
    
    func getAllStatistics(in timeRange: (start: Date, end: Date)? = nil) -> [PerformanceMetricType: PerformanceStatistics] {
        return queue.sync {
            var statistics: [PerformanceMetricType: PerformanceStatistics] = [:]
            
            for type in PerformanceMetricType.allCases {
                if let stats = getStatistics(for: type, in: timeRange) {
                    statistics[type] = stats
                }
            }
            
            return statistics
        }
    }
    
    func clearData(in timeRange: (start: Date, end: Date)? = nil) {
        queue.async(flags: .barrier) {
            if let timeRange = timeRange {
                self.metrics.removeAll { metric in
                    metric.timestamp >= timeRange.start && metric.timestamp <= timeRange.end
                }
            } else {
                self.metrics.removeAll()
            }
            
            if self.enableVerboseLogging {
                print("🗑️ [PerformanceMonitor] 清除性能数据")
            }
        }
    }
    
    func exportData(format: ExportFormat) -> Data? {
        return queue.sync {
            switch format {
            case .json:
                return exportAsJSON()
            case .csv:
                return exportAsCSV()
            case .xml:
                return exportAsXML()
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func filterMetrics(by type: PerformanceMetricType, in timeRange: (start: Date, end: Date)?) -> [PerformanceMetric] {
        var filtered = metrics.filter { $0.type == type }
        
        if let timeRange = timeRange {
            filtered = filtered.filter { metric in
                metric.timestamp >= timeRange.start && metric.timestamp <= timeRange.end
            }
        }
        
        return filtered
    }
    
    private func calculateStatistics(for metrics: [PerformanceMetric], type: PerformanceMetricType) -> PerformanceStatistics {
        let values = metrics.map { $0.value }.sorted()
        let count = values.count
        
        let min = values.first ?? 0
        let max = values.last ?? 0
        let average = values.reduce(0, +) / Double(count)
        
        let median = count % 2 == 0 ? 
            (values[count/2 - 1] + values[count/2]) / 2 : 
            values[count/2]
        
        let p95Index = Int(Double(count) * 0.95)
        let p95 = p95Index < count ? values[p95Index] : max
        
        let p99Index = Int(Double(count) * 0.99)
        let p99 = p99Index < count ? values[p99Index] : max
        
        let variance = values.map { pow($0 - average, 2) }.reduce(0, +) / Double(count)
        let standardDeviation = sqrt(variance)
        
        let timeRange = (
            start: metrics.map { $0.timestamp }.min() ?? Date(),
            end: metrics.map { $0.timestamp }.max() ?? Date()
        )
        
        return PerformanceStatistics(
            metricType: type,
            count: count,
            min: min,
            max: max,
            average: average,
            median: median,
            p95: p95,
            p99: p99,
            standardDeviation: standardDeviation,
            timeRange: timeRange
        )
    }
    
    private func exportAsJSON() -> Data? {
        let exportData: [String: Any] = [
            "exportTime": Date().timeIntervalSince1970,
            "metricsCount": metrics.count,
            "metrics": metrics.map { metric in
                [
                    "id": metric.id,
                    "type": metric.type.rawValue,
                    "value": metric.value,
                    "unit": metric.unit,
                    "timestamp": metric.timestamp.timeIntervalSince1970,
                    "context": metric.context,
                    "metadata": metric.metadata
                ]
            }
        ]
        
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    private func exportAsCSV() -> Data? {
        let header = "ID,Type,Value,Unit,Timestamp,Context,Metadata\n"
        let rows = metrics.map { metric in
            let metadataString = (try? JSONSerialization.data(withJSONObject: metric.metadata))
                .flatMap { String(data: $0, encoding: .utf8) } ?? ""
            return "\(metric.id),\(metric.type.rawValue),\(metric.value),\(metric.unit),\(metric.timestamp.timeIntervalSince1970),\(metric.context),\"\(metadataString)\""
        }
        
        let csvContent = header + rows.joined(separator: "\n")
        return csvContent.data(using: .utf8)
    }
    
    private func exportAsXML() -> Data? {
        let xmlContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <PerformanceData>
            <ExportTime>\(Date().timeIntervalSince1970)</ExportTime>
            <MetricsCount>\(metrics.count)</MetricsCount>
            <Metrics>
        \(metrics.map { metric in
            let metadataString = (try? JSONSerialization.data(withJSONObject: metric.metadata))
                .flatMap { String(data: $0, encoding: .utf8) } ?? ""
            return """
                <Metric>
                    <ID>\(metric.id)</ID>
                    <Type>\(metric.type.rawValue)</Type>
                    <Value>\(metric.value)</Value>
                    <Unit>\(metric.unit)</Unit>
                    <Timestamp>\(metric.timestamp.timeIntervalSince1970)</Timestamp>
                    <Context>\(metric.context)</Context>
                    <Metadata>\(metadataString)</Metadata>
                </Metric>
            """
        }.joined(separator: "\n"))
            </Metrics>
        </PerformanceData>
        """
        
        return xmlContent.data(using: .utf8)
    }
}

// MARK: - 性能监控装饰器
class PerformanceMonitoringDecorator {
    private let monitor: PerformanceMonitorProtocol
    private let enableVerboseLogging: Bool
    
    init(monitor: PerformanceMonitorProtocol, enableVerboseLogging: Bool = true) {
        self.monitor = monitor
        self.enableVerboseLogging = enableVerboseLogging
    }
    
    /// 监控异步操作的执行时间
    /// - Parameters:
    ///   - operation: 要监控的操作
    ///   - context: 操作上下文
    ///   - completion: 完成回调
    func monitorAsyncOperation<T>(
        _ operation: @escaping () async throws -> T,
        context: String,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let startTime = Date()
        
        Task {
            do {
                let result = try await operation()
                let executionTime = Date().timeIntervalSince(startTime) * 1000 // 转换为毫秒
                
                let metric = PerformanceMetric(
                    type: .executionTime,
                    value: executionTime,
                    unit: "ms",
                    context: context,
                    metadata: ["success": true]
                )
                monitor.recordMetric(metric)
                
                completion(.success(result))
            } catch {
                let executionTime = Date().timeIntervalSince(startTime) * 1000
                
                let metric = PerformanceMetric(
                    type: .executionTime,
                    value: executionTime,
                    unit: "ms",
                    context: context,
                    metadata: ["success": false, "error": error.localizedDescription]
                )
                monitor.recordMetric(metric)
                
                completion(.failure(error))
            }
        }
    }
    
    /// 监控同步操作的执行时间
    /// - Parameters:
    ///   - operation: 要监控的操作
    ///   - context: 操作上下文
    /// - Returns: 操作结果
    func monitorSyncOperation<T>(
        _ operation: () throws -> T,
        context: String
    ) throws -> T {
        let startTime = Date()
        
        do {
            let result = try operation()
            let executionTime = Date().timeIntervalSince(startTime) * 1000
            
            let metric = PerformanceMetric(
                type: .executionTime,
                value: executionTime,
                unit: "ms",
                context: context,
                metadata: ["success": true]
            )
            monitor.recordMetric(metric)
            
            return result
        } catch {
            let executionTime = Date().timeIntervalSince(startTime) * 1000
            
            let metric = PerformanceMetric(
                type: .executionTime,
                value: executionTime,
                unit: "ms",
                context: context,
                metadata: ["success": false, "error": error.localizedDescription]
            )
            monitor.recordMetric(metric)
            
            throw error
        }
    }
    
    /// 记录内存使用情况
    /// - Parameter context: 上下文
    func recordMemoryUsage(context: String) {
        let memoryInfo = getMemoryInfo()
        let metric = PerformanceMetric(
            type: .memoryUsage,
            value: memoryInfo.used,
            unit: "MB",
            context: context,
            metadata: [
                "total": memoryInfo.total,
                "available": memoryInfo.available,
                "usage_percentage": memoryInfo.usagePercentage
            ]
        )
        monitor.recordMetric(metric)
    }
    
    /// 记录网络延迟
    /// - Parameters:
    ///   - latency: 延迟时间（毫秒）
    ///   - context: 上下文
    func recordNetworkLatency(_ latency: Double, context: String) {
        let metric = PerformanceMetric(
            type: .networkLatency,
            value: latency,
            unit: "ms",
            context: context
        )
        monitor.recordMetric(metric)
    }
    
    /// 记录缓存命中率
    /// - Parameters:
    ///   - hitRate: 命中率（0-100）
    ///   - context: 上下文
    func recordCacheHitRate(_ hitRate: Double, context: String) {
        let metric = PerformanceMetric(
            type: .cacheHitRate,
            value: hitRate,
            unit: "%",
            context: context
        )
        monitor.recordMetric(metric)
    }
    
    /// 记录错误率
    /// - Parameters:
    ///   - errorRate: 错误率（0-100）
    ///   - context: 上下文
    func recordErrorRate(_ errorRate: Double, context: String) {
        let metric = PerformanceMetric(
            type: .errorRate,
            value: errorRate,
            unit: "%",
            context: context
        )
        monitor.recordMetric(metric)
    }
    
    /// 记录吞吐量
    /// - Parameters:
    ///   - throughput: 吞吐量（请求/秒）
    ///   - context: 上下文
    func recordThroughput(_ throughput: Double, context: String) {
        let metric = PerformanceMetric(
            type: .throughput,
            value: throughput,
            unit: "req/s",
            context: context
        )
        monitor.recordMetric(metric)
    }
    
    /// 记录响应大小
    /// - Parameters:
    ///   - size: 响应大小（字节）
    ///   - context: 上下文
    func recordResponseSize(_ size: Int, context: String) {
        let metric = PerformanceMetric(
            type: .responseSize,
            value: Double(size),
            unit: "bytes",
            context: context
        )
        monitor.recordMetric(metric)
    }
    
    /// 记录重试次数
    /// - Parameters:
    ///   - count: 重试次数
    ///   - context: 上下文
    func recordRetryCount(_ count: Int, context: String) {
        let metric = PerformanceMetric(
            type: .retryCount,
            value: Double(count),
            unit: "次",
            context: context
        )
        monitor.recordMetric(metric)
    }
    
    /// 记录验证时间
    /// - Parameters:
    ///   - time: 验证时间（毫秒）
    ///   - context: 上下文
    func recordValidationTime(_ time: Double, context: String) {
        let metric = PerformanceMetric(
            type: .validationTime,
            value: time,
            unit: "ms",
            context: context
        )
        monitor.recordMetric(metric)
    }
    
    // MARK: - 私有方法
    
    private func getMemoryInfo() -> (used: Double, total: Double, available: Double, usagePercentage: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            let availableMB = totalMB - usedMB
            let usagePercentage = (usedMB / totalMB) * 100.0
            
            return (used: usedMB, total: totalMB, available: availableMB, usagePercentage: usagePercentage)
        }
        
        return (used: 0, total: 0, available: 0, usagePercentage: 0)
    }
}

// MARK: - 空性能监控器（用于禁用监控）
class EmptyPerformanceMonitor: PerformanceMonitorProtocol {
    func recordMetric(_ metric: PerformanceMetric) {
        // 空实现，不记录任何指标
    }
    
    func getStatistics(for type: PerformanceMetricType, in timeRange: (start: Date, end: Date)?) -> PerformanceStatistics? {
        return nil
    }
    
    func getAllStatistics(in timeRange: (start: Date, end: Date)?) -> [PerformanceMetricType: PerformanceStatistics] {
        return [:]
    }
    
    func clearData(in timeRange: (start: Date, end: Date)?) {
        // 空实现，不执行任何操作
    }
    
    func exportData(format: ExportFormat) -> Data? {
        return nil
    }
}

// MARK: - 性能监控工厂
enum PerformanceMonitorFactory {
    /// 创建默认性能监控器
    static func createDefault(enableVerboseLogging: Bool = true) -> PerformanceMonitorProtocol {
        return PerformanceMonitor(enableVerboseLogging: enableVerboseLogging)
    }
    
    /// 创建高性能性能监控器
    static func createHighPerformance(enableVerboseLogging: Bool = false) -> PerformanceMonitorProtocol {
        return PerformanceMonitor(enableVerboseLogging: enableVerboseLogging, maxMetricsCount: 50000)
    }
    
    /// 创建轻量级性能监控器
    static func createLightweight(enableVerboseLogging: Bool = false) -> PerformanceMonitorProtocol {
        return PerformanceMonitor(enableVerboseLogging: enableVerboseLogging, maxMetricsCount: 1000)
    }
    
    /// 创建性能监控装饰器
    static func createDecorator(monitor: PerformanceMonitorProtocol, enableVerboseLogging: Bool = true) -> PerformanceMonitoringDecorator {
        return PerformanceMonitoringDecorator(monitor: monitor, enableVerboseLogging: enableVerboseLogging)
    }
}
