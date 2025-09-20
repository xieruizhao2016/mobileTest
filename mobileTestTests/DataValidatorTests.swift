//
//  DataValidatorTests.swift
//  mobileTestTests
//
//  Created by ruizhao_xie on 12/19/24.
//

import XCTest
@testable import mobileTest

class DataValidatorTests: XCTestCase {
    
    var validator: DataValidatorProtocol!
    
    override func setUp() {
        super.setUp()
        validator = DataValidatorFactory.createDefault(enableVerboseLogging: false)
    }
    
    override func tearDown() {
        validator = nil
        super.tearDown()
    }
    
    // MARK: - 基本验证测试
    
    func testValidateValidBookingData() async throws {
        // Given
        let bookingData = createValidBookingData()
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertTrue(result.isValid, "有效数据应该通过验证")
        XCTAssertTrue(result.errors.isEmpty, "有效数据不应该有错误")
    }
    
    func testValidateEmptyData() async throws {
        // Given
        let emptyData = Data()
        
        // When
        let result = try await validator.validate(emptyData)
        
        // Then
        XCTAssertFalse(result.isValid, "空数据应该验证失败")
        XCTAssertFalse(result.errors.isEmpty, "空数据应该有错误")
        XCTAssertEqual(result.errors.first?.code, .missingField)
    }
    
    func testValidateInvalidJSON() async throws {
        // Given
        let invalidJSON = "invalid json data".data(using: .utf8)!
        
        // When
        let result = try await validator.validate(invalidJSON)
        
        // Then
        XCTAssertFalse(result.isValid, "无效JSON应该验证失败")
        XCTAssertFalse(result.errors.isEmpty, "无效JSON应该有错误")
        XCTAssertEqual(result.errors.first?.code, .dataCorruption)
    }
    
    // MARK: - 必填字段验证测试
    
    func testValidateMissingShipReference() async throws {
        // Given
        var bookingData = createValidBookingData()
        bookingData = BookingData(
            shipReference: "", // 空的船舶参考号
            expiryTime: bookingData.expiryTime,
            duration: bookingData.duration,
            segments: bookingData.segments
        )
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertFalse(result.isValid, "缺少船舶参考号应该验证失败")
        XCTAssertTrue(result.errors.contains { $0.field == "shipReference" })
    }
    
    func testValidateMissingSegments() async throws {
        // Given
        var bookingData = createValidBookingData()
        bookingData = BookingData(
            shipReference: bookingData.shipReference,
            expiryTime: bookingData.expiryTime,
            duration: bookingData.duration,
            segments: [] // 空的航段列表
        )
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertFalse(result.isValid, "缺少航段应该验证失败")
        XCTAssertTrue(result.errors.contains { $0.field == "segments" })
    }
    
    // MARK: - 数据格式验证测试
    
    func testValidateInvalidShipReferenceFormat() async throws {
        // Given
        var bookingData = createValidBookingData()
        bookingData = BookingData(
            shipReference: "invalid@reference#", // 无效格式
            expiryTime: bookingData.expiryTime,
            duration: bookingData.duration,
            segments: bookingData.segments
        )
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertFalse(result.isValid, "无效船舶参考号格式应该验证失败")
        XCTAssertTrue(result.errors.contains { $0.field == "shipReference" })
        XCTAssertEqual(result.errors.first?.code, .invalidFormat)
    }
    
    func testValidateNegativeDuration() async throws {
        // Given
        var bookingData = createValidBookingData()
        bookingData = BookingData(
            shipReference: bookingData.shipReference,
            expiryTime: bookingData.expiryTime,
            duration: -100, // 负数持续时间
            segments: bookingData.segments
        )
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertFalse(result.isValid, "负数持续时间应该验证失败")
        XCTAssertTrue(result.errors.contains { $0.field == "duration" })
    }
    
