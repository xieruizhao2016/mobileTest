//
//  AsyncFileReader.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

// MARK: - 异步文件读取协议
protocol AsyncFileReaderProtocol {
    /// 异步读取本地文件
    /// - Parameters:
    ///   - fileName: 文件名（不包含扩展名）
    ///   - fileExtension: 文件扩展名
    ///   - bundle: Bundle实例，默认为main
    /// - Returns: 文件数据
    /// - Throws: BookingDataError
    func readLocalFile(fileName: String, fileExtension: String, bundle: Bundle) async throws -> Data
    
    /// 异步读取远程文件
    /// - Parameters:
    ///   - url: 远程文件URL
    ///   - timeout: 请求超时时间
    /// - Returns: 文件数据
    /// - Throws: BookingDataError
    func readRemoteFile(url: URL, timeout: TimeInterval) async throws -> Data
    
    /// 异步读取文件（自动检测本地或远程）
    /// - Parameters:
    ///   - source: 文件源（本地文件名或远程URL）
    ///   - fileExtension: 文件扩展名（仅用于本地文件）
    ///   - timeout: 请求超时时间（仅用于远程文件）
    /// - Returns: 文件数据
    /// - Throws: BookingDataError
    func readFile(source: String, fileExtension: String?, timeout: TimeInterval?) async throws -> Data
    
    /// 带进度回调的异步文件读取
    /// - Parameters:
    ///   - source: 文件源
    ///   - fileExtension: 文件扩展名
    ///   - timeout: 超时时间
    ///   - progressCallback: 进度回调
    /// - Returns: 文件数据
    /// - Throws: BookingDataError
    func readFileWithProgress(
        source: String,
        fileExtension: String?,
        timeout: TimeInterval?,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> Data
    
    /// 异步读取压缩文件
    /// - Parameters:
    ///   - fileName: 文件名（不包含扩展名）
    ///   - fileExtension: 文件扩展名
    ///   - bundle: Bundle实例
    ///   - autoDecompress: 是否自动解压缩
    /// - Returns: 文件数据（如果autoDecompress为true，返回解压缩后的数据）
    /// - Throws: BookingDataError
    func readCompressedFile(
        fileName: String,
        fileExtension: String,
        bundle: Bundle,
        autoDecompress: Bool
    ) async throws -> Data
    
    /// 异步读取远程压缩文件
    /// - Parameters:
    ///   - url: 远程文件URL
    ///   - timeout: 请求超时时间
    ///   - autoDecompress: 是否自动解压缩
    /// - Returns: 文件数据（如果autoDecompress为true，返回解压缩后的数据）
    /// - Throws: BookingDataError
    func readRemoteCompressedFile(
        url: URL,
        timeout: TimeInterval,
        autoDecompress: Bool
    ) async throws -> Data
    
    /// 检测文件是否为压缩格式
    /// - Parameter data: 文件数据
    /// - Returns: 压缩信息，如果不是压缩格式则返回nil
    func detectCompressionFormat(from data: Data) -> CompressionInfo?
}

// MARK: - 异步文件读取实现
class AsyncFileReader: AsyncFileReaderProtocol {
    
    // MARK: - 属性
    private let urlSession: URLSession
    private let enableVerboseLogging: Bool
    private let retryManager: RetryManager
    private let compressionManager: CompressionManagerProtocol
    
    // MARK: - 初始化器
    
    /// 使用默认配置初始化
    /// - Parameters:
    ///   - enableVerboseLogging: 是否启用详细日志
    ///   - retryConfiguration: 重试配置
    ///   - compressionManager: 压缩管理器
    init(enableVerboseLogging: Bool = true, retryConfiguration: RetryConfiguration = .default, compressionManager: CompressionManagerProtocol? = nil) {
        self.enableVerboseLogging = enableVerboseLogging
        self.retryManager = RetryManager(configuration: retryConfiguration, enableVerboseLogging: enableVerboseLogging)
        self.compressionManager = compressionManager ?? CompressionManagerFactory.createDefault(enableVerboseLogging: enableVerboseLogging)
        
        // 配置URLSession
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
    }
    
