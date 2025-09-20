//
//  LocalizationTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

class LocalizationTests: XCTestCase {
    
    var localizationManager: LocalizationManager!
    var languageSwitcher: LanguageSwitcher!
    
    override func setUp() {
        super.setUp()
        localizationManager = LocalizationManager(initialLanguage: .english, enableVerboseLogging: false)
        languageSwitcher = LanguageSwitcher.shared
    }
    
    override func tearDown() {
        localizationManager = nil
        languageSwitcher = nil
        super.tearDown()
    }
    
    // MARK: - 本地化管理器测试
    
    func testLocalizationManagerInitialization() {
        // 测试初始化
        XCTAssertNotNil(localizationManager)
        XCTAssertEqual(localizationManager.currentLanguage, .english)
    }
    
    func testLocalizedStringRetrieval() {
        // 测试获取本地化字符串
        let loadingText = localizationManager.localizedString(for: .loading)
        XCTAssertFalse(loadingText.isEmpty)
        XCTAssertEqual(loadingText, "Loading...")
        
        let errorText = localizationManager.localizedString(for: .error)
        XCTAssertFalse(errorText.isEmpty)
        XCTAssertEqual(errorText, "Error")
    }
    
    func testLocalizedStringWithArguments() {
        // 测试带参数的本地化字符串
        let fileNotFoundText = localizationManager.localizedString(for: .errorFileNotFound, arguments: "test.txt")
        XCTAssertFalse(fileNotFoundText.isEmpty)
        XCTAssertTrue(fileNotFoundText.contains("test.txt"))
    }
    
    func testLocalizedStringWithDefaultValue() {
        // 测试带默认值的本地化字符串
        let unknownKey = LocalizationKey(rawValue: "unknown.key") ?? .errorGeneric
        let defaultText = localizationManager.localizedString(for: unknownKey, defaultValue: "Default Text")
        XCTAssertEqual(defaultText, "Default Text")
    }
    
    func testLanguageSwitching() {
        // 测试语言切换
        let initialLanguage = localizationManager.currentLanguage
        XCTAssertEqual(initialLanguage, .english)
        
        // 切换到中文
        localizationManager.setLanguage(.chineseSimplified)
        XCTAssertEqual(localizationManager.currentLanguage, .chineseSimplified)
        
        // 验证中文文本
        let loadingTextChinese = localizationManager.localizedString(for: .loading)
        XCTAssertFalse(loadingTextChinese.isEmpty)
        XCTAssertNotEqual(loadingTextChinese, "Loading...")
        
        // 切换回英文
        localizationManager.setLanguage(.english)
        XCTAssertEqual(localizationManager.currentLanguage, .english)
    }
    
    func testSupportedLanguages() {
        // 测试支持的语言列表
        let supportedLanguages = localizationManager.getAvailableLanguages()
        XCTAssertFalse(supportedLanguages.isEmpty)
        XCTAssertTrue(supportedLanguages.contains(.english))
        XCTAssertTrue(supportedLanguages.contains(.chineseSimplified))
        XCTAssertTrue(supportedLanguages.contains(.chineseTraditional))
        XCTAssertTrue(supportedLanguages.contains(.japanese))
        XCTAssertTrue(supportedLanguages.contains(.korean))
    }
    
    func testLanguageSupportCheck() {
        // 测试语言支持检查
        XCTAssertTrue(localizationManager.isLanguageSupported("en"))
        XCTAssertTrue(localizationManager.isLanguageSupported("zh-Hans"))
        XCTAssertTrue(localizationManager.isLanguageSupported("ja"))
        XCTAssertFalse(localizationManager.isLanguageSupported("invalid"))
    }
    
    func testSystemLanguageDetection() {
        // 测试系统语言检测
        let systemLanguage = localizationManager.getSystemLanguage()
        XCTAssertNotNil(systemLanguage)
        XCTAssertTrue(localizationManager.getAvailableLanguages().contains(systemLanguage))
    }
    
