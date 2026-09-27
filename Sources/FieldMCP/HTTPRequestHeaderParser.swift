import Foundation

/// Shares HTTP header line splitting between the local adapter and its tests.
package enum MCPHTTPRequestHeaderParser {
    package static func lines(_ headerText: String) -> [String] {
        headerText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n")
            .map(String.init)
    }
}
