//
//  CompressionManager.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation
import Compression

// MARK: - 压缩格式枚举
enum CompressionFormat: String, CaseIterable {
    case zip = "zip"
    case gzip = "gz"
    case deflate = "deflate"
    case lz4 = "lz4"
    case lzfse = "lzfse"
    case lzma = "lzma"
    case zlib = "zlib"
    
    var fileExtensions: [String] {
        switch self {
        case .zip:
            return ["zip"]
        case .gzip:
            return ["gz", "gzip"]
        case .deflate:
            return ["deflate"]
        case .lz4:
            return ["lz4"]
        case .lzfse:
            return ["lzfse"]
        case .lzma:
            return ["lzma", "xz"]
        case .zlib:
            return ["zlib"]
        }
    }
    
    var displayName: String {
        switch self {
        case .zip:
            return "ZIP"
        case .gzip:
            return "GZIP"
        case .deflate:
            return "DEFLATE"
        case .lz4:
            return "LZ4"
        case .lzfse:
            return "LZFSE"
        case .lzma:
            return "LZMA"
        case .zlib:
            return "ZLIB"
        }
    }
    
    var mimeType: String {
        switch self {
        case .zip:
            return "application/zip"
        case .gzip:
            return "application/gzip"
        case .deflate:
            return "application/deflate"
        case .lz4:
            return "application/lz4"
        case .lzfse:
            return "application/lzfse"
        case .lzma:
            return "application/x-lzma"
        case .zlib:
            return "application/zlib"
        }
    }
}

// MARK: - 压缩信息结构
struct CompressionInfo {
    let format: CompressionFormat
    let originalSize: Int
    let compressedSize: Int
    let compressionRatio: Double
    let isCompressed: Bool
    
    var compressionPercentage: Double {
        return (1.0 - compressionRatio) * 100.0
    }
    
    var spaceSaved: Int {
        return originalSize - compressedSize
    }
}

// MARK: - 压缩文件条目
struct CompressedFileEntry {
    let name: String
    let size: Int
    let compressedSize: Int
    let isDirectory: Bool
    let modificationDate: Date?
    let data: Data?
    
    var compressionRatio: Double {
        guard size > 0 else { return 1.0 }
        return Double(compressedSize) / Double(size)
    }
}

// MARK: - 压缩管理器协议
protocol CompressionManagerProtocol {
    /// 检测数据是否为压缩格式
    /// - Parameter data: 要检测的数据
    /// - Returns: 压缩信息，如果不是压缩格式则返回nil
    func detectCompressionFormat(from data: Data) -> CompressionInfo?
    
    /// 解压缩数据
    /// - Parameters:
    ///   - data: 压缩数据
    ///   - format: 压缩格式
    /// - Returns: 解压缩后的数据
    /// - Throws: BookingDataError
    func decompress(data: Data, format: CompressionFormat) async throws -> Data
    
    /// 压缩数据
    /// - Parameters:
    ///   - data: 原始数据
    ///   - format: 压缩格式
    /// - Returns: 压缩后的数据
    /// - Throws: BookingDataError
    func compress(data: Data, format: CompressionFormat) async throws -> Data
    
    /// 获取ZIP文件中的条目列表
    /// - Parameter data: ZIP文件数据
    /// - Returns: 文件条目列表
    /// - Throws: BookingDataError
    func getZipEntries(from data: Data) async throws -> [CompressedFileEntry]
    
    /// 从ZIP文件中提取特定文件
    /// - Parameters:
    ///   - data: ZIP文件数据
    ///   - fileName: 要提取的文件名
    /// - Returns: 提取的文件数据
    /// - Throws: BookingDataError
    func extractFileFromZip(data: Data, fileName: String) async throws -> Data
    
    /// 验证压缩文件完整性
    /// - Parameters:
    ///   - data: 压缩数据
    ///   - format: 压缩格式
    /// - Returns: 是否完整
    func validateCompression(data: Data, format: CompressionFormat) async -> Bool
}

