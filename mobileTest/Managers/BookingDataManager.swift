//
//  BookingDataManager.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation
import Combine

// MARK: - 数据管理器协议
protocol BookingDataManagerProtocol {
    func getBookingData() async throws -> BookingData
    func refreshBookingData() async throws -> BookingData
    func getDataStatus() async -> DataStatus
    var dataPublisher: AnyPublisher<BookingData, Never> { get }
}

// MARK: - 数据管理器实现
@MainActor
class BookingDataManager: ObservableObject, BookingDataManagerProtocol {
    
    // MARK: - 属性
    @Published private(set) var currentData: BookingData?
    @Published private(set) var dataStatus: DataStatus = .loading
    
    private let bookingService: BookingServiceProtocol
    private let bookingCache: BookingCacheProtocol
    private let dataSubject = PassthroughSubject<BookingData, Never>()
    
    // MARK: - 初始化
    
    /// 初始化数据管理器
    /// - Parameters:
    ///   - bookingService: 预订服务
    ///   - bookingCache: 预订缓存
    init(bookingService: BookingServiceProtocol = BookingService(), 
         bookingCache: BookingCacheProtocol = BookingCache()) {
        self.bookingService = bookingService
        self.bookingCache = bookingCache
        
        print("🚀 [BookingDataManager] 数据管理器已初始化")
    }
    
    // MARK: - 公共方法
    
    /// 获取预订数据（优先从缓存获取，缓存无效时从服务获取）
    /// - Returns: 预订数据
    /// - Throws: BookingDataError
    func getBookingData() async throws -> BookingData {
        print("📋 [BookingDataManager] 开始获取预订数据...")
        
        dataStatus = .loading
        
        do {
            // 首先尝试从缓存获取
            if let cachedData = try await getCachedDataIfValid() {
                print("✅ [BookingDataManager] 使用缓存数据")
                currentData = cachedData.data
                dataStatus = .loaded
                dataSubject.send(cachedData.data)
                return cachedData.data
            }
            
            // 缓存无效，从服务获取新数据
            print("🔄 [BookingDataManager] 缓存无效，从服务获取新数据")
            return try await fetchAndCacheNewData()
            
        } catch {
            print("❌ [BookingDataManager] 获取数据失败: \(error.localizedDescription)")
            dataStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    /// 强制刷新预订数据
    /// - Returns: 新的预订数据
    /// - Throws: BookingDataError
    func refreshBookingData() async throws -> BookingData {
        print("🔄 [BookingDataManager] 强制刷新数据...")
        
        dataStatus = .loading
        
        do {
            return try await fetchAndCacheNewData()
        } catch {
            print("❌ [BookingDataManager] 刷新数据失败: \(error.localizedDescription)")
            dataStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    /// 获取当前数据状态
    /// - Returns: 数据状态
    func getDataStatus() async -> DataStatus {
        return dataStatus
    }
    
    /// 数据发布者
    var dataPublisher: AnyPublisher<BookingData, Never> {
        return dataSubject.eraseToAnyPublisher()
    }
    
    // MARK: - 私有方法
    
    /// 获取有效的缓存数据
    /// - Returns: 缓存的预订数据，如果无效则返回nil
    /// - Throws: BookingDataError
    private func getCachedDataIfValid() async throws -> CachedBookingData? {
        print("🔍 [BookingDataManager] 检查缓存数据...")
        
        let cachedData = try bookingCache.load()
        
        if let cachedData = cachedData {
            if cachedData.isValid {
                print("✅ [BookingDataManager] 找到有效缓存数据")
                return cachedData
            } else {
                print("⚠️ [BookingDataManager] 缓存数据已过期")
                return nil
            }
        } else {
            print("ℹ️ [BookingDataManager] 无缓存数据")
            return nil
        }
    }
    
    /// 获取新数据并缓存
    /// - Returns: 新的预订数据
    /// - Throws: BookingDataError
    private func fetchAndCacheNewData() async throws -> BookingData {
        print("🌐 [BookingDataManager] 从服务获取新数据...")
        
        let (newData, timestamp) = try await bookingService.fetchBookingDataWithTimestamp()
        
        // 检查数据是否过期
        if newData.isExpired {
            print("⚠️ [BookingDataManager] 获取的数据已过期")
            dataStatus = .expired
            throw BookingDataError.dataExpired("数据已过期")
        }
        
        // 保存到缓存
        do {
            try bookingCache.save(newData, timestamp: timestamp)
            print("💾 [BookingDataManager] 新数据已保存到缓存")
        } catch {
            print("⚠️ [BookingDataManager] 保存缓存失败，但继续使用数据: \(error.localizedDescription)")
        }
        
        // 更新状态
        currentData = newData
        dataStatus = .loaded
        dataSubject.send(newData)
        
        print("✅ [BookingDataManager] 成功获取并缓存新数据")
        return newData
    }
}

// MARK: - 数据管理器扩展
extension BookingDataManager {
    
    /// 获取缓存统计信息
    /// - Returns: 缓存统计信息
    func getCacheStatistics() -> String {
        return bookingCache.getCacheStatistics()
    }
    
    /// 清除缓存
    /// - Throws: BookingDataError
    func clearCache() throws {
        print("🗑️ [BookingDataManager] 清除缓存...")
        try bookingCache.clearLegacyCache()
        print("✅ [BookingDataManager] 缓存已清除")
    }
    
    /// 获取当前数据的详细信息
    /// - Returns: 数据详细信息字符串
    func getCurrentDataInfo() -> String {
        guard let data = currentData else {
            return "无当前数据"
        }
        
        var info = "📊 当前数据信息:\n"
        info += "   - 船舶参考号: \(data.shipReference)\n"
        info += "   - 过期时间: \(data.formattedExpiryTime)\n"
        info += "   - 持续时间: \(data.formattedDuration)\n"
        info += "   - 航段数量: \(data.segments.count)\n"
        info += "   - 数据状态: \(dataStatus)\n"
        info += "   - 是否过期: \(data.isExpired ? "是" : "否")"
        
        return info
    }
}

// MARK: - 数据状态扩展
extension DataStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .loading:
            return "加载中"
        case .loaded:
            return "已加载"
        case .expired:
            return "已过期"
        case .error(let message):
            return "错误: \(message)"
        }
    }
}
