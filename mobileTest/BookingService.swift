//
//  BookingService.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

// MARK: - 预订服务协议
protocol BookingServiceProtocol {
    func fetchBookingData() async throws -> BookingData
    func fetchBookingDataWithTimestamp() async throws -> (data: BookingData, timestamp: Date)
    func fetchBookingDataFromRemote(url: URL) async throws -> BookingData
    func fetchBookingDataWithProgress(progressCallback: @escaping (Double) -> Void) async throws -> BookingData
    
    /// 获取压缩文件数据
    /// - Parameters:
    ///   - fileName: 文件名（不包含扩展名）
    ///   - fileExtension: 文件扩展名
    ///   - autoDecompress: 是否自动解压缩
    /// - Returns: BookingData对象
    /// - Throws: BookingDataError
    func fetchCompressedBookingData(fileName: String, fileExtension: String, autoDecompress: Bool) async throws -> BookingData
    
    /// 从远程URL获取压缩文件数据
    /// - Parameters:
    ///   - url: 远程文件URL
    ///   - autoDecompress: 是否自动解压缩
    /// - Returns: BookingData对象
    /// - Throws: BookingDataError
    func fetchCompressedBookingDataFromRemote(url: URL, autoDecompress: Bool) async throws -> BookingData
    
    /// 检测文件是否为压缩格式
    /// - Parameter data: 文件数据
    /// - Returns: 压缩信息，如果不是压缩格式则返回nil
    func detectCompressionFormat(from data: Data) -> CompressionInfo?
    
    /// 检测数据格式版本
    /// - Parameter data: 要检测的数据
    /// - Returns: 版本信息，如果无法检测则返回nil
    func detectDataVersion(from data: Data) -> VersionInfo?
    
    /// 检查版本兼容性
    /// - Parameters:
    ///   - sourceVersion: 源版本
    ///   - targetVersion: 目标版本
    /// - Returns: 兼容性级别
    func checkVersionCompatibility(sourceVersion: VersionInfo, targetVersion: VersionInfo) -> CompatibilityLevel
    
    /// 迁移数据到目标版本
    /// - Parameters:
    ///   - data: 要迁移的数据
    ///   - targetVersion: 目标版本
    /// - Returns: 迁移结果
    func migrateData(_ data: Data, to targetVersion: VersionInfo) async throws -> MigrationResult
    
    /// 获取版本历史
    /// - Returns: 版本历史列表
    func getVersionHistory() -> [VersionInfo]
}

// MARK: - 预订服务实现
class BookingService: BookingServiceProtocol {
    
    // MARK: - 属性
    private let configuration: BookingServiceConfigurationProtocol
    private let cacheManager: BookingCache
    private let fileReader: AsyncFileReaderProtocol
    private let dataValidator: Any?
    private let performanceMonitor: PerformanceMonitorProtocol
    private let performanceDecorator: PerformanceMonitoringDecorator
    private let versionManager: VersionManagerProtocol
    
    // MARK: - 初始化器
    
    /// 使用默认配置初始化
    convenience init() {
        self.init(configuration: BookingServiceConfigurationFactory.createDefault())
    }
    
