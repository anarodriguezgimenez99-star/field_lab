import Foundation
import FieldCore
import FieldMCP
import SwiftUI

#if os(macOS)
import AppKit
import Network
import Security
import MCP

@MainActor
final class MCPServerManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isStarting = false
    @Published private(set) var isStopping = false
    @Published private(set) var port: UInt16 = 8765
    @Published private(set) var token: String
    @Published private(set) var lastError: String?

    private var preferredPort: UInt16
    private let repository: FieldRepository
    private let authHeaderHelperPath: String?
    private var server: LocalMCPServer?

    init(repository: FieldRepository) {
        self.repository = repository
        preferredPort = Self.configuredPort()
        port = preferredPort
        let savedToken = KeychainTokenStore.load() ?? UUID().uuidString.replacingOccurrences(of: "-", with: "")
        token = savedToken
        KeychainTokenStore.save(savedToken)
        authHeaderHelperPath = MCPKeychainHeaderHelper.install()
    }

    private static func configuredPort() -> UInt16 {
        guard let value = ProcessInfo.processInfo.environment["FIELD_MCP_PORT"],
              let port = UInt16(value), (8765...8800).contains(port) else {
            return 8765
        }
        return port
    }

    var endpoint: String { "http://127.0.0.1:\(port)/mcp" }

    var codexSetup: String {
        var configuration = """
        [mcp_servers.field]
        url = "\(endpoint)"
        """
        if let authHeaderHelperPath {
            configuration += "\nhttp_headers_helper = \(Self.tomlString(Self.shellQuoted(authHeaderHelperPath)))\n"
        } else {
            configuration += "\nbearer_token_env_var = \"FIELD_MCP_TOKEN\"\n"
        }
        return configuration
    }

    var claudeCodeSetup: String {
        var jsonObject: [String: Any] = ["type": "http", "url": endpoint]
        if let authHeaderHelperPath {
            jsonObject["headersHelper"] = Self.shellQuoted(authHeaderHelperPath)
        } else {
            jsonObject["headers"] = ["Authorization": "Bearer ${FIELD_MCP_TOKEN}"]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys, .withoutEscapingSlashes]),
              let json = String(data: data, encoding: .utf8) else {
            return "No se pudo generar la configuración de Claude Code."
        }
        return "claude mcp add-json field \(Self.shellQuoted(json)) --scope user"
    }

    var setupPrompt: String {
        """
        Conecta Field LAB a este cliente como servidor MCP HTTP local.

        Endpoint: \(endpoint)
        Autenticación: Authorization: Bearer, con credencial guardada en el Llavero de macOS.
        Alcance: solo este Mac, enlazado a 127.0.0.1.

        Detecta si estás en Codex o Claude Code y configura el servidor con el alcance de usuario. Para Codex, usa esta entrada TOML:
        \(codexSetup)

        Para Claude Code, usa este comando:
        \(claudeCodeSetup)

        \(authHeaderHelperPath == nil ? "El helper del Llavero no está disponible. Usa FIELD_MCP_TOKEN en el entorno del cliente y pídeme que la configure localmente si no existe." : "Los snippets usan un helper local que obtiene el token del Llavero al conectar.")
        No incluyas el token en este chat, en el historial de comandos ni en archivos del proyecto. Después verifica la conexión y dime cómo quedó.

        Si usas otro cliente MCP, configúralo con transporte HTTP Streamable y la misma autenticación. Si no puede ejecutar un helper de cabeceras local, usa FIELD_MCP_TOKEN como variable de entorno y pídeme que la configure fuera del chat.

        Field LAB permite leer y buscar conocimiento, guardar notas de trabajo y proponer cambios permanentes para aprobación humana. No afirmes que una propuesta se guardó como conocimiento canónico.
        """
    }

    func start() {
        guard !isRunning, !isStarting, !isStopping else { return }
        isStarting = true
        lastError = nil
        let repository = repository
        let token = token
        let preferredPort = preferredPort
        Task { [weak self] in
            do {
                let (server, boundPort) = try await Self.startServer(repository: repository, token: token, preferredPort: preferredPort)
                await MainActor.run {
                    self?.server = server
                    self?.port = boundPort
                    self?.preferredPort = boundPort
                    self?.isRunning = true
                    self?.isStarting = false
                }
            } catch {
                await MainActor.run {
                    self?.lastError = error.localizedDescription
                    self?.isStarting = false
                }
            }
        }
    }

    func stop() {
        guard isRunning, !isStopping else { return }
        let server = server
        self.server = nil
        isRunning = false
        isStopping = true
        Task { [weak self] in
            await server?.stop()
            await MainActor.run { self?.isStopping = false }
        }
    }

    func regenerateToken() {
        guard !isStarting, !isStopping else { return }
        let replacementToken = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        guard isRunning else {
            token = replacementToken
            KeychainTokenStore.save(replacementToken)
            return
        }

        let runningServer = server
        server = nil
        isRunning = false
        isStopping = true
        Task { [weak self] in
            await runningServer?.stop()
            await MainActor.run {
                guard let self else { return }
                self.token = replacementToken
                KeychainTokenStore.save(replacementToken)
                self.isStopping = false
            }
        }
    }

    private static func startServer(repository: FieldRepository, token: String, preferredPort: UInt16) async throws -> (LocalMCPServer, UInt16) {
        let candidates = Array(preferredPort...UInt16(8800)) + Array(UInt16(8765)..<preferredPort)
        for candidatePort in candidates {
            let candidate = try LocalMCPServer(repository: repository, token: token, port: candidatePort)
            do {
                try await candidate.start()
                guard let boundPort = candidate.boundPort else { throw LocalMCPServerError.couldNotReadBoundPort }
                return (candidate, boundPort)
            } catch {
                await candidate.stop()
                guard isMCPAddressInUse(error) else { throw error }
            }
        }
        throw LocalMCPServerError.noPortsAvailable
    }

    var usesKeychainHeaderHelper: Bool { authHeaderHelperPath != nil }

    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func tomlString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

