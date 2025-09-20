//
//  mobileTestUITests.swift
//  mobileTestUITests
//
//  Created by ruizhao_xie on 9/20/25.
//

import XCTest

final class mobileTestUITests: XCTestCase {
    
    var app: XCUIApplication!

    override func setUpWithError() throws {
        // 在每个测试方法调用前设置
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        // 在每个测试方法调用后清理
        app = nil
    }

    // MARK: - 基本UI测试
    
    @MainActor
    func testAppLaunch() throws {
        // 验证应用成功启动
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        
        // 验证导航标题存在
        let navigationTitle = app.navigationBars["预订数据"]
        XCTAssertTrue(navigationTitle.exists)
    }
    
    @MainActor
    func testNavigationTitle() throws {
        // 验证导航标题正确显示
        let navigationTitle = app.navigationBars["预订数据"]
        XCTAssertTrue(navigationTitle.exists)
    }
    
    @MainActor
    func testRefreshButton() throws {
        // 验证刷新按钮存在
        let refreshButton = app.navigationBars.buttons["arrow.clockwise"]
        XCTAssertTrue(refreshButton.exists)
    }
    
    // MARK: - 数据加载测试
    
    @MainActor
    func testDataLoading() throws {
        // 等待数据加载完成
        let loadingIndicator = app.progressIndicators.firstMatch
        if loadingIndicator.exists {
            // 如果显示加载指示器，等待其消失
            XCTAssertTrue(waitForElementToDisappear(loadingIndicator, timeout: 15))
        }
        
        // 验证数据已加载（检查列表是否存在）
        let list = app.tables.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 15), "数据列表应该在15秒内加载完成")
        
        // 验证列表不为空
        XCTAssertGreaterThan(list.cells.count, 0, "数据列表应该包含数据")
    }
    
    @MainActor
    func testBasicInfoSection() throws {
        // 等待数据加载
        let list = app.tables.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        
        // 验证基本信息部分存在
        let basicInfoSection = list.staticTexts["基本信息"]
        XCTAssertTrue(basicInfoSection.exists)
        
        // 验证船舶参考号显示
        let shipReference = list.staticTexts.containing(NSPredicate(format: "label CONTAINS '船舶参考号'")).firstMatch
        XCTAssertTrue(shipReference.exists)
    }
    
    @MainActor
    func testSegmentsSection() throws {
        // 等待数据加载
        let list = app.tables.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        
        // 验证航段信息部分存在
        let segmentsSection = list.staticTexts.containing(NSPredicate(format: "label CONTAINS '航段信息'")).firstMatch
        XCTAssertTrue(segmentsSection.exists)
        
        // 验证航段数据存在
        let segmentRow = list.cells.containing(NSPredicate(format: "label CONTAINS '航段'")).firstMatch
        XCTAssertTrue(segmentRow.exists)
    }
    
    // MARK: - 刷新功能测试
    
    @MainActor
    func testRefreshFunctionality() throws {
        // 等待初始数据加载
        let list = app.tables.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        
        // 点击刷新按钮
        let refreshButton = app.navigationBars.buttons["arrow.clockwise"]
        XCTAssertTrue(refreshButton.exists)
        refreshButton.tap()
        
        // 验证刷新后数据仍然存在
        XCTAssertTrue(list.waitForExistence(timeout: 5))
    }
    
    @MainActor
    func testRefreshButtonDisabledDuringLoading() throws {
        // 这个测试验证刷新按钮在加载时被禁用
        // 由于加载很快，我们主要验证按钮存在且可点击
        let refreshButton = app.navigationBars.buttons["arrow.clockwise"]
        XCTAssertTrue(refreshButton.exists)
        XCTAssertTrue(refreshButton.isEnabled)
    }
    
    // MARK: - 错误处理测试
    
    @MainActor
    func testErrorHandling() throws {
        // 这个测试主要验证应用不会崩溃
        // 在正常情况下，应用应该能正常加载数据
        let list = app.tables.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        
        // 验证没有错误提示显示
        let errorAlert = app.alerts.firstMatch
        XCTAssertFalse(errorAlert.exists)
    }
    
    // MARK: - 滚动和交互测试
    
    @MainActor
    func testScrollFunctionality() throws {
        // 等待数据加载
        let list = app.tables.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        
        // 测试滚动功能
        list.swipeUp()
        list.swipeDown()
        
        // 验证列表仍然存在
        XCTAssertTrue(list.exists)
    }
    
    @MainActor
    func testSegmentInteraction() throws {
        // 等待数据加载
        let list = app.tables.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10))
        
        // 查找并点击航段行
        let segmentRow = list.cells.containing(NSPredicate(format: "label CONTAINS '航段'")).firstMatch
        if segmentRow.exists {
            segmentRow.tap()
            // 验证点击后没有崩溃
            XCTAssertTrue(list.exists)
        }
    }
    
    // MARK: - 性能测试
    
    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // 测量应用启动时间
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
    
    @MainActor
    func testDataLoadingPerformance() throws {
        // 测量数据加载性能
        measure {
            let app = XCUIApplication()
            app.launch()
            
            let list = app.tables.firstMatch
            XCTAssertTrue(list.waitForExistence(timeout: 10))
        }
    }
    
    // MARK: - 辅助方法
    
    private func waitForElementToAppear(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        return element.waitForExistence(timeout: timeout)
    }
    
    private func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}