# SwiftRest

A Swift REST API client library for KarpelesLab-style REST endpoints.

## Features

- Modern async/await API using Swift actors
- OAuth2 token authentication with automatic refresh
- API key authentication with Ed25519 signing
- Chunked file uploads with progress tracking
- Generic response decoding
- Path-based data access (e.g., `user/profile/name`)
- Comprehensive error handling with typed errors
- Cross-platform support (macOS, iOS, tvOS, watchOS)

## Requirements

- Swift 5.9+
- macOS 12+ / iOS 15+ / tvOS 15+ / watchOS 8+

## Installation

### Swift Package Manager

Add SwiftRest to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/KarpelesLab/swiftrest.git", from: "1.0.0")
]
```

Or add it in Xcode via File → Add Package Dependencies.

## Usage

### Basic Setup

```swift
import SwiftRest

// Create a client with custom configuration
let config = RestClientConfig(host: "api.example.com")
    .withClientId("your-client-id")
    .withContext(language: "en", timezone: "UTC")

let client = RestClient(config: config)
```

### Authentication

#### OAuth2 Token

```swift
let auth = TokenAuthentication(
    accessToken: "your-access-token",
    refreshToken: "your-refresh-token",
    expiresAt: Date().addingTimeInterval(3600),
    clientId: "your-client-id"
)
await client.setAuthentication(auth)

// Token will be automatically refreshed on expiration when using requestWithRetry
let user: User = try await client.requestWithRetry("User:get", method: .get)
```

#### API Key with Ed25519 Signing

```swift
let auth = try APIKeyAuthentication(
    keyId: "your-key-id",
    secret: "base64-encoded-32-byte-secret"
)
await client.setAuthentication(auth)
```

### Making Requests

```swift
// Define your response types
struct User: Decodable {
    let id: String
    let name: String
    let email: String
}

// GET request with typed response
let user: User = try await client.request(
    "User:get",
    method: .get,
    params: ["id": "user-123"]
)

// POST request
let result: CreateResult = try await client.request(
    "User:create",
    method: .post,
    params: ["name": "John", "email": "john@example.com"]
)

// Access raw response for dynamic data
let response = try await client.request("User:list", method: .get)
let firstName = response.getString("0/name")
let count = response.getInt("count")
```

### File Uploads

```swift
// Upload a file with progress tracking
let video: Video = try await client.upload(
    "Channel/Media:upload",
    file: URL(fileURLWithPath: "/path/to/video.mp4"),
    params: ["Name": "My Video", "Description": "A cool video"],
    progress: { progress in
        print("Upload progress: \(Int(progress * 100))%")
    }
)

// Upload data directly
let image: Image = try await client.upload(
    "User/Avatar:upload",
    data: imageData,
    filename: "avatar.jpg",
    mimeType: "image/jpeg"
)
```

### Error Handling

```swift
do {
    let user: User = try await client.request("User:get", method: .get)
} catch let error as RestError {
    switch error {
    case .tokenExpired:
        // Handle token expiration
        print("Token expired, please login again")
    case .apiError(let message, let code, let extra, let requestId):
        print("API error [\(code ?? 0)]: \(message)")
    case .httpError(let statusCode, let message):
        print("HTTP \(statusCode): \(message ?? "Unknown error")")
    case .networkError(let underlying):
        print("Network error: \(underlying.localizedDescription)")
    default:
        print("Error: \(error.localizedDescription)")
    }

    // Convenience checks
    if error.isNotFound {
        print("Resource not found")
    } else if error.isPermissionDenied {
        print("Access denied")
    } else if error.isAuthenticationError {
        print("Authentication required")
    }
}
```

### Pagination

```swift
let response = try await client.request("User:list", method: .get, params: ["page": 1])

if let paging = response.paging {
    print("Page \(paging.pageNo) of \(paging.pageMax)")
    print("Total items: \(paging.count)")

    if paging.hasNextPage {
        // Fetch next page
    }
}
```

### Debug Mode

```swift
// Enable debug logging
await client.setDebug(true)

// Requests and responses will be logged:
// ➡️ POST https://api.example.com/_special/rest/User:create
//    Params: ["name": "John"]
// ✅ 200
//    {"result":"success","data":{"id":"user-123"}}
```

## API Reference

### RestClientConfig

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `scheme` | String | `"https"` | URL scheme |
| `host` | String | `"www.atonline.com"` | API host |
| `restPath` | String | `"/_special/rest/"` | Base path for REST endpoints |
| `clientId` | String? | `nil` | Client ID header |
| `requestTimeout` | TimeInterval | `60` | Request timeout in seconds |
| `uploadResourceTimeout` | TimeInterval | `3600` | Upload timeout in seconds |

### HTTPMethod

- `.get` - GET request (params in URL)
- `.post` - POST request (params in body)
- `.put` - PUT request (params in body)
- `.patch` - PATCH request (params in body)
- `.delete` - DELETE request
- `.head` - HEAD request
- `.options` - OPTIONS request

### RestError

| Case | Description |
|------|-------------|
| `.invalidURL` | Invalid URL constructed |
| `.invalidResponse` | Server returned invalid response |
| `.noData` | No data in response |
| `.httpError` | HTTP status code error |
| `.apiError` | API-level error from server |
| `.tokenExpired` | Authentication token expired |
| `.loginRequired` | Authentication required |
| `.uploadFailed` | File upload failed |
| `.networkError` | Network connectivity error |

## License

BSD 3-Clause License. See [LICENSE](LICENSE) for details.