private enum LocalMCPServerError: LocalizedError {
    case noPortsAvailable
    case couldNotReadBoundPort

    var errorDescription: String? {
        switch self {
        case .noPortsAvailable:
            "No hay puertos libres entre 8765 y 8800. Cierra el servicio que los ocupa e inténtalo de nuevo."
        case .couldNotReadBoundPort:
            "El servidor se inició, pero no se pudo confirmar el puerto asignado."
        }
    }
}

private func isMCPAddressInUse(_ error: Error) -> Bool {
    guard let networkError = error as? NWError,
          case .posix(let code) = networkError else { return false }
    return code == .EADDRINUSE
}

private final class LocalMCPServer: @unchecked Sendable {
    private let mcpServer: MCP.Server
    private let transport: StatelessHTTPServerTransport
    private let httpServer: LocalHTTPServer
    private let repository: FieldRepository

    init(repository: FieldRepository, token: String, port: UInt16) throws {
        self.repository = repository
        mcpServer = MCP.Server(
            name: "Field LAB",
            version: "0.1.0",
            capabilities: .init(
                resources: .init(subscribe: false, listChanged: false),
                tools: .init(listChanged: false)
            )
        )
        transport = StatelessHTTPServerTransport()
        let transport = self.transport
        httpServer = try LocalHTTPServer(port: port, token: token) { request in
            await transport.handleRequest(request)
        }
    }

    func start() async throws {
        try await Self.registerHandlers(server: mcpServer, repository: repository)
        try await mcpServer.start(transport: transport)
        do {
            try await httpServer.start()
        } catch {
            await mcpServer.stop()
            throw error
        }
    }

    func stop() async {
        await httpServer.stop()
        await mcpServer.stop()
    }

    var boundPort: UInt16? { httpServer.boundPort }

