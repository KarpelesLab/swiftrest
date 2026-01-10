import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Main REST API client for communicating with KarpelesLab-style REST endpoints
public actor RestClient {
    /// Default shared instance
    public static let shared = RestClient()

    /// Configuration for the client
    public let config: RestClientConfig

    /// URL session for regular requests
    private let session: URLSession

    /// URL session for uploads (longer timeout)
    private let uploadSession: URLSession

    /// Current authentication
    private var authentication: RestAuthentication?

    /// Debug mode - logs requests and responses
    public var debug: Bool = false

    /// Initialize with configuration
    public init(config: RestClientConfig = .default) {
        self.config = config

        let regularConfig = URLSessionConfiguration.default
        regularConfig.timeoutIntervalForRequest = config.requestTimeout
        regularConfig.timeoutIntervalForResource = config.resourceTimeout
        regularConfig.httpMaximumConnectionsPerHost = config.maxConnectionsPerHost
        self.session = URLSession(configuration: regularConfig)

        let uploadConfig = URLSessionConfiguration.default
        uploadConfig.timeoutIntervalForRequest = config.uploadRequestTimeout
        uploadConfig.timeoutIntervalForResource = config.uploadResourceTimeout
        uploadConfig.httpMaximumConnectionsPerHost = config.maxConnectionsPerHost
        self.uploadSession = URLSession(configuration: uploadConfig)
    }

    /// Set the authentication method
    public func setAuthentication(_ auth: RestAuthentication?) {
        self.authentication = auth
    }

    /// Enable or disable debug logging
    public func setDebug(_ enabled: Bool) {
        self.debug = enabled
    }

    /// Get current authentication
    public func getAuthentication() -> RestAuthentication? {
        return self.authentication
    }

    // MARK: - Request Methods

    /// Perform a request and decode the response
    public func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        params: [String: Any]? = nil
    ) async throws -> T {
        let response = try await performRequest(endpoint, method: method, params: params)
        return try response.decode()
    }

    /// Perform a request and return the raw response
    public func request(
        _ endpoint: String,
        method: HTTPMethod = .get,
        params: [String: Any]? = nil
    ) async throws -> RestResponse {
        return try await performRequest(endpoint, method: method, params: params)
    }

    /// Perform a request with automatic token refresh on expiration
    public func requestWithRetry<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        params: [String: Any]? = nil
    ) async throws -> T {
        do {
            return try await request(endpoint, method: method, params: params)
        } catch let error as RestError {
            if case .tokenExpired = error, let auth = authentication as? TokenAuthentication {
                try await auth.refresh(using: self)
                return try await request(endpoint, method: method, params: params)
            }
            if case .redirect = error, let auth = authentication as? TokenAuthentication {
                // Redirect might mean auth is invalid - try refresh
                try await auth.refresh(using: self)
                return try await request(endpoint, method: method, params: params)
            }
            throw error
        }
    }

    // MARK: - Authentication-Required Requests

    /// Perform a request that requires authentication
    /// Throws `loginRequired` if no authentication is configured
    public func authRequest<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        params: [String: Any]? = nil
    ) async throws -> T {
        guard authentication != nil else {
            throw RestError.loginRequired
        }
        return try await request(endpoint, method: method, params: params)
    }

    /// Perform a request that requires authentication (raw response)
    /// Throws `loginRequired` if no authentication is configured
    public func authRequest(
        _ endpoint: String,
        method: HTTPMethod = .get,
        params: [String: Any]? = nil
    ) async throws -> RestResponse {
        guard authentication != nil else {
            throw RestError.loginRequired
        }
        return try await performRequest(endpoint, method: method, params: params)
    }

    /// Perform an authentication-required request with automatic token refresh
    /// Throws `loginRequired` if no authentication is configured
    public func authRequestWithRetry<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        params: [String: Any]? = nil
    ) async throws -> T {
        guard authentication != nil else {
            throw RestError.loginRequired
        }
        do {
            return try await request(endpoint, method: method, params: params)
        } catch let error as RestError {
            // Token expired or redirect (server might redirect to login when token is invalid)
            if case .tokenExpired = error, let auth = authentication as? TokenAuthentication {
                try await auth.refresh(using: self)
                return try await request(endpoint, method: method, params: params)
            }
            if case .redirect = error, let auth = authentication as? TokenAuthentication {
                // Redirect might mean auth is required/invalid - try refresh
                try await auth.refresh(using: self)
                return try await request(endpoint, method: method, params: params)
            }
            throw error
        }
    }

    /// Perform an authentication-required request with automatic token refresh (raw response)
    /// Throws `loginRequired` if no authentication is configured
    public func authRequestWithRetry(
        _ endpoint: String,
        method: HTTPMethod = .get,
        params: [String: Any]? = nil
    ) async throws -> RestResponse {
        guard authentication != nil else {
            throw RestError.loginRequired
        }
        do {
            return try await performRequest(endpoint, method: method, params: params)
        } catch let error as RestError {
            // Token expired or redirect (server might redirect to login when token is invalid)
            if case .tokenExpired = error, let auth = authentication as? TokenAuthentication {
                try await auth.refresh(using: self)
                return try await performRequest(endpoint, method: method, params: params)
            }
            if case .redirect = error, let auth = authentication as? TokenAuthentication {
                // Redirect might mean auth is required/invalid - try refresh
                try await auth.refresh(using: self)
                return try await performRequest(endpoint, method: method, params: params)
            }
            throw error
        }
    }

    // MARK: - Optionally-Authenticated Requests

    /// Perform a request that optionally uses authentication
    /// If auth is configured, uses it; otherwise makes unauthenticated request
    public func optAuthRequest<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        params: [String: Any]? = nil
    ) async throws -> T {
        // Just use the normal request - it will apply auth if available
        return try await request(endpoint, method: method, params: params)
    }

    /// Perform a request that optionally uses authentication (raw response)
    /// If auth is configured, uses it; otherwise makes unauthenticated request
    public func optAuthRequest(
        _ endpoint: String,
        method: HTTPMethod = .get,
        params: [String: Any]? = nil
    ) async throws -> RestResponse {
        // Just use the normal request - it will apply auth if available
        return try await performRequest(endpoint, method: method, params: params)
    }

    /// Perform an optionally-authenticated request with automatic token refresh
    /// If auth is configured, uses it with refresh; otherwise makes unauthenticated request
    public func optAuthRequestWithRetry<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        params: [String: Any]? = nil
    ) async throws -> T {
        // If no auth, just make unauthenticated request
        guard authentication != nil else {
            return try await request(endpoint, method: method, params: params)
        }
        // Otherwise use retry logic
        do {
            return try await request(endpoint, method: method, params: params)
        } catch let error as RestError {
            if case .tokenExpired = error, let auth = authentication as? TokenAuthentication {
                try await auth.refresh(using: self)
                return try await request(endpoint, method: method, params: params)
            }
            if case .redirect = error, let auth = authentication as? TokenAuthentication {
                // Redirect might mean auth is invalid - try refresh
                try await auth.refresh(using: self)
                return try await request(endpoint, method: method, params: params)
            }
            throw error
        }
    }

    /// Perform an optionally-authenticated request with automatic token refresh (raw response)
    /// If auth is configured, uses it with refresh; otherwise makes unauthenticated request
    public func optAuthRequestWithRetry(
        _ endpoint: String,
        method: HTTPMethod = .get,
        params: [String: Any]? = nil
    ) async throws -> RestResponse {
        // If no auth, just make unauthenticated request
        guard authentication != nil else {
            return try await performRequest(endpoint, method: method, params: params)
        }
        // Otherwise use retry logic
        do {
            return try await performRequest(endpoint, method: method, params: params)
        } catch let error as RestError {
            if case .tokenExpired = error, let auth = authentication as? TokenAuthentication {
                try await auth.refresh(using: self)
                return try await performRequest(endpoint, method: method, params: params)
            }
            if case .redirect = error, let auth = authentication as? TokenAuthentication {
                // Redirect might mean auth is invalid - try refresh
                try await auth.refresh(using: self)
                return try await performRequest(endpoint, method: method, params: params)
            }
            throw error
        }
    }

    // MARK: - Raw/Nude Requests (bypass RestResponse parsing)

    /// Perform a request and decode the response directly (no result/data wrapper)
    /// Use for endpoints that return raw JSON (e.g., OAuth2 token endpoint)
    public func requestRaw<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        params: [String: Any]? = nil
    ) async throws -> T {
        let request = try await buildRequest(endpoint, method: method, params: params)

        if debug {
            logRequest(request, params: params)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RestError.invalidResponse
        }

        if debug {
            logResponse(httpResponse, data: data)
        }

        // Check for HTTP errors
        guard (200..<300).contains(httpResponse.statusCode) else {
            // Try to parse error from response
            var errorMessage: String? = nil
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                errorMessage = json["error"] as? String ?? json["error_description"] as? String ?? json["message"] as? String
            } else if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                errorMessage = text
            }
            throw RestError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        // Decode directly from response body
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Internal Request Handling

    private func performRequest(
        _ endpoint: String,
        method: HTTPMethod,
        params: [String: Any]?
    ) async throws -> RestResponse {
        let request = try await buildRequest(endpoint, method: method, params: params)

        if debug {
            print("🌐 REST: \(method.rawValue) \(endpoint)")
        }

        if debug {
            logRequest(request, params: params)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RestError.invalidResponse
        }

        if debug {
            logResponse(httpResponse, data: data)
        }

        let requestId = httpResponse.value(forHTTPHeaderField: "X-Request-Id")

        return try RestResponse(
            data: data,
            httpResponse: httpResponse,
            requestId: requestId
        )
    }

    private func buildRequest(
        _ endpoint: String,
        method: HTTPMethod,
        params: [String: Any]?
    ) async throws -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = config.scheme
        urlComponents.host = config.host
        urlComponents.path = config.restPath + endpoint

        var queryItems = config.contextParams.map { URLQueryItem(name: $0.key, value: $0.value) }

        // For GET/HEAD/OPTIONS, encode params as JSON in _ query parameter
        if method.encodesParamsInURL, let params = params {
            let jsonData = try JSONSerialization.data(withJSONObject: params)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                queryItems.append(URLQueryItem(name: "_", value: jsonString))
            }
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw RestError.invalidURL(endpoint)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("false", forHTTPHeaderField: "Sec-Rest-Http")

        if let clientId = config.clientId {
            request.setValue(clientId, forHTTPHeaderField: "Sec-ClientId")
        }

        // For POST/PUT/PATCH, encode params as JSON body
        if method.encodesParamsInBody, let params = params {
            let jsonData = try JSONSerialization.data(withJSONObject: params)
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        // Apply authentication
        if let auth = authentication {
            request = try await auth.sign(request: request)
        }

        return request
    }

    // MARK: - Logging

    private func logRequest(_ request: URLRequest, params: [String: Any]?) {
        print("➡️ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")")
        if let params = params {
            print("   Params: \(params)")
        }
    }

    private func logResponse(_ response: HTTPURLResponse, data: Data) {
        let emoji = (200..<300).contains(response.statusCode) ? "✅" : "❌"
        print("\(emoji) \(response.statusCode)")
        if let str = String(data: data.prefix(500), encoding: .utf8) {
            print("   \(str)")
        }
    }
}

