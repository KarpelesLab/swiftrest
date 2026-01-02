/// SwiftRest - A Swift REST API client library
///
/// This library provides a clean, async/await-based REST API client for communicating
/// with KarpelesLab-style REST endpoints.
///
/// ## Features
/// - OAuth2 token authentication with automatic refresh
/// - API key authentication with Ed25519 signing
/// - Chunked file uploads with progress tracking
/// - Generic response decoding
/// - Comprehensive error handling
///
/// ## Quick Start
/// ```swift
/// let client = RestClient(config: RestClientConfig(host: "api.example.com"))
///
/// // Set up authentication
/// let auth = TokenAuthentication(accessToken: "your-token")
/// await client.setAuthentication(auth)
///
/// // Make a request
/// struct User: Decodable { let id: Int; let name: String }
/// let user: User = try await client.request("User:get", method: .get, params: ["id": 123])
/// ```
///
/// ## Upload Example
/// ```swift
/// let response: FileInfo = try await client.upload(
///     "File:upload",
///     file: URL(fileURLWithPath: "/path/to/file.mp4"),
///     progress: { progress in
///         print("Upload progress: \(progress * 100)%")
///     }
/// )
/// ```

// Re-export all public types for convenient access
// Users can simply: import SwiftRest