    /// 使用指定配置初始化
    /// - Parameter configuration: 服务配置
    init(configuration: BookingServiceConfigurationProtocol) {
        self.configuration = configuration
        
        // 根据配置创建缓存管理器
        if configuration.enableCaching {
            self.cacheManager = BookingCacheFactory.createCustom(
                maxItems: 50,
                maxMemoryMB: 20,
                expirationTime: configuration.cacheExpirationTime,
                enableLRU: true,
                enableStatistics: configuration.enableVerboseLogging
            )
        } else {
            // 创建一个禁用统计的缓存管理器（实际上不会缓存）
            self.cacheManager = BookingCacheFactory.createCustom(
                maxItems: 0,
                maxMemoryMB: 0,
                expirationTime: 0,
                enableLRU: false,
                enableStatistics: false
            )
        }
        
        // 创建异步文件读取器
        let compressionManager = configuration.enableCompression ? 
            CompressionManagerFactory.createDefault(enableVerboseLogging: configuration.enableVerboseLogging) :
            CompressionManagerFactory.createDisabled()
        
        self.fileReader = AsyncFileReaderFactory.createDefault(
            enableVerboseLogging: configuration.enableVerboseLogging,
            retryConfiguration: configuration.retryConfiguration,
            compressionManager: compressionManager
        )
        
        // 创建数据验证器
        self.dataValidator = Self.createDataValidator(configuration: configuration)
        
        // 创建性能监控器
        self.performanceMonitor = Self.createPerformanceMonitor(configuration: configuration)
        self.performanceDecorator = PerformanceMonitorFactory.createDecorator(
            monitor: self.performanceMonitor,
            enableVerboseLogging: configuration.enableVerboseLogging
        )
        
        // 创建版本管理器
        self.versionManager = Self.createVersionManager(configuration: configuration)
    }
    
    /// 使用指定配置和文件读取器初始化（用于测试）
    /// - Parameters:
    ///   - configuration: 服务配置
    ///   - fileReader: 异步文件读取器
    init(configuration: BookingServiceConfigurationProtocol, fileReader: AsyncFileReaderProtocol) {
        self.configuration = configuration
        self.fileReader = fileReader
        
        // 根据配置创建缓存管理器
        if configuration.enableCaching {
            self.cacheManager = BookingCacheFactory.createCustom(
                maxItems: 50,
                maxMemoryMB: 20,
                expirationTime: configuration.cacheExpirationTime,
                enableLRU: true,
                enableStatistics: configuration.enableVerboseLogging
            )
        } else {
            // 创建一个禁用统计的缓存管理器（实际上不会缓存）
            self.cacheManager = BookingCacheFactory.createCustom(
                maxItems: 0,
                maxMemoryMB: 0,
                expirationTime: 0,
                enableLRU: false,
                enableStatistics: false
            )
        }
        
        // 创建数据验证器
        self.dataValidator = Self.createDataValidator(configuration: configuration)
        
        // 创建性能监控器
        self.performanceMonitor = Self.createPerformanceMonitor(configuration: configuration)
        self.performanceDecorator = PerformanceMonitorFactory.createDecorator(
            monitor: self.performanceMonitor,
            enableVerboseLogging: configuration.enableVerboseLogging
        )
        
        // 创建版本管理器
        self.versionManager = Self.createVersionManager(configuration: configuration)
    }
    
    // MARK: - 公共方法
    
    /// 获取预订数据
    /// - Returns: BookingData对象
    /// - Throws: BookingDataError
    func fetchBookingData() async throws -> BookingData {
        log("🔄 [BookingService] 开始获取预订数据...")
        
        // 记录内存使用情况
        performanceDecorator.recordMemoryUsage(context: "BookingService.fetchBookingData.start")
        
        // 检查缓存
        if configuration.enableCaching {
            let cacheKey = "\(configuration.fileName).\(configuration.fileExtension)"
            if let cachedData: BookingData = cacheManager.get(key: cacheKey) {
                log("📦 [BookingService] 从缓存获取数据")
                performanceDecorator.recordCacheHitRate(100.0, context: "BookingService.fetchBookingData")
                return cachedData
            }
        }
        
        do {
            let data = try await loadDataFromFileAsync()
            let bookingData = try await parseBookingData(from: data)
            
            // 缓存数据
            if configuration.enableCaching {
                let cacheKey = "\(configuration.fileName).\(configuration.fileExtension)"
                cacheManager.set(key: cacheKey, value: bookingData)
            }
            
            // 记录性能指标
            performanceDecorator.recordResponseSize(data.count, context: "BookingService.fetchBookingData")
            performanceDecorator.recordMemoryUsage(context: "BookingService.fetchBookingData.end")
            
            log("✅ [BookingService] 成功获取预订数据")
            if configuration.enableVerboseLogging {
                log("📊 [BookingService] 数据详情:")
                log("   - 船舶参考号: \(bookingData.shipReference)")
                log("   - 过期时间: \(bookingData.formattedExpiryTime)")
                log("   - 持续时间: \(bookingData.formattedDuration)")
                log("   - 航段数量: \(bookingData.segments.count)")
                log("   - 数据是否过期: \(bookingData.isExpired ? "是" : "否")")
            }
            
            return bookingData
        } catch let error as BookingDataError {
            ErrorHandler.logError(error, context: "BookingService.fetchBookingData", enableVerboseLogging: configuration.enableVerboseLogging)
            throw error
        } catch {
            let bookingError = ErrorHandler.handleFileSystemError(error, filePath: "\(configuration.fileName).\(configuration.fileExtension)")
            ErrorHandler.logError(bookingError, context: "BookingService.fetchBookingData", enableVerboseLogging: configuration.enableVerboseLogging)
            throw bookingError
        }
    }
    