// MARK: - Upload Support

extension RestClient {

    /// Upload a file using the chunked upload protocol
    public func upload<T: Decodable>(
        _ endpoint: String,
        file: URL,
        params: [String: Any] = [:],
        progress: ((Double) -> Void)? = nil
    ) async throws -> T {
        let response = try await uploadFile(endpoint, file: file, params: params, progress: progress)
        return try response.decode()
    }

    /// Upload data using the chunked upload protocol
    public func upload<T: Decodable>(
        _ endpoint: String,
        data: Data,
        filename: String,
        mimeType: String,
        params: [String: Any] = [:],
        progress: ((Double) -> Void)? = nil
    ) async throws -> T {
        let response = try await uploadData(
            endpoint,
            data: data,
            filename: filename,
            mimeType: mimeType,
            params: params,
            progress: progress
        )
        return try response.decode()
    }

    private func uploadFile(
        _ endpoint: String,
        file: URL,
        params: [String: Any],
        progress: ((Double) -> Void)?
    ) async throws -> RestResponse {
        // Get file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
        guard let fileSize = attributes[.size] as? Int64, fileSize > 0 else {
            throw RestError.uploadFailed("Invalid file size")
        }

        let filename = file.lastPathComponent
        let mimeType = mimeTypeForPath(file.path)
        let modTime = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? Date().timeIntervalSince1970

        // Phase 1: Negotiate upload
        var negotiateParams = params
        negotiateParams["filename"] = filename
        negotiateParams["size"] = fileSize
        negotiateParams["type"] = mimeType
        negotiateParams["lastModified"] = Int64(modTime * 1000)

        let negotiateResponse = try await performRequest(endpoint, method: .post, params: negotiateParams)
        let uploadInfo = try negotiateResponse.decode(as: UploadNegotiationResponse.self)

        // Phase 2: Upload chunks
        let fileHandle = try FileHandle(forReadingFrom: file)
        defer { try? fileHandle.close() }

        try await uploadChunks(
            to: uploadInfo.put,
            fileHandle: fileHandle,
            fileSize: fileSize,
            blockSize: uploadInfo.blocksize ?? Int(fileSize),
            mimeType: mimeType,
            progress: progress
        )

        // Phase 3: Complete upload
        return try await performRequest(uploadInfo.complete, method: .post, params: [:])
    }

