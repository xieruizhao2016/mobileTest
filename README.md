# mobileTest - iOS预订数据管理应用

## 📋 项目需求分析

### 核心功能需求

#### 1. 数据管理器实现
- **目标**：创建数据管理器作为预订数据的提供者，参考 `booking.json` 文件
- **要求**：
  - 包含服务层 (Service Layer)
  - 包含本地持久化缓存层 (Local Persistent Caching Layer)
  - 处理数据时效性 (Data Timeliness)
  - 支持刷新机制和统一外部接口
  - 实现错误处理机制

#### 2. 列表显示页面
- **目标**：创建列表格式的数据展示页面
- **关键要求**：每次页面出现时都要调用数据提供者接口
- **输出**：将获取的数据打印到控制台

#### 3. 技术约束
- 服务层可使用JSON文件模拟API响应
- 使用Git进行版本控制，仓库名称为"mobileTest"
- 代码中不包含"Accenture"字样

## 🏗️ 架构设计

### 分层架构
```
┌─────────────────────────────────────┐
│           UI Layer                  │
│        (ContentView)                │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│        Data Manager                 │
│    (BookingDataManager)             │
│   - 统一数据接口                    │
│   - 数据时效性检查                  │
│   - 刷新机制                        │
└─────────────────┬───────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
┌───────▼────────┐ ┌────────▼────────┐
│ Service Layer  │ │  Cache Layer    │
│(BookingService)│ │ (BookingCache)  │
│- 数据获取      │ │- 本地存储       │
│- JSON解析      │ │- 持久化         │
└────────────────┘ └─────────────────┘
        │                   │
        └─────────┬─────────┘
                  │
        ┌─────────▼─────────┐
        │   Data Source     │
        │  (booking.json)   │
        └───────────────────┘
```

### 数据模型设计
基于 `booking.json` 结构：
- `BookingData` - 主预订数据模型
- `Segment` - 航段数据模型
- `OriginDestinationPair` - 起终点对模型
- `Location` - 地点信息模型

## 📝 实现计划

### 阶段1：基础架构搭建 ✅
- [x] 创建README.md文档
- [x] 创建数据模型 (Models)
- [x] 实现服务层 (Service Layer)
- [x] 实现缓存层 (Cache Layer)

### 阶段2：核心功能实现 ✅
- [x] 实现数据管理器 (Data Manager)
- [x] 更新UI层显示列表
- [x] 添加数据获取和刷新逻辑

### 阶段3：完善和测试 ✅
- [x] 添加错误处理机制
- [x] 实现日志输出功能
- [x] 测试完整功能
- [x] 代码提交和版本控制

## 🔧 技术栈

- **开发语言**：Swift
- **UI框架**：SwiftUI
- **架构模式**：MVVM + 分层架构
- **数据存储**：UserDefaults (本地缓存)
- **版本控制**：Git + GitHub

## 📊 数据源结构

```json
{
    "shipReference": "ABCDEF",
    "shipToken": "AAAABBBCCCCDDD", 
    "canIssueTicketChecking": false,
    "expiryTime": "1722409261",
    "duration": 2430,
    "segments": [
        {
            "id": 1,
            "originAndDestinationPair": {
                "destination": {
                    "code": "BBB",
                    "displayName": "BBB DisplayName",
                    "url": "www.ship.com"
                },
                "destinationCity": "AAA",
                "origin": {
                    "code": "AAA", 
                    "displayName": "AAA DisplayName",
                    "url": "www.ship.com"
                },
                "originCity": "BBB"
            }
        }
    ]
}
```

## 🚀 运行说明

1. 使用Xcode打开 `mobileTest.xcodeproj`
2. 选择目标设备或模拟器
3. 运行项目 (⌘+R)
4. 查看控制台输出获取数据信息

## 📝 开发日志

### 2024-12-19
- 项目初始化
- 需求分析和架构设计
- 创建README.md文档
- 实现完整的数据管理架构
- 创建数据模型 (BookingModels.swift)
- 实现服务层 (BookingService.swift)
- 实现缓存层 (BookingCache.swift)
- 实现数据管理器 (BookingDataManager.swift)
- 更新UI层显示列表 (ContentView.swift)
- 添加错误处理和日志输出
- 项目构建测试成功
- 代码提交到GitHub

## 🎯 功能特性

### ✅ 已实现功能
- **数据模型**：完整的预订数据结构定义
- **服务层**：JSON文件数据获取和解析
- **缓存层**：本地持久化存储，5分钟有效期
- **数据管理器**：统一数据接口，支持缓存和刷新
- **UI界面**：美观的列表显示，实时数据更新
- **错误处理**：完善的错误捕获和用户友好提示
- **日志输出**：详细的控制台日志，满足需求要求
- **数据时效性**：自动检查数据过期状态

### 🔄 数据流程
1. **页面出现** → 调用数据管理器
2. **检查缓存** → 有效则使用缓存数据
3. **缓存无效** → 从服务层获取新数据
4. **数据解析** → 验证数据有效性
5. **更新缓存** → 保存到本地存储
6. **UI更新** → 显示数据并打印到控制台

---

*最后更新：2024-12-19*
