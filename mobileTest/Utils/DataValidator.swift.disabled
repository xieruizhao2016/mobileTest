//
//  DataValidator.swift
//  mobileTest
//
//  Created by ruizhao_xie on 12/19/24.
//

import Foundation

// MARK: - 数据验证结果
struct ValidationResult {
    let isValid: Bool
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
    
    init(isValid: Bool = true, errors: [ValidationError] = [], warnings: [ValidationWarning] = []) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
    
    /// 合并多个验证结果
    static func combine(_ results: [ValidationResult]) -> ValidationResult {
        let allErrors = results.flatMap { $0.errors }
        let allWarnings = results.flatMap { $0.warnings }
        let isValid = allErrors.isEmpty
        
        return ValidationResult(isValid: isValid, errors: allErrors, warnings: allWarnings)
    }
}

// MARK: - 验证错误
struct ValidationError: Error, LocalizedError {
    let field: String
    let message: String
    let code: ValidationErrorCode
    let severity: ValidationSeverity
    
    var errorDescription: String? {
        return "[\(field)] \(message)"
    }
    
    init(field: String, message: String, code: ValidationErrorCode, severity: ValidationSeverity = .error) {
        self.field = field
        self.message = message
        self.code = code
        self.severity = severity
    }
}

// MARK: - 验证警告
struct ValidationWarning {
    let field: String
    let message: String
    let code: ValidationWarningCode
    
    init(field: String, message: String, code: ValidationWarningCode) {
        self.field = field
        self.message = message
        self.code = code
    }
}

// MARK: - 验证错误代码
enum ValidationErrorCode: String, CaseIterable {
    // 数据格式错误
    case missingField = "MISSING_FIELD"
    case invalidType = "INVALID_TYPE"
    case invalidFormat = "INVALID_FORMAT"
    case invalidValue = "INVALID_VALUE"
    
    // 业务规则错误
    case businessRuleViolation = "BUSINESS_RULE_VIOLATION"
    case dataInconsistency = "DATA_INCONSISTENCY"
    case constraintViolation = "CONSTRAINT_VIOLATION"
    
    // 数据完整性错误
    case dataCorruption = "DATA_CORRUPTION"
    case referenceIntegrity = "REFERENCE_INTEGRITY"
    case duplicateData = "DUPLICATE_DATA"
    
    // 时间相关错误
    case invalidDate = "INVALID_DATE"
    case dateOutOfRange = "DATE_OUT_OF_RANGE"
    case expiredData = "EXPIRED_DATA"
    
    // 网络相关错误
    case invalidURL = "INVALID_URL"
    case networkDataError = "NETWORK_DATA_ERROR"
}

// MARK: - 验证警告代码
enum ValidationWarningCode: String, CaseIterable {
    case deprecatedField = "DEPRECATED_FIELD"
    case optionalFieldMissing = "OPTIONAL_FIELD_MISSING"
    case dataQualityIssue = "DATA_QUALITY_ISSUE"
    case performanceWarning = "PERFORMANCE_WARNING"
    case compatibilityWarning = "COMPATIBILITY_WARNING"
}

// MARK: - 验证严重程度
enum ValidationSeverity: String, CaseIterable {
    case error = "ERROR"
    case warning = "WARNING"
    case info = "INFO"
    
    var priority: Int {
        switch self {
        case .error: return 3
        case .warning: return 2
        case .info: return 1
        }
    }
}

// MARK: - 数据验证器协议
protocol DataValidatorProtocol {
    /// 验证数据
    /// - Parameter data: 要验证的数据
    /// - Returns: 验证结果
    func validate(_ data: Data) async throws -> ValidationResult
    
    /// 验证BookingData对象
    /// - Parameter bookingData: 要验证的预订数据
    /// - Returns: 验证结果
    func validate(_ bookingData: BookingData) async throws -> ValidationResult
}

// MARK: - JSON数据验证器
class JSONDataValidator: DataValidatorProtocol {
    
    private let enableVerboseLogging: Bool
    private let validationRules: [ValidationRule]
    
    init(enableVerboseLogging: Bool = true, validationRules: [ValidationRule] = ValidationRuleFactory.createDefaultRules()) {
        self.enableVerboseLogging = enableVerboseLogging
        self.validationRules = validationRules
    }
    