    /// 获取预订数据并包含时间戳
    /// - Returns: 包含数据和获取时间的元组
    /// - Throws: BookingDataError
    func fetchBookingDataWithTimestamp() async throws -> (data: BookingData, timestamp: Date) {
        let startTime = Date()
        let data = try await fetchBookingData()
        let endTime = Date()
        
        // 使用实际的数据获取时间作为时间戳
        let timestamp = configuration.enableVerboseLogging ? startTime : endTime
        return (data: data, timestamp: timestamp)
    }
    
    /// 从远程URL获取预订数据
    /// - Parameter url: 远程文件URL
    /// - Returns: BookingData对象
    /// - Throws: BookingDataError
    func fetchBookingDataFromRemote(url: URL) async throws -> BookingData {
        log("🌐 [BookingService] 开始从远程URL获取数据: \(url.absoluteString)")
        
        do {
            let data = try await fileReader.readRemoteFile(url: url, timeout: configuration.requestTimeout)
            let bookingData = try await parseBookingData(from: data)
            
            // 缓存远程数据
            if configuration.enableCaching {
                let cacheKey = "remote_\(url.lastPathComponent)"
                cacheManager.set(key: cacheKey, value: bookingData)
            }
            
            log("✅ [BookingService] 成功从远程获取预订数据")
            if configuration.enableVerboseLogging {
                log("📊 [BookingService] 远程数据详情:")
                log("   - 船舶参考号: \(bookingData.shipReference)")
                log("   - 过期时间: \(bookingData.formattedExpiryTime)")
                log("   - 持续时间: \(bookingData.formattedDuration)")
                log("   - 航段数量: \(bookingData.segments.count)")
                log("   - 数据是否过期: \(bookingData.isExpired ? "是" : "否")")
            }
            
            return bookingData
        } catch let error as BookingDataError {
            ErrorHandler.logError(error, context: "BookingService.fetchBookingDataFromRemote", enableVerboseLogging: configuration.enableVerboseLogging)
            throw error
        } catch {
            let bookingError = ErrorHandler.handleNetworkError(error, url: url.absoluteString)
            ErrorHandler.logError(bookingError, context: "BookingService.fetchBookingDataFromRemote", enableVerboseLogging: configuration.enableVerboseLogging)
            throw bookingError
        }
    }
    