    /// 使用自定义URLSession初始化
    /// - Parameters:
    ///   - urlSession: 自定义URLSession
    ///   - enableVerboseLogging: 是否启用详细日志
    ///   - retryConfiguration: 重试配置
    ///   - compressionManager: 压缩管理器
    init(urlSession: URLSession, enableVerboseLogging: Bool = true, retryConfiguration: RetryConfiguration = .default, compressionManager: CompressionManagerProtocol? = nil) {
        self.urlSession = urlSession
        self.enableVerboseLogging = enableVerboseLogging
        self.retryManager = RetryManager(configuration: retryConfiguration, enableVerboseLogging: enableVerboseLogging)
        self.compressionManager = compressionManager ?? CompressionManagerFactory.createDefault(enableVerboseLogging: enableVerboseLogging)
    }
    
    // MARK: - 公共方法
    
    /// 异步读取本地文件
    func readLocalFile(fileName: String, fileExtension: String, bundle: Bundle = .main) async throws -> Data {
        log("📁 [AsyncFileReader] 开始读取本地文件: \(fileName).\(fileExtension)")
        
        guard let fileURL = bundle.url(forResource: fileName, withExtension: fileExtension) else {
            let error = BookingDataError.fileNotFound("Bundle中找不到文件: \(fileName).\(fileExtension)")
            ErrorHandler.logError(error, context: "AsyncFileReader.readLocalFile", enableVerboseLogging: enableVerboseLogging)
            throw error
        }
        
        return try await retryManager.executeWithRetry {
            try await self.readLocalFileWithFileHandle(url: fileURL)
        }
    }
    
    /// 异步读取远程文件
    func readRemoteFile(url: URL, timeout: TimeInterval = 30.0) async throws -> Data {
        log("🌐 [AsyncFileReader] 开始读取远程文件: \(url.absoluteString)")
        
        return try await retryManager.executeWithRetry {
            var request = URLRequest(url: url)
            request.timeoutInterval = timeout
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("mobileTest/1.0", forHTTPHeaderField: "User-Agent")
            
            do {
                let (data, response) = try await self.urlSession.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = BookingDataError.networkError("无效的HTTP响应")
                    ErrorHandler.logError(error, context: "AsyncFileReader.readRemoteFile", enableVerboseLogging: self.enableVerboseLogging)
                    throw error
                }
                
                guard httpResponse.statusCode == 200 else {
                    let error = ErrorHandler.handleHTTPStatusCode(httpResponse.statusCode, url: url.absoluteString)
                    ErrorHandler.logError(error, context: "AsyncFileReader.readRemoteFile", enableVerboseLogging: self.enableVerboseLogging)
                    throw error
                }
                
                self.log("✅ [AsyncFileReader] 成功读取远程文件，大小: \(data.count) 字节")
                return data
                
            } catch let error as URLError {
                let bookingError = ErrorHandler.handleNetworkError(error, url: url.absoluteString)
                ErrorHandler.logError(bookingError, context: "AsyncFileReader.readRemoteFile", enableVerboseLogging: self.enableVerboseLogging)
                throw bookingError
            } catch let error as BookingDataError {
                ErrorHandler.logError(error, context: "AsyncFileReader.readRemoteFile", enableVerboseLogging: self.enableVerboseLogging)
                throw error
            } catch {
                let bookingError = BookingDataError.networkError("读取失败: \(error.localizedDescription)")
                ErrorHandler.logError(bookingError, context: "AsyncFileReader.readRemoteFile", enableVerboseLogging: self.enableVerboseLogging)
                throw bookingError
            }
        }
    }
    
    /// 异步读取文件（自动检测本地或远程）
    func readFile(source: String, fileExtension: String? = nil, timeout: TimeInterval? = nil) async throws -> Data {
        // 检测是否为URL
        if let url = URL(string: source), url.scheme != nil {
            log("🌐 [AsyncFileReader] 检测到远程URL，使用网络读取")
            return try await readRemoteFile(url: url, timeout: timeout ?? 30.0)
        } else {
            log("📁 [AsyncFileReader] 检测到本地文件，使用本地读取")
            guard let fileExtension = fileExtension else {
                let error = BookingDataError.missingConfiguration("缺少文件扩展名")
                ErrorHandler.logError(error, context: "AsyncFileReader.readFile", enableVerboseLogging: enableVerboseLogging)
                throw error
            }
            return try await readLocalFile(fileName: source, fileExtension: fileExtension)
        }
    }
    