    // MCPToolCatalog enumerates each feature's complete capability declarations.
    // Add a feature provider here once; its tools then appear in tools/list and
    // route through the capability registry without edits to the HTTP transport.
    private static let toolFeatures: [any MCPToolFeature.Type] = []

    private static func registerHandlers(server: MCP.Server, repository: FieldRepository) async throws {
        try await MCPToolCatalog.register(on: server, repository: repository, features: toolFeatures)

        await server.withMethodHandler(ListResources.self) { _ in
            .init(resources: [
                Resource(name: "Projects", uri: "field://projects", description: "Field LAB projects"),
                Resource(name: "Tools", uri: "field://tools", description: "Field LAB tools")
            ], nextCursor: nil)
        }

        await server.withMethodHandler(ReadResource.self) { params in
            let value: String = await MainActor.run {
                if params.uri == "field://projects" {
                    repository.logActivity(agent: "mcp-resource-client", action: "read_resource", detail: params.uri)
                    return repository.projects(includeArchived: false).map { "\($0.id.uuidString) · \($0.title)" }.joined(separator: "\n")
                }
                if params.uri == "field://tools" {
                    repository.logActivity(agent: "mcp-resource-client", action: "read_resource", detail: params.uri)
                    return repository.tools().map { "\($0.id.uuidString) · \($0.name)" }.joined(separator: "\n")
                }
                return ""
            }
            guard ["field://projects", "field://tools"].contains(params.uri) else {
                throw MCPError.invalidParams("Unknown Field LAB resource: \(params.uri)")
            }
            return .init(contents: [.text(value, uri: params.uri, mimeType: "text/plain")])
        }
    }
}

private final class LocalHTTPServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "com.field.mcp.http")
    private let token: String
    private let requestHandler: @Sendable (HTTPRequest) async -> HTTPResponse
    private(set) var boundPort: UInt16?

    init(port: UInt16, token: String, requestHandler: @escaping @Sendable (HTTPRequest) async -> HTTPResponse) throws {
        self.token = token
        self.requestHandler = requestHandler
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = false
        let localPort = NWEndpoint.Port(rawValue: port)!
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: localPort)
        listener = try NWListener(using: parameters, on: localPort)
    }

    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Swift.Error>) in
            let gate = ContinuationGate()
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready where gate.claim():
                    self.boundPort = self.listener.port?.rawValue
                    continuation.resume()
                case .failed(let error) where gate.claim():
                    continuation.resume(throwing: error)
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
        }
    }

    func stop() async {
        listener.cancel()
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        Task { [weak self] in
            guard let self else { return }
            let data = await self.readRequest(connection)
            guard let request = self.parse(data), request.path == "/mcp" else {
                self.send(status: 404, headers: [:], body: Data("Not Found".utf8), on: connection)
                return
            }
            guard request.method.uppercased() == "POST" else {
                self.send(status: 405, headers: ["Allow": "POST"], body: Data("Method Not Allowed".utf8), on: connection)
                return
            }
            guard MCPRequestAuthenticator.isAuthorized(authorization: request.header("Authorization"), token: self.token) else {
                self.send(status: 401, headers: ["WWW-Authenticate": "Bearer"], body: Data("Unauthorized".utf8), on: connection)
                return
            }
            let response = await self.requestHandler(request)
            switch response {
            case .stream:
                self.send(status: 501, headers: [:], body: Data("Streaming is not enabled in Field LAB's stateless transport.".utf8), on: connection)
            default:
                self.send(status: response.statusCode, headers: response.headers, body: response.bodyData ?? Data(), on: connection)
            }
        }
    }

    private func readRequest(_ connection: NWConnection) async -> Data {
        var buffer = Data()
        while buffer.range(of: Data("\r\n\r\n".utf8)) == nil && buffer.count < 2_000_000 {
            let chunk = await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, _ in
                    continuation.resume(returning: data ?? (isComplete ? Data() : Data()))
                }
            }
            buffer.append(chunk)
            if chunk.isEmpty { break }
        }
        guard let separator = buffer.range(of: Data("\r\n\r\n".utf8)) else { return buffer }
        let headerText = String(decoding: buffer[..<separator.lowerBound], as: UTF8.self)
        let contentLength = headerText.split(separator: "\n").first(where: { $0.lowercased().contains("content-length") }).flatMap { Int($0.split(separator: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "0") } ?? 0
        let bodyStart = separator.upperBound
        while buffer.count - bodyStart < contentLength {
            let chunk = await withCheckedContinuation { (continuation: CheckedContinuation<Data, Never>) in
                connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, _, _ in continuation.resume(returning: data ?? Data()) }
            }
            buffer.append(chunk)
            if chunk.isEmpty { break }
        }
        return buffer
    }

    private func parse(_ data: Data) -> HTTPRequest? {
        guard let separator = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerText = String(decoding: data[..<separator.lowerBound], as: UTF8.self)
        let lines = headerText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let components = line.split(separator: ":", maxSplits: 1).map(String.init)
            if components.count == 2 { headers[components[0].trimmingCharacters(in: .whitespaces)] = components[1].trimmingCharacters(in: .whitespaces) }
        }
        return HTTPRequest(method: String(parts[0]), headers: headers, body: Data(data[separator.upperBound...]), path: String(parts[1]))
    }

    private func send(status: Int, headers: [String: String], body: Data, on connection: NWConnection) {
        let reason: String = [200: "OK", 202: "Accepted", 400: "Bad Request", 401: "Unauthorized", 404: "Not Found", 405: "Method Not Allowed", 500: "Internal Server Error", 501: "Not Implemented"][status] ?? "Response"
        var allHeaders = headers
        allHeaders["Content-Length"] = String(body.count)
        allHeaders["Connection"] = "close"
        if allHeaders["Content-Type"] == nil { allHeaders["Content-Type"] = "application/json" }
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        allHeaders.forEach { head += "\($0.key): \($0.value)\r\n" }
        head += "\r\n"
        var output = Data(head.utf8)
        output.append(body)
        connection.send(content: output, completion: .contentProcessed { _ in connection.cancel() })
    }
}