    // MARK: - 语言切换器测试
    
    func testLanguageSwitcherInitialization() {
        // 测试语言切换器初始化
        XCTAssertNotNil(languageSwitcher)
        XCTAssertNotNil(languageSwitcher.currentLanguage)
    }
    
    func testLanguageSwitchingWithSwitcher() {
        // 测试使用语言切换器切换语言
        let initialLanguage = languageSwitcher.currentLanguage
        
        // 切换到中文
        languageSwitcher.switchLanguage(to: .chineseSimplified)
        XCTAssertEqual(languageSwitcher.currentLanguage, .chineseSimplified)
        
        // 验证显示名称
        XCTAssertEqual(languageSwitcher.currentLanguageDisplayName, "简体中文")
        
        // 切换回初始语言
        languageSwitcher.switchLanguage(to: initialLanguage)
        XCTAssertEqual(languageSwitcher.currentLanguage, initialLanguage)
    }
    
    func testLanguageMenuItems() {
        // 测试语言菜单项创建
        let menuItems = languageSwitcher.createLanguageMenuItems()
        XCTAssertFalse(menuItems.isEmpty)
        
        // 验证当前选中的语言
        let selectedItems = menuItems.filter { $0.isSelected }
        XCTAssertEqual(selectedItems.count, 1)
        XCTAssertEqual(selectedItems.first?.language, languageSwitcher.currentLanguage)
    }
    
    func testLanguageDisplayNames() {
        // 测试语言显示名称
        XCTAssertEqual(languageSwitcher.getLanguageDisplayName(for: .english), "English")
        XCTAssertEqual(languageSwitcher.getLanguageDisplayName(for: .chineseSimplified), "简体中文")
        XCTAssertEqual(languageSwitcher.getLanguageDisplayName(for: .chineseTraditional), "繁體中文")
        XCTAssertEqual(languageSwitcher.getLanguageDisplayName(for: .japanese), "日本語")
        XCTAssertEqual(languageSwitcher.getLanguageDisplayName(for: .korean), "한국어")
    }
    
    func testLanguageSwitcherLocalizedString() {
        // 测试语言切换器的本地化字符串获取
        let errorText = languageSwitcher.localizedString(for: .error)
        XCTAssertFalse(errorText.isEmpty)
        
        let fileNotFoundText = languageSwitcher.localizedString(for: .errorFileNotFound, arguments: "test.txt")
        XCTAssertFalse(fileNotFoundText.isEmpty)
        XCTAssertTrue(fileNotFoundText.contains("test.txt"))
    }
    
    // MARK: - 错误消息国际化测试
    
    func testBookingDataErrorLocalization() {
        // 测试BookingDataError的本地化
        let fileNotFoundError = BookingDataError.fileNotFound("test.txt")
        let errorDescription = fileNotFoundError.errorDescription
        XCTAssertNotNil(errorDescription)
        XCTAssertFalse(errorDescription!.isEmpty)
        XCTAssertTrue(errorDescription!.contains("test.txt"))
    }
    
    func testErrorHandlerLocalization() {
        // 测试ErrorHandler的本地化
        let testError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let bookingError = ErrorHandler.handleNetworkError(testError, url: "https://example.com")
        
        XCTAssertNotNil(bookingError.errorDescription)
        XCTAssertFalse(bookingError.errorDescription!.isEmpty)
    }
    
    func testErrorLocalizationWithDifferentLanguages() {
        // 测试不同语言下的错误消息
        let testError = BookingDataError.fileNotFound("test.txt")
        
        // 英文
        localizationManager.setLanguage(.english)
        let englishError = testError.errorDescription
        XCTAssertNotNil(englishError)
        
        // 中文
        localizationManager.setLanguage(.chineseSimplified)
        let chineseError = testError.errorDescription
        XCTAssertNotNil(chineseError)
        
        // 验证不同语言的消息不同
        XCTAssertNotEqual(englishError, chineseError)
    }
    