// MARK: - 压缩管理器实现
class CompressionManager: CompressionManagerProtocol {
    
    private let enableVerboseLogging: Bool
    
    init(enableVerboseLogging: Bool = false) {
        self.enableVerboseLogging = enableVerboseLogging
    }
    
    // MARK: - 压缩格式检测
    
    func detectCompressionFormat(from data: Data) -> CompressionInfo? {
        guard data.count > 4 else { return nil }
        
        let header = data.prefix(4)
        let bytes = Array(header)
        
        // ZIP文件检测 (PK开头)
        if bytes.count >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4B {
            return CompressionInfo(
                format: .zip,
                originalSize: 0, // ZIP文件无法直接获取原始大小
                compressedSize: data.count,
                compressionRatio: 0.0,
                isCompressed: true
            )
        }
        
        // GZIP文件检测 (1F 8B)
        if bytes.count >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B {
            return CompressionInfo(
                format: .gzip,
                originalSize: 0, // 需要解压缩后才能获取
                compressedSize: data.count,
                compressionRatio: 0.0,
                isCompressed: true
            )
        }
        
        // LZ4文件检测
        if bytes.count >= 4 {
            let magic = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
            if magic == 0x184D2204 {
                return CompressionInfo(
                    format: .lz4,
                    originalSize: 0,
                    compressedSize: data.count,
                    compressionRatio: 0.0,
                    isCompressed: true
                )
            }
        }
        
        return nil
    }
    
    // MARK: - 数据解压缩
    
    func decompress(data: Data, format: CompressionFormat) async throws -> Data {
        log("🔄 [CompressionManager] 开始解压缩 \(format.displayName) 数据，大小: \(data.count) 字节")
        
        switch format {
        case .zip:
            return try await decompressZip(data: data)
        case .gzip:
            return try await decompressGzip(data: data)
        case .deflate:
            return try await decompressDeflate(data: data)
        case .lz4:
            return try await decompressLZ4(data: data)
        case .lzfse:
            return try await decompressLZFSE(data: data)
        case .lzma:
            return try await decompressLZMA(data: data)
        case .zlib:
            return try await decompressZlib(data: data)
        }
    }
    
    // MARK: - 数据压缩
    
    func compress(data: Data, format: CompressionFormat) async throws -> Data {
        log("🔄 [CompressionManager] 开始压缩 \(format.displayName) 数据，大小: \(data.count) 字节")
        
        switch format {
        case .zip:
            return try await compressZip(data: data)
        case .gzip:
            return try await compressGzip(data: data)
        case .deflate:
            return try await compressDeflate(data: data)
        case .lz4:
            return try await compressLZ4(data: data)
        case .lzfse:
            return try await compressLZFSE(data: data)
        case .lzma:
            return try await compressLZMA(data: data)
        case .zlib:
            return try await compressZlib(data: data)
        }
    }
    
    // MARK: - ZIP文件处理
    
