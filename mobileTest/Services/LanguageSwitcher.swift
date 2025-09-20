//
//  LanguageSwitcher.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

// MARK: - 语言切换管理器
class LanguageSwitcher {
    
    static let shared = LanguageSwitcher()
    
    private let localizationManager: LocalizationManagerProtocol
    private let userDefaults = UserDefaults.standard
    private let languageKey = "selectedLanguage"
    
    private init() {
        // 从用户偏好设置中获取保存的语言，如果没有则使用系统语言
        let savedLanguage = userDefaults.string(forKey: languageKey)
        let initialLanguage: SupportedLanguage
        
        if let savedLanguage = savedLanguage,
           let language = SupportedLanguage(rawValue: savedLanguage) {
            initialLanguage = language
        } else {
            initialLanguage = LocalizationManager().getSystemLanguage()
        }
        
        self.localizationManager = LocalizationManager(initialLanguage: initialLanguage)
    }
    
    /// 获取当前语言
    var currentLanguage: SupportedLanguage {
        return localizationManager.currentLanguage
    }
    
    /// 获取当前语言的显示名称
    var currentLanguageDisplayName: String {
        return currentLanguage.displayName
    }
    
    /// 切换语言
    /// - Parameter language: 要切换到的语言
    func switchLanguage(to language: SupportedLanguage) {
        guard language != currentLanguage else { return }
        
        // 更新本地化管理器
        localizationManager.setLanguage(language)
        
        // 保存到用户偏好设置
        userDefaults.set(language.rawValue, forKey: languageKey)
        userDefaults.synchronize()
        
        // 发送语言切换通知
        NotificationCenter.default.post(
            name: .languageDidChange,
            object: nil,
            userInfo: ["newLanguage": language]
        )
        
        print("🌐 [LanguageSwitcher] 语言已切换到: \(language.displayName) (\(language.rawValue))")
    }
    
    /// 获取支持的语言列表
    var supportedLanguages: [SupportedLanguage] {
        return localizationManager.getAvailableLanguages()
    }
    
    /// 获取语言的显示名称
    /// - Parameter language: 语言代码
    /// - Returns: 显示名称
    func getLanguageDisplayName(for language: SupportedLanguage) -> String {
        return language.displayName
    }
    
    /// 检查是否支持指定语言
    /// - Parameter languageCode: 语言代码
    /// - Returns: 是否支持
    func isLanguageSupported(_ languageCode: String) -> Bool {
        return localizationManager.isLanguageSupported(languageCode)
    }
    
    /// 重置为系统语言
    func resetToSystemLanguage() {
        let systemLanguage = localizationManager.getSystemLanguage()
        switchLanguage(to: systemLanguage)
    }
    
    /// 获取本地化字符串
    /// - Parameters:
    ///   - key: 本地化键
    ///   - arguments: 格式化参数
    /// - Returns: 本地化字符串
    func localizedString(for key: LocalizationKey, arguments: CVarArg...) -> String {
        return localizationManager.localizedString(for: key, arguments: arguments)
    }
    
    /// 获取本地化字符串（带默认值）
    /// - Parameters:
    ///   - key: 本地化键
    ///   - defaultValue: 默认值
    ///   - arguments: 格式化参数
    /// - Returns: 本地化字符串
    func localizedString(for key: LocalizationKey, defaultValue: String, arguments: CVarArg...) -> String {
        return localizationManager.localizedString(for: key, defaultValue: defaultValue, arguments: arguments)
    }
}

// MARK: - 语言切换通知
// 注意：languageDidChange 通知已在 LocalizationManager.swift 中定义

// MARK: - 语言切换示例用法
extension LanguageSwitcher {
    
    /// 演示语言切换功能
    func demonstrateLanguageSwitching() {
        print("🌐 [LanguageSwitcher] 开始演示语言切换功能")
        print("当前语言: \(currentLanguageDisplayName)")
        
        // 获取支持的语言列表
        let supportedLanguages = self.supportedLanguages
        print("支持的语言:")
        for language in supportedLanguages {
            print("  - \(language.displayName) (\(language.rawValue))")
        }
        
        // 演示切换到不同语言
        let testKey = LocalizationKey.errorFileNotFound
        print("\n测试本地化字符串:")
        
        for language in supportedLanguages.prefix(3) { // 只测试前3种语言
            switchLanguage(to: language)
            let localizedString = localizedString(for: testKey, arguments: "test.txt")
            print("  \(language.displayName): \(localizedString)")
        }
        
        // 重置为系统语言
        resetToSystemLanguage()
        print("\n已重置为系统语言: \(currentLanguageDisplayName)")
    }
    
    /// 创建语言选择菜单数据
    /// - Returns: 语言选择菜单项数组
    func createLanguageMenuItems() -> [LanguageMenuItem] {
        return supportedLanguages.map { language in
            LanguageMenuItem(
                language: language,
                displayName: language.displayName,
                isSelected: language == currentLanguage
            )
        }
    }
}

// MARK: - 语言菜单项
struct LanguageMenuItem {
    let language: SupportedLanguage
    let displayName: String
    let isSelected: Bool
}
