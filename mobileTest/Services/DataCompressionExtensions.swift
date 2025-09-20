//
//  DataCompressionExtensions.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation
import Compression

// MARK: - Data压缩扩展
extension Data {
    
    // MARK: - GZIP压缩/解压缩
    
    /// GZIP压缩
    /// - Returns: 压缩后的数据
    /// - Throws: 压缩错误
    func gzipped() throws -> Data {
        guard !isEmpty else { return self }
        
        return try withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_ZLIB
            )
            
            guard compressedSize > 0 else {
                throw CompressionError.compressionFailed
            }
            
            return Data(bytes: buffer, count: compressedSize)
        }
    }
    
    /// GZIP解压缩
    /// - Returns: 解压缩后的数据
    /// - Throws: 解压缩错误
    func gunzipped() throws -> Data {
        guard !isEmpty else { return self }
        
        return try withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count * 4) // 预估解压缩后大小
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, count * 4,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_ZLIB
            )
            
            guard decompressedSize > 0 else {
                throw CompressionError.decompressionFailed
            }
            
            return Data(bytes: buffer, count: decompressedSize)
        }
    }
    
    // MARK: - DEFLATE压缩/解压缩
    
    /// DEFLATE压缩
    /// - Returns: 压缩后的数据
    /// - Throws: 压缩错误
    func deflated() throws -> Data {
        guard !isEmpty else { return self }
        
        return try withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_ZLIB
            )
            
            guard compressedSize > 0 else {
                throw CompressionError.compressionFailed
            }
            
            return Data(bytes: buffer, count: compressedSize)
        }
    }
    
    /// DEFLATE解压缩
    /// - Returns: 解压缩后的数据
    /// - Throws: 解压缩错误
    func inflated() throws -> Data {
        guard !isEmpty else { return self }
        
        return try withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count * 4)
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, count * 4,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_ZLIB
            )
            
            guard decompressedSize > 0 else {
                throw CompressionError.decompressionFailed
            }
            
            return Data(bytes: buffer, count: decompressedSize)
        }
    }
    
    // MARK: - LZ4压缩/解压缩
    
    /// LZ4压缩
    /// - Returns: 压缩后的数据
    /// - Throws: 压缩错误
    func lz4Compressed() throws -> Data {
        guard !isEmpty else { return self }
        
        return try withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_LZ4
            )
            
            guard compressedSize > 0 else {
                throw CompressionError.compressionFailed
            }
            
            return Data(bytes: buffer, count: compressedSize)
        }
    }
    
    /// LZ4解压缩
    /// - Returns: 解压缩后的数据
    /// - Throws: 解压缩错误
    func lz4Decompressed() throws -> Data {
        guard !isEmpty else { return self }
        
        return try withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count * 4)
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, count * 4,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_LZ4
            )
            
            guard decompressedSize > 0 else {
                throw CompressionError.decompressionFailed
            }
            
            return Data(bytes: buffer, count: decompressedSize)
        }
    }
    
    // MARK: - LZFSE压缩/解压缩
    
    /// LZFSE压缩
    /// - Returns: 压缩后的数据
    /// - Throws: 压缩错误
    func lzfseCompressed() throws -> Data {
        guard !isEmpty else { return self }
        
        return try withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_LZFSE
            )
            
            guard compressedSize > 0 else {
                throw CompressionError.compressionFailed
            }
            
            return Data(bytes: buffer, count: compressedSize)
        }
    }
    
    /// LZFSE解压缩
    /// - Returns: 解压缩后的数据
    /// - Throws: 解压缩错误
    func lzfseDecompressed() throws -> Data {
        guard !isEmpty else { return self }
        
        return try withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count * 4)
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, count * 4,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_LZFSE
            )
            
            guard decompressedSize > 0 else {
                throw CompressionError.decompressionFailed
            }
            
            return Data(bytes: buffer, count: decompressedSize)
        }
    }
    
    // MARK: - LZMA压缩/解压缩
    
    /// LZMA压缩
    /// - Returns: 压缩后的数据
    /// - Throws: 压缩错误
    func lzmaCompressed() throws -> Data {
        guard !isEmpty else { return self }
        
        return try withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_LZMA
            )
            
            guard compressedSize > 0 else {
                throw CompressionError.compressionFailed
            }
            
            return Data(bytes: buffer, count: compressedSize)
        }
    }
    
    /// LZMA解压缩
    /// - Returns: 解压缩后的数据
    /// - Throws: 解压缩错误
    func lzmaDecompressed() throws -> Data {
        guard !isEmpty else { return self }
        
        return try withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count * 4)
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, count * 4,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_LZMA
            )
            
            guard decompressedSize > 0 else {
                throw CompressionError.decompressionFailed
            }
            
            return Data(bytes: buffer, count: decompressedSize)
        }
    }
    
    // MARK: - ZLIB压缩/解压缩
    
    /// ZLIB压缩
    /// - Returns: 压缩后的数据
    /// - Throws: 压缩错误
    func zlibCompressed() throws -> Data {
        guard !isEmpty else { return self }
        
        return try withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_ZLIB
            )
            
            guard compressedSize > 0 else {
                throw CompressionError.compressionFailed
            }
            
            return Data(bytes: buffer, count: compressedSize)
        }
    }
    
    /// ZLIB解压缩
    /// - Returns: 解压缩后的数据
    /// - Throws: 解压缩错误
    func zlibDecompressed() throws -> Data {
        guard !isEmpty else { return self }
        
        return try withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: count * 4)
            defer { buffer.deallocate() }
            
            let decompressedSize = compression_decode_buffer(
                buffer, count * 4,
                bytes.bindMemory(to: UInt8.self).baseAddress!, count,
                nil, COMPRESSION_ZLIB
            )
            
            guard decompressedSize > 0 else {
                throw CompressionError.decompressionFailed
            }
            
            return Data(bytes: buffer, count: decompressedSize)
        }
    }
}

