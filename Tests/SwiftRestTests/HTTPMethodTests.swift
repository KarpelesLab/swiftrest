import XCTest
@testable import SwiftRest

final class HTTPMethodTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.patch.rawValue, "PATCH")
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
        XCTAssertEqual(HTTPMethod.head.rawValue, "HEAD")
        XCTAssertEqual(HTTPMethod.options.rawValue, "OPTIONS")
    }

    func testEncodesParamsInURL() {
        // These methods should encode params in URL
        XCTAssertTrue(HTTPMethod.get.encodesParamsInURL)
        XCTAssertTrue(HTTPMethod.head.encodesParamsInURL)
        XCTAssertTrue(HTTPMethod.options.encodesParamsInURL)

        // These methods should NOT encode params in URL
        XCTAssertFalse(HTTPMethod.post.encodesParamsInURL)
        XCTAssertFalse(HTTPMethod.put.encodesParamsInURL)
        XCTAssertFalse(HTTPMethod.patch.encodesParamsInURL)
        XCTAssertFalse(HTTPMethod.delete.encodesParamsInURL)
    }

    func testEncodesParamsInBody() {
        // These methods should encode params in body
        XCTAssertTrue(HTTPMethod.post.encodesParamsInBody)
        XCTAssertTrue(HTTPMethod.put.encodesParamsInBody)
        XCTAssertTrue(HTTPMethod.patch.encodesParamsInBody)

        // These methods should NOT encode params in body
        XCTAssertFalse(HTTPMethod.get.encodesParamsInBody)
        XCTAssertFalse(HTTPMethod.head.encodesParamsInBody)
        XCTAssertFalse(HTTPMethod.options.encodesParamsInBody)
        XCTAssertFalse(HTTPMethod.delete.encodesParamsInBody)
    }
}