    func testValidateExpiredData() async throws {
        // Given
        var bookingData = createValidBookingData()
        bookingData = BookingData(
            shipReference: bookingData.shipReference,
            expiryTime: Date().addingTimeInterval(-3600), // 1小时前过期
            duration: bookingData.duration,
            segments: bookingData.segments
        )
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertTrue(result.isValid, "过期数据应该通过验证（只是警告）")
        XCTAssertFalse(result.warnings.isEmpty, "过期数据应该有警告")
        XCTAssertTrue(result.warnings.contains { $0.field == "expiryTime" })
    }
    
    // MARK: - 航段数据验证测试
    
    func testValidateSegmentWithEmptyId() async throws {
        // Given
        var bookingData = createValidBookingData()
        var segments = bookingData.segments
        segments[0] = BookingSegment(
            id: "", // 空的航段ID
            origin: segments[0].origin,
            destination: segments[0].destination,
            departureTime: segments[0].departureTime,
            arrivalTime: segments[0].arrivalTime,
            price: segments[0].price,
            availableSeats: segments[0].availableSeats
        )
        bookingData = BookingData(
            shipReference: bookingData.shipReference,
            expiryTime: bookingData.expiryTime,
            duration: bookingData.duration,
            segments: segments
        )
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertFalse(result.isValid, "空航段ID应该验证失败")
        XCTAssertTrue(result.errors.contains { $0.field.contains("segments[0].id") })
    }
    
    func testValidateSegmentWithSameOriginAndDestination() async throws {
        // Given
        var bookingData = createValidBookingData()
        var segments = bookingData.segments
        segments[0] = BookingSegment(
            id: segments[0].id,
            origin: "Beijing",
            destination: "Beijing", // 出发地和目的地相同
            departureTime: segments[0].departureTime,
            arrivalTime: segments[0].arrivalTime,
            price: segments[0].price,
            availableSeats: segments[0].availableSeats
        )
        bookingData = BookingData(
            shipReference: bookingData.shipReference,
            expiryTime: bookingData.expiryTime,
            duration: bookingData.duration,
            segments: segments
        )
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertFalse(result.isValid, "出发地和目的地相同应该验证失败")
        XCTAssertTrue(result.errors.contains { $0.field.contains("segments[0]") })
        XCTAssertEqual(result.errors.first?.code, .businessRuleViolation)
    }
    
    func testValidateSegmentWithInvalidTimeOrder() async throws {
        // Given
        var bookingData = createValidBookingData()
        var segments = bookingData.segments
        let departureTime = Date().addingTimeInterval(3600)
        let arrivalTime = Date() // 到达时间早于出发时间
        segments[0] = BookingSegment(
            id: segments[0].id,
            origin: segments[0].origin,
            destination: segments[0].destination,
            departureTime: departureTime,
            arrivalTime: arrivalTime,
            price: segments[0].price,
            availableSeats: segments[0].availableSeats
        )
        bookingData = BookingData(
            shipReference: bookingData.shipReference,
            expiryTime: bookingData.expiryTime,
            duration: bookingData.duration,
            segments: segments
        )
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertFalse(result.isValid, "到达时间早于出发时间应该验证失败")
        XCTAssertTrue(result.errors.contains { $0.field.contains("segments[0].arrivalTime") })
    }
    
    func testValidateSegmentWithNegativePrice() async throws {
        // Given
        var bookingData = createValidBookingData()
        var segments = bookingData.segments
        segments[0] = BookingSegment(
            id: segments[0].id,
            origin: segments[0].origin,
            destination: segments[0].destination,
            departureTime: segments[0].departureTime,
            arrivalTime: segments[0].arrivalTime,
            price: -100, // 负数价格
            availableSeats: segments[0].availableSeats
        )
        bookingData = BookingData(
            shipReference: bookingData.shipReference,
            expiryTime: bookingData.expiryTime,
            duration: bookingData.duration,
            segments: segments
        )
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertFalse(result.isValid, "负数价格应该验证失败")
        XCTAssertTrue(result.errors.contains { $0.field.contains("segments[0].price") })
    }
    
    // MARK: - 数据一致性验证测试
    
