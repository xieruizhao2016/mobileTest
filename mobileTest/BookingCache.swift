//
//  BookingCache.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation
import os.log

// MARK: - 缓存键管理
struct CacheKey {
    let namespace: String
    let key: String
    
    var fullKey: String {
        return "\(namespace):\(key)"
    }
    
    /// 创建预订相关的缓存键
    static func booking(_ key: String) -> CacheKey {
        return CacheKey(namespace: "booking", key: key)
    }
    
    /// 创建用户相关的缓存键
    static func user(_ key: String) -> CacheKey {
        return CacheKey(namespace: "user", key: key)
    }
    
    /// 创建会话相关的缓存键
    static func session(_ key: String) -> CacheKey {
        return CacheKey(namespace: "session", key: key)
    }
    
    /// 创建临时缓存键
    static func temp(_ key: String) -> CacheKey {
        return CacheKey(namespace: "temp", key: key)
    }
    
    /// 验证缓存键格式
    func isValid() -> Bool {
        return !namespace.isEmpty && !key.isEmpty && 
               namespace.count <= 50 && key.count <= 100 &&
               !namespace.contains(":") && !key.contains(":")
    }
}

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
    let averageResponseTime: TimeInterval
    let topKeys: [(String, Int)] // 最常访问的键及其访问次数
    
    var hitRatePercentage: String {
        return String(format: "%.1f%%", hitRate * 100)
    }
    
    var memoryUsageMB: Double {
        return Double(memoryUsage) / (1024 * 1024)
    }
    
    var formattedMemoryUsage: String {
        return String(format: "%.2f MB", memoryUsageMB)
    }
}

// MARK: - 性能监控
struct CacheMetrics {
    let hitRate: Double
    let averageResponseTime: TimeInterval
    let memoryUsage: Int
    let evictionRate: Double
    let topKeys: [(String, Int)]
    let namespaceStats: [String: Int] // 各命名空间的统计
    