    // MARK: - 私有方法
    
    /// 使用FileHandle异步读取本地文件
    /// - Parameter url: 文件URL
    /// - Returns: 文件数据
    /// - Throws: BookingDataError
    private func readLocalFileWithFileHandle(url: URL) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let fileHandle = try FileHandle(forReadingFrom: url)
                    defer {
                        try? fileHandle.close()
                    }
                    
                    // 获取文件大小
                    let fileSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
                    self.log("📊 [AsyncFileReader] 文件大小: \(fileSize) 字节")
                    
                    // 分块读取文件（适用于大文件）
                    let chunkSize = 1024 * 1024 // 1MB chunks
                    var data = Data()
                    
                    while true {
                        let chunk = fileHandle.readData(ofLength: chunkSize)
                        if chunk.isEmpty {
                            break
                        }
                        data.append(chunk)
                        
                        // 更新进度（可选）
                        if self.enableVerboseLogging {
                            let progress = Double(data.count) / Double(fileSize) * 100
                            self.log("📈 [AsyncFileReader] 读取进度: \(String(format: "%.1f", progress))%")
                        }
                    }
                    
                    self.log("✅ [AsyncFileReader] 成功读取本地文件，大小: \(data.count) 字节")
                    continuation.resume(returning: data)
                    
                } catch {
                    let bookingError = ErrorHandler.handleFileSystemError(error, filePath: url.path)
                    self.log("❌ [AsyncFileReader] 读取本地文件失败: \(bookingError.localizedDescription)")
                    continuation.resume(throwing: bookingError)
                }
            }
        }
    }
    
    /// 条件日志输出
    /// - Parameter message: 日志消息
    private func log(_ message: String) {
        if enableVerboseLogging {
            print(message)
        }
    }
}

// MARK: - 高级异步文件读取功能
extension AsyncFileReader {
    