    func testValidateDuplicateSegmentIds() async throws {
        // Given
        var bookingData = createValidBookingData()
        var segments = bookingData.segments
        segments.append(segments[0]) // 添加重复的航段
        bookingData = BookingData(
            shipReference: bookingData.shipReference,
            expiryTime: bookingData.expiryTime,
            duration: bookingData.duration,
            segments: segments
        )
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertFalse(result.isValid, "重复航段ID应该验证失败")
        XCTAssertTrue(result.errors.contains { $0.field == "segments" })
        XCTAssertEqual(result.errors.first?.code, .duplicateData)
    }
    
    // MARK: - 业务规则验证测试
    
    func testValidateHighTotalPrice() async throws {
        // Given
        var bookingData = createValidBookingData()
        var segments = bookingData.segments
        segments[0] = BookingSegment(
            id: segments[0].id,
            origin: segments[0].origin,
            destination: segments[0].destination,
            departureTime: segments[0].departureTime,
            arrivalTime: segments[0].arrivalTime,
            price: 200000, // 异常高的价格
            availableSeats: segments[0].availableSeats
        )
        bookingData = BookingData(
            shipReference: bookingData.shipReference,
            expiryTime: bookingData.expiryTime,
            duration: bookingData.duration,
            segments: segments
        )
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertTrue(result.isValid, "高价格应该通过验证（只是警告）")
        XCTAssertFalse(result.warnings.isEmpty, "高价格应该有警告")
        XCTAssertTrue(result.warnings.contains { $0.field == "totalPrice" })
    }
    
    func testValidateTooManySegments() async throws {
        // Given
        var segments: [BookingSegment] = []
        for i in 0..<25 { // 创建25个航段
            let segment = BookingSegment(
                id: "segment_\(i)",
                origin: "City\(i)",
                destination: "City\(i+1)",
                departureTime: Date().addingTimeInterval(TimeInterval(i * 3600)),
                arrivalTime: Date().addingTimeInterval(TimeInterval((i + 1) * 3600)),
                price: 1000,
                availableSeats: 50
            )
            segments.append(segment)
        }
        
        let bookingData = BookingData(
            shipReference: "SHIP123",
            expiryTime: Date().addingTimeInterval(86400),
            duration: 86400,
            segments: segments
        )
        
        // When
        let result = try await validator.validate(bookingData)
        
        // Then
        XCTAssertTrue(result.isValid, "多航段应该通过验证（只是警告）")
        XCTAssertFalse(result.warnings.isEmpty, "多航段应该有警告")
        XCTAssertTrue(result.warnings.contains { $0.field == "segments" })
    }
    
    // MARK: - 验证器工厂测试
    
    func testCreateStrictValidator() {
        // When
        let strictValidator = DataValidatorFactory.createStrict(enableVerboseLogging: false)
        
        // Then
        XCTAssertNotNil(strictValidator)
        XCTAssertTrue(strictValidator is JSONDataValidator)
    }
    
    func testCreateLenientValidator() {
        // When
        let lenientValidator = DataValidatorFactory.createLenient(enableVerboseLogging: false)
        
        // Then
        XCTAssertNotNil(lenientValidator)
        XCTAssertTrue(lenientValidator is JSONDataValidator)
    }
    
    func testCreateCustomValidator() {
        // Given
        let customRules: [ValidationRule] = [RequiredFieldsValidationRule()]
        
        // When
        let customValidator = DataValidatorFactory.createCustom(rules: customRules, enableVerboseLogging: false)
        
        // Then
        XCTAssertNotNil(customValidator)
        XCTAssertTrue(customValidator is JSONDataValidator)
    }
    
    // MARK: - 空验证器测试
    
    func testEmptyValidator() async throws {
        // Given
        let emptyValidator = EmptyDataValidator()
        let bookingData = createValidBookingData()
        
        // When
        let result = try await emptyValidator.validate(bookingData)
        
        // Then
        XCTAssertTrue(result.isValid, "空验证器应该总是返回有效")
        XCTAssertTrue(result.errors.isEmpty, "空验证器不应该有错误")
        XCTAssertTrue(result.warnings.isEmpty, "空验证器不应该有警告")
    }
    
    // MARK: - 辅助方法
    
