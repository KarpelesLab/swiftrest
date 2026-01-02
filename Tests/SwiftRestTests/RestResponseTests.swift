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