    private func uploadData(
        _ endpoint: String,
        data: Data,
        filename: String,
        mimeType: String,
        params: [String: Any],
        progress: ((Double) -> Void)?
    ) async throws -> RestResponse {
        let fileSize = Int64(data.count)

        // Phase 1: Negotiate upload
        var negotiateParams = params
        negotiateParams["filename"] = filename
        negotiateParams["size"] = fileSize
        negotiateParams["type"] = mimeType
        negotiateParams["lastModified"] = Int64(Date().timeIntervalSince1970 * 1000)

        let negotiateResponse = try await performRequest(endpoint, method: .post, params: negotiateParams)
        let uploadInfo = try negotiateResponse.decode(as: UploadNegotiationResponse.self)

        // Phase 2: Upload chunks
        let blockSize = uploadInfo.blocksize ?? data.count
        let totalChunks = (data.count + blockSize - 1) / blockSize

        for chunkIndex in 0..<totalChunks {
            let startByte = chunkIndex * blockSize
            let endByte = min(startByte + blockSize, data.count)
            let chunkData = data[startByte..<endByte]

            try await uploadChunk(
                to: uploadInfo.put,
                data: Data(chunkData),
                startByte: startByte,
                endByte: endByte - 1,
                mimeType: mimeType
            )

            progress?(Double(chunkIndex + 1) / Double(totalChunks))
        }

        // Phase 3: Complete upload
        return try await performRequest(uploadInfo.complete, method: .post, params: [:])
    }