    /// 带进度回调的获取预订数据
    /// - Parameter progressCallback: 进度回调函数
    /// - Returns: BookingData对象
    /// - Throws: BookingDataError
    func fetchBookingDataWithProgress(progressCallback: @escaping (Double) -> Void) async throws -> BookingData {
        log("📈 [BookingService] 开始带进度回调的数据获取...")
        
        // 检查缓存
        if configuration.enableCaching {
            let cacheKey = "\(configuration.fileName).\(configuration.fileExtension)"
            if let cachedData: BookingData = cacheManager.get(key: cacheKey) {
                log("📦 [BookingService] 从缓存获取数据")
                progressCallback(1.0) // 缓存命中，进度100%
                return cachedData
            }
        }
        
        do {
            let data = try await fileReader.readFileWithProgress(
                source: configuration.fileName,
                fileExtension: configuration.fileExtension,
                timeout: configuration.requestTimeout,
                progressCallback: progressCallback
            )
            let bookingData = try await parseBookingData(from: data)
            
            // 缓存数据
            if configuration.enableCaching {
                let cacheKey = "\(configuration.fileName).\(configuration.fileExtension)"
                cacheManager.set(key: cacheKey, value: bookingData)
            }
            
            log("✅ [BookingService] 带进度回调的数据获取成功")
            return bookingData
        } catch let error as BookingDataError {
            ErrorHandler.logError(error, context: "BookingService.fetchBookingDataWithProgress", enableVerboseLogging: configuration.enableVerboseLogging)
            throw error
        } catch {
            let bookingError = ErrorHandler.handleFileSystemError(error, filePath: "\(configuration.fileName).\(configuration.fileExtension)")
            ErrorHandler.logError(bookingError, context: "BookingService.fetchBookingDataWithProgress", enableVerboseLogging: configuration.enableVerboseLogging)
            throw bookingError
        }
    }
    
    // MARK: - 私有方法
    
    /// 创建数据验证器
    /// - Parameter configuration: 服务配置
    /// - Returns: 数据验证器实例
    private static func createDataValidator(configuration: BookingServiceConfigurationProtocol) -> Any? {
        // 由于DataValidator被禁用，返回nil表示不使用数据验证
        return nil
    }
    
    /// 创建性能监控器
    /// - Parameter configuration: 服务配置
    /// - Returns: 性能监控器实例
    private static func createPerformanceMonitor(configuration: BookingServiceConfigurationProtocol) -> PerformanceMonitorProtocol {
        guard configuration.enablePerformanceMonitoring else {
            // 如果禁用性能监控，返回一个空的监控器
            return EmptyPerformanceMonitor()
        }
        
        switch configuration.performanceMonitoringLevel {
        case .detailed:
            return PerformanceMonitorFactory.createHighPerformance(enableVerboseLogging: configuration.enableVerboseLogging)
        case .standard:
            return PerformanceMonitorFactory.createDefault(enableVerboseLogging: configuration.enableVerboseLogging)
        case .minimal:
            return PerformanceMonitorFactory.createLightweight(enableVerboseLogging: configuration.enableVerboseLogging)
        case .disabled:
            return EmptyPerformanceMonitor()
        }
    }
    
    /// 创建版本管理器
    /// - Parameter configuration: 服务配置
    /// - Returns: 版本管理器实例
    private static func createVersionManager(configuration: BookingServiceConfigurationProtocol) -> VersionManagerProtocol {
        guard configuration.enableVersionControl else {
            // 如果禁用版本控制，返回一个空的版本管理器
            return VersionManagerFactory.createDisabled()
        }
        
        switch configuration.versionControlLevel {
        case .full:
            return VersionManagerFactory.createCustom(
                currentVersion: configuration.maximumSupportedVersion,
                minimumSupportedVersion: configuration.minimumSupportedVersion,
                maximumSupportedVersion: configuration.maximumSupportedVersion,
                versionStrategy: configuration.versionStrategy,
                enableVerboseLogging: configuration.enableVerboseLogging
            )
        case .basic:
            return VersionManagerFactory.createDefault(enableVerboseLogging: configuration.enableVerboseLogging)
        case .disabled:
            return VersionManagerFactory.createDisabled()
        }
    }
    
