//
//  BookingModels.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

// MARK: - 主预订数据模型
struct BookingData: Codable {
    let shipReference: String
    let shipToken: String
    let canIssueTicketChecking: Bool
    let expiryTime: String
    let duration: Int
    let segments: [Segment]
    
    /// 检查数据是否过期
    var isExpired: Bool {
        guard let expiryTimestamp = Double(expiryTime) else { return true }
        let expiryDate = Date(timeIntervalSince1970: expiryTimestamp)
        return Date() > expiryDate
    }
    
    /// 获取格式化的过期时间
    var formattedExpiryTime: String {
        guard let expiryTimestamp = Double(expiryTime) else { return "未知" }
        let expiryDate = Date(timeIntervalSince1970: expiryTimestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: expiryDate)
    }
    
    /// 获取格式化的持续时间
    var formattedDuration: String {
        let hours = duration / 60
        let minutes = duration % 60
        return "\(hours)小时\(minutes)分钟"
    }
}

// MARK: - 航段数据模型
struct Segment: Codable, Identifiable {
    let id: Int
    let originAndDestinationPair: OriginDestinationPair
    
    /// 获取航段描述
    var description: String {
        return "\(originAndDestinationPair.origin.displayName) → \(originAndDestinationPair.destination.displayName)"
    }
}

// MARK: - 起终点对模型
struct OriginDestinationPair: Codable {
    let destination: Location
    let destinationCity: String
    let origin: Location
    let originCity: String
    
    /// 获取完整的路线描述
    var routeDescription: String {
        return "\(origin.displayName) (\(originCity)) → \(destination.displayName) (\(destinationCity))"
    }
}

// MARK: - 地点信息模型
struct Location: Codable {
    let code: String
    let displayName: String
    let url: String
    
    /// 获取格式化的地点信息
    var formattedInfo: String {
        return "\(displayName) (\(code))"
    }
}

// MARK: - 数据状态枚举
enum DataStatus: Equatable {
    case loading      // 加载中
    case loaded       // 已加载
    case expired      // 已过期
    case error(String) // 错误状态
}

// MARK: - 数据管理器错误类型
enum BookingDataError: Error, LocalizedError {
    case fileNotFound
    case invalidJSON
    case dataExpired
    case networkError(String)
    case cacheError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "找不到数据文件"
        case .invalidJSON:
            return "JSON数据格式无效"
        case .dataExpired:
            return "数据已过期"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .cacheError(let message):
            return "缓存错误: \(message)"
        }
    }
}
