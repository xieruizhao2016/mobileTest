//
//  ContentView.swift
//  mobileTest
//
//  Created by ruizhao_xie on 9/20/25.
//

import SwiftUI

struct ContentView: View {
    // MARK: - 属性
    @StateObject private var dataManager = BookingDataManager()
    @State private var bookingData: BookingData?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // MARK: - 视图主体
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 头部信息
                headerView
                
                // 主要内容区域
                if isLoading {
                    loadingView
                } else if let data = bookingData {
                    dataListView(data: data)
                } else if let error = errorMessage {
                    errorView(error: error)
                } else {
                    emptyView
                }
                
                Spacer()
            }
            .navigationTitle("预订数据")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .onAppear {
                loadData()
            }
            .alert("错误", isPresented: $showingError) {
                Button("确定") { }
            } message: {
                Text(errorMessage ?? "未知错误")
            }
        }
    }
    
    // MARK: - 子视图
    
    /// 头部信息视图
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "ship.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("船舶预订系统")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal)
            
            if let data = bookingData {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("参考号: \(data.shipReference)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("状态: \(data.isExpired ? "已过期" : "有效")")
                            .font(.caption)
                            .foregroundColor(data.isExpired ? .red : .green)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("持续时间: \(data.formattedDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("航段: \(data.segments.count)个")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    /// 加载视图
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("正在加载数据...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 数据列表视图
    private func dataListView(data: BookingData) -> some View {
        List {
            // 基本信息部分
            Section("基本信息") {
                InfoRow(title: "船舶参考号", value: data.shipReference)
                InfoRow(title: "船舶令牌", value: data.shipToken)
                InfoRow(title: "可出票检查", value: data.canIssueTicketChecking ? "是" : "否")
                InfoRow(title: "过期时间", value: data.formattedExpiryTime)
                InfoRow(title: "持续时间", value: data.formattedDuration)
            }
            
            // 航段信息部分
            Section("航段信息 (\(data.segments.count)个)") {
                ForEach(data.segments) { segment in
                    SegmentRow(segment: segment)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    /// 错误视图
    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("加载失败")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重试") {
                loadData()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 空视图
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("暂无数据")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("点击刷新按钮获取数据")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// 刷新按钮
    private var refreshButton: some View {
        Button(action: {
            loadData(forceRefresh: true)
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.title3)
        }
        .disabled(isLoading)
    }
    
    // MARK: - 方法
    
    /// 加载数据
    /// - Parameter forceRefresh: 是否强制刷新
    private func loadData(forceRefresh: Bool = false) {
        print("🔄 [ContentView] 开始加载数据，强制刷新: \(forceRefresh)")
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let data: BookingData
                
                if forceRefresh {
                    data = try await dataManager.refreshBookingData()
                } else {
                    data = try await dataManager.getBookingData()
                }
                
                await MainActor.run {
                    self.bookingData = data
                    self.isLoading = false
                    
                    // 打印数据到控制台（需求要求）
                    printDataToConsole(data)
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    self.showingError = true
                    
                    print("❌ [ContentView] 加载数据失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 打印数据到控制台
    /// - Parameter data: 预订数据
    private func printDataToConsole(_ data: BookingData) {
        print("📋 [ContentView] ========== 预订数据详情 ==========")
        print("🚢 船舶参考号: \(data.shipReference)")
        print("🎫 船舶令牌: \(data.shipToken)")
        print("✅ 可出票检查: \(data.canIssueTicketChecking)")
        print("⏰ 过期时间: \(data.formattedExpiryTime)")
        print("⏱️ 持续时间: \(data.formattedDuration)")
        print("📊 航段数量: \(data.segments.count)")
        print("🔍 数据状态: \(data.isExpired ? "已过期" : "有效")")
        
        print("\n📋 航段详情:")
        for (index, segment) in data.segments.enumerated() {
            print("   \(index + 1). 航段ID: \(segment.id)")
            print("      起点: \(segment.originAndDestinationPair.origin.displayName) (\(segment.originAndDestinationPair.origin.code))")
            print("      终点: \(segment.originAndDestinationPair.destination.displayName) (\(segment.originAndDestinationPair.destination.code))")
            print("      路线: \(segment.originAndDestinationPair.routeDescription)")
        }
        
        print("📋 [ContentView] ================================")
    }
}

// MARK: - 辅助视图

/// 信息行视图
struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

/// 航段行视图
struct SegmentRow: View {
    let segment: Segment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("航段 \(segment.id)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "airplane")
                    .foregroundColor(.blue)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("起点")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(segment.originAndDestinationPair.origin.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("(\(segment.originAndDestinationPair.origin.code))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("终点")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(segment.originAndDestinationPair.destination.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("(\(segment.originAndDestinationPair.destination.code))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
}
