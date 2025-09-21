//
//  QuickTestData.swift
//  mobileTest
//
//  Created by AI Assistant on 2024-12-21.
//

import Foundation

/// 快速测试数据生成器
class QuickTestData {
    
    /// 快速生成一个有效的测试数据
    /// - Returns: 未过期的BookingData
    static func generateQuickValidData() -> BookingData {
        // 创建未来2小时后的过期时间
        let futureTime = Date().addingTimeInterval(2 * 60 * 60) // 2小时后
        let expiryTimestamp = futureTime.timeIntervalSince1970
        
        // 创建简单的航段数据
        let segment = Segment(
            id: 1,
            originAndDestinationPair: OriginDestinationPair(
                destination: Location(
                    code: "SHA",
                    displayName: "上海虹桥国际机场",
                    url: "https://www.shairport.com"
                ),
                destinationCity: "上海",
                origin: Location(
                    code: "PEK",
                    displayName: "北京首都国际机场",
                    url: "https://www.bcia.com.cn"
                ),
                originCity: "北京"
            )
        )
        
        return BookingData(
            shipReference: "SHIP_REF_\(Int.random(in: 1000...9999))",
            shipToken: "TOKEN_\(Int.random(in: 100000...999999))",
            canIssueTicketChecking: true,
            expiryTime: String(expiryTimestamp),
            duration: 120, // 2小时
            segments: [segment]
        )
    }
    
    /// 快速生成多个有效的测试数据
    /// - Parameter count: 数据数量
    /// - Returns: 未过期的BookingData数组
    static func generateMultipleValidData(count: Int = 3) -> [BookingData] {
        var data: [BookingData] = []
        
        for i in 1...count {
            let futureTime = Date().addingTimeInterval(TimeInterval(i * 60 * 60)) // 1小时、2小时、3小时后
            let expiryTimestamp = futureTime.timeIntervalSince1970
            
            let cities = [
                ("北京", "PEK"), ("上海", "SHA"), ("广州", "CAN"), ("深圳", "SZX"),
                ("成都", "CTU"), ("杭州", "HGH"), ("南京", "NKG"), ("武汉", "WUH")
            ]
            
            let originCity = cities.randomElement()!
            let destinationCity = cities.randomElement()!
            
            let segment = Segment(
                id: i,
                originAndDestinationPair: OriginDestinationPair(
                    destination: Location(
                        code: destinationCity.1,
                        displayName: destinationCity.0,
                        url: "https://www.airport.com"
                    ),
                    destinationCity: destinationCity.0,
                    origin: Location(
                        code: originCity.1,
                        displayName: originCity.0,
                        url: "https://www.airport.com"
                    ),
                    originCity: originCity.0
                )
            )
            
            let bookingData = BookingData(
                shipReference: "SHIP_REF_\(String(format: "%04d", i))",
                shipToken: "TOKEN_\(String(format: "%08d", i))_\(Int.random(in: 1000...9999))",
                canIssueTicketChecking: Bool.random(),
                expiryTime: String(expiryTimestamp),
                duration: Int.random(in: 60...300), // 1-5小时
                segments: [segment]
            )
            
            data.append(bookingData)
        }
        
        return data
    }
    
    /// 快速生成即将过期的测试数据（30分钟内过期）
    /// - Returns: 即将过期的BookingData
    static func generateSoonToExpireData() -> BookingData {
        // 创建30分钟后过期的数据
        let soonTime = Date().addingTimeInterval(30 * 60) // 30分钟后
        let expiryTimestamp = soonTime.timeIntervalSince1970
        
        let segment = Segment(
            id: 1,
            originAndDestinationPair: OriginDestinationPair(
                destination: Location(
                    code: "CAN",
                    displayName: "广州白云国际机场",
                    url: "https://www.gbiac.net"
                ),
                destinationCity: "广州",
                origin: Location(
                    code: "PEK",
                    displayName: "北京首都国际机场",
                    url: "https://www.bcia.com.cn"
                ),
                originCity: "北京"
            )
        )
        
        return BookingData(
            shipReference: "SOON_EXPIRE_\(Int.random(in: 1000...9999))",
            shipToken: "SOON_TOKEN_\(Int.random(in: 100000...999999))",
            canIssueTicketChecking: true,
            expiryTime: String(expiryTimestamp),
            duration: 180, // 3小时
            segments: [segment]
        )
    }
    