    /// 带进度回调的异步文件读取
    /// - Parameters:
    ///   - source: 文件源
    ///   - fileExtension: 文件扩展名
    ///   - timeout: 超时时间
    ///   - progressCallback: 进度回调
    /// - Returns: 文件数据
    /// - Throws: BookingDataError
    func readFileWithProgress(
        source: String,
        fileExtension: String? = nil,
        timeout: TimeInterval? = nil,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> Data {
        
        // 检测是否为URL
        if let url = URL(string: source), url.scheme != nil {
            return try await retryManager.executeWithRetry(
                { try await self.readRemoteFileWithProgress(url: url, timeout: timeout ?? 30.0, progressCallback: progressCallback) },
                progressCallback: progressCallback
            )
        } else {
            guard let fileExtension = fileExtension else {
                throw BookingDataError.missingConfiguration("缺少文件扩展名")
            }
            return try await retryManager.executeWithRetry(
                { try await self.readLocalFileWithProgress(fileName: source, fileExtension: fileExtension, progressCallback: progressCallback) },
                progressCallback: progressCallback
            )
        }
    }
    
    /// 带进度的本地文件读取
    private func readLocalFileWithProgress(
        fileName: String,
        fileExtension: String,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> Data {
        guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            throw BookingDataError.fileNotFound("Bundle中找不到文件: \(fileName).\(fileExtension)")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let fileHandle = try FileHandle(forReadingFrom: fileURL)
                    defer {
                        try? fileHandle.close()
                    }
                    
                    let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
                    var data = Data()
                    let chunkSize = 1024 * 64 // 64KB chunks for better progress updates
                    
                    while true {
                        let chunk = fileHandle.readData(ofLength: chunkSize)
                        if chunk.isEmpty {
                            break
                        }
                        data.append(chunk)
                        
                        let progress = Double(data.count) / Double(fileSize)
                        DispatchQueue.main.async {
                            progressCallback(progress)
                        }
                    }
                    
                    continuation.resume(returning: data)
                    
                } catch {
                    let bookingError = ErrorHandler.handleFileSystemError(error, filePath: fileURL.path)
                    continuation.resume(throwing: bookingError)
                }
            }
        }
    }
    
    /// 带进度的远程文件读取
    private func readRemoteFileWithProgress(
        url: URL,
        timeout: TimeInterval,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                throw ErrorHandler.handleHTTPStatusCode(httpResponse.statusCode, url: url.absoluteString)
            } else {
                throw BookingDataError.networkError("无效的HTTP响应")
            }
        }
        
        // 模拟进度更新（实际应用中可能需要流式下载）
        DispatchQueue.main.async {
            progressCallback(1.0)
        }
        
        return data
    }
    
    /// 批量异步读取多个文件
    /// - Parameter sources: 文件源数组
    /// - Returns: 文件数据数组
    /// - Throws: BookingDataError
    func readMultipleFiles(sources: [(source: String, fileExtension: String?, timeout: TimeInterval?)]) async throws -> [Data] {
        log("📚 [AsyncFileReader] 开始批量读取 \(sources.count) 个文件")
        
        return try await withThrowingTaskGroup(of: Data.self) { group in
            var results: [Data] = []
            
            // 添加所有读取任务
            for source in sources {
                group.addTask {
                    try await self.readFile(
                        source: source.source,
                        fileExtension: source.fileExtension,
                        timeout: source.timeout
                    )
                }
            }
            
            // 收集结果
            for try await data in group {
                results.append(data)
            }
            
            log("✅ [AsyncFileReader] 批量读取完成，成功读取 \(results.count) 个文件")
            return results
        }
    }
    
    /// 取消所有进行中的请求
    func cancelAllRequests() {
        urlSession.invalidateAndCancel()
        log("🛑 [AsyncFileReader] 已取消所有网络请求")
    }
    
    // MARK: - 压缩文件读取方法
    
    /// 异步读取压缩文件
    /// - Parameters:
    ///   - fileName: 文件名（不包含扩展名）
    ///   - fileExtension: 文件扩展名
    ///   - bundle: Bundle实例
    ///   - autoDecompress: 是否自动解压缩
    /// - Returns: 文件数据（如果autoDecompress为true，返回解压缩后的数据）
    /// - Throws: BookingDataError
    func readCompressedFile(
        fileName: String,
        fileExtension: String,
        bundle: Bundle,
        autoDecompress: Bool
    ) async throws -> Data {
        log("📦 [AsyncFileReader] 开始读取压缩文件: \(fileName).\(fileExtension)")
        
        // 首先读取原始文件数据
        let rawData = try await readLocalFile(fileName: fileName, fileExtension: fileExtension, bundle: bundle)
        
        // 检测压缩格式
        guard let compressionInfo = compressionManager.detectCompressionFormat(from: rawData) else {
            log("⚠️ [AsyncFileReader] 文件不是压缩格式，返回原始数据")
            return rawData
        }
        
        log("🔍 [AsyncFileReader] 检测到压缩格式: \(compressionInfo.format.displayName)")
        
        if autoDecompress {
            log("🔄 [AsyncFileReader] 开始自动解压缩...")
            let decompressedData = try await compressionManager.decompress(data: rawData, format: compressionInfo.format)
            log("✅ [AsyncFileReader] 解压缩完成，原始大小: \(rawData.count) 字节，解压缩后大小: \(decompressedData.count) 字节")
            return decompressedData
        } else {
            log("📦 [AsyncFileReader] 返回压缩数据，大小: \(rawData.count) 字节")
            return rawData
        }
    }
    
    /// 异步读取远程压缩文件
    /// - Parameters:
    ///   - url: 远程文件URL
    ///   - timeout: 请求超时时间
    ///   - autoDecompress: 是否自动解压缩
    /// - Returns: 文件数据（如果autoDecompress为true，返回解压缩后的数据）
    /// - Throws: BookingDataError
    func readRemoteCompressedFile(
        url: URL,
        timeout: TimeInterval,
        autoDecompress: Bool
    ) async throws -> Data {
        log("🌐 [AsyncFileReader] 开始读取远程压缩文件: \(url.absoluteString)")
        
        // 首先读取原始文件数据
        let rawData = try await readRemoteFile(url: url, timeout: timeout)
        
        // 检测压缩格式
        guard let compressionInfo = compressionManager.detectCompressionFormat(from: rawData) else {
            log("⚠️ [AsyncFileReader] 远程文件不是压缩格式，返回原始数据")
            return rawData
        }
        
        log("🔍 [AsyncFileReader] 检测到远程文件压缩格式: \(compressionInfo.format.displayName)")
        
        if autoDecompress {
            log("🔄 [AsyncFileReader] 开始自动解压缩远程文件...")
            let decompressedData = try await compressionManager.decompress(data: rawData, format: compressionInfo.format)
            log("✅ [AsyncFileReader] 远程文件解压缩完成，原始大小: \(rawData.count) 字节，解压缩后大小: \(decompressedData.count) 字节")
            return decompressedData
        } else {
            log("📦 [AsyncFileReader] 返回远程压缩数据，大小: \(rawData.count) 字节")
            return rawData
        }
    }
    
    /// 检测文件是否为压缩格式
    /// - Parameter data: 文件数据
    /// - Returns: 压缩信息，如果不是压缩格式则返回nil
    func detectCompressionFormat(from data: Data) -> CompressionInfo? {
        return compressionManager.detectCompressionFormat(from: data)
    }
}