    /// 验证原始JSON数据
    func validate(_ data: Data) async throws -> ValidationResult {
        log("🔍 [JSONDataValidator] 开始验证JSON数据，大小: \(data.count) 字节")
        
        // 1. 基本JSON格式验证
        let jsonValidation = try await validateJSONFormat(data)
        if !jsonValidation.isValid {
            return jsonValidation
        }
        
        // 2. 解析为BookingData对象
        let bookingData: BookingData
        do {
            let decoder = JSONDecoder()
            bookingData = try decoder.decode(BookingData.self, from: data)
            log("✅ [JSONDataValidator] JSON解析成功")
        } catch {
            let validationError = ValidationError(
                field: "JSON",
                message: "JSON解析失败: \(error.localizedDescription)",
                code: .dataCorruption
            )
            return ValidationResult(isValid: false, errors: [validationError])
        }
        
        // 3. 验证BookingData对象
        return try await validate(bookingData)
    }
    
    /// 验证BookingData对象
    func validate(_ bookingData: BookingData) async throws -> ValidationResult {
        log("🔍 [JSONDataValidator] 开始验证BookingData对象")
        
        var allResults: [ValidationResult] = []
        
        // 执行所有验证规则
        for rule in validationRules {
            do {
                let result = try await rule.validate(bookingData)
                allResults.append(result)
                
                if !result.isValid {
                    log("❌ [JSONDataValidator] 验证规则 '\(rule.name)' 失败")
                    for error in result.errors {
                        log("   - 错误: \(error.errorDescription ?? "")")
                    }
                } else if !result.warnings.isEmpty {
                    log("⚠️ [JSONDataValidator] 验证规则 '\(rule.name)' 有警告")
                    for warning in result.warnings {
                        log("   - 警告: [\(warning.field)] \(warning.message)")
                    }
                }
            } catch {
                let validationError = ValidationError(
                    field: "ValidationRule",
                    message: "验证规则 '\(rule.name)' 执行失败: \(error.localizedDescription)",
                    code: .dataCorruption
                )
                allResults.append(ValidationResult(isValid: false, errors: [validationError]))
            }
        }
        
        let finalResult = ValidationResult.combine(allResults)
        
        if finalResult.isValid {
            log("✅ [JSONDataValidator] 数据验证通过")
        } else {
            log("❌ [JSONDataValidator] 数据验证失败，错误数量: \(finalResult.errors.count)")
        }
        
        return finalResult
    }
    
    /// 验证JSON格式
    private func validateJSONFormat(_ data: Data) async throws -> ValidationResult {
        // 检查数据是否为空
        if data.isEmpty {
            let error = ValidationError(
                field: "JSON",
                message: "JSON数据为空",
                code: .missingField
            )
            return ValidationResult(isValid: false, errors: [error])
        }
        
        // 检查是否为有效的JSON
        do {
            _ = try JSONSerialization.jsonObject(with: data, options: [])
            return ValidationResult(isValid: true)
        } catch {
            let validationError = ValidationError(
                field: "JSON",
                message: "无效的JSON格式: \(error.localizedDescription)",
                code: .invalidFormat
            )
            return ValidationResult(isValid: false, errors: [validationError])
        }
    }
    
    /// 条件日志输出
    private func log(_ message: String) {
        if enableVerboseLogging {
            print(message)
        }
    }
}

// MARK: - 验证规则协议
protocol ValidationRule {
    var name: String { get }
    var description: String { get }
    var priority: Int { get }
    
    func validate(_ bookingData: BookingData) async throws -> ValidationResult
}

// MARK: - 必填字段验证规则
class RequiredFieldsValidationRule: ValidationRule {
    let name = "必填字段验证"
    let description = "验证所有必填字段是否存在"
    let priority = 1
    
    private let requiredFields: [String] = [
        "shipReference",
        "expiryTime",
        "duration",
        "segments"
    ]
    
