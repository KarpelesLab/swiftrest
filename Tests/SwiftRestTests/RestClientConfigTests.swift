import XCTest
@testable import SwiftRest

final class RestClientConfigTests: XCTestCase {

    func testDefaultConfig() {
        let config = RestClientConfig.default

        XCTAssertEqual(config.scheme, "https")
        XCTAssertEqual(config.host, "www.atonline.com")
        XCTAssertEqual(config.restPath, "/_special/rest/")
        XCTAssertNil(config.clientId)
        XCTAssertTrue(config.contextParams.isEmpty)
        XCTAssertEqual(config.requestTimeout, 60)
        XCTAssertEqual(config.resourceTimeout, 300)
        XCTAssertEqual(config.uploadRequestTimeout, 300)
        XCTAssertEqual(config.uploadResourceTimeout, 3600)
        XCTAssertEqual(config.maxConnectionsPerHost, 50)
    }

    func testCustomConfig() {
        let config = RestClientConfig(
            scheme: "http",
            host: "api.example.com",
            restPath: "/api/v1/",
            clientId: "test-client",
            contextParams: ["lang": "en"],
            requestTimeout: 30,
            resourceTimeout: 120,
            uploadRequestTimeout: 120,
            uploadResourceTimeout: 1800,
            maxConnectionsPerHost: 10
        )

        XCTAssertEqual(config.scheme, "http")
        XCTAssertEqual(config.host, "api.example.com")
        XCTAssertEqual(config.restPath, "/api/v1/")
        XCTAssertEqual(config.clientId, "test-client")
        XCTAssertEqual(config.contextParams["lang"], "en")
        XCTAssertEqual(config.requestTimeout, 30)
        XCTAssertEqual(config.resourceTimeout, 120)
        XCTAssertEqual(config.uploadRequestTimeout, 120)
        XCTAssertEqual(config.uploadResourceTimeout, 1800)
        XCTAssertEqual(config.maxConnectionsPerHost, 10)
    }

    func testWithContext() {
        let config = RestClientConfig.default
            .withContext(language: "en", timezone: "UTC")

        XCTAssertEqual(config.contextParams["_ctx[l]"], "en")
        XCTAssertEqual(config.contextParams["_ctx[t]"], "UTC")
    }

    func testWithClientId() {
        let config = RestClientConfig.default
            .withClientId("my-client-id")

        XCTAssertEqual(config.clientId, "my-client-id")
    }

    func testChainedConfiguration() {
        let config = RestClientConfig(host: "api.test.com")
            .withClientId("client-123")
            .withContext(language: "ja", timezone: "Asia/Tokyo")

        XCTAssertEqual(config.host, "api.test.com")
        XCTAssertEqual(config.clientId, "client-123")
        XCTAssertEqual(config.contextParams["_ctx[l]"], "ja")
        XCTAssertEqual(config.contextParams["_ctx[t]"], "Asia/Tokyo")
    }
}
