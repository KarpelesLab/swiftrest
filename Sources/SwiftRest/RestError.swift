import Foundation

/// Errors that can occur during REST API calls
public enum RestError: Error, Equatable, Sendable {
    /// Invalid URL
    case invalidURL(_ url: String)

    /// Invalid response from server
    case invalidResponse

    /// No data in response
    case noData

    /// HTTP error with status code
    case httpError(statusCode: Int, message: String?)

    /// API error from server
    case apiError(message: String, code: Int?, extra: String?, requestId: String?)

    /// Token has expired
    case tokenExpired

    /// Login required
    case loginRequired

    /// Redirect response
    case redirect(url: String)

    /// Upload failed
    case uploadFailed(_ message: String)

    /// Upload stalled (no progress)
    case uploadStalled

    /// Decoding error
    case decodingError(_ message: String)

    /// Network error
    case networkError(_ underlying: Error)

    /// No refresh token available
    case noRefreshToken

    /// No client ID for token refresh
    case noClientId

    public static func == (lhs: RestError, rhs: RestError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL(let a), .invalidURL(let b)):
            return a == b
        case (.invalidResponse, .invalidResponse):
            return true
        case (.noData, .noData):
            return true
        case (.httpError(let a1, let a2), .httpError(let b1, let b2)):
            return a1 == b1 && a2 == b2
        case (.apiError(let a1, let a2, let a3, let a4), .apiError(let b1, let b2, let b3, let b4)):
            return a1 == b1 && a2 == b2 && a3 == b3 && a4 == b4
        case (.tokenExpired, .tokenExpired):
            return true
        case (.loginRequired, .loginRequired):
            return true
        case (.redirect(let a), .redirect(let b)):
            return a == b
        case (.uploadFailed(let a), .uploadFailed(let b)):
            return a == b
        case (.uploadStalled, .uploadStalled):
            return true
        case (.decodingError(let a), .decodingError(let b)):
            return a == b
        case (.noRefreshToken, .noRefreshToken):
            return true
        case (.noClientId, .noClientId):
            return true
        case (.networkError, .networkError):
            // Cannot compare underlying errors
            return false
        default:
            return false
        }
    }
}

extension RestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response from server"
        case .noData:
            return "No data in response"
        case .httpError(let statusCode, let message):
            if let message = message {
                return "HTTP \(statusCode): \(message)"
            }
            return "HTTP error \(statusCode)"
        case .apiError(let message, let code, let extra, _):
            var desc = message
            if let code = code {
                desc = "[\(code)] \(desc)"
            }
            if let extra = extra {
                desc += " (\(extra))"
            }
            return desc
        case .tokenExpired:
            return "Authentication token has expired"
        case .loginRequired:
            return "Login required"
        case .redirect(let url):
            return "Redirect to: \(url)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .uploadStalled:
            return "Upload stalled (no progress)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .noRefreshToken:
            return "No refresh token available"
        case .noClientId:
            return "No client ID for token refresh"
        }
    }
}

// MARK: - Error Code Mapping

extension RestError {
    /// Check if this is a permission denied error (403)
    public var isPermissionDenied: Bool {
        switch self {
        case .httpError(let code, _) where code == 403:
            return true
        case .apiError(_, let code, _, _) where code == 403:
            return true
        default:
            return false
        }
    }

    /// Check if this is a not found error (404)
    public var isNotFound: Bool {
        switch self {
        case .httpError(let code, _) where code == 404:
            return true
        case .apiError(_, let code, _, _) where code == 404:
            return true
        default:
            return false
        }
    }

    /// Check if this is an authentication error
    public var isAuthenticationError: Bool {
        switch self {
        case .tokenExpired, .loginRequired, .noRefreshToken, .noClientId:
            return true
        case .httpError(let code, _) where code == 401:
            return true
        case .apiError(_, let code, _, _) where code == 401:
            return true
        default:
            return false
        }
    }
}