// MARK: - 文件读取工厂
enum AsyncFileReaderFactory {
    /// 创建默认的异步文件读取器
    /// - Parameters:
    ///   - enableVerboseLogging: 是否启用详细日志
    ///   - retryConfiguration: 重试配置
    ///   - compressionManager: 压缩管理器
    /// - Returns: AsyncFileReader实例
    static func createDefault(enableVerboseLogging: Bool = true, retryConfiguration: RetryConfiguration = .default, compressionManager: CompressionManagerProtocol? = nil) -> AsyncFileReader {
        return AsyncFileReader(enableVerboseLogging: enableVerboseLogging, retryConfiguration: retryConfiguration, compressionManager: compressionManager)
    }
    
    /// 创建用于测试的异步文件读取器
    /// - Parameters:
    ///   - enableVerboseLogging: 是否启用详细日志
    ///   - retryConfiguration: 重试配置
    ///   - compressionManager: 压缩管理器
    /// - Returns: AsyncFileReader实例
    static func createForTesting(enableVerboseLogging: Bool = true, retryConfiguration: RetryConfiguration = .fast, compressionManager: CompressionManagerProtocol? = nil) -> AsyncFileReader {
        return AsyncFileReader(enableVerboseLogging: enableVerboseLogging, retryConfiguration: retryConfiguration, compressionManager: compressionManager)
    }
    
    /// 创建用于生产环境的异步文件读取器
    /// - Parameters:
    ///   - enableVerboseLogging: 是否启用详细日志
    ///   - retryConfiguration: 重试配置
    ///   - compressionManager: 压缩管理器
    /// - Returns: AsyncFileReader实例
    static func createForProduction(enableVerboseLogging: Bool = false, retryConfiguration: RetryConfiguration = .conservative, compressionManager: CompressionManagerProtocol? = nil) -> AsyncFileReader {
        return AsyncFileReader(enableVerboseLogging: enableVerboseLogging, retryConfiguration: retryConfiguration, compressionManager: compressionManager)
    }
    
    /// 创建高可靠性异步文件读取器
    /// - Parameters:
    ///   - enableVerboseLogging: 是否启用详细日志
    ///   - compressionManager: 压缩管理器
    /// - Returns: AsyncFileReader实例
    static func createHighReliability(enableVerboseLogging: Bool = true, compressionManager: CompressionManagerProtocol? = nil) -> AsyncFileReader {
        let adaptiveConfig = RetryConfiguration(
            maxAttempts: 5,
            baseDelay: 1.0,
            maxDelay: 60.0,
            strategy: AdaptiveRetryStrategy(),
            enabled: true
        )
        return AsyncFileReader(enableVerboseLogging: enableVerboseLogging, retryConfiguration: adaptiveConfig, compressionManager: compressionManager)
    }
    
    /// 创建支持压缩的异步文件读取器
    /// - Parameters:
    ///   - enableVerboseLogging: 是否启用详细日志
    ///   - retryConfiguration: 重试配置
    /// - Returns: AsyncFileReader实例
    static func createWithCompression(enableVerboseLogging: Bool = true, retryConfiguration: RetryConfiguration = .default) -> AsyncFileReader {
        let compressionManager = CompressionManagerFactory.createDefault(enableVerboseLogging: enableVerboseLogging)
        return AsyncFileReader(enableVerboseLogging: enableVerboseLogging, retryConfiguration: retryConfiguration, compressionManager: compressionManager)
    }
}