    private func createValidBookingData() -> BookingData {
        let segment1 = BookingSegment(
            id: "segment_1",
            origin: "Beijing",
            destination: "Shanghai",
            departureTime: Date().addingTimeInterval(3600),
            arrivalTime: Date().addingTimeInterval(7200),
            price: 1500,
            availableSeats: 100
        )
        
        let segment2 = BookingSegment(
            id: "segment_2",
            origin: "Shanghai",
            destination: "Guangzhou",
            departureTime: Date().addingTimeInterval(10800),
            arrivalTime: Date().addingTimeInterval(14400),
            price: 1200,
            availableSeats: 80
        )
        
        return BookingData(
            shipReference: "SHIP123",
            expiryTime: Date().addingTimeInterval(86400), // 24小时后过期
            duration: 14400, // 4小时
            segments: [segment1, segment2]
        )
    }
}

// MARK: - 验证规则测试
class ValidationRuleTests: XCTestCase {
    
    func testRequiredFieldsValidationRule() async throws {
        // Given
        let rule = RequiredFieldsValidationRule()
        let bookingData = createValidBookingData()
        
        // When
        let result = try await rule.validate(bookingData)
        
        // Then
        XCTAssertTrue(result.isValid, "有效数据应该通过必填字段验证")
    }
    
    func testRequiredFieldsValidationRuleWithMissingFields() async throws {
        // Given
        let rule = RequiredFieldsValidationRule()
        var bookingData = createValidBookingData()
        bookingData = BookingData(
            shipReference: "", // 空的船舶参考号
            expiryTime: bookingData.expiryTime,
            duration: bookingData.duration,
            segments: [] // 空的航段列表
        )
        
        // When
        let result = try await rule.validate(bookingData)
        
        // Then
        XCTAssertFalse(result.isValid, "缺少必填字段应该验证失败")
        XCTAssertEqual(result.errors.count, 2, "应该有2个错误")
    }
    
    func testDataFormatValidationRule() async throws {
        // Given
        let rule = DataFormatValidationRule()
        let bookingData = createValidBookingData()
        
        // When
        let result = try await rule.validate(bookingData)
        
        // Then
        XCTAssertTrue(result.isValid, "有效数据应该通过格式验证")
    }
    
    func testSegmentsValidationRule() async throws {
        // Given
        let rule = SegmentsValidationRule()
        let bookingData = createValidBookingData()
        
        // When
        let result = try await rule.validate(bookingData)
        
        // Then
        XCTAssertTrue(result.isValid, "有效航段数据应该通过验证")
    }
    
    func testBusinessRulesValidationRule() async throws {
        // Given
        let rule = BusinessRulesValidationRule()
        let bookingData = createValidBookingData()
        
        // When
        let result = try await rule.validate(bookingData)
        
        // Then
        XCTAssertTrue(result.isValid, "有效数据应该通过业务规则验证")
    }
    
    func testDataConsistencyValidationRule() async throws {
        // Given
        let rule = DataConsistencyValidationRule()
        let bookingData = createValidBookingData()
        
        // When
        let result = try await rule.validate(bookingData)
        
        // Then
        XCTAssertTrue(result.isValid, "一致的数据应该通过验证")
    }
    
    // MARK: - 辅助方法
    
    private func createValidBookingData() -> BookingData {
        let segment1 = BookingSegment(
            id: "segment_1",
            origin: "Beijing",
            destination: "Shanghai",
            departureTime: Date().addingTimeInterval(3600),
            arrivalTime: Date().addingTimeInterval(7200),
            price: 1500,
            availableSeats: 100
        )
        
        let segment2 = BookingSegment(
            id: "segment_2",
            origin: "Shanghai",
            destination: "Guangzhou",
            departureTime: Date().addingTimeInterval(10800),
            arrivalTime: Date().addingTimeInterval(14400),
            price: 1200,
            availableSeats: 80
        )
        
        return BookingData(
            shipReference: "SHIP123",
            expiryTime: Date().addingTimeInterval(86400),
            duration: 14400,
            segments: [segment1, segment2]
        )
    }
}
