//
//  TestDataGenerator.swift
//  mobileTest
//
//  Created by AI Assistant on 2024-12-21.
//

import Foundation

/// 测试数据生成器
class TestDataGenerator {
    
    /// 生成未过期的测试数据
    /// - Parameter count: 生成的数据数量
    /// - Returns: 未过期的BookingData数组
    static func generateValidTestData(count: Int = 5) -> [BookingData] {
        var testData: [BookingData] = []
        
        for i in 1...count {
            let bookingData = createValidBookingData(index: i)
            testData.append(bookingData)
        }
        
        return testData
    }
    
    /// 创建单个有效的预订数据
    /// - Parameter index: 数据索引
    /// - Returns: 未过期的BookingData
    private static func createValidBookingData(index: Int) -> BookingData {
        // 创建未来24小时后的过期时间
        let futureTime = Date().addingTimeInterval(24 * 60 * 60) // 24小时后
        let expiryTimestamp = futureTime.timeIntervalSince1970
        
        // 创建航段数据
        let segments = createTestSegments(count: Int.random(in: 1...3))
        
        return BookingData(
            shipReference: "SHIP_REF_\(String(format: "%04d", index))",
            shipToken: "TOKEN_\(String(format: "%08d", index))_\(Int.random(in: 1000...9999))",
            canIssueTicketChecking: Bool.random(),
            expiryTime: String(expiryTimestamp),
            duration: Int.random(in: 60...480), // 1-8小时
            segments: segments
        )
    }
    