// MARK: - 压缩错误类型
enum CompressionError: Error, LocalizedError {
    case compressionFailed
    case decompressionFailed
    case invalidFormat
    case insufficientMemory
    case corruptedData
    
    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            return "数据压缩失败"
        case .decompressionFailed:
            return "数据解压缩失败"
        case .invalidFormat:
            return "无效的压缩格式"
        case .insufficientMemory:
            return "内存不足"
        case .corruptedData:
            return "数据已损坏"
        }
    }
}

// MARK: - 压缩工具类
class CompressionUtils {
    
    /// 检测文件是否为压缩格式
    /// - Parameter filePath: 文件路径
    /// - Returns: 压缩格式，如果不是压缩格式则返回nil
    static func detectCompressionFormat(filePath: String) -> CompressionFormat? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return nil
        }
        
        let manager = CompressionManager()
        return manager.detectCompressionFormat(from: data)?.format
    }
    
    /// 获取压缩信息
    /// - Parameter data: 数据
    /// - Returns: 压缩信息
    static func getCompressionInfo(data: Data) -> CompressionInfo? {
        let manager = CompressionManager()
        return manager.detectCompressionFormat(from: data)
    }
    
    /// 计算压缩比
    /// - Parameters:
    ///   - originalSize: 原始大小
    ///   - compressedSize: 压缩后大小
    /// - Returns: 压缩比
    static func calculateCompressionRatio(originalSize: Int, compressedSize: Int) -> Double {
        guard originalSize > 0 else { return 1.0 }
        return Double(compressedSize) / Double(originalSize)
    }
    
    /// 计算压缩百分比
    /// - Parameters:
    ///   - originalSize: 原始大小
    ///   - compressedSize: 压缩后大小
    /// - Returns: 压缩百分比
    static func calculateCompressionPercentage(originalSize: Int, compressedSize: Int) -> Double {
        let ratio = calculateCompressionRatio(originalSize: originalSize, compressedSize: compressedSize)
        return (1.0 - ratio) * 100.0
    }
    
    /// 格式化文件大小
    /// - Parameter bytes: 字节数
    /// - Returns: 格式化后的文件大小字符串
    static func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