private final class ContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var hasClaimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !hasClaimed else { return false }
        hasClaimed = true
        return true
    }
}

private enum KeychainTokenStore {
    fileprivate static let service = "com.field.app.mcp"
    fileprivate static let account = "local-token"

    static func load() -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let attributes: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) != errSecSuccess { var item = query; item[kSecValueData as String] = data; SecItemAdd(item as CFDictionary, nil) }
    }
}

private enum MCPKeychainHeaderHelper {
    private static var script: String {
        """
        #!/bin/sh
        set -eu
        token=$(/usr/bin/security find-generic-password -s '\(KeychainTokenStore.service)' -a '\(KeychainTokenStore.account)' -w)
        [ -n "$token" ]
        /usr/bin/printf '{"Authorization":"Bearer %s"}\\n' "$token"
        """
    }

    static func install() -> String? {
        let fileManager = FileManager.default
        guard let support = try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else { return nil }
        let directory = support.appendingPathComponent("Field LAB/MCP", isDirectory: true)
        let helper = directory.appendingPathComponent("auth-headers", isDirectory: false)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(script.utf8).write(to: helper, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: helper.path)
            return helper.path
        } catch {
            return nil
        }
    }
}

#else

@MainActor
final class MCPServerManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isStarting = false
    @Published private(set) var isStopping = false
    @Published private(set) var port: UInt16 = 8765
    @Published private(set) var token = "Unavailable on this platform"
    var endpoint: String { "MCP is available on macOS" }
    var codexSetup: String { "Run Field LAB on macOS to enable its local MCP server." }
    var claudeCodeSetup: String { "Run Field LAB on macOS to enable its local MCP server." }
    var setupPrompt: String { "Run Field LAB on macOS to enable its local MCP server." }
    var usesKeychainHeaderHelper: Bool { false }
    init(repository: FieldRepository) {}
    func start() {}
    func stop() {}
    func regenerateToken() {}
}

#endif