    func getZipEntries(from data: Data) async throws -> [CompressedFileEntry] {
        log("📦 [CompressionManager] 开始解析ZIP文件条目")
        
        // 这里需要实现ZIP文件解析逻辑
        // 由于Swift标准库没有内置ZIP支持，这里提供一个基础实现
        // 在实际项目中，建议使用第三方库如ZipArchive
        
        var entries: [CompressedFileEntry] = []
        
        // 简化的ZIP解析实现
        // 注意：这是一个基础实现，完整的ZIP解析需要更复杂的逻辑
        let zipData = data
        var offset = 0
        
        while offset < zipData.count - 30 {
            let header = zipData.subdata(in: offset..<min(offset + 30, zipData.count))
            
            // 检查ZIP文件头签名
            if header.count >= 4 {
                let signature = header.prefix(4)
                if Array(signature) == [0x50, 0x4B, 0x03, 0x04] {
                    // 找到ZIP条目
                    if header.count >= 30 {
                        let fileNameLength = UInt16(header[26]) | (UInt16(header[27]) << 8)
                        let extraFieldLength = UInt16(header[28]) | (UInt16(header[29]) << 8)
                        
                        if offset + 30 + Int(fileNameLength) <= zipData.count {
                            let fileNameData = zipData.subdata(in: (offset + 30)..<(offset + 30 + Int(fileNameLength)))
                            if let fileName = String(data: fileNameData, encoding: .utf8) {
                                let entry = CompressedFileEntry(
                                    name: fileName,
                                    size: 0, // 需要从ZIP头中解析
                                    compressedSize: 0,
                                    isDirectory: fileName.hasSuffix("/"),
                                    modificationDate: nil,
                                    data: nil
                                )
                                entries.append(entry)
                            }
                        }
                        
                        offset += 30 + Int(fileNameLength) + Int(extraFieldLength)
                    } else {
                        break
                    }
                } else {
                    offset += 1
                }
            } else {
                break
            }
        }
        
        log("✅ [CompressionManager] 找到 \(entries.count) 个ZIP条目")
        return entries
    }
    
    func extractFileFromZip(data: Data, fileName: String) async throws -> Data {
        log("📤 [CompressionManager] 开始从ZIP中提取文件: \(fileName)")
        
        // 这里需要实现ZIP文件提取逻辑
        // 由于Swift标准库没有内置ZIP支持，这里抛出一个错误
        // 在实际项目中，建议使用第三方库如ZipArchive
        
        throw BookingDataError.unsupportedOperation("ZIP文件提取需要第三方库支持")
    }
    
    // MARK: - 压缩文件验证
    
