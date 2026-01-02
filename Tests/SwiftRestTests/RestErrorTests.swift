import XCTest
@testable import SwiftRest

final class RestErrorTests: XCTestCase {

    func testErrorEquality() {
        XCTAssertEqual(RestError.invalidURL("test"), RestError.invalidURL("test"))
        XCTAssertNotEqual(RestError.invalidURL("test"), RestError.invalidURL("other"))

        XCTAssertEqual(RestError.invalidResponse, RestError.invalidResponse)
        XCTAssertEqual(RestError.noData, RestError.noData)
        XCTAssertEqual(RestError.tokenExpired, RestError.tokenExpired)
        XCTAssertEqual(RestError.loginRequired, RestError.loginRequired)
        XCTAssertEqual(RestError.uploadStalled, RestError.uploadStalled)
        XCTAssertEqual(RestError.noRefreshToken, RestError.noRefreshToken)
        XCTAssertEqual(RestError.noClientId, RestError.noClientId)

        XCTAssertEqual(
            RestError.httpError(statusCode: 404, message: "Not found"),
            RestError.httpError(statusCode: 404, message: "Not found")
        )
        XCTAssertNotEqual(
            RestError.httpError(statusCode: 404, message: "Not found"),
            RestError.httpError(statusCode: 500, message: "Not found")
        )

        XCTAssertEqual(
            RestError.apiError(message: "test", code: 123, extra: "extra", requestId: "req-1"),
            RestError.apiError(message: "test", code: 123, extra: "extra", requestId: "req-1")
        )
    }

    func testErrorDescriptions() {
        XCTAssertEqual(
            RestError.invalidURL("http://test").errorDescription,
            "Invalid URL: http://test"
        )

        XCTAssertEqual(
            RestError.invalidResponse.errorDescription,
            "Invalid response from server"
        )

        XCTAssertEqual(
            RestError.noData.errorDescription,
            "No data in response"
        )

        XCTAssertEqual(
            RestError.httpError(statusCode: 500, message: "Server error").errorDescription,
            "HTTP 500: Server error"
        )

        XCTAssertEqual(
            RestError.httpError(statusCode: 404, message: nil).errorDescription,
            "HTTP error 404"
        )

        XCTAssertEqual(
            RestError.tokenExpired.errorDescription,
            "Authentication token has expired"
        )

        XCTAssertEqual(
            RestError.uploadFailed("Disk full").errorDescription,
            "Upload failed: Disk full"
        )
    }

    func testApiErrorDescription() {
        let error = RestError.apiError(
            message: "Invalid parameter",
            code: 400,
            extra: "field: email",
            requestId: "req-123"
        )
        XCTAssertEqual(error.errorDescription, "[400] Invalid parameter (field: email)")

        let errorNoCode = RestError.apiError(
            message: "Unknown error",
            code: nil,
            extra: nil,
            requestId: nil
        )
        XCTAssertEqual(errorNoCode.errorDescription, "Unknown error")
    }

    func testIsPermissionDenied() {
        XCTAssertTrue(RestError.httpError(statusCode: 403, message: nil).isPermissionDenied)
        XCTAssertTrue(RestError.apiError(message: "Forbidden", code: 403, extra: nil, requestId: nil).isPermissionDenied)
        XCTAssertFalse(RestError.httpError(statusCode: 404, message: nil).isPermissionDenied)
        XCTAssertFalse(RestError.tokenExpired.isPermissionDenied)
    }

    func testIsNotFound() {
        XCTAssertTrue(RestError.httpError(statusCode: 404, message: nil).isNotFound)
        XCTAssertTrue(RestError.apiError(message: "Not found", code: 404, extra: nil, requestId: nil).isNotFound)
        XCTAssertFalse(RestError.httpError(statusCode: 403, message: nil).isNotFound)
        XCTAssertFalse(RestError.noData.isNotFound)
    }

    func testIsAuthenticationError() {
        XCTAssertTrue(RestError.tokenExpired.isAuthenticationError)
        XCTAssertTrue(RestError.loginRequired.isAuthenticationError)
        XCTAssertTrue(RestError.noRefreshToken.isAuthenticationError)
        XCTAssertTrue(RestError.noClientId.isAuthenticationError)
        XCTAssertTrue(RestError.httpError(statusCode: 401, message: nil).isAuthenticationError)
        XCTAssertTrue(RestError.apiError(message: "Unauthorized", code: 401, extra: nil, requestId: nil).isAuthenticationError)
        XCTAssertFalse(RestError.httpError(statusCode: 403, message: nil).isAuthenticationError)
        XCTAssertFalse(RestError.noData.isAuthenticationError)
    }
}
