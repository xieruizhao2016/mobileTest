//
//  BookingCache.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation
import os.log

// MARK: - 缓存项模型
struct CacheItem<T> {
    let data: T
    let timestamp: Date
    let accessCount: Int
    let lastAccessTime: Date
    
    init(data: T) {
        self.data = data
        self.timestamp = Date()
        self.accessCount = 1
        self.lastAccessTime = Date()
    }
    
    init(data: T, timestamp: Date, accessCount: Int, lastAccessTime: Date) {
        self.data = data
        self.timestamp = timestamp
        self.accessCount = accessCount
        self.lastAccessTime = lastAccessTime
    }
    
    /// 更新访问信息
    func accessed() -> CacheItem<T> {
        return CacheItem(
            data: self.data,
            timestamp: self.timestamp,
            accessCount: self.accessCount + 1,
            lastAccessTime: Date()
        )
    }
}

// MARK: - 缓存统计信息
struct CacheStatistics {
    let totalItems: Int
    let hitCount: Int
    let missCount: Int
    let evictionCount: Int
    let memoryUsage: Int // 字节
    let hitRate: Double
    
    var hitRatePercentage: String {
        return String(format: "%.1f%%", hitRate * 100)
    }
}

// MARK: - 缓存配置
protocol CacheConfigurationProtocol {
    var maxItems: Int { get }
    var maxMemoryMB: Int { get }
    var expirationTime: TimeInterval { get }
    var enableLRU: Bool { get }
    var enableStatistics: Bool { get }
}

// MARK: - 默认缓存配置
struct DefaultCacheConfiguration: CacheConfigurationProtocol {
    let maxItems: Int
    let maxMemoryMB: Int
    let expirationTime: TimeInterval
    let enableLRU: Bool
    let enableStatistics: Bool
    
    init(
        maxItems: Int = 100,
        maxMemoryMB: Int = 50,
        expirationTime: TimeInterval = 300.0,
        enableLRU: Bool = true,
        enableStatistics: Bool = true
    ) {
        self.maxItems = maxItems
        self.maxMemoryMB = maxMemoryMB
        self.expirationTime = expirationTime
        self.enableLRU = enableLRU
        self.enableStatistics = enableStatistics
    }
}

// MARK: - 缓存数据模型 (保持向后兼容)
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

// MARK: - 预订缓存协议 (保持向后兼容)
protocol BookingCacheProtocol {
    func save(_ data: BookingData, timestamp: Date) throws
    func load() throws -> CachedBookingData?
    func clearLegacyCache() throws
    func isCacheValid() -> Bool
    func getCacheInfo() -> (isValid: Bool, timestamp: Date?, age: TimeInterval?)
    func getCacheStatistics() -> String
}

// MARK: - 高级缓存协议
protocol AdvancedCacheProtocol {
    func get<T>(key: String) -> T?
    func set<T>(key: String, value: T)
    func remove(key: String)
    func clear()
    func getStatistics() -> CacheStatistics
    func warmup<T>(items: [(key: String, value: T)])
}

// MARK: - 统一缓存实现
class BookingCache: BookingCacheProtocol, AdvancedCacheProtocol {
    
    // MARK: - 属性
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "cached_booking_data"
    private let cacheExpiryKey = "cache_expiry_key"
    
    // 缓存配置
    private let configuration: CacheConfigurationProtocol
    
    // 内存缓存 (高级功能)
    private var memoryCache: [String: CacheItem<Any>] = [:]
    private let queue = DispatchQueue(label: "com.mobiletest.cache", attributes: .concurrent)
    private let logger = Logger(subsystem: "com.mobiletest", category: "BookingCache")
    
    // 统计信息
    private var hitCount: Int = 0
    private var missCount: Int = 0
    private var evictionCount: Int = 0
    
    // 缓存有效期（秒）- 5分钟 (向后兼容)
    private let cacheValidityDuration: TimeInterval = 300
    
    // MARK: - 初始化器
    
    /// 使用默认配置初始化
    convenience init() {
        self.init(configuration: DefaultCacheConfiguration())
    }
    
    /// 使用指定配置初始化
    /// - Parameter configuration: 缓存配置
    init(configuration: CacheConfigurationProtocol) {
        self.configuration = configuration
    }
    
    // MARK: - 高级缓存方法 (AdvancedCacheProtocol)
    
    /// 获取缓存数据
    /// - Parameter key: 缓存键
    /// - Returns: 缓存的数据，如果不存在或已过期则返回nil
    func get<T>(key: String) -> T? {
        return queue.sync {
            guard let item = memoryCache[key] else {
                missCount += 1
                logger.debug("缓存未命中: \(key)")
                return nil
            }
            
            // 检查是否过期
            if isExpired(item) {
                memoryCache.removeValue(forKey: key)
                missCount += 1
                logger.debug("缓存已过期: \(key)")
                return nil
            }
            
            // 更新访问信息
            if configuration.enableLRU {
                memoryCache[key] = item.accessed()
            }
            
            hitCount += 1
            logger.debug("缓存命中: \(key)")
            return item.data as? T
        }
    }
    
    /// 设置缓存数据
    /// - Parameters:
    ///   - key: 缓存键
    ///   - value: 要缓存的数据
    func set<T>(key: String, value: T) {
        queue.async(flags: .barrier) {
            // 检查内存限制
            if self.shouldEvict() {
                self.evictItems()
            }
            
            let item = CacheItem(data: value as Any)
            self.memoryCache[key] = item
            self.logger.debug("数据已缓存: \(key)")
        }
    }
    
