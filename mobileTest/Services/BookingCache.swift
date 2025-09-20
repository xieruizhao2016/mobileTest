//
//  BookingCache.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

// MARK: - 缓存数据模型
struct CachedBookingData: Codable {
    let data: BookingData
    let timestamp: Date
    let expiryTime: Date
    
    /// 检查缓存是否有效
    var isValid: Bool {
        return Date() < expiryTime
    }
    
    /// 获取缓存年龄（秒）
    var age: TimeInterval {
        return Date().timeIntervalSince(timestamp)
    }
    
    /// 获取格式化的缓存时间
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: timestamp)
    }
}

// MARK: - 预订缓存协议
protocol BookingCacheProtocol {
    func save(_ data: BookingData, timestamp: Date) throws
    func load() throws -> CachedBookingData?
    func clear() throws
    func isCacheValid() -> Bool
    func getCacheInfo() -> (isValid: Bool, timestamp: Date?, age: TimeInterval?)
    func getCacheStatistics() -> String
}

// MARK: - 预订缓存实现
class BookingCache: BookingCacheProtocol {
    
    // MARK: - 属性
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "cached_booking_data"
    private let cacheExpiryKey = "cache_expiry_time"
    
    // 缓存有效期（秒）- 5分钟
    private let cacheValidityDuration: TimeInterval = 300
    
    // MARK: - 公共方法
    
    /// 保存数据到缓存
    /// - Parameters:
    ///   - data: 预订数据
    ///   - timestamp: 数据获取时间戳
    /// - Throws: BookingDataError
    func save(_ data: BookingData, timestamp: Date) throws {
        print("💾 [BookingCache] 开始保存数据到缓存...")
        
        do {
            let expiryTime = timestamp.addingTimeInterval(cacheValidityDuration)
            let cachedData = CachedBookingData(
                data: data,
                timestamp: timestamp,
                expiryTime: expiryTime
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encodedData = try encoder.encode(cachedData)
            
            userDefaults.set(encodedData, forKey: cacheKey)
            userDefaults.set(expiryTime, forKey: cacheExpiryKey)
            
            print("✅ [BookingCache] 数据已保存到缓存")
            print("📅 [BookingCache] 缓存时间: \(cachedData.formattedTimestamp)")
            print("⏰ [BookingCache] 缓存过期时间: \(formatDate(expiryTime))")
            print("🔄 [BookingCache] 缓存有效期: \(cacheValidityDuration)秒")
            
        } catch {
            print("❌ [BookingCache] 保存缓存失败: \(error.localizedDescription)")
            throw BookingDataError.cacheError("保存失败: \(error.localizedDescription)")
        }
    }
    
    /// 从缓存加载数据
    /// - Returns: 缓存的预订数据，如果不存在或无效则返回nil
    /// - Throws: BookingDataError
    func load() throws -> CachedBookingData? {
        print("📖 [BookingCache] 尝试从缓存加载数据...")
        
        guard let encodedData = userDefaults.data(forKey: cacheKey) else {
            print("ℹ️ [BookingCache] 缓存中无数据")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cachedData = try decoder.decode(CachedBookingData.self, from: encodedData)
            
            if cachedData.isValid {
                print("✅ [BookingCache] 成功从缓存加载有效数据")
                print("📅 [BookingCache] 缓存时间: \(cachedData.formattedTimestamp)")
                print("⏱️ [BookingCache] 缓存年龄: \(String(format: "%.1f", cachedData.age))秒")
                return cachedData
            } else {
                print("⚠️ [BookingCache] 缓存数据已过期")
                print("📅 [BookingCache] 缓存时间: \(cachedData.formattedTimestamp)")
                print("⏰ [BookingCache] 过期时间: \(formatDate(cachedData.expiryTime))")
                return nil
            }
            
        } catch {
            print("❌ [BookingCache] 解析缓存数据失败: \(error.localizedDescription)")
            throw BookingDataError.cacheError("解析失败: \(error.localizedDescription)")
        }
    }
    
    /// 清除缓存
    /// - Throws: BookingDataError
    func clear() throws {
        print("🗑️ [BookingCache] 清除缓存数据...")
        
        userDefaults.removeObject(forKey: cacheKey)
        userDefaults.removeObject(forKey: cacheExpiryKey)
        
        print("✅ [BookingCache] 缓存已清除")
    }
    
    /// 检查缓存是否有效
    /// - Returns: 缓存是否有效
    func isCacheValid() -> Bool {
        guard let cachedData = try? load() else { return false }
        return cachedData.isValid
    }
    
    /// 获取缓存信息
    /// - Returns: 缓存状态信息
    func getCacheInfo() -> (isValid: Bool, timestamp: Date?, age: TimeInterval?) {
        guard let cachedData = try? load() else {
            return (isValid: false, timestamp: nil, age: nil)
        }
        
        return (
            isValid: cachedData.isValid,
            timestamp: cachedData.timestamp,
            age: cachedData.age
        )
    }
    
    // MARK: - 私有方法
    
    /// 格式化日期
    /// - Parameter date: 日期对象
    /// - Returns: 格式化的日期字符串
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - 缓存管理扩展
extension BookingCache {
    
    /// 获取缓存统计信息
    /// - Returns: 缓存统计信息字符串
    func getCacheStatistics() -> String {
        let info = getCacheInfo()
        
        var statistics = "📊 缓存统计信息:\n"
        statistics += "   - 缓存状态: \(info.isValid ? "有效" : "无效/不存在")\n"
        
        if let timestamp = info.timestamp {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "zh_CN")
            statistics += "   - 缓存时间: \(formatter.string(from: timestamp))\n"
        }
        
        if let age = info.age {
            statistics += "   - 缓存年龄: \(String(format: "%.1f", age))秒\n"
        }
        
        statistics += "   - 缓存有效期: \(cacheValidityDuration)秒"
        
        return statistics
    }
}
