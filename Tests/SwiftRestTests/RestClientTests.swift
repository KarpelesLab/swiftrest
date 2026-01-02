import XCTest
@testable import SwiftRest

final class RestClientTests: XCTestCase {

    func testClientInitialization() async {
        let config = RestClientConfig(host: "api.test.com")
        let client = RestClient(config: config)

        let clientConfig = await client.config
        XCTAssertEqual(clientConfig.host, "api.test.com")
    }

    func testClientWithDefaultConfig() async {
        let client = RestClient()
        let config = await client.config

        XCTAssertEqual(config.scheme, "https")
        XCTAssertEqual(config.host, "www.atonline.com")
    }

    func testSetAuthentication() async throws {
        let client = RestClient()
        let auth = TokenAuthentication(accessToken: "test-token")

        await client.setAuthentication(auth)

        let retrievedAuth = await client.getAuthentication()
        XCTAssertNotNil(retrievedAuth)
    }

    func testDebugMode() async {
        let client = RestClient()

        // Debug is off by default
        let debugOff = await client.debug
        XCTAssertFalse(debugOff)

        // Can enable debug
        await client.setDebug(true)
        let debugOn = await client.debug
        XCTAssertTrue(debugOn)
    }
}

// Extension to allow setting debug mode for testing
extension RestClient {
    func setDebug(_ value: Bool) {
        self.debug = value
    }
}