    func validate(_ bookingData: BookingData) async throws -> ValidationResult {
        var errors: [ValidationError] = []
        
        // 验证shipReference
        if bookingData.shipReference.isEmpty {
            errors.append(ValidationError(
                field: "shipReference",
                message: "船舶参考号不能为空",
                code: .missingField
            ))
        }
        
        // 验证segments
        if bookingData.segments.isEmpty {
            errors.append(ValidationError(
                field: "segments",
                message: "航段信息不能为空",
                code: .missingField
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
}

// MARK: - 数据格式验证规则
class DataFormatValidationRule: ValidationRule {
    let name = "数据格式验证"
    let description = "验证数据格式的正确性"
    let priority = 2
    
    func validate(_ bookingData: BookingData) async throws -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // 验证船舶参考号格式
        if !bookingData.shipReference.isEmpty {
            if !isValidShipReference(bookingData.shipReference) {
                errors.append(ValidationError(
                    field: "shipReference",
                    message: "船舶参考号格式无效: \(bookingData.shipReference)",
                    code: .invalidFormat
                ))
            }
        }
        
        // 验证过期时间
        if bookingData.expiryTime <= Date() {
            warnings.append(ValidationWarning(
                field: "expiryTime",
                message: "数据已过期",
                code: .dataQualityIssue
            ))
        }
        
        // 验证持续时间
        if bookingData.duration <= 0 {
            errors.append(ValidationError(
                field: "duration",
                message: "持续时间必须大于0",
                code: .invalidValue
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
    
    private func isValidShipReference(_ reference: String) -> Bool {
        // 船舶参考号应该是字母数字组合，长度在3-20之间
        let pattern = "^[A-Za-z0-9]{3,20}$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: reference.utf16.count)
        return regex?.firstMatch(in: reference, options: [], range: range) != nil
    }
}

// MARK: - 航段数据验证规则
class SegmentsValidationRule: ValidationRule {
    let name = "航段数据验证"
    let description = "验证航段数据的完整性和一致性"
    let priority = 3
    
    func validate(_ bookingData: BookingData) async throws -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        for (index, segment) in bookingData.segments.enumerated() {
            let segmentPrefix = "segments[\(index)]"
            
            // 验证航段ID
            if segment.id.isEmpty {
                errors.append(ValidationError(
                    field: "\(segmentPrefix).id",
                    message: "航段ID不能为空",
                    code: .missingField
                ))
            }
            
            // 验证出发地
            if segment.origin.isEmpty {
                errors.append(ValidationError(
                    field: "\(segmentPrefix).origin",
                    message: "出发地不能为空",
                    code: .missingField
                ))
            }
            
            // 验证目的地
            if segment.destination.isEmpty {
                errors.append(ValidationError(
                    field: "\(segmentPrefix).destination",
                    message: "目的地不能为空",
                    code: .missingField
                ))
            }
            
            // 验证出发地和目的地不能相同
            if segment.origin == segment.destination {
                errors.append(ValidationError(
                    field: "\(segmentPrefix)",
                    message: "出发地和目的地不能相同",
                    code: .businessRuleViolation
                ))
            }
            
            // 验证出发时间
            if segment.departureTime <= Date() {
                warnings.append(ValidationWarning(
                    field: "\(segmentPrefix).departureTime",
                    message: "出发时间已过期",
                    code: .dataQualityIssue
                ))
            }
            
            // 验证到达时间
            if segment.arrivalTime <= segment.departureTime {
                errors.append(ValidationError(
                    field: "\(segmentPrefix).arrivalTime",
                    message: "到达时间必须晚于出发时间",
                    code: .businessRuleViolation
                ))
            }
            
            // 验证价格
            if segment.price < 0 {
                errors.append(ValidationError(
                    field: "\(segmentPrefix).price",
                    message: "价格不能为负数",
                    code: .invalidValue
                ))
            }
            
            // 验证可用座位数
            if segment.availableSeats < 0 {
                errors.append(ValidationError(
                    field: "\(segmentPrefix).availableSeats",
                    message: "可用座位数不能为负数",
                    code: .invalidValue
                ))
            }
        }
        
        // 验证航段之间的时间连续性
        if bookingData.segments.count > 1 {
            for i in 0..<(bookingData.segments.count - 1) {
                let currentSegment = bookingData.segments[i]
                let nextSegment = bookingData.segments[i + 1]
                
                if currentSegment.arrivalTime > nextSegment.departureTime {
                    warnings.append(ValidationWarning(
                        field: "segments[\(i)]-segments[\(i+1)]",
                        message: "航段时间不连续",
                        code: .dataQualityIssue
                    ))
                }
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
}

// MARK: - 业务规则验证
class BusinessRulesValidationRule: ValidationRule {
    let name = "业务规则验证"
    let description = "验证业务逻辑规则"
    let priority = 4
    
    func validate(_ bookingData: BookingData) async throws -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // 验证总价格合理性
        let totalPrice = bookingData.segments.reduce(0) { $0 + $1.price }
        if totalPrice > 100000 { // 假设最大价格为100,000
            warnings.append(ValidationWarning(
                field: "totalPrice",
                message: "总价格异常高: \(totalPrice)",
                code: .dataQualityIssue
            ))
        }
        
        // 验证航段数量合理性
        if bookingData.segments.count > 20 {
            warnings.append(ValidationWarning(
                field: "segments",
                message: "航段数量过多: \(bookingData.segments.count)",
                code: .performanceWarning
            ))
        }
        
        // 验证数据新鲜度
        let dataAge = Date().timeIntervalSince(bookingData.expiryTime)
        if dataAge > 86400 { // 24小时
            warnings.append(ValidationWarning(
                field: "expiryTime",
                message: "数据可能已过期",
                code: .dataQualityIssue
            ))
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
}

// MARK: - 数据一致性验证
class DataConsistencyValidationRule: ValidationRule {
    let name = "数据一致性验证"
    let description = "验证数据内部一致性"
    let priority = 5
    
    func validate(_ bookingData: BookingData) async throws -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // 验证航段ID唯一性
        let segmentIds = bookingData.segments.map { $0.id }
        let uniqueIds = Set(segmentIds)
        if segmentIds.count != uniqueIds.count {
            errors.append(ValidationError(
                field: "segments",
                message: "航段ID存在重复",
                code: .duplicateData
            ))
        }
        
        // 验证航段顺序
        for i in 0..<(bookingData.segments.count - 1) {
            let currentSegment = bookingData.segments[i]
            let nextSegment = bookingData.segments[i + 1]
            
            // 检查目的地和下一个出发地是否匹配
            if currentSegment.destination != nextSegment.origin {
                warnings.append(ValidationWarning(
                    field: "segments[\(i)]-segments[\(i+1)]",
                    message: "航段连接不一致: \(currentSegment.destination) -> \(nextSegment.origin)",
                    code: .dataQualityIssue
                ))
            }
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors, warnings: warnings)
    }
}

// MARK: - 验证规则工厂
enum ValidationRuleFactory {
    /// 创建默认验证规则
    static func createDefaultRules() -> [ValidationRule] {
        return [
            RequiredFieldsValidationRule(),
            DataFormatValidationRule(),
            SegmentsValidationRule(),
            BusinessRulesValidationRule(),
            DataConsistencyValidationRule()
        ]
    }
    
    /// 创建严格验证规则
    static func createStrictRules() -> [ValidationRule] {
        return [
            RequiredFieldsValidationRule(),
            DataFormatValidationRule(),
            SegmentsValidationRule(),
            BusinessRulesValidationRule(),
            DataConsistencyValidationRule()
        ]
    }
    
    /// 创建宽松验证规则
    static func createLenientRules() -> [ValidationRule] {
        return [
            RequiredFieldsValidationRule(),
            DataFormatValidationRule()
        ]
    }
    
    /// 创建自定义验证规则
    static func createCustomRules(_ rules: [ValidationRule]) -> [ValidationRule] {
        return rules.sorted { $0.priority < $1.priority }
    }
}

// MARK: - 空数据验证器（用于禁用验证）
class EmptyDataValidator: DataValidatorProtocol {
    func validate(_ data: Data) async throws -> ValidationResult {
        return ValidationResult(isValid: true)
    }
    
    func validate(_ bookingData: BookingData) async throws -> ValidationResult {
        return ValidationResult(isValid: true)
    }
}

// MARK: - 数据验证器工厂
enum DataValidatorFactory {
    /// 创建默认数据验证器
    static func createDefault(enableVerboseLogging: Bool = true) -> DataValidatorProtocol {
        return JSONDataValidator(enableVerboseLogging: enableVerboseLogging)
    }
    
    /// 创建严格数据验证器
    static func createStrict(enableVerboseLogging: Bool = true) -> DataValidatorProtocol {
        let rules = ValidationRuleFactory.createStrictRules()
        return JSONDataValidator(enableVerboseLogging: enableVerboseLogging, validationRules: rules)
    }
    
    /// 创建宽松数据验证器
    static func createLenient(enableVerboseLogging: Bool = true) -> DataValidatorProtocol {
        let rules = ValidationRuleFactory.createLenientRules()
        return JSONDataValidator(enableVerboseLogging: enableVerboseLogging, validationRules: rules)
    }
    
    /// 创建自定义数据验证器
    static func createCustom(rules: [ValidationRule], enableVerboseLogging: Bool = true) -> DataValidatorProtocol {
        return JSONDataValidator(enableVerboseLogging: enableVerboseLogging, validationRules: rules)
    }
}