    func validateCompression(data: Data, format: CompressionFormat) async -> Bool {
        log("🔍 [CompressionManager] 开始验证 \(format.displayName) 文件完整性")
        
        do {
            switch format {
            case .zip:
                // 验证ZIP文件头
                return data.count >= 4 && Array(data.prefix(4)) == [0x50, 0x4B, 0x03, 0x04]
            case .gzip:
                // 验证GZIP文件头
                return data.count >= 2 && Array(data.prefix(2)) == [0x1F, 0x8B]
            case .lz4:
                // 验证LZ4文件头
                if data.count >= 4 {
                    let magic = UInt32(data[0]) | (UInt32(data[1]) << 8) | (UInt32(data[2]) << 16) | (UInt32(data[3]) << 24)
                    return magic == 0x184D2204
                }
                return false
            default:
                // 对于其他格式，尝试解压缩来验证
                _ = try await decompress(data: data, format: format)
                return true
            }
        } catch {
            log("❌ [CompressionManager] 压缩文件验证失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 私有解压缩方法
    
    private func decompressZip(data: Data) async throws -> Data {
        // ZIP解压缩需要第三方库支持
        throw BookingDataError.unsupportedOperation("ZIP解压缩需要第三方库支持")
    }
    
    private func decompressGzip(data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let decompressedData = try data.gunzipped()
                    continuation.resume(returning: decompressedData)
                } catch {
                    continuation.resume(throwing: BookingDataError.dataCorrupted("GZIP解压缩失败: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func decompressDeflate(data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let decompressedData = try data.deflated()
                    continuation.resume(returning: decompressedData)
                } catch {
                    continuation.resume(throwing: BookingDataError.dataCorrupted("DEFLATE解压缩失败: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func decompressLZ4(data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let decompressedData = try data.lz4Decompressed()
                    continuation.resume(returning: decompressedData)
                } catch {
                    continuation.resume(throwing: BookingDataError.dataCorrupted("LZ4解压缩失败: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func decompressLZFSE(data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let decompressedData = try data.lzfseDecompressed()
                    continuation.resume(returning: decompressedData)
                } catch {
                    continuation.resume(throwing: BookingDataError.dataCorrupted("LZFSE解压缩失败: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func decompressLZMA(data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let decompressedData = try data.lzmaDecompressed()
                    continuation.resume(returning: decompressedData)
                } catch {
                    continuation.resume(throwing: BookingDataError.dataCorrupted("LZMA解压缩失败: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func decompressZlib(data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let decompressedData = try data.zlibDecompressed()
                    continuation.resume(returning: decompressedData)
                } catch {
                    continuation.resume(throwing: BookingDataError.dataCorrupted("ZLIB解压缩失败: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    // MARK: - 私有压缩方法
    
    private func compressZip(data: Data) async throws -> Data {
        // ZIP压缩需要第三方库支持
        throw BookingDataError.unsupportedOperation("ZIP压缩需要第三方库支持")
    }
    
    private func compressGzip(data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let compressedData = try data.gzipped()
                    continuation.resume(returning: compressedData)
                } catch {
                    continuation.resume(throwing: BookingDataError.encodingError("GZIP压缩失败: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func compressDeflate(data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let compressedData = try data.deflated()
                    continuation.resume(returning: compressedData)
                } catch {
                    continuation.resume(throwing: BookingDataError.encodingError("DEFLATE压缩失败: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func compressLZ4(data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let compressedData = try data.lz4Compressed()
                    continuation.resume(returning: compressedData)
                } catch {
                    continuation.resume(throwing: BookingDataError.encodingError("LZ4压缩失败: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func compressLZFSE(data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let compressedData = try data.lzfseCompressed()
                    continuation.resume(returning: compressedData)
                } catch {
                    continuation.resume(throwing: BookingDataError.encodingError("LZFSE压缩失败: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func compressLZMA(data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let compressedData = try data.lzmaCompressed()
                    continuation.resume(returning: compressedData)
                } catch {
                    continuation.resume(throwing: BookingDataError.encodingError("LZMA压缩失败: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func compressZlib(data: Data) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let compressedData = try data.zlibCompressed()
                    continuation.resume(returning: compressedData)
                } catch {
                    continuation.resume(throwing: BookingDataError.encodingError("ZLIB压缩失败: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    // MARK: - 日志方法
    
    private func log(_ message: String) {
        if enableVerboseLogging {
            print(message)
        }
    }
}

// MARK: - 空压缩管理器（用于禁用压缩功能）
class EmptyCompressionManager: CompressionManagerProtocol {
    
    func detectCompressionFormat(from data: Data) -> CompressionInfo? {
        return nil
    }
    
    func decompress(data: Data, format: CompressionFormat) async throws -> Data {
        throw BookingDataError.unsupportedOperation("压缩功能已禁用")
    }
    
    func compress(data: Data, format: CompressionFormat) async throws -> Data {
        throw BookingDataError.unsupportedOperation("压缩功能已禁用")
    }
    
    func getZipEntries(from data: Data) async throws -> [CompressedFileEntry] {
        throw BookingDataError.unsupportedOperation("压缩功能已禁用")
    }
    
    func extractFileFromZip(data: Data, fileName: String) async throws -> Data {
        throw BookingDataError.unsupportedOperation("压缩功能已禁用")
    }
    
    func validateCompression(data: Data, format: CompressionFormat) async -> Bool {
        return false
    }
}

// MARK: - 压缩管理器工厂
class CompressionManagerFactory {
    
    static func createDefault(enableVerboseLogging: Bool = false) -> CompressionManagerProtocol {
        return CompressionManager(enableVerboseLogging: enableVerboseLogging)
    }
    
    static func createDisabled() -> CompressionManagerProtocol {
        return EmptyCompressionManager()
    }
    
    static func createCustom(enableVerboseLogging: Bool = false) -> CompressionManagerProtocol {
        return CompressionManager(enableVerboseLogging: enableVerboseLogging)
    }
}