    /// 异步从文件加载数据
    /// - Returns: Data对象
    /// - Throws: BookingDataError
    private func loadDataFromFileAsync() async throws -> Data {
        log("📁 [BookingService] 开始异步加载文件: \(configuration.fileName).\(configuration.fileExtension)")
        
        do {
            let data = try await fileReader.readLocalFile(
                fileName: configuration.fileName,
                fileExtension: configuration.fileExtension,
                bundle: .main
            )
            log("✅ [BookingService] 异步文件加载成功，大小: \(data.count) 字节")
            return data
        } catch let error as BookingDataError {
            ErrorHandler.logError(error, context: "BookingService.loadDataFromFileAsync", enableVerboseLogging: configuration.enableVerboseLogging)
            throw error
        } catch {
            let bookingError = ErrorHandler.handleFileSystemError(error, filePath: "\(configuration.fileName).\(configuration.fileExtension)")
            ErrorHandler.logError(bookingError, context: "BookingService.loadDataFromFileAsync", enableVerboseLogging: configuration.enableVerboseLogging)
            throw bookingError
        }
    }
    
    /// 从文件加载数据（保留原有方法以向后兼容）
    /// - Returns: Data对象
    /// - Throws: BookingDataError
    private func loadDataFromFile() async throws -> Data {
        guard let fileURL = Bundle.main.url(forResource: configuration.fileName, withExtension: configuration.fileExtension) else {
            let error = BookingDataError.fileNotFound("Bundle中找不到文件: \(configuration.fileName).\(configuration.fileExtension)")
            ErrorHandler.logError(error, context: "BookingService.loadDataFromFile", enableVerboseLogging: configuration.enableVerboseLogging)
            throw error
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            log("📁 [BookingService] 成功从文件加载数据，大小: \(data.count) 字节")
            return data
        } catch {
            let bookingError = ErrorHandler.handleFileSystemError(error, filePath: fileURL.path)
            ErrorHandler.logError(bookingError, context: "BookingService.loadDataFromFile", enableVerboseLogging: configuration.enableVerboseLogging)
            throw bookingError
        }
    }
    
    /// 解析预订数据
    /// - Parameter data: 原始数据
    /// - Returns: BookingData对象
    /// - Throws: BookingDataError
    private func parseBookingData(from data: Data) async throws -> BookingData {
        do {
            // 1. 首先验证原始JSON数据
            if configuration.enableDataValidation && dataValidator != nil {
                log("🔍 [BookingService] 开始验证原始JSON数据...")
                // 由于DataValidator被禁用，跳过验证
                log("ℹ️ [BookingService] 数据验证已禁用，跳过验证")
            }
            
            // 2. 解析JSON数据
            let decoder = JSONDecoder()
            let bookingData = try decoder.decode(BookingData.self, from: data)
            log("🔍 [BookingService] 成功解析JSON数据")
            
            // 3. 验证解析后的BookingData对象
            if configuration.enableDataValidation && dataValidator != nil {
                log("🔍 [BookingService] 开始验证BookingData对象...")
                // 由于DataValidator被禁用，跳过验证
                log("ℹ️ [BookingService] BookingData验证已禁用，跳过验证")
            }
            
            return bookingData
        } catch let error as BookingDataError {
            ErrorHandler.logError(error, context: "BookingService.parseBookingData", enableVerboseLogging: configuration.enableVerboseLogging)
            throw error
        } catch {
            let bookingError = BookingDataError.invalidJSON("JSON解析失败: \(error.localizedDescription)")
            ErrorHandler.logError(bookingError, context: "BookingService.parseBookingData", enableVerboseLogging: configuration.enableVerboseLogging)
            throw bookingError
        }
    }
}

// MARK: - 缓存和日志扩展
extension BookingService {
    
    /// 条件日志输出
    /// - Parameter message: 日志消息
    private func log(_ message: String) {
        if configuration.enableVerboseLogging {
            print(message)
        }
    }
    
    /// 清除所有缓存
    func clearCache() {
        (cacheManager as AdvancedCacheProtocol).clear() // 明确使用高级缓存的clear方法
        log("🗑️ [BookingService] 所有缓存已清除")
    }
    
