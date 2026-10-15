import Foundation

enum SyncFailure: LocalizedError {
    case notConfigured(String)
    case notFound
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let text): text
        case .notFound: "No countdown uses that code."
        case .message(let text): text
        }
    }
}

protocol SyncBackend {
    func fetch(code: String) async throws -> SyncPayload?
    func push(_ payload: SyncPayload) async throws -> SyncPayload
    func delete(code: String) async throws
}

struct LocalSyncBackend: SyncBackend {
    func fetch(code: String) async throws -> SyncPayload? {
        throw SyncFailure.notConfigured(
            "Invite codes need a sync server or iCloud. You can still send a countdown file from the countdown screen."
        )
    }

    func push(_ payload: SyncPayload) async throws -> SyncPayload {
        payload
    }

    func delete(code: String) async throws {}
}
