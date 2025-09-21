//
//  TestDataManager.swift
//  mobileTest
//
//  Created by AI Assistant on 2024-12-21.
//

import Foundation

/// 测试数据管理器
@MainActor
class TestDataManager: ObservableObject {
    
    @Published var testData: [BookingData] = []
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    
    private let bookingDataManager: BookingDataManager
    
    init(bookingDataManager: BookingDataManager) {
        self.bookingDataManager = bookingDataManager
    }
    
    /// 生成并加载测试数据
    /// - Parameter scenario: 测试场景
    func generateAndLoadTestData(scenario: TestDataGenerator.TestScenario = .normal) async {
        isLoading = true
        
        do {
            // 生成测试数据
            let generatedData = TestDataGenerator.generateDataForScenario(scenario)
            
            // 保存到文件
            let filename = "test_data_\(scenario).json"
            try TestDataGenerator.saveTestDataToFile(generatedData, filename: filename)
            
            // 更新本地数据
            testData = generatedData
            lastUpdateTime = Date()
            
            // 打印统计信息
            TestDataGenerator.printTestDataStatistics(generatedData)
            
            print("✅ 测试数据生成完成: \(scenario)")
            
        } catch {
            print("❌ 生成测试数据失败: \(error)")
        }
        
        isLoading = false
    }
    
    /// 从文件加载测试数据
    /// - Parameter filename: 文件名
    func loadTestDataFromFile(_ filename: String) async {
        isLoading = true
        
        do {
            let loadedData = try TestDataGenerator.loadTestDataFromFile(filename)
            testData = loadedData
            lastUpdateTime = Date()
            
            TestDataGenerator.printTestDataStatistics(loadedData)
            print("✅ 从文件加载测试数据完成: \(filename)")
            
        } catch {
            print("❌ 从文件加载测试数据失败: \(error)")
        }
        
        isLoading = false
    }
    
    /// 清空测试数据
    func clearTestData() {
        testData.removeAll()
        lastUpdateTime = nil
        print("🗑️ 测试数据已清空")
    }
    
    /// 获取有效数据
    var validData: [BookingData] {
        return testData.filter { !$0.isExpired }
    }
    
    /// 获取过期数据
    var expiredData: [BookingData] {
        return testData.filter { $0.isExpired }
    }
    
    /// 获取即将过期的数据（1小时内）
    var soonToExpireData: [BookingData] {
        let oneHourFromNow = Date().addingTimeInterval(60 * 60)
        return testData.filter { booking in
            guard let expiryTimestamp = Double(booking.expiryTime) else { return false }
            let expiryDate = Date(timeIntervalSince1970: expiryTimestamp)
            return expiryDate > Date() && expiryDate < oneHourFromNow
        }
    }
    
    /// 测试缓存功能
    func testCacheFunctionality() async {
        print("\n🧪 开始测试缓存功能...")
        
        guard let firstValidData = validData.first else {
            print("❌ 没有有效数据可供测试")
            return
        }
        
        do {
            // 测试保存到缓存
            print("📝 测试保存数据到缓存...")
            bookingDataManager.setTestData(firstValidData)
            print("✅ 数据保存到缓存成功")
            
            // 测试从缓存读取
            print("📖 测试从缓存读取数据...")
            let cachedData = try await bookingDataManager.getBookingData()
            print("✅ 从缓存读取数据成功")
            print("   缓存数据: \(cachedData.shipReference)")
            print("   过期时间: \(cachedData.formattedExpiryTime)")
            print("   是否过期: \(cachedData.isExpired ? "是" : "否")")
            
            // 测试缓存统计
            print("📊 获取缓存统计信息...")
            let cacheStats = bookingDataManager.getCacheStatistics() as String
            print("缓存统计: \(cacheStats)")
            
        } catch {
            print("❌ 缓存测试失败: \(error)")
        }
    }
    
    /// 测试数据验证
    func testDataValidation() {
        print("\n🔍 开始测试数据验证...")
        
        for (index, booking) in testData.enumerated() {
            print("\n数据 \(index + 1):")
            print("  船票参考: \(booking.shipReference)")
            print("  船票令牌: \(booking.shipToken)")
            print("  是否过期: \(booking.isExpired ? "是" : "否")")
            print("  过期时间: \(booking.formattedExpiryTime)")
            print("  持续时间: \(booking.formattedDuration)")
            print("  航段数量: \(booking.segments.count)")
            print("  可出票: \(booking.canIssueTicketChecking ? "是" : "否")")
            
            // 验证航段数据
            for (segmentIndex, segment) in booking.segments.enumerated() {
                print("    航段 \(segmentIndex + 1): \(segment.originAndDestinationPair.origin.displayName) -> \(segment.originAndDestinationPair.destination.displayName)")
            }
        }
    }
    
    /// 运行完整测试套件
    func runFullTestSuite() async {
        print("\n🚀 开始运行完整测试套件...")
        
        // 生成测试数据
        await generateAndLoadTestData(scenario: .normal)
        
        // 测试数据验证
        testDataValidation()
        
        // 测试缓存功能
        await testCacheFunctionality()
        
        // 测试性能监控
        await testPerformanceMonitoring()
        
        print("\n✅ 完整测试套件运行完成")
    }
    
    /// 测试性能监控
    func testPerformanceMonitoring() async {
        print("\n📈 开始测试性能监控...")
        
        do {
            // 模拟一些操作来生成性能数据
            for _ in 0..<5 {
                _ = try await bookingDataManager.getBookingData()
            }
            
            // 获取性能指标
            let performanceMetrics = bookingDataManager.getPerformanceMetrics()
            print("性能指标:")
            print(performanceMetrics)
            
        } catch {
            print("❌ 性能监控测试失败: \(error)")
        }
    }
    
    /// 生成测试报告
    func generateTestReport() -> String {
        var report = "📋 测试数据报告\n"
        report += "生成时间: \(Date())\n"
        report += "总数据量: \(testData.count)\n"
        report += "有效数据: \(validData.count)\n"
        report += "过期数据: \(expiredData.count)\n"
        report += "即将过期: \(soonToExpireData.count)\n\n"
        
        report += "📊 数据分布:\n"
        let avgDuration = testData.isEmpty ? 0 : testData.map { $0.duration }.reduce(0, +) / testData.count
        report += "平均持续时间: \(avgDuration)分钟\n"
        
        let totalSegments = testData.map { $0.segments.count }.reduce(0, +)
        report += "总航段数: \(totalSegments)\n"
        
        let canIssueCount = testData.filter { $0.canIssueTicketChecking }.count
        report += "可出票数量: \(canIssueCount)\n\n"
        
        report += "📝 详细数据:\n"
        for (index, booking) in testData.enumerated() {
            let status = booking.isExpired ? "❌" : "✅"
            report += "\(index + 1). \(status) \(booking.shipReference) - \(booking.formattedExpiryTime)\n"
        }
        
        return report
    }
}