    /// 获取缓存统计信息
    /// - Returns: 缓存统计信息
    func getCacheStats() -> CacheStatistics {
        return cacheManager.getStatistics()
    }
    
    /// 预热缓存
    /// - Parameter data: 要预热的预订数据
    func warmupCache(with data: BookingData) {
        let cacheKey = "\(configuration.fileName).\(configuration.fileExtension)"
        cacheManager.warmup(items: [(key: cacheKey, value: data)])
        log("🔥 [BookingService] 缓存预热完成")
    }
    
    /// 移除特定缓存
    /// - Parameter key: 缓存键
    func removeCache(key: String) {
        cacheManager.remove(key: key)
        log("🗑️ [BookingService] 缓存已移除: \(key)")
    }
    
    /// 获取性能统计信息
    /// - Parameter timeRange: 时间范围
    /// - Returns: 性能统计信息
    func getPerformanceStatistics(in timeRange: (start: Date, end: Date)? = nil) -> [PerformanceMetricType: PerformanceStatistics] {
        return performanceMonitor.getAllStatistics(in: timeRange)
    }
    
    /// 获取指定类型的性能统计
    /// - Parameters:
    ///   - type: 指标类型
    ///   - timeRange: 时间范围
    /// - Returns: 性能统计信息
    func getPerformanceStatistics(for type: PerformanceMetricType, in timeRange: (start: Date, end: Date)? = nil) -> PerformanceStatistics? {
        return performanceMonitor.getStatistics(for: type, in: timeRange)
    }
    
    /// 导出性能数据
    /// - Parameter format: 导出格式
    /// - Returns: 导出的数据
    func exportPerformanceData(format: ExportFormat) -> Data? {
        return performanceMonitor.exportData(format: format)
    }
    
    /// 清除性能数据
    /// - Parameter timeRange: 时间范围
    func clearPerformanceData(in timeRange: (start: Date, end: Date)? = nil) {
        performanceMonitor.clearData(in: timeRange)
        log("🗑️ [BookingService] 性能数据已清除")
    }
}

// MARK: - 模拟网络延迟的扩展
extension BookingService {
    
    /// 模拟网络请求延迟
    /// - Parameter seconds: 延迟秒数
    private func simulateNetworkDelay(_ seconds: Double = 1.0) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
    /// 带延迟的数据获取（用于测试）
    /// - Returns: BookingData对象
    /// - Throws: BookingDataError
    func fetchBookingDataWithDelay() async throws -> BookingData {
        log("⏳ [BookingService] 模拟网络延迟...")
        await simulateNetworkDelay(0.5)
        return try await fetchBookingData()
    }
    
