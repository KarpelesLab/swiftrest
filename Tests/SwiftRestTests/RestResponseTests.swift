import XCTest
@testable import SwiftRest

final class RestResponseTests: XCTestCase {

    func testSuccessResponse() throws {
        let json = """
        {
            "result": "success",
            "data": {
                "id": 123,
                "name": "Test User",
                "email": "test@example.com"
            },
            "time": 1234567890
        }
        """
        let data = Data(json.utf8)
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["X-Request-Id": "req-123"]
        )!

        let response = try RestResponse(data: data, httpResponse: httpResponse, requestId: "req-123")

        XCTAssertEqual(response.result, "success")
        XCTAssertEqual(response.requestId, "req-123")
        XCTAssertEqual(response.httpStatusCode, 200)
        XCTAssertNil(response.error)
    }

    func testDecodeResponse() throws {
        struct User: Decodable {
            let id: Int
            let name: String
            let email: String
        }

        let json = """
        {
            "result": "success",
            "data": {
                "id": 123,
                "name": "Test User",
                "email": "test@example.com"
            }
        }
        """
        let data = Data(json.utf8)
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        let response = try RestResponse(data: data, httpResponse: httpResponse, requestId: nil)
        let user: User = try response.decode()

        XCTAssertEqual(user.id, 123)
        XCTAssertEqual(user.name, "Test User")
        XCTAssertEqual(user.email, "test@example.com")
    }

    func testGetPathAccess() throws {
        let json = """
        {
            "result": "success",
            "data": {
                "user": {
                    "profile": {
                        "name": "John",
                        "age": 30
                    }
                },
                "items": ["a", "b", "c"]
            }
        }
        """
        let data = Data(json.utf8)
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        let response = try RestResponse(data: data, httpResponse: httpResponse, requestId: nil)

        XCTAssertEqual(response.getString("user/profile/name"), "John")
        XCTAssertEqual(response.getInt("user/profile/age"), 30)
        XCTAssertEqual(response.get("items/1") as? String, "b")
        XCTAssertNil(response.get("user/nonexistent"))
        XCTAssertNil(response.get("items/10"))
    }

    func testErrorResponse() {
        let json = """
        {
            "result": "error",
            "error": "Invalid request",
            "code": 400,
            "extra": "missing field: email"
        }
        """
        let data = Data(json.utf8)
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: ["X-Request-Id": "req-456"]
        )!

        XCTAssertThrowsError(try RestResponse(data: data, httpResponse: httpResponse, requestId: "req-456")) { error in
            guard case let RestError.apiError(message, code, extra, requestId) = error else {
                XCTFail("Expected apiError")
                return
            }
            XCTAssertEqual(message, "Invalid request")
            XCTAssertEqual(code, 400)
            XCTAssertEqual(extra, "missing field: email")
            XCTAssertEqual(requestId, "req-456")
        }
    }

    func testTokenExpiredError() {
        let json = """
        {
            "result": "error",
            "error": "Token expired",
            "token": "invalid_request_token",
            "extra": "token_expired"
        }
        """
        let data = Data(json.utf8)
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )!

        XCTAssertThrowsError(try RestResponse(data: data, httpResponse: httpResponse, requestId: nil)) { error in
            XCTAssertEqual(error as? RestError, RestError.tokenExpired)
        }
    }

    func testPagingInfo() throws {
        let json = """
        {
            "result": "success",
            "data": [],
            "paging": {
                "page_no": 2,
                "count": 100,
                "page_max": 10,
                "results_per_page": 10
            }
        }
        """
        let data = Data(json.utf8)
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        let response = try RestResponse(data: data, httpResponse: httpResponse, requestId: nil)

        XCTAssertNotNil(response.paging)
        XCTAssertEqual(response.paging?.pageNo, 2)
        XCTAssertEqual(response.paging?.count, 100)
        XCTAssertEqual(response.paging?.pageMax, 10)
        XCTAssertEqual(response.paging?.resultsPerPage, 10)
        XCTAssertTrue(response.paging?.hasNextPage ?? false)
        XCTAssertTrue(response.paging?.hasPreviousPage ?? false)
    }

    func testRedirectResponse() {
        let json = """
        {
            "result": "redirect",
            "redirect_url": "https://example.com/new-location"
        }
        """
        let data = Data(json.utf8)
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: nil
        )!

        XCTAssertThrowsError(try RestResponse(data: data, httpResponse: httpResponse, requestId: nil)) { error in
            guard case let RestError.redirect(url) = error else {
                XCTFail("Expected redirect error")
                return
            }
            XCTAssertEqual(url, "https://example.com/new-location")
        }
    }

    // MARK: - Data type handling tests

    func testDataIsString() throws {
        let json = """
        {"result": "success", "data": "hello world"}
        """
        let response = try makeResponse(json)

        XCTAssertEqual(response.dataString, "hello world")
        XCTAssertNil(response.dataDict)
        XCTAssertNil(response.dataArray)
        XCTAssertNil(response.dataAnyArray)
        XCTAssertFalse(response.isDataArray)
        XCTAssertFalse(response.isDataDict)
        XCTAssertFalse(response.isDataNil)
    }

    func testDataIsInteger() throws {
        let json = """
        {"result": "success", "data": 42}
        """
        let response = try makeResponse(json)

        XCTAssertEqual(response.dataInt, 42)
        XCTAssertEqual(response.dataDouble, 42.0)
        XCTAssertNil(response.dataString)
        XCTAssertNil(response.dataDict)
        XCTAssertFalse(response.isDataDict)
        XCTAssertFalse(response.isDataNil)
    }

    func testDataIsDouble() throws {
        let json = """
        {"result": "success", "data": 3.14}
        """
        let response = try makeResponse(json)

        XCTAssertEqual(response.dataDouble, 3.14)
        // 3.14 is not exactly representable as Int
        XCTAssertNil(response.dataInt)
        XCTAssertNil(response.dataString)
    }

    func testDataIsBool() throws {
        let json = """
        {"result": "success", "data": true}
        """
        let response = try makeResponse(json)

        XCTAssertEqual(response.dataBool, true)
        XCTAssertFalse(response.isDataNil)
    }

    func testDataIsBoolFalse() throws {
        let json = """
        {"result": "success", "data": false}
        """
        let response = try makeResponse(json)

        XCTAssertEqual(response.dataBool, false)
    }

    func testDataIsNull() throws {
        let json = """
        {"result": "success", "data": null}
        """
        let response = try makeResponse(json)

        XCTAssertNil(response.data)
        XCTAssertTrue(response.isDataNil)
        XCTAssertNil(response.dataDict)
        XCTAssertNil(response.dataArray)
        XCTAssertNil(response.dataString)
        XCTAssertNil(response.dataInt)
        XCTAssertNil(response.dataBool)
    }

    func testDataIsStringArray() throws {
        let json = """
        {"result": "success", "data": ["apple", "banana", "cherry"]}
        """
        let response = try makeResponse(json)

        XCTAssertTrue(response.isDataArray)
        XCTAssertFalse(response.isDataDict)
        XCTAssertNotNil(response.dataAnyArray)
        XCTAssertEqual(response.dataAnyArray?.count, 3)
        // dataArray requires [[String: Any]], so should be nil for string arrays
        XCTAssertNil(response.dataArray)
    }

    func testDataIsMixedArray() throws {
        let json = """
        {"result": "success", "data": [1, "two", true, null]}
        """
        let response = try makeResponse(json)

        XCTAssertTrue(response.isDataArray)
        XCTAssertNotNil(response.dataAnyArray)
        XCTAssertEqual(response.dataAnyArray?.count, 4)
    }

    func testDataAbsent() throws {
        let json = """
        {"result": "success"}
        """
        let response = try makeResponse(json)

        XCTAssertNil(response.data)
        XCTAssertTrue(response.isDataNil)
    }

    // MARK: - Decode with various data types

    func testDecodeString() throws {
        let json = """
        {"result": "success", "data": "hello"}
        """
        let response = try makeResponse(json)
        let value: String = try response.decode()
        XCTAssertEqual(value, "hello")
    }

    func testDecodeInt() throws {
        let json = """
        {"result": "success", "data": 42}
        """
        let response = try makeResponse(json)
        let value: Int = try response.decode()
        XCTAssertEqual(value, 42)
    }

    func testDecodeBool() throws {
        let json = """
        {"result": "success", "data": true}
        """
        let response = try makeResponse(json)
        let value: Bool = try response.decode()
        XCTAssertEqual(value, true)
    }

    func testDecodeStringArray() throws {
        let json = """
        {"result": "success", "data": ["a", "b", "c"]}
        """
        let response = try makeResponse(json)
        let value: [String] = try response.decode()
        XCTAssertEqual(value, ["a", "b", "c"])
    }

    func testDecodeNullThrowsNoData() throws {
        let json = """
        {"result": "success", "data": null}
        """
        let response = try makeResponse(json)
        XCTAssertThrowsError(try response.decode(as: String.self)) { error in
            XCTAssertEqual(error as? RestError, RestError.noData)
        }
    }

    // MARK: - Helpers

    private func makeResponse(_ json: String) throws -> RestResponse {
        let data = Data(json.utf8)
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return try RestResponse(data: data, httpResponse: httpResponse, requestId: nil)
    }

    func testGetBoolFromVariousTypes() throws {
        let json = """
        {
            "result": "success",
            "data": {
                "bool_true": true,
                "bool_false": false,
                "int_one": 1,
                "int_zero": 0,
                "string_true": "true",
                "string_one": "1",
                "string_false": "false"
            }
        }
        """
        let data = Data(json.utf8)
        let httpResponse = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        let response = try RestResponse(data: data, httpResponse: httpResponse, requestId: nil)

        XCTAssertEqual(response.getBool("bool_true"), true)
        XCTAssertEqual(response.getBool("bool_false"), false)
        XCTAssertEqual(response.getBool("int_one"), true)
        XCTAssertEqual(response.getBool("int_zero"), false)
        XCTAssertEqual(response.getBool("string_true"), true)
        XCTAssertEqual(response.getBool("string_one"), true)
        XCTAssertEqual(response.getBool("string_false"), false)
    }
}
