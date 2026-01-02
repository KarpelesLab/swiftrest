import Foundation

/// HTTP request methods
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"

    /// Whether parameters should be encoded in the URL query string
    var encodesParamsInURL: Bool {
        switch self {
        case .get, .head, .options:
            return true
        case .post, .put, .patch, .delete:
            return false
        }
    }

    /// Whether parameters should be encoded in the request body
    var encodesParamsInBody: Bool {
        switch self {
        case .post, .put, .patch:
            return true
        case .get, .head, .options, .delete:
            return false
        }
    }
}