    /// 带重试机制的数据获取
    /// - Returns: BookingData对象
    /// - Throws: BookingDataError
    func fetchBookingDataWithRetry() async throws -> BookingData {
        var lastError: Error?
        
        for attempt in 1...configuration.maxRetryAttempts {
            do {
                log("🔄 [BookingService] 尝试获取数据 (第\(attempt)次)")
                return try await fetchBookingData()
            } catch {
                lastError = error
                log("❌ [BookingService] 第\(attempt)次尝试失败: \(error.localizedDescription)")
                
                if attempt < configuration.maxRetryAttempts {
                    let delay = configuration.retryConfiguration.baseDelay
                    log("⏳ [BookingService] 等待\(delay)秒后重试...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        log("💥 [BookingService] 所有重试尝试都失败了")
        let finalError = lastError as? BookingDataError ?? BookingDataError.networkError("重试失败")
        ErrorHandler.logError(finalError, context: "BookingService.fetchBookingDataWithRetry", enableVerboseLogging: configuration.enableVerboseLogging)
        throw finalError
    }
    
    // MARK: - 压缩文件读取方法
    
    /// 获取压缩文件数据
    /// - Parameters:
    ///   - fileName: 文件名（不包含扩展名）
    ///   - fileExtension: 文件扩展名
    ///   - autoDecompress: 是否自动解压缩
    /// - Returns: BookingData对象
    /// - Throws: BookingDataError
    func fetchCompressedBookingData(fileName: String, fileExtension: String, autoDecompress: Bool) async throws -> BookingData {
        log("📦 [BookingService] 开始获取压缩文件数据: \(fileName).\(fileExtension)")
        
        guard configuration.enableCompression else {
            let error = BookingDataError.unsupportedOperation("压缩功能已禁用")
            ErrorHandler.logError(error, context: "BookingService.fetchCompressedBookingData", enableVerboseLogging: configuration.enableVerboseLogging)
            throw error
        }
        
        // 检查缓存
        if configuration.enableCaching {
            let cacheKey = "compressed_\(fileName).\(fileExtension)"
            if let cachedData: BookingData = cacheManager.get(key: cacheKey) {
                log("📦 [BookingService] 从缓存获取压缩数据")
                return cachedData
            }
        }
        
        do {
            let data = try await fileReader.readCompressedFile(
                fileName: fileName,
                fileExtension: fileExtension,
                bundle: .main,
                autoDecompress: autoDecompress
            )
            let bookingData = try await parseBookingData(from: data)
            
            // 缓存数据
            if configuration.enableCaching {
                let cacheKey = "compressed_\(fileName).\(fileExtension)"
                cacheManager.set(key: cacheKey, value: bookingData)
            }
            
            log("✅ [BookingService] 成功获取压缩文件数据")
            if configuration.enableVerboseLogging {
                log("📊 [BookingService] 压缩数据详情:")
                log("   - 船舶参考号: \(bookingData.shipReference)")
                log("   - 过期时间: \(bookingData.formattedExpiryTime)")
                log("   - 持续时间: \(bookingData.formattedDuration)")
                log("   - 航段数量: \(bookingData.segments.count)")
                log("   - 数据是否过期: \(bookingData.isExpired ? "是" : "否")")
            }
            
            return bookingData
        } catch let error as BookingDataError {
            ErrorHandler.logError(error, context: "BookingService.fetchCompressedBookingData", enableVerboseLogging: configuration.enableVerboseLogging)
            throw error
        } catch {
            let bookingError = ErrorHandler.handleFileSystemError(error, filePath: "\(fileName).\(fileExtension)")
            ErrorHandler.logError(bookingError, context: "BookingService.fetchCompressedBookingData", enableVerboseLogging: configuration.enableVerboseLogging)
            throw bookingError
        }
    }
    
    /// 从远程URL获取压缩文件数据
    /// - Parameters:
    ///   - url: 远程文件URL
    ///   - autoDecompress: 是否自动解压缩
    /// - Returns: BookingData对象
    /// - Throws: BookingDataError
    func fetchCompressedBookingDataFromRemote(url: URL, autoDecompress: Bool) async throws -> BookingData {
        log("🌐 [BookingService] 开始从远程URL获取压缩文件数据: \(url.absoluteString)")
        
        guard configuration.enableCompression else {
            let error = BookingDataError.unsupportedOperation("压缩功能已禁用")
            ErrorHandler.logError(error, context: "BookingService.fetchCompressedBookingDataFromRemote", enableVerboseLogging: configuration.enableVerboseLogging)
            throw error
        }
        
        do {
            let data = try await fileReader.readRemoteCompressedFile(
                url: url,
                timeout: configuration.requestTimeout,
                autoDecompress: autoDecompress
            )
            let bookingData = try await parseBookingData(from: data)
            
            // 缓存远程压缩数据
            if configuration.enableCaching {
                let cacheKey = "remote_compressed_\(url.lastPathComponent)"
                cacheManager.set(key: cacheKey, value: bookingData)
            }
            
            log("✅ [BookingService] 成功从远程获取压缩文件数据")
            if configuration.enableVerboseLogging {
                log("📊 [BookingService] 远程压缩数据详情:")
                log("   - 船舶参考号: \(bookingData.shipReference)")
                log("   - 过期时间: \(bookingData.formattedExpiryTime)")
                log("   - 持续时间: \(bookingData.formattedDuration)")
                log("   - 航段数量: \(bookingData.segments.count)")
                log("   - 数据是否过期: \(bookingData.isExpired ? "是" : "否")")
            }
            
            return bookingData
        } catch let error as BookingDataError {
            ErrorHandler.logError(error, context: "BookingService.fetchCompressedBookingDataFromRemote", enableVerboseLogging: configuration.enableVerboseLogging)
            throw error
        } catch {
            let bookingError = ErrorHandler.handleNetworkError(error, url: url.absoluteString)
            ErrorHandler.logError(bookingError, context: "BookingService.fetchCompressedBookingDataFromRemote", enableVerboseLogging: configuration.enableVerboseLogging)
            throw bookingError
        }
    }
    
    /// 检测文件是否为压缩格式
    /// - Parameter data: 文件数据
    /// - Returns: 压缩信息，如果不是压缩格式则返回nil
    func detectCompressionFormat(from data: Data) -> CompressionInfo? {
        return fileReader.detectCompressionFormat(from: data)
    }
    
    // MARK: - 版本控制方法
    
    /// 检测数据格式版本
    /// - Parameter data: 要检测的数据
    /// - Returns: 版本信息，如果无法检测则返回nil
    func detectDataVersion(from data: Data) -> VersionInfo? {
        return versionManager.detectVersion(from: data)
    }
    
    /// 检查版本兼容性
    /// - Parameters:
    ///   - sourceVersion: 源版本
    ///   - targetVersion: 目标版本
    /// - Returns: 兼容性级别
    func checkVersionCompatibility(sourceVersion: VersionInfo, targetVersion: VersionInfo) -> CompatibilityLevel {
        return versionManager.checkCompatibility(sourceVersion: sourceVersion, targetVersion: targetVersion)
    }
    
    /// 迁移数据到目标版本
    /// - Parameters:
    ///   - data: 要迁移的数据
    ///   - targetVersion: 目标版本
    /// - Returns: 迁移结果
    func migrateData(_ data: Data, to targetVersion: VersionInfo) async throws -> MigrationResult {
        log("🔄 [BookingService] 开始数据迁移到版本: \(targetVersion.versionString)")
        
        guard configuration.enableVersionControl else {
            let error = BookingDataError.unsupportedOperation("版本控制功能已禁用")
            ErrorHandler.logError(error, context: "BookingService.migrateData", enableVerboseLogging: configuration.enableVerboseLogging)
            throw error
        }
        
        do {
            let result = try await versionManager.migrateData(data, to: targetVersion)
            
            if result.isSuccessful {
                log("✅ [BookingService] 数据迁移成功")
                if configuration.enableVerboseLogging {
                    log("📊 [BookingService] 迁移详情:")
                    log("   - 源版本: \(result.sourceVersion.versionString)")
                    log("   - 目标版本: \(result.targetVersion.versionString)")
                    log("   - 迁移步骤数: \(result.migrationSteps.count)")
                    if result.hasWarnings {
                        log("   - 警告数量: \(result.warnings.count)")
                    }
                }
            } else {
                log("❌ [BookingService] 数据迁移失败")
                if configuration.enableVerboseLogging {
                    log("📊 [BookingService] 失败详情:")
                    log("   - 错误数量: \(result.errors.count)")
                    for error in result.errors {
                        log("   - 错误: \(error)")
                    }
                }
            }
            
            return result
        } catch {
            let bookingError = BookingDataError.versionMismatch("数据迁移失败: \(error.localizedDescription)")
            ErrorHandler.logError(bookingError, context: "BookingService.migrateData", enableVerboseLogging: configuration.enableVerboseLogging)
            throw bookingError
        }
    }
    
    /// 获取版本历史
    /// - Returns: 版本历史列表
    func getVersionHistory() -> [VersionInfo] {
        return versionManager.getVersionHistory()
    }
}