    /// 移除指定缓存
    /// - Parameter key: 缓存键
    func remove(key: String) {
        queue.async(flags: .barrier) {
            self.memoryCache.removeValue(forKey: key)
            self.logger.debug("缓存已移除: \(key)")
        }
    }
    
    /// 清除所有缓存 (高级缓存)
    func clear() {
        queue.async(flags: .barrier) {
            self.memoryCache.removeAll()
            self.hitCount = 0
            self.missCount = 0
            self.evictionCount = 0
            self.logger.debug("所有缓存已清除")
        }
    }
    
    /// 获取缓存统计信息
    /// - Returns: 缓存统计信息
    func getStatistics() -> CacheStatistics {
        return queue.sync {
            let totalItems = memoryCache.count
            let totalRequests = hitCount + missCount
            let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
            let memoryUsage = estimateMemoryUsage()
            
            return CacheStatistics(
                totalItems: totalItems,
                hitCount: hitCount,
                missCount: missCount,
                evictionCount: evictionCount,
                memoryUsage: memoryUsage,
                hitRate: hitRate
            )
        }
    }
    
    /// 预热缓存
    /// - Parameter items: 要预热的缓存项
    func warmup<T>(items: [(key: String, value: T)]) {
        queue.async(flags: .barrier) {
            for (key, value) in items {
                if !self.memoryCache.keys.contains(key) {
                    let item = CacheItem(data: value as Any)
                    self.memoryCache[key] = item
                }
            }
            self.logger.debug("缓存预热完成，共\(items.count)项")
        }
    }
    
    // MARK: - 向后兼容方法 (BookingCacheProtocol)
    
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
    
    /// 清除缓存 (向后兼容)
    /// - Throws: BookingDataError
    func clearLegacyCache() throws {
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
    
    /// 检查缓存项是否过期
    /// - Parameter item: 缓存项
    /// - Returns: 是否过期
    private func isExpired(_ item: CacheItem<Any>) -> Bool {
        let now = Date()
        let age = now.timeIntervalSince(item.timestamp)
        return age > configuration.expirationTime
    }
    
    /// 检查是否需要清理缓存
    /// - Returns: 是否需要清理
    private func shouldEvict() -> Bool {
        // 检查数量限制
        if memoryCache.count >= configuration.maxItems {
            return true
        }
        
        // 检查内存限制
        let memoryUsageMB = estimateMemoryUsage() / (1024 * 1024)
        if memoryUsageMB >= configuration.maxMemoryMB {
            return true
        }
        
        return false
    }
    
    /// 清理过期和LRU项
    private func evictItems() {
        // 首先清理过期项
        let expiredKeys = memoryCache.compactMap { (key, item) in
            isExpired(item) ? key : nil
        }
        
        for key in expiredKeys {
            memoryCache.removeValue(forKey: key)
            evictionCount += 1
        }
        
        // 如果仍然超过限制，使用LRU策略
        var totalRemoved = expiredKeys.count
        if memoryCache.count >= configuration.maxItems {
            let itemsToRemove = memoryCache.count - configuration.maxItems + 1
            
            if configuration.enableLRU {
                // 按最后访问时间排序，移除最久未访问的项
                let sortedItems = memoryCache.sorted { $0.value.lastAccessTime < $1.value.lastAccessTime }
                for i in 0..<min(itemsToRemove, sortedItems.count) {
                    let key = sortedItems[i].key
                    memoryCache.removeValue(forKey: key)
                    evictionCount += 1
                }
            } else {
                // 随机移除
                let keys = Array(memoryCache.keys)
                for _ in 0..<itemsToRemove {
                    if let randomKey = keys.randomElement() {
                        memoryCache.removeValue(forKey: randomKey)
                        evictionCount += 1
                    }
                }
            }
            totalRemoved += itemsToRemove
        }
        
        logger.debug("缓存清理完成，移除了\(totalRemoved)项")
    }
    
    /// 估算内存使用量
    /// - Returns: 估算的内存使用量（字节）
    private func estimateMemoryUsage() -> Int {
        // 这是一个简化的估算，实际使用中可能需要更精确的计算
        let averageItemSize = 1024 // 假设每个缓存项平均1KB
        return memoryCache.count * averageItemSize
    }
    
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

// MARK: - 缓存工厂
enum BookingCacheFactory {
    /// 创建默认缓存
    static func createDefault() -> BookingCache {
        let config = DefaultCacheConfiguration()
        return BookingCache(configuration: config)
    }
    
    /// 创建高性能缓存
    static func createHighPerformance() -> BookingCache {
        let config = DefaultCacheConfiguration(
            maxItems: 500,
            maxMemoryMB: 100,
            expirationTime: 600.0,
            enableLRU: true,
            enableStatistics: true
        )
        return BookingCache(configuration: config)
    }
    
    /// 创建内存优化缓存
    static func createMemoryOptimized() -> BookingCache {
        let config = DefaultCacheConfiguration(
            maxItems: 50,
            maxMemoryMB: 10,
            expirationTime: 180.0,
            enableLRU: true,
            enableStatistics: true
        )
        return BookingCache(configuration: config)
    }
    
    /// 创建自定义缓存
    static func createCustom(
        maxItems: Int = 100,
        maxMemoryMB: Int = 50,
        expirationTime: TimeInterval = 300.0,
        enableLRU: Bool = true,
        enableStatistics: Bool = true
    ) -> BookingCache {
        let config = DefaultCacheConfiguration(
            maxItems: maxItems,
            maxMemoryMB: maxMemoryMB,
            expirationTime: expirationTime,
            enableLRU: enableLRU,
            enableStatistics: enableStatistics
        )
        return BookingCache(configuration: config)
    }
}