    // MARK: - 性能测试
    
    func testLocalizationPerformance() {
        // 测试本地化性能
        measure {
            for _ in 0..<1000 {
                _ = localizationManager.localizedString(for: .errorFileNotFound, arguments: "test.txt")
            }
        }
    }
    
    func testLanguageSwitchingPerformance() {
        // 测试语言切换性能
        let languages: [SupportedLanguage] = [.english, .chineseSimplified, .japanese, .korean]
        
        measure {
            for language in languages {
                localizationManager.setLanguage(language)
                _ = localizationManager.localizedString(for: .error)
            }
        }
    }
    
    // MARK: - 边界情况测试
    
    func testEmptyArguments() {
        // 测试空参数
        let errorText = localizationManager.localizedString(for: .error)
        XCTAssertFalse(errorText.isEmpty)
    }
    
    func testInvalidLanguageCode() {
        // 测试无效语言代码
        XCTAssertFalse(localizationManager.isLanguageSupported(""))
        XCTAssertFalse(localizationManager.isLanguageSupported("invalid"))
        XCTAssertFalse(localizationManager.isLanguageSupported("123"))
    }
    
    func testLanguageSwitchingToSameLanguage() {
        // 测试切换到相同语言
        let initialLanguage = languageSwitcher.currentLanguage
        languageSwitcher.switchLanguage(to: initialLanguage)
        XCTAssertEqual(languageSwitcher.currentLanguage, initialLanguage)
    }
    
    // MARK: - 通知测试
    
    func testLanguageChangeNotification() {
        // 测试语言切换通知
        let expectation = XCTestExpectation(description: "Language change notification")
        
        let observer = NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { notification in
            if let newLanguage = notification.userInfo?["newLanguage"] as? SupportedLanguage {
                XCTAssertEqual(newLanguage, .chineseSimplified)
                expectation.fulfill()
            }
        }
        
        // 切换语言
        languageSwitcher.switchLanguage(to: .chineseSimplified)
        
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}

// MARK: - 模拟测试
class MockLocalizationManager: LocalizationManagerProtocol {
    var currentLanguage: SupportedLanguage = .english
    var localizedStrings: [LocalizationKey: String] = [:]
    
    func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
    }
    
    func localizedString(for key: LocalizationKey, arguments: CVarArg...) -> String {
        return localizedStrings[key] ?? key.rawValue
    }
    
    func localizedString(for key: LocalizationKey, defaultValue: String, arguments: CVarArg...) -> String {
        return localizedStrings[key] ?? defaultValue
    }
    
    func isLanguageSupported(_ language: String) -> Bool {
        return SupportedLanguage(rawValue: language) != nil
    }
    
    func getSystemLanguage() -> SupportedLanguage {
        return .english
    }
    
    func getAvailableLanguages() -> [SupportedLanguage] {
        return [.english, .chineseSimplified, .japanese]
    }
}

class LocalizationMockTests: XCTestCase {
    
    func testMockLocalizationManager() {
        let mockManager = MockLocalizationManager()
        
        // 设置模拟数据
        mockManager.localizedStrings[.error] = "Mock Error"
        mockManager.localizedStrings[.loading] = "Mock Loading"
        
        // 测试模拟功能
        XCTAssertEqual(mockManager.localizedString(for: .error), "Mock Error")
        XCTAssertEqual(mockManager.localizedString(for: .loading), "Mock Loading")
        XCTAssertEqual(mockManager.localizedString(for: .success), "common.success") // 默认值
        
        // 测试语言切换
        mockManager.setLanguage(.chineseSimplified)
        XCTAssertEqual(mockManager.currentLanguage, .chineseSimplified)
        
        // 测试语言支持
        XCTAssertTrue(mockManager.isLanguageSupported("en"))
        XCTAssertFalse(mockManager.isLanguageSupported("invalid"))
    }
}
