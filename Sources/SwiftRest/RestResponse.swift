import Foundation

/// Response from a REST API call
public struct RestResponse: @unchecked Sendable {
    /// The result status: "success", "error", or "redirect"
    public let result: String

    /// The raw data payload
    public let rawData: Data

    /// Parsed data as JSON (can be dictionary, array, or other JSON types)
    public let data: Any?

    /// Error message if result is "error"
    public let error: String?

    /// Error code (HTTP-like)
    public let code: Int?

    /// Additional error information
    public let extra: String?

    /// Token status
    public let token: String?

    /// Paging information
    public let paging: PagingInfo?

    /// Request ID from response header
    public let requestId: String?

    /// HTTP status code
    public let httpStatusCode: Int

    /// Redirect URL if result is "redirect"
    public let redirectUrl: String?

    /// Access permissions for objects (keyed by object ID)
    public let access: [String: AccessInfo]?

    // MARK: - Convenience accessors

    /// Get data as a dictionary (for single object responses)
    public var dataDict: [String: Any]? {
        return data as? [String: Any]
    }

    /// Get data as an array (for list responses)
    public var dataArray: [[String: Any]]? {
        return data as? [[String: Any]]
    }

    /// Check if data is an array
    public var isDataArray: Bool {
        return data is [Any]
    }

    /// Check if data is a dictionary
    public var isDataDict: Bool {
        return data is [String: Any]
    }

    /// Initialize from HTTP response data
    init(data: Data, httpResponse: HTTPURLResponse, requestId: String?) throws {
        self.rawData = data
        self.httpStatusCode = httpResponse.statusCode
        self.requestId = requestId

        // Parse JSON response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            #if DEBUG
            if let rawString = String(data: data, encoding: .utf8) {
                print("🔴 REST Invalid JSON response: \(rawString.prefix(500))")
            }
            #endif
            throw RestError.invalidResponse
        }

        #if DEBUG
        // Log successful responses for debugging OAuth issues
        if let result = json["result"] as? String, result == "success" {
            print("✅ REST Response: result=\(result), data keys=\((json["data"] as? [String: Any])?.keys.sorted() ?? [])")
        }
        #endif

        self.result = json["result"] as? String ?? "error"
        self.error = json["error"] as? String
        self.code = json["code"] as? Int
        self.extra = json["extra"] as? String
        self.token = json["token"] as? String
        self.redirectUrl = json["redirect_url"] as? String

        // Parse paging info
        if let pagingDict = json["paging"] as? [String: Any] {
            self.paging = PagingInfo(from: pagingDict)
        } else {
            self.paging = nil
        }

        // Parse access info
        if let accessDict = json["access"] as? [String: [String: Any]] {
            var accessMap: [String: AccessInfo] = [:]
            for (objectId, accessData) in accessDict {
                accessMap[objectId] = AccessInfo(from: accessData)
            }
            self.access = accessMap
        } else {
            self.access = nil
        }

        // Store the data payload
        self.data = json["data"]

        // Check for errors
        if self.result == "error" {
            // Debug: log error details
            #if DEBUG
            print("🔴 REST API Error: message=\(self.error ?? "nil"), token=\(self.token ?? "nil"), extra=\(self.extra ?? "nil"), code=\(self.code ?? -1)")
            // Log full JSON when error has no message (helps debug OAuth issues)
            if self.error == nil {
                if let rawString = String(data: data, encoding: .utf8) {
                    print("🔴 REST Full error response: \(rawString.prefix(1000))")
                }
            }
            #endif

            // Check for token expiration (various formats the API might use)
            if self.token == "invalid_request_token" && self.extra == "token_expired" {
                throw RestError.tokenExpired
            }
            // Also check for 401 HTTP status or explicit token errors
            if self.code == 401 || self.extra == "token_expired" || self.error?.contains("token") == true {
                throw RestError.tokenExpired
            }

            throw RestError.apiError(
                message: self.error ?? "Unknown error",
                code: self.code,
                extra: self.extra,
                requestId: requestId
            )
        }

        // Check for redirect (often means login required)
        if self.result == "redirect" {
            #if DEBUG
            print("🔄 REST API Redirect: url=\(self.redirectUrl ?? "nil")")
            #endif
            throw RestError.redirect(url: self.redirectUrl ?? "")
        }
    }

    /// Decode the data payload to a specific type
    public func decode<T: Decodable>(as type: T.Type = T.self) throws -> T {
        guard let dataValue = data else {
            throw RestError.noData
        }

        let jsonData = try JSONSerialization.data(withJSONObject: dataValue)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let timestamp = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: timestamp)
            }
            if let string = try? container.decode(String.self) {
                let formatter = ISO8601DateFormatter()
                if let date = formatter.date(from: string) {
                    return date
                }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
        }
        return try decoder.decode(type, from: jsonData)
    }

    /// Get a value at a path (e.g., "user/name")
    public func get(_ path: String) -> Any? {
        let components = path.split(separator: "/")
        var current: Any? = data

        for component in components {
            if let dict = current as? [String: Any] {
                current = dict[String(component)]
            } else if let array = current as? [Any], let index = Int(component) {
                if index >= 0 && index < array.count {
                    current = array[index]
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }

        return current
    }

    /// Get a string value at a path
    public func getString(_ path: String) -> String? {
        return get(path) as? String
    }

    /// Get an integer value at a path
    public func getInt(_ path: String) -> Int? {
        if let int = get(path) as? Int {
            return int
        }
        if let string = get(path) as? String {
            return Int(string)
        }
        return nil
    }

    /// Get a boolean value at a path
    public func getBool(_ path: String) -> Bool? {
        if let bool = get(path) as? Bool {
            return bool
        }
        if let int = get(path) as? Int {
            return int != 0
        }
        if let string = get(path) as? String {
            return string == "true" || string == "1"
        }
        return nil
    }
}

/// Paging information from response
public struct PagingInfo: Sendable {
    public let pageNo: Int
    public let count: Int
    public let pageMax: Int
    public let resultsPerPage: Int

    public var hasNextPage: Bool {
        return pageNo < pageMax
    }

    public var hasPreviousPage: Bool {
        return pageNo > 1
    }

    init?(from dict: [String: Any]) {
        guard let pageNo = dict["page_no"] as? Int,
              let count = dict["count"] as? Int,
              let pageMax = dict["page_max"] as? Int,
              let resultsPerPage = dict["results_per_page"] as? Int else {
            return nil
        }
        self.pageNo = pageNo
        self.count = count
        self.pageMax = pageMax
        self.resultsPerPage = resultsPerPage
    }
}

/// Access permission information for an object
public struct AccessInfo: @unchecked Sendable {
    /// Required permission level (e.g., "R" for read, "W" for write, "A" for admin)
    public let required: String?

    /// Available permission level for the current user
    public let available: String?

    /// Raw access data for additional fields
    public let rawData: [String: Any]

    /// Check if the user can read the object
    public var canRead: Bool {
        guard let available = available else { return false }
        return available.contains("R") || available.contains("W") || available.contains("A")
    }

    /// Check if the user can write/edit the object
    public var canWrite: Bool {
        guard let available = available else { return false }
        return available.contains("W") || available.contains("A")
    }

    /// Check if the user has admin access to the object
    public var canAdmin: Bool {
        guard let available = available else { return false }
        return available.contains("A")
    }

    init(from dict: [String: Any]) {
        self.required = dict["required"] as? String
        self.available = dict["available"] as? String
        self.rawData = dict
    }
}
