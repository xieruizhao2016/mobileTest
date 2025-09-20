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
}

// MARK: - 预订服务实现
class BookingService: BookingServiceProtocol {
    
    // MARK: - 属性
    private let fileName = "booking"
    private let fileExtension = "json"
    
    // MARK: - 公共方法
    
    /// 获取预订数据
    /// - Returns: BookingData对象
    /// - Throws: BookingDataError
    func fetchBookingData() async throws -> BookingData {
        print("🔄 [BookingService] 开始获取预订数据...")
        
        do {
            let data = try await loadDataFromFile()
            let bookingData = try parseBookingData(from: data)
            
            print("✅ [BookingService] 成功获取预订数据")
            print("📊 [BookingService] 数据详情:")
            print("   - 船舶参考号: \(bookingData.shipReference)")
            print("   - 过期时间: \(bookingData.formattedExpiryTime)")
            print("   - 持续时间: \(bookingData.formattedDuration)")
            print("   - 航段数量: \(bookingData.segments.count)")
            print("   - 数据是否过期: \(bookingData.isExpired ? "是" : "否")")
            
            return bookingData
        } catch {
            print("❌ [BookingService] 获取数据失败: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// 获取预订数据并包含时间戳
    /// - Returns: 包含数据和获取时间的元组
    /// - Throws: BookingDataError
    func fetchBookingDataWithTimestamp() async throws -> (data: BookingData, timestamp: Date) {
        let data = try await fetchBookingData()
        let timestamp = Date()
        return (data: data, timestamp: timestamp)
    }
    
    // MARK: - 私有方法
    
    /// 从文件加载数据
    /// - Returns: Data对象
    /// - Throws: BookingDataError
    private func loadDataFromFile() async throws -> Data {
        guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
            print("❌ [BookingService] 找不到文件: \(fileName).\(fileExtension)")
            throw BookingDataError.fileNotFound
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            print("📁 [BookingService] 成功从文件加载数据，大小: \(data.count) 字节")
            return data
        } catch {
            print("❌ [BookingService] 读取文件失败: \(error.localizedDescription)")
            throw BookingDataError.networkError("文件读取失败: \(error.localizedDescription)")
        }
    }
    
    /// 解析预订数据
    /// - Parameter data: 原始数据
    /// - Returns: BookingData对象
    /// - Throws: BookingDataError
    private func parseBookingData(from data: Data) throws -> BookingData {
        do {
            let decoder = JSONDecoder()
            let bookingData = try decoder.decode(BookingData.self, from: data)
            print("🔍 [BookingService] 成功解析JSON数据")
            return bookingData
        } catch {
            print("❌ [BookingService] JSON解析失败: \(error.localizedDescription)")
            throw BookingDataError.invalidJSON
        }
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
        print("⏳ [BookingService] 模拟网络延迟...")
        await simulateNetworkDelay(0.5)
        return try await fetchBookingData()
    }
}
