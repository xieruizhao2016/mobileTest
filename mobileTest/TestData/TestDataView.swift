//
//  TestDataView.swift
//  mobileTest
//
//  Created by AI Assistant on 2024-12-21.
//

import SwiftUI

struct TestDataView: View {
    @StateObject private var testDataManager: TestDataManager
    @State private var selectedScenario: TestDataGenerator.TestScenario = .normal
    @State private var showingTestReport = false
    
    init(bookingDataManager: BookingDataManager) {
        self._testDataManager = StateObject(wrappedValue: TestDataManager(bookingDataManager: bookingDataManager))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // 标题
                Text("测试数据管理")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                
                // 场景选择
                VStack(alignment: .leading, spacing: 6) {
                    Text("选择测试场景:")
                        .font(.subheadline)
                    
                    Picker("测试场景", selection: $selectedScenario) {
                        Text("正常场景").tag(TestDataGenerator.TestScenario.normal)
                        Text("高并发场景").tag(TestDataGenerator.TestScenario.highVolume)
                        Text("边界情况").tag(TestDataGenerator.TestScenario.edgeCase)
                        Text("性能测试").tag(TestDataGenerator.TestScenario.performance)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                
                // 操作按钮 - 压缩成两排
                VStack(spacing: 8) {
                    // 第一排：生成测试数据
                    Button(action: {
                        Task {
                            await testDataManager.generateAndLoadTestData(scenario: selectedScenario)
                        }
                    }) {
                        HStack {
                            if testDataManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                            }
                            Text("生成测试数据")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(testDataManager.isLoading)
                    
                    // 第二排：其他按钮
                    HStack(spacing: 8) {
                        Button(action: {
                            Task {
                                await testDataManager.testCacheFunctionality()
                            }
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "externaldrive.fill")
                                    .font(.caption)
                                Text("测试缓存")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        
                        Button(action: {
                            Task {
                                await testDataManager.runFullTestSuite()
                            }
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "play.circle.fill")
                                    .font(.caption)
                                Text("完整测试")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        
                        Button(action: {
                            testDataManager.testDataValidation()
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                Text("数据验证")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        
                        Button(action: {
                            showingTestReport = true
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "doc.text.fill")
                                    .font(.caption)
                                Text("测试报告")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                        
                        Button(action: {
                            testDataManager.clearTestData()
                        }) {
                            VStack(spacing: 2) {
                                Image(systemName: "trash.fill")
                                    .font(.caption)
                                Text("清空数据")
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 数据统计
                if !testDataManager.testData.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("数据统计")
                            .font(.subheadline)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 6) {
                            StatCard(
                                title: "总数据",
                                value: "\(testDataManager.testData.count)",
                                color: .blue
                            )
                            
                            StatCard(
                                title: "有效数据",
                                value: "\(testDataManager.validData.count)",
                                color: .green
                            )
                            
                            StatCard(
                                title: "过期数据",
                                value: "\(testDataManager.expiredData.count)",
                                color: .red
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                
                // 数据列表
                if !testDataManager.testData.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("数据列表")
                            .font(.subheadline)
                            .padding(.horizontal)
                        
                        List(testDataManager.testData.indices, id: \.self) { index in
                            let booking = testDataManager.testData[index]
                            BookingDataRow(booking: booking, index: index)
                        }
                        .frame(maxHeight: 400)
                    }
                }
                
                Spacer()
                
                // 最后更新时间
                if let lastUpdate = testDataManager.lastUpdateTime {
                    Text("最后更新: \(lastUpdate, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingTestReport) {
            TestReportView(report: testDataManager.generateTestReport())
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

// MARK: - 统计卡片
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 预订数据行
struct BookingDataRow: View {
    let booking: BookingData
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(index + 1). \(booking.shipReference)")
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: booking.isExpired ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(booking.isExpired ? .red : .green)
            }
            
            Text("令牌: \(booking.shipToken)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text("过期: \(booking.formattedExpiryTime)")
                    .font(.caption)
                
                Spacer()
                
                Text("持续: \(booking.formattedDuration)")
                    .font(.caption)
            }
            
            HStack {
                Text("航段: \(booking.segments.count)")
                    .font(.caption)
                
                Spacer()
                
                Text("出票: \(booking.canIssueTicketChecking ? "是" : "否")")
                    .font(.caption)
                    .foregroundColor(booking.canIssueTicketChecking ? .green : .red)
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - 测试报告视图
struct TestReportView: View {
    let report: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(report)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("测试报告")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    TestDataView(bookingDataManager: BookingDataManager())
}