    private func uploadChunks(
        to url: String,
        fileHandle: FileHandle,
        fileSize: Int64,
        blockSize: Int,
        mimeType: String,
        progress: ((Double) -> Void)?
    ) async throws {
        let totalChunks = (Int(fileSize) + blockSize - 1) / blockSize

        for chunkIndex in 0..<totalChunks {
            let startByte = chunkIndex * blockSize
            let endByte = min(startByte + blockSize, Int(fileSize))
            let chunkLength = endByte - startByte

            try fileHandle.seek(toOffset: UInt64(startByte))
            guard let chunkData = try fileHandle.read(upToCount: chunkLength) else {
                throw RestError.uploadFailed("Failed to read chunk at offset \(startByte)")
            }

            try await uploadChunk(
                to: url,
                data: chunkData,
                startByte: startByte,
                endByte: endByte - 1,
                mimeType: mimeType
            )

            progress?(Double(chunkIndex + 1) / Double(totalChunks))
        }
    }

    private func uploadChunk(
        to urlString: String,
        data: Data,
        startByte: Int,
        endByte: Int,
        mimeType: String
    ) async throws {
        guard let url = URL(string: urlString) else {
            throw RestError.invalidURL(urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.setValue("bytes \(startByte)-\(endByte)/*", forHTTPHeaderField: "Content-Range")

        if let auth = authentication {
            request = try await auth.sign(request: request)
        }

        let (responseData, response) = try await uploadSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RestError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            // Try to extract error message from response body
            var errorMessage: String? = nil
            if let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                errorMessage = json["error"] as? String ?? json["error_description"] as? String ?? json["message"] as? String
            } else if let text = String(data: responseData, encoding: .utf8), !text.isEmpty {
                errorMessage = text
            }
            throw RestError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }

    private func mimeTypeForPath(_ path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "mp4": return "video/mp4"
        case "mov": return "video/quicktime"
        case "webm": return "video/webm"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        case "pdf": return "application/pdf"
        case "json": return "application/json"
        case "txt": return "text/plain"
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "xml": return "application/xml"
        case "zip": return "application/zip"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Upload Response Types

private struct UploadNegotiationResponse: Decodable {
    let put: String
    let complete: String
    let blocksize: Int?

    enum CodingKeys: String, CodingKey {
        case put = "PUT"
        case complete = "Complete"
        case blocksize = "Blocksize"
    }
}