    /// 创建测试航段数据
    /// - Parameter count: 航段数量
    /// - Returns: 航段数组
    private static func createTestSegments(count: Int) -> [Segment] {
        let cities = [
            ("北京", "PEK"), ("上海", "SHA"), ("广州", "CAN"), ("深圳", "SZX"),
            ("成都", "CTU"), ("杭州", "HGH"), ("南京", "NKG"), ("武汉", "WUH"),
            ("西安", "XIY"), ("重庆", "CKG"), ("天津", "TSN"), ("青岛", "TAO")
        ]
        
        var segments: [Segment] = []
        
        for i in 0..<count {
            let originCity = cities.randomElement()!
            let destinationCity = cities.randomElement()!
            
            let segment = Segment(
                id: i + 1,
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
            segments.append(segment)
        }
        
        return segments
    }
    
    /// 生成已过期的测试数据（用于测试过期逻辑）
    /// - Parameter count: 生成的数据数量
    /// - Returns: 已过期的BookingData数组
    static func generateExpiredTestData(count: Int = 3) -> [BookingData] {
        var testData: [BookingData] = []
        
        for i in 1...count {
            let bookingData = createExpiredBookingData(index: i)
            testData.append(bookingData)
        }
        
        return testData
    }
    
    /// 创建单个已过期的预订数据
    /// - Parameter index: 数据索引
    /// - Returns: 已过期的BookingData
    private static func createExpiredBookingData(index: Int) -> BookingData {
        // 创建过去24小时前的过期时间
        let pastTime = Date().addingTimeInterval(-24 * 60 * 60) // 24小时前
        let expiryTimestamp = pastTime.timeIntervalSince1970
        
        // 创建航段数据
        let segments = createTestSegments(count: Int.random(in: 1...2))
        
        return BookingData(
            shipReference: "EXPIRED_SHIP_REF_\(String(format: "%04d", index))",
            shipToken: "EXPIRED_TOKEN_\(String(format: "%08d", index))_\(Int.random(in: 1000...9999))",
            canIssueTicketChecking: false,
            expiryTime: String(expiryTimestamp),
            duration: Int.random(in: 120...360), // 2-6小时
            segments: segments
        )
    }
    
    /// 生成混合测试数据（包含有效和过期数据）
    /// - Parameters:
    ///   - validCount: 有效数据数量
    ///   - expiredCount: 过期数据数量
    /// - Returns: 混合的BookingData数组
    static func generateMixedTestData(validCount: Int = 3, expiredCount: Int = 2) -> [BookingData] {
        let validData = generateValidTestData(count: validCount)
        let expiredData = generateExpiredTestData(count: expiredCount)
        return validData + expiredData
    }
    
    /// 生成即将过期的测试数据（1小时内过期）
    /// - Parameter count: 生成的数据数量
    /// - Returns: 即将过期的BookingData数组
    static func generateSoonToExpireTestData(count: Int = 2) -> [BookingData] {
        var testData: [BookingData] = []
        
        for i in 1...count {
            let bookingData = createSoonToExpireBookingData(index: i)
            testData.append(bookingData)
        }
        
        return testData
    }
    
    /// 创建单个即将过期的预订数据
    /// - Parameter index: 数据索引
    /// - Returns: 即将过期的BookingData
    private static func createSoonToExpireBookingData(index: Int) -> BookingData {
        // 创建30分钟后过期的数据
        let soonTime = Date().addingTimeInterval(30 * 60) // 30分钟后
        let expiryTimestamp = soonTime.timeIntervalSince1970
        
        // 创建航段数据
        let segments = createTestSegments(count: 1)
        
        return BookingData(
            shipReference: "SOON_EXPIRE_SHIP_REF_\(String(format: "%04d", index))",
            shipToken: "SOON_EXPIRE_TOKEN_\(String(format: "%08d", index))_\(Int.random(in: 1000...9999))",
            canIssueTicketChecking: true,
            expiryTime: String(expiryTimestamp),
            duration: Int.random(in: 90...180), // 1.5-3小时
            segments: segments
        )
    }
    
    /// 保存测试数据到JSON文件
    /// - Parameters:
    ///   - data: 要保存的数据
    ///   - filename: 文件名
    /// - Throws: 编码错误
    static func saveTestDataToFile(_ data: [BookingData], filename: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(data)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        try jsonData.write(to: fileURL)
        print("✅ 测试数据已保存到: \(fileURL.path)")
    }
    
    /// 从JSON文件加载测试数据
    /// - Parameter filename: 文件名
    /// - Returns: BookingData数组
    /// - Throws: 解码错误
    static func loadTestDataFromFile(_ filename: String) throws -> [BookingData] {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        let jsonData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([BookingData].self, from: jsonData)
    }
    
    /// 打印测试数据统计信息
    /// - Parameter data: 测试数据
    static func printTestDataStatistics(_ data: [BookingData]) {
        print("\n📊 测试数据统计:")
        print("总数量: \(data.count)")
        
        let validCount = data.filter { !$0.isExpired }.count
        let expiredCount = data.filter { $0.isExpired }.count
        
        print("有效数据: \(validCount)")
        print("过期数据: \(expiredCount)")
        
        if !data.isEmpty {
            let avgDuration = data.map { $0.duration }.reduce(0, +) / data.count
            print("平均持续时间: \(avgDuration)分钟")
            
            let totalSegments = data.map { $0.segments.count }.reduce(0, +)
            print("总航段数: \(totalSegments)")
        }
        
        print("\n📋 数据详情:")
        for (index, booking) in data.enumerated() {
            let status = booking.isExpired ? "❌ 已过期" : "✅ 有效"
            print("\(index + 1). \(booking.shipReference) - \(status)")
            print("   过期时间: \(booking.formattedExpiryTime)")
            print("   持续时间: \(booking.formattedDuration)")
            print("   航段数: \(booking.segments.count)")
        }
    }
}

// MARK: - 测试数据扩展
extension TestDataGenerator {
    
    /// 生成特定场景的测试数据
    enum TestScenario {
        case normal          // 正常场景
        case highVolume      // 高并发场景
        case edgeCase        // 边界情况
        case performance     // 性能测试
    }
    
    /// 根据场景生成测试数据
    /// - Parameter scenario: 测试场景
    /// - Returns: 测试数据
    static func generateDataForScenario(_ scenario: TestScenario) -> [BookingData] {
        switch scenario {
        case .normal:
            return generateMixedTestData(validCount: 5, expiredCount: 2)
            
        case .highVolume:
            return generateValidTestData(count: 50)
            
        case .edgeCase:
            var data: [BookingData] = []
            data.append(contentsOf: generateValidTestData(count: 1))
            data.append(contentsOf: generateExpiredTestData(count: 1))
            data.append(contentsOf: generateSoonToExpireTestData(count: 1))
            return data
            
        case .performance:
            return generateValidTestData(count: 100)
        }
    }
}
