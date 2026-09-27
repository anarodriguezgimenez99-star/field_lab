import Foundation

/// Splits HTTP header text into lines for the local adapter and its clients.
public enum MCPHTTPRequestHeaderParser {
    public static func lines(_ headerText: String) -> [String] {
        headerText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n")
            .map(String.init)
    }
}