    var formattedReport: String {
        var report = "📊 缓存性能报告\n"
        report += "   - 命中率: \(String(format: "%.1f%%", hitRate * 100))\n"
        report += "   - 平均响应时间: \(String(format: "%.3f", averageResponseTime))ms\n"
        report += "   - 内存使用: \(String(format: "%.2f", Double(memoryUsage) / (1024 * 1024)))MB\n"
        report += "   - 清理率: \(String(format: "%.1f%%", evictionRate * 100))\n"
        
        if !topKeys.isEmpty {
            report += "   - 热门键: \(topKeys.prefix(3).map { "\($0.0)(\($0.1))" }.joined(separator: ", "))\n"
        }
        
        if !namespaceStats.isEmpty {
            report += "   - 命名空间分布: \(namespaceStats.map { "\($0.key):\($0.value)" }.joined(separator: ", "))"
        }
        
        return report
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

// MARK: - 缓存策略协议
protocol CacheStrategyProtocol {
    func getCachedDataWithStrategy(strategy: CacheStrategy) async throws -> CachedBookingData?
    func saveDataWithStrategy(_ data: BookingData, timestamp: Date, strategy: CacheStrategy) async throws
    func getCachedDataFromMemory() async throws -> CachedBookingData?
    func getCachedDataFromDisk() async throws -> CachedBookingData?
    func getCachedDataSmart() async throws -> CachedBookingData?
    func makeSmartCacheDecision(dataSize: Int, availableMemory: UInt64, totalMemory: UInt64) -> CacheStrategy
    func getMemoryInfo() -> (totalMemory: UInt64, availableMemory: UInt64)
    func calculateAccurateDataSize(_ data: BookingData) -> Int
    func formatBytes(_ bytes: Int) -> String
}

// MARK: - 统一缓存实现
class BookingCache: BookingCacheProtocol, AdvancedCacheProtocol, CacheStrategyProtocol {
    
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
    private var totalResponseTime: TimeInterval = 0
    private var keyAccessCounts: [String: Int] = [:]
    private var namespaceCounts: [String: Int] = [:]
    
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
    
    /// 获取缓存数据（同步版本，保持向后兼容）
    /// - Parameter key: 缓存键
    /// - Returns: 缓存的数据，如果不存在或已过期则返回nil
    func get<T>(key: String) -> T? {
        return queue.sync {
            return performGetOperation(key: key)
        }
    }
    
    /// 异步获取缓存数据
    /// - Parameter key: 缓存键
    /// - Returns: 缓存的数据，如果不存在或已过期则返回nil
    func getAsync<T>(key: String) async -> T? {
        return await withCheckedContinuation { continuation in
            queue.async {
                let result = self.performGetOperation(key: key) as T?
                continuation.resume(returning: result)
            }
        }
    }
    
    /// 执行缓存获取操作的核心逻辑
    /// - Parameter key: 缓存键
    /// - Returns: 缓存的数据，如果不存在或已过期则返回nil
    private func performGetOperation<T>(key: String) -> T? {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let item = memoryCache[key] else {
            missCount += 1
            recordAccess(key: key, isHit: false, responseTime: CFAbsoluteTimeGetCurrent() - startTime)
            logger.debug("缓存未命中: \(key)")
            return nil
        }
        
        // 检查是否过期
        if isExpired(item) {
            memoryCache.removeValue(forKey: key)
            missCount += 1
            recordAccess(key: key, isHit: false, responseTime: CFAbsoluteTimeGetCurrent() - startTime)
            logger.debug("缓存已过期: \(key)")
            return nil
        }
        
        // 更新访问信息
        if configuration.enableLRU {
            memoryCache[key] = item.accessed()
        }
        
        hitCount += 1
        recordAccess(key: key, isHit: true, responseTime: CFAbsoluteTimeGetCurrent() - startTime)
        logger.debug("缓存命中: \(key)")
        return item.data as? T
    }
    
    /// 记录访问统计信息
    /// - Parameters:
    ///   - key: 缓存键
    ///   - isHit: 是否命中
    ///   - responseTime: 响应时间
    private func recordAccess(key: String, isHit: Bool, responseTime: TimeInterval) {
        totalResponseTime += responseTime
        
        // 记录键访问次数
        keyAccessCounts[key, default: 0] += 1
        
        // 记录命名空间统计
        if let namespace = extractNamespace(from: key) {
            namespaceCounts[namespace, default: 0] += 1
        }
    }
    
    /// 从缓存键中提取命名空间
    /// - Parameter key: 缓存键
    /// - Returns: 命名空间，如果无法提取则返回nil
    private func extractNamespace(from key: String) -> String? {
        let components = key.components(separatedBy: ":")
        return components.count > 1 ? components[0] : nil
    }
    
    /// 设置缓存数据（同步版本，保持向后兼容）
    /// - Parameters:
    ///   - key: 缓存键
    ///   - value: 要缓存的数据
    func set<T>(key: String, value: T) {
        queue.async(flags: .barrier) {
            self.performSetOperation(key: key, value: value)
        }
    }
    
    /// 异步设置缓存数据
    /// - Parameters:
    ///   - key: 缓存键
    ///   - value: 要缓存的数据
    func setAsync<T>(key: String, value: T) async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                self.performSetOperation(key: key, value: value)
                continuation.resume()
            }
        }
    }
    
    /// 执行缓存设置操作的核心逻辑
    /// - Parameters:
    ///   - key: 缓存键
    ///   - value: 要缓存的数据
    private func performSetOperation<T>(key: String, value: T) {
        // 检查内存限制
        if shouldEvict() {
            evictItems()
        }
        
        let item = CacheItem(data: value as Any)
        memoryCache[key] = item
        logger.debug("数据已缓存: \(key)")
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
            let averageResponseTime = totalRequests > 0 ? totalResponseTime / Double(totalRequests) : 0.0
            
            // 获取最常访问的键
            let topKeys = keyAccessCounts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
            
            return CacheStatistics(
                totalItems: totalItems,
                hitCount: hitCount,
                missCount: missCount,
                evictionCount: evictionCount,
                memoryUsage: memoryUsage,
                hitRate: hitRate,
                averageResponseTime: averageResponseTime,
                topKeys: Array(topKeys)
            )
        }
    }
    
    /// 获取详细的缓存性能指标
    /// - Returns: 缓存性能指标
    func getMetrics() -> CacheMetrics {
        return queue.sync {
            let totalRequests = hitCount + missCount
            let hitRate = totalRequests > 0 ? Double(hitCount) / Double(totalRequests) : 0.0
            let averageResponseTime = totalRequests > 0 ? totalResponseTime / Double(totalRequests) : 0.0
            let evictionRate = totalRequests > 0 ? Double(evictionCount) / Double(totalRequests) : 0.0
            let memoryUsage = estimateMemoryUsage()
            
            // 获取最常访问的键
            let topKeys = keyAccessCounts.sorted { $0.value > $1.value }.prefix(10).map { ($0.key, $0.value) }
            
            return CacheMetrics(
                hitRate: hitRate,
                averageResponseTime: averageResponseTime,
                memoryUsage: memoryUsage,
                evictionRate: evictionRate,
                topKeys: Array(topKeys),
                namespaceStats: namespaceCounts
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
    
    /// 智能预热缓存
    /// - Parameter strategy: 预热策略
    func smartWarmup(strategy: CacheWarmupStrategy) async {
        logger.debug("开始智能缓存预热...")
        
        // 获取所有可能需要预热的键
        let keysToWarmup = memoryCache.keys.filter { key in
            return strategy.shouldWarmup(key: key) && !memoryCache.keys.contains(key)
        }
        
        // 按优先级排序
        let sortedKeys = keysToWarmup.sorted { key1, key2 in
            strategy.getWarmupPriority(key: key1) > strategy.getWarmupPriority(key: key2)
        }
        
        var successCount = 0
        var failureCount = 0
        
        for key in sortedKeys {
            do {
                let data = try await strategy.getWarmupData(key: key)
                set(key: key, value: data)
                successCount += 1
            } catch {
                logger.error("预热失败: \(key), 错误: \(error.localizedDescription)")
                failureCount += 1
            }
        }
        
        logger.debug("智能预热完成: 成功\(successCount)项, 失败\(failureCount)项")
    }
    
    // MARK: - CacheKey 便捷方法
    
    /// 使用CacheKey获取缓存数据
    /// - Parameter cacheKey: 缓存键
    /// - Returns: 缓存的数据，如果不存在或已过期则返回nil
    func get<T>(_ cacheKey: CacheKey) -> T? {
        guard cacheKey.isValid() else {
            logger.warning("无效的缓存键: \(cacheKey.fullKey)")
            return nil
        }
        return get(key: cacheKey.fullKey)
    }
    
    /// 使用CacheKey异步获取缓存数据
    /// - Parameter cacheKey: 缓存键
    /// - Returns: 缓存的数据，如果不存在或已过期则返回nil
    func getAsync<T>(_ cacheKey: CacheKey) async -> T? {
        guard cacheKey.isValid() else {
            logger.warning("无效的缓存键: \(cacheKey.fullKey)")
            return nil
        }
        return await getAsync(key: cacheKey.fullKey)
    }
    
    /// 使用CacheKey设置缓存数据
    /// - Parameters:
    ///   - cacheKey: 缓存键
    ///   - value: 要缓存的数据
    func set<T>(_ cacheKey: CacheKey, value: T) {
        guard cacheKey.isValid() else {
            logger.warning("无效的缓存键: \(cacheKey.fullKey)")
            return
        }
        set(key: cacheKey.fullKey, value: value)
    }
    
    /// 使用CacheKey异步设置缓存数据
    /// - Parameters:
    ///   - cacheKey: 缓存键
    ///   - value: 要缓存的数据
    func setAsync<T>(_ cacheKey: CacheKey, value: T) async {
        guard cacheKey.isValid() else {
            logger.warning("无效的缓存键: \(cacheKey.fullKey)")
            return
        }
        await setAsync(key: cacheKey.fullKey, value: value)
    }
    
    /// 使用CacheKey移除缓存
    /// - Parameter cacheKey: 缓存键
    func remove(_ cacheKey: CacheKey) {
        guard cacheKey.isValid() else {
            logger.warning("无效的缓存键: \(cacheKey.fullKey)")
            return
        }
        remove(key: cacheKey.fullKey)
    }
    
    /// 按命名空间清除缓存
    /// - Parameter namespace: 命名空间
    func clearNamespace(_ namespace: String) {
        queue.async(flags: .barrier) {
            let keysToRemove = self.memoryCache.keys.filter { key in
                if let keyNamespace = self.extractNamespace(from: key) {
                    return keyNamespace == namespace
                }
                return false
            }
            
            for key in keysToRemove {
                self.memoryCache.removeValue(forKey: key)
            }
            
            self.logger.debug("已清除命名空间 '\(namespace)' 的缓存，共\(keysToRemove.count)项")
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
        var totalSize = 0
        
        for (key, item) in memoryCache {
            // 计算键的大小
            totalSize += key.count * MemoryLayout<Character>.size
            
            // 计算CacheItem结构的大小
            totalSize += MemoryLayout<Date>.size * 2 // timestamp + lastAccessTime
            totalSize += MemoryLayout<Int>.size // accessCount
            
            // 估算数据大小
            totalSize += calculateObjectSize(item.data)
        }
        
        return totalSize
    }
    
    /// 计算对象的内存大小
    /// - Parameter object: 要计算大小的对象
    /// - Returns: 估算的对象大小（字节）
    private func calculateObjectSize(_ object: Any) -> Int {
        let mirror = Mirror(reflecting: object)
        
        switch mirror.displayStyle {
        case .struct, .class:
            var size = 0
            for child in mirror.children {
                if let label = child.label {
                    size += label.count * MemoryLayout<Character>.size
                }
                size += calculateObjectSize(child.value)
            }
            return size
            
        case .collection:
            if let array = object as? [Any] {
                return array.reduce(0) { $0 + calculateObjectSize($1) }
            }
            return 1024 // 默认估算
            
        case .dictionary:
            if let dict = object as? [String: Any] {
                return dict.reduce(0) { result, pair in
                    return result + pair.key.count * MemoryLayout<Character>.size + calculateObjectSize(pair.value)
                }
            }
            return 1024 // 默认估算
            
        case .optional:
            if let optionalValue = mirror.children.first?.value {
                return calculateObjectSize(optionalValue)
            }
            return 0
            
        default:
            // 对于基本类型，使用类型大小估算
            switch object {
            case is String:
                if let str = object as? String {
                    return str.count * MemoryLayout<Character>.size
                }
            case is Int:
                return MemoryLayout<Int>.size
            case is Double:
                return MemoryLayout<Double>.size
            case is Bool:
                return MemoryLayout<Bool>.size
            case is Date:
                return MemoryLayout<Date>.size
            default:
                break
            }
            return 1024 // 默认估算
        }
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
    
    // MARK: - 缓存策略方法 (CacheStrategyProtocol)
    
    /// 根据缓存策略获取缓存数据
    /// - Parameter strategy: 缓存策略
    /// - Returns: 缓存的预订数据，如果无效则返回nil
    /// - Throws: BookingDataError
    func getCachedDataWithStrategy(strategy: CacheStrategy) async throws -> CachedBookingData? {
        print("🔍 [BookingCache] 根据策略检查缓存数据... (策略: \(strategy))")
        
        switch strategy {
        case .memoryOnly:
            return try await getCachedDataFromMemory()
        case .diskOnly:
            return try await getCachedDataFromDisk()
        case .hybrid:
            // 先检查内存，再检查磁盘
            if let memoryData = try await getCachedDataFromMemory() {
                return memoryData
            }
            return try await getCachedDataFromDisk()
        case .smart:
            // 智能策略：根据数据大小和访问频率决定
            return try await getCachedDataSmart()
            
        case .disabled:
            print("💾 [BookingCache] 缓存已禁用，返回nil")
            return nil
        }
    }
    
    /// 从内存获取缓存数据
    /// - Returns: 缓存的预订数据，如果无效则返回nil
    /// - Throws: BookingDataError
    func getCachedDataFromMemory() async throws -> CachedBookingData? {
        print("🔍 [BookingCache] 从内存检查缓存数据...")
        
        // 暂时禁用异步内存缓存，直接返回nil
        print("ℹ️ [BookingCache] 异步内存缓存功能已暂时禁用")
        return nil
    }
    
    /// 从磁盘获取缓存数据
    /// - Returns: 缓存的预订数据，如果无效则返回nil
    /// - Throws: BookingDataError
    func getCachedDataFromDisk() async throws -> CachedBookingData? {
        print("🔍 [BookingCache] 从磁盘检查缓存数据...")
        
        let cachedData = try load()
        
        if let cachedData = cachedData {
            if cachedData.isValid {
                print("✅ [BookingCache] 从磁盘找到有效缓存数据")
                // 暂时禁用回填到内存缓存
                print("ℹ️ [BookingCache] 内存缓存回填功能已暂时禁用")
                return cachedData
            } else {
                print("⚠️ [BookingCache] 磁盘缓存数据已过期")
                return nil
            }
        } else {
            print("ℹ️ [BookingCache] 磁盘中无缓存数据")
            return nil
        }
    }
    
    /// 智能缓存策略
    /// - Returns: 缓存的预订数据，如果无效则返回nil
    /// - Throws: BookingDataError
    func getCachedDataSmart() async throws -> CachedBookingData? {
        print("🔍 [BookingCache] 使用智能缓存策略...")
        
        // 智能策略：优先使用内存，如果内存没有则使用磁盘
        // 同时考虑数据大小和访问频率
        if let memoryData = try await getCachedDataFromMemory() {
            return memoryData
        }
        
        // 如果内存没有，尝试从磁盘获取
        if let diskData = try await getCachedDataFromDisk() {
            return diskData
        }
        
        return nil
    }
    
    /// 根据缓存策略保存数据
    /// - Parameters:
    ///   - data: 预订数据
    ///   - timestamp: 时间戳
    ///   - strategy: 缓存策略
    /// - Throws: BookingDataError
    func saveDataWithStrategy(_ data: BookingData, timestamp: Date, strategy: CacheStrategy) async throws {
        let expiryTime = Date().addingTimeInterval(300) // 5分钟后过期
        let cachedData = CachedBookingData(data: data, timestamp: timestamp, expiryTime: expiryTime)
        
        switch strategy {
        case .memoryOnly:
            // 暂时禁用异步内存缓存
            print("💾 [BookingCache] 异步内存缓存功能已暂时禁用")
            
        case .diskOnly:
            try save(data, timestamp: timestamp)
            print("💾 [BookingCache] 数据已保存到磁盘缓存")
            
        case .hybrid:
            // 暂时禁用异步内存缓存，只保存到磁盘
            try save(data, timestamp: timestamp)
            print("💾 [BookingCache] 数据已保存到磁盘缓存（混合模式暂时禁用内存缓存）")
            
        case .smart:
            // 智能策略：暂时只保存到磁盘
            try save(data, timestamp: timestamp)
            print("💾 [BookingCache] 智能缓存策略暂时只保存到磁盘")
            
        case .disabled:
            print("💾 [BookingCache] 缓存已禁用，跳过保存")
        }
    }
    
    /// 智能缓存决策
    /// - Parameters:
    ///   - dataSize: 数据大小
    ///   - availableMemory: 可用内存
    ///   - totalMemory: 总内存
    /// - Returns: 缓存策略决策
    func makeSmartCacheDecision(dataSize: Int, availableMemory: UInt64, totalMemory: UInt64) -> CacheStrategy {
        let dataSizeUInt64 = UInt64(dataSize)
        
        // 如果数据太大（超过可用内存的50%），只保存到磁盘
        if dataSizeUInt64 > availableMemory / 2 {
            return .diskOnly
        }
        
        // 如果数据较小（小于1MB）且内存充足，保存到内存
        if dataSizeUInt64 < 1024 * 1024 && availableMemory > dataSizeUInt64 * 4 {
            return .memoryOnly
        }
        
        // 如果数据中等大小且内存充足，使用混合策略
        if dataSizeUInt64 < 10 * 1024 * 1024 && availableMemory > dataSizeUInt64 * 2 {
            return .hybrid
        }
        
        // 默认保存到磁盘
        return .diskOnly
    }
    
    /// 获取系统内存信息
    /// - Returns: 内存信息（总内存，可用内存）
    func getMemoryInfo() -> (totalMemory: UInt64, availableMemory: UInt64) {
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
            return (totalMemory: info.resident_size, availableMemory: info.resident_size)
        }
        
        // 如果获取失败，返回默认值
        return (totalMemory: 1024 * 1024 * 1024, availableMemory: 512 * 1024 * 1024) // 1GB总内存，512MB可用
    }
    
    /// 准确计算数据大小
    /// - Parameter data: 预订数据
    /// - Returns: 准确的字节数
    func calculateAccurateDataSize(_ data: BookingData) -> Int {
        var totalSize = 0
        
        // 使用Mirror进行反射计算对象大小
        let mirror = Mirror(reflecting: data)
        for child in mirror.children {
            if let label = child.label {
                totalSize += calculatePropertySize(label: label, value: child.value)
            }
        }
        
        return totalSize
    }
    
    /// 计算属性大小
    /// - Parameters:
    ///   - label: 属性名
    ///   - value: 属性值
    /// - Returns: 属性大小
    private func calculatePropertySize(label: String, value: Any) -> Int {
        var size = 0
        
        switch value {
        case let stringValue as String:
            // UTF-8编码的字符串大小
            size += stringValue.utf8.count
        case let arrayValue as [Any]:
            // 数组大小
            size += MemoryLayout<Any>.size * arrayValue.count
            for item in arrayValue {
                size += calculatePropertySize(label: "item", value: item)
            }
        case let segment as Segment:
            // Segment对象大小
            size += calculateSegmentSize(segment)
        default:
            // 其他类型使用内存布局估算
            size += MemoryLayout<Any>.size
        }
        
        return size
    }
    
    /// 计算Segment对象大小
    /// - Parameter segment: 航段对象
    /// - Returns: 航段大小
    private func calculateSegmentSize(_ segment: Segment) -> Int {
        var size = 0
        
        // 使用Mirror计算Segment大小
        let mirror = Mirror(reflecting: segment)
        for child in mirror.children {
            if let label = child.label {
                size += calculatePropertySize(label: label, value: child.value)
            }
        }
        
        return size
    }
    
    /// 格式化字节数
    /// - Parameter bytes: 字节数
    /// - Returns: 格式化的字符串
    func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
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

// MARK: - 智能缓存预热策略
protocol CacheWarmupStrategy {
    func shouldWarmup(key: String) -> Bool
    func getWarmupPriority(key: String) -> Int
    func getWarmupData(key: String) async throws -> Any
}

// MARK: - 基于使用模式的预测性预热
class PredictiveWarmup: CacheWarmupStrategy {
    private let usagePatterns: [String: UsagePattern]
    private let dataProvider: (String) async throws -> Any
    
    init(usagePatterns: [String: UsagePattern], dataProvider: @escaping (String) async throws -> Any) {
        self.usagePatterns = usagePatterns
        self.dataProvider = dataProvider
    }
    
    func shouldWarmup(key: String) -> Bool {
        return usagePatterns[key]?.shouldWarmup ?? false
    }
    
    func getWarmupPriority(key: String) -> Int {
        return usagePatterns[key]?.priority ?? 0
    }
    
    func getWarmupData(key: String) async throws -> Any {
        return try await dataProvider(key)
    }
}

// MARK: - 使用模式
struct UsagePattern {
    let accessFrequency: Double // 访问频率 (0.0 - 1.0)
    let timePattern: TimePattern // 时间模式
    let priority: Int // 优先级 (0-100)
    
    var shouldWarmup: Bool {
        return accessFrequency > 0.3 && priority > 50
    }
}

enum TimePattern {
    case always // 总是需要
    case businessHours // 工作时间
    case peakHours // 高峰时间
    case specific([Date]) // 特定时间
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