    /// 快速生成已过期的测试数据
    /// - Returns: 已过期的BookingData
    static func generateExpiredData() -> BookingData {
        // 创建1小时前过期的数据
        let pastTime = Date().addingTimeInterval(-60 * 60) // 1小时前
        let expiryTimestamp = pastTime.timeIntervalSince1970
        
        let segment = Segment(
            id: 1,
            originAndDestinationPair: OriginDestinationPair(
                destination: Location(
                    code: "SZX",
                    displayName: "深圳宝安国际机场",
                    url: "https://www.szairport.com"
                ),
                destinationCity: "深圳",
                origin: Location(
                    code: "SHA",
                    displayName: "上海虹桥国际机场",
                    url: "https://www.shairport.com"
                ),
                originCity: "上海"
            )
        )
        
        return BookingData(
            shipReference: "EXPIRED_\(Int.random(in: 1000...9999))",
            shipToken: "EXPIRED_TOKEN_\(Int.random(in: 100000...999999))",
            canIssueTicketChecking: false,
            expiryTime: String(expiryTimestamp),
            duration: 120, // 2小时
            segments: [segment]
        )
    }
    
    /// 快速生成混合测试数据
    /// - Returns: 包含有效、即将过期和已过期数据的数组
    static func generateMixedTestData() -> [BookingData] {
        var data: [BookingData] = []
        
        // 添加有效数据
        data.append(contentsOf: generateMultipleValidData(count: 2))
        
        // 添加即将过期的数据
        data.append(generateSoonToExpireData())
        
        // 添加已过期的数据
        data.append(generateExpiredData())
        
        return data
    }
    
    /// 打印测试数据信息
    /// - Parameter data: 测试数据
    static func printTestDataInfo(_ data: [BookingData]) {
        print("\n🧪 快速测试数据信息:")
        print("总数量: \(data.count)")
        
        let validCount = data.filter { !$0.isExpired }.count
        let expiredCount = data.filter { $0.isExpired }.count
        
        print("有效数据: \(validCount)")
        print("过期数据: \(expiredCount)")
        
        print("\n📋 数据详情:")
        for (index, booking) in data.enumerated() {
            let status = booking.isExpired ? "❌ 已过期" : "✅ 有效"
            print("\(index + 1). \(booking.shipReference) - \(status)")
            print("   过期时间: \(booking.formattedExpiryTime)")
            print("   持续时间: \(booking.formattedDuration)")
            print("   可出票: \(booking.canIssueTicketChecking ? "是" : "否")")
        }
    }
    
    /// 快速测试缓存功能
    /// - Parameter dataManager: 数据管理器
    static func quickTestCache(_ dataManager: BookingDataManager) async {
        print("\n🚀 快速测试缓存功能...")
        
        let testData = generateQuickValidData()
        
        do {
            // 保存测试数据
            print("📝 保存测试数据...")
            await dataManager.setTestData(testData)
            print("✅ 保存成功")
            
            // 从缓存读取
            print("📖 从缓存读取数据...")
            let cachedData = try await dataManager.getBookingData()
            print("✅ 读取成功")
            print("   缓存数据: \(cachedData.shipReference)")
            print("   过期时间: \(cachedData.formattedExpiryTime)")
            print("   是否过期: \(cachedData.isExpired ? "是" : "否")")
            
            // 获取缓存统计
            print("📊 获取缓存统计...")
            let cacheStats = await dataManager.getCacheStatistics() as String
            print("缓存统计: \(cacheStats)")
            
        } catch {
            print("❌ 缓存测试失败: \(error)")
        }
    }
}
