import Foundation

struct HTTPSyncBackend: SyncBackend {
    var baseURLString: String
    var token: String?

    func fetch(code: String) async throws -> SyncPayload? {
        let request = try makeRequest(code: code, method: "GET")
        let (data, http) = try await send(request)
        if http.statusCode == 404 { return nil }
        try validate(http, data: data)
        return try SyncCoding.decoder.decode(SyncPayload.self, from: data)
    }

    func push(_ payload: SyncPayload) async throws -> SyncPayload {
        var request = try makeRequest(code: payload.countdown.inviteCode, method: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try SyncCoding.encoder.encode(payload)
        let (data, http) = try await send(request)
        if http.statusCode == 409 {
            return try SyncCoding.decoder.decode(SyncPayload.self, from: data)
        }
        try validate(http, data: data)
        if data.isEmpty { return payload }
        return try SyncCoding.decoder.decode(SyncPayload.self, from: data)
    }

    func delete(code: String) async throws {
        let request = try makeRequest(code: code, method: "DELETE")
        let (data, http) = try await send(request)
        if http.statusCode == 404 { return }
        try validate(http, data: data)
    }

    private func makeRequest(code: String, method: String) throws -> URLRequest {
        guard let base = URL(string: baseURLString),
              let scheme = base.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw SyncFailure.notConfigured("Enter a server URL in Settings. It should look like http://192.168.1.20:8787.")
        }
        let url = base.appending(path: "v1/rooms/\(code)")
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SyncFailure.message("The server sent an unexpected response.")
        }
        return (data, http)
    }

    private func validate(_ http: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            if body.isEmpty {
                throw SyncFailure.message("The server returned \(http.statusCode).")
            }
            throw SyncFailure.message("The server returned \(http.statusCode). \(body)")
        }
    }
}
