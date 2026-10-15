import CloudKit
import Foundation

struct CloudKitSyncBackend: SyncBackend {
    var containerID: String

    func fetch(code: String) async throws -> SyncPayload? {
        let database = try await database()
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: code))
            return try payload(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            throw wrap(error)
        }
    }

    func push(_ payload: SyncPayload) async throws -> SyncPayload {
        let database = try await database()
        let recordID = CKRecord.ID(recordName: payload.countdown.inviteCode)
        if let existing = try? await database.record(for: recordID),
           let existingDate = existing["updatedAt"] as? Date,
           existingDate > payload.countdown.updatedAt {
            return try self.payload(from: existing)
        }

        let photoURL = try writeTemporaryPhoto(payload.photoBase64)
        defer {
            if let photoURL {
                try? FileManager.default.removeItem(at: photoURL)
            }
        }
        let record = record(from: payload, photoFile: photoURL, recordID: recordID)
        do {
            let saved = try await database.save(record)
            return try self.payload(from: saved)
        } catch {
            throw wrap(error)
        }
    }

    func delete(code: String) async throws {
        let database = try await database()
        do {
            try await database.deleteRecord(withID: CKRecord.ID(recordName: code))
        } catch let error as CKError where error.code == .unknownItem {
            return
        } catch {
            throw wrap(error)
        }
    }

    private func database() async throws -> CKDatabase {
        let container = CKContainer(identifier: containerID)
        let status = try await container.accountStatus()
        guard status == .available else {
            throw SyncFailure.notConfigured(
                "Sign into iCloud on this iPhone. CloudKit also needs a paid Apple Developer account and the iCloud capability."
            )
        }
        return container.publicCloudDatabase
    }

    private func record(from payload: SyncPayload, photoFile: URL?, recordID: CKRecord.ID) -> CKRecord {
        let record = CKRecord(recordType: "Countdown", recordID: recordID)
        let countdown = payload.countdown
        record.setObject(countdown.id.uuidString as NSString, forKey: "countdownID")
        record.setObject(countdown.title as NSString, forKey: "title")
        record.setObject(countdown.targetDate as NSDate, forKey: "targetDate")
        record.setObject(countdown.kind.rawValue as NSString, forKey: "kind")
        record.setObject(countdown.theme.rawValue as NSString, forKey: "theme")
        record.setObject(countdown.note as NSString, forKey: "note")
        record.setObject(countdown.ownerName as NSString, forKey: "ownerName")
        record.setObject((countdown.partnerName ?? "") as NSString, forKey: "partnerName")
        record.setObject(countdown.createdAt as NSDate, forKey: "createdAt")
        record.setObject(countdown.updatedAt as NSDate, forKey: "updatedAt")
        record.setObject(countdown.liveActivityMode.rawValue as NSString, forKey: "liveActivityMode")
        if let photoFile {
            record.setObject(CKAsset(fileURL: photoFile), forKey: "photo")
        }
        return record
    }

    private func payload(from record: CKRecord) throws -> SyncPayload {
        guard
            let idString = record["countdownID"] as? String,
            let id = UUID(uuidString: idString),
            let title = record["title"] as? String,
            let targetDate = record["targetDate"] as? Date,
            let kindRaw = record["kind"] as? String,
            let themeRaw = record["theme"] as? String,
            let ownerName = record["ownerName"] as? String,
            let createdAt = record["createdAt"] as? Date,
            let updatedAt = record["updatedAt"] as? Date
        else {
            throw SyncFailure.message("That iCloud countdown is missing a few fields.")
        }
        let partner = record["partnerName"] as? String
        let modeRaw = record["liveActivityMode"] as? String
        let countdown = Countdown(
            id: id,
            title: title,
            targetDate: targetDate,
            kind: CountdownKind(rawValue: kindRaw) ?? .custom,
            theme: CountdownTheme(rawValue: themeRaw) ?? .midnight,
            note: record["note"] as? String ?? "",
            inviteCode: record.recordID.recordName,
            ownerName: ownerName,
            partnerName: (partner?.isEmpty == false) ? partner : nil,
            createdAt: createdAt,
            updatedAt: updatedAt,
            photoFilename: nil,
            liveActivityMode: LiveActivityMode(rawValue: modeRaw ?? "") ?? .automatic
        )
        var photoBase64: String?
        if let asset = record["photo"] as? CKAsset, let url = asset.fileURL, let data = try? Data(contentsOf: url) {
            photoBase64 = data.base64EncodedString()
        }
        return SyncPayload(countdown: countdown, photoBase64: photoBase64)
    }

    private func writeTemporaryPhoto(_ base64: String?) throws -> URL? {
        guard let base64, let data = Data(base64Encoded: base64), !data.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func wrap(_ error: Error) -> SyncFailure {
        let text = error.localizedDescription
        let lower = text.lowercased()
        if lower.contains("container") || lower.contains("permission") || lower.contains("entitlement") {
            return .message(
                "iCloud isn't available for this build. \(text) A paid Apple Developer account has to enable the iCloud capability."
            )
        }
        return .message(text)
    }
}
