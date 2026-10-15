import Foundation
import UIKit
import WidgetKit

struct CountdownDraft: Equatable {
    var title: String
    var targetDate: Date
    var kind: CountdownKind
    var theme: CountdownTheme
    var note: String
    var photoJPEG: Data?
    var liveActivityMode: LiveActivityMode
    var removePhoto: Bool

    init() {
        title = ""
        targetDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        kind = .trip
        theme = .sunrise
        note = ""
        photoJPEG = nil
        liveActivityMode = .automatic
        removePhoto = false
    }

    init(countdown: Countdown) {
        title = countdown.title
        targetDate = countdown.targetDate
        kind = countdown.kind
        theme = countdown.theme
        note = countdown.note
        photoJPEG = nil
        liveActivityMode = countdown.liveActivityMode
        removePhoto = false
    }
}

@MainActor
@Observable
final class CountdownRepository {
    private let store: SharedStore
    private let photos: PhotoStore

    private(set) var database: SharedDatabase
    var lastSyncMessage: String?
    var importMessage: String?
    var isSyncing = false
    var openedCountdownID: UUID?
    var pendingJoinCode: String?

    init(store: SharedStore = SharedStore()) {
        self.store = store
        self.photos = PhotoStore(store: store)
        self.database = store.load()
    }

    var profile: UserProfile { database.profile }
    var countdowns: [Countdown] { database.countdowns }
    var usesAppGroup: Bool { store.usesAppGroup }

    var upcoming: [Countdown] {
        database.countdowns
            .filter { $0.targetDate >= Date() }
            .sorted { $0.targetDate < $1.targetDate }
    }

    var memories: [Countdown] {
        database.countdowns
            .filter { $0.targetDate < Date() }
            .sorted { $0.targetDate > $1.targetDate }
    }

    var featured: Countdown? {
        upcoming.first ?? memories.first
    }

    func countdown(_ id: UUID) -> Countdown? {
        database.countdowns.first { $0.id == id }
    }

    func image(for countdown: Countdown) -> UIImage? {
        guard let data = photos.data(named: countdown.photoFilename) else { return nil }
        return UIImage(data: data)
    }

    func finishOnboarding(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        database.profile.displayName = trimmed
        database.profile.didCompleteOnboarding = true
        persist()
    }

    func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        database.profile.displayName = trimmed
        persist()
    }

    func setWidgetPinnedID(_ id: UUID?) {
        database.profile.widgetPinnedID = id
        persist()
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        if enabled {
            let status = await NotificationScheduler.authorizationStatus()
            if status == .notDetermined {
                database.profile.notificationsEnabled = await NotificationScheduler.requestAuthorization()
            } else if status == .denied {
                database.profile.notificationsEnabled = false
                lastSyncMessage = "Notifications are off for Countdown Together in iOS Settings."
            } else {
                database.profile.notificationsEnabled = true
            }
        } else {
            database.profile.notificationsEnabled = false
        }
        persist()
        await NotificationScheduler.reschedule(
            countdowns: database.countdowns,
            enabled: database.profile.notificationsEnabled
        )
    }

    func updateSyncSettings(mode: SyncMode, baseURL: String, apiKey: String) async {
        database.profile.syncMode = mode
        database.profile.httpBaseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainStore.set(apiKey, for: Self.apiKeyAccount)
        persist()
        await pushAll()
    }

    func storedAPIKey() -> String {
        KeychainStore.string(for: Self.apiKeyAccount) ?? ""
    }

    func create(_ draft: CountdownDraft) async -> UUID? {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let now = CountdownMath.timestamp()
        var countdown = Countdown(
            id: UUID(),
            title: String(title.prefix(60)),
            targetDate: draft.targetDate,
            kind: draft.kind,
            theme: draft.theme,
            note: String(draft.note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(280)),
            inviteCode: uniqueCode(),
            ownerName: database.profile.displayName,
            partnerName: nil,
            createdAt: now,
            updatedAt: now,
            photoFilename: nil,
            liveActivityMode: draft.liveActivityMode
        )
        if let jpeg = draft.photoJPEG {
            countdown.photoFilename = try? photos.save(jpeg, id: countdown.id)
        }
        database.countdowns.append(countdown)
        persist()
        await afterLocalChange()
        if let message = await push(countdown) {
            lastSyncMessage = message
        }
        return countdown.id
    }

    func update(_ id: UUID, with draft: CountdownDraft) async {
        guard let index = database.countdowns.firstIndex(where: { $0.id == id }) else { return }
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        var countdown = database.countdowns[index]
        countdown.title = String(title.prefix(60))
        countdown.targetDate = draft.targetDate
        countdown.kind = draft.kind
        countdown.theme = draft.theme
        countdown.note = String(draft.note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(280))
        countdown.liveActivityMode = draft.liveActivityMode
        countdown.updatedAt = CountdownMath.timestamp()
        if draft.removePhoto {
            photos.delete(named: countdown.photoFilename)
            countdown.photoFilename = nil
        }
        if let jpeg = draft.photoJPEG {
            countdown.photoFilename = try? photos.save(jpeg, id: countdown.id)
        }
        database.countdowns[index] = countdown
        persist()
        await afterLocalChange()
        if let message = await push(countdown) {
            lastSyncMessage = message
        }
    }

    func setLiveActivityMode(_ mode: LiveActivityMode, for id: UUID) async {
        guard let index = database.countdowns.firstIndex(where: { $0.id == id }) else { return }
        database.countdowns[index].liveActivityMode = mode
        database.countdowns[index].updatedAt = CountdownMath.timestamp()
        let countdown = database.countdowns[index]
        persist()
        if let warning = await LiveActivityController.reconcile(database.countdowns) {
            lastSyncMessage = warning
        }
        if let message = await push(countdown) {
            lastSyncMessage = message
        }
    }

    func delete(_ id: UUID) async {
        guard let countdown = countdown(id) else { return }
        photos.delete(named: countdown.photoFilename)
        database.countdowns.removeAll { $0.id == id }
        if database.profile.widgetPinnedID == id {
            database.profile.widgetPinnedID = nil
        }
        persist()
        await LiveActivityController.end(id)
        await NotificationScheduler.reschedule(
            countdowns: database.countdowns,
            enabled: database.profile.notificationsEnabled
        )
        guard database.profile.syncMode != .local else { return }
        do {
            try await makeBackend().delete(code: countdown.inviteCode)
        } catch {
            lastSyncMessage = error.localizedDescription
        }
    }

    func join(code raw: String) async throws -> UUID {
        let code = InviteCode.normalize(raw)
        guard code.count == InviteCode.length else {
            throw SyncFailure.message("Enter the \(InviteCode.length)-character code.")
        }
        if let existing = database.countdowns.first(where: { $0.inviteCode == code }) {
            return existing.id
        }
        let backend = try makeBackend()
        guard let payload = try await backend.fetch(code: code) else {
            throw SyncFailure.notFound
        }
        var countdown = adopt(payload)
        if countdown.updatedAt != payload.countdown.updatedAt || countdown.partnerName != payload.countdown.partnerName {
            countdown = adopt(try await backend.push(makePayload(for: countdown)))
        }
        upsert(countdown)
        persist()
        await afterLocalChange()
        return countdown.id
    }

    func importFile(at url: URL) async -> UUID? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: url) else {
            importMessage = "Couldn't read that file."
            return nil
        }
        return await importCountdown(from: data)
    }

    func importCountdown(from data: Data) async -> UUID? {
        guard let payload = try? SyncCoding.decoder.decode(SyncPayload.self, from: data) else {
            importMessage = "That file isn't a Countdown Together card."
            return nil
        }
        let countdown = adopt(payload)
        upsert(countdown)
        openedCountdownID = countdown.id
        persist()
        await afterLocalChange()
        if let message = await push(countdown) {
            lastSyncMessage = message
        }
        return countdown.id
    }

    func handle(url: URL) {
        if url.isFileURL {
            Task { _ = await importFile(at: url) }
            return
        }
        guard url.scheme == AppLink.scheme else { return }
        let code = InviteCode.normalize(url.lastPathComponent)
        guard !code.isEmpty else { return }
        pendingJoinCode = code
    }

    func handleBecameActive() async {
        if let warning = await LiveActivityController.reconcile(database.countdowns) {
            lastSyncMessage = warning
        }
        await NotificationScheduler.reschedule(
            countdowns: database.countdowns,
            enabled: database.profile.notificationsEnabled
        )
        await refreshFromServer()
    }

    func refreshFromServer() async {
        guard database.profile.syncMode != .local else { return }
        isSyncing = true
        defer { isSyncing = false }
        let backend: SyncBackend
        do {
            backend = try makeBackend()
        } catch {
            lastSyncMessage = error.localizedDescription
            return
        }
        var warning: String?
        for countdown in database.countdowns {
            do {
                guard let remote = try await backend.fetch(code: countdown.inviteCode) else { continue }
                if remote.countdown.updatedAt > countdown.updatedAt {
                    upsert(adopt(remote))
                }
            } catch {
                warning = error.localizedDescription
            }
        }
        persist()
        lastSyncMessage = warning
        _ = await LiveActivityController.reconcile(database.countdowns)
    }

    func addSamples() async {
        let now = CountdownMath.timestamp()
        let owner = database.profile.displayName
        let samples = [
            sample(
                id: Self.lisbonID,
                title: "Lisbon",
                target: now.addingTimeInterval(24 * 86_400),
                kind: .trip,
                theme: .ocean,
                note: "The week we keep talking about.",
                code: "WEEKAWAY",
                owner: owner,
                now: now
            ),
            sample(
                id: Self.dinnerID,
                title: "Dinner",
                target: now.addingTimeInterval(8 * 3_600),
                kind: .date,
                theme: .rose,
                note: "The place on the corner.",
                code: "TABLEFR2",
                owner: owner,
                now: now
            )
        ]
        var inserted: [Countdown] = []
        for sample in samples where !database.countdowns.contains(where: { $0.id == sample.id }) {
            database.countdowns.append(sample)
            inserted.append(sample)
        }
        guard !inserted.isEmpty else { return }
        persist()
        await afterLocalChange()
        var failure: String?
        for countdown in inserted {
            if let message = await push(countdown) {
                failure = failure ?? message
            }
        }
        if let failure {
            lastSyncMessage = failure
        }
    }

    func clearSyncMessage() {
        lastSyncMessage = nil
    }

    func clearImportMessage() {
        importMessage = nil
    }

    func makePayload(for countdown: Countdown) -> SyncPayload {
        let data = photos.data(named: countdown.photoFilename)
        let encoded = data.flatMap { $0.count <= 1_000_000 ? $0.base64EncodedString() : nil }
        return SyncPayload(countdown: countdown, photoBase64: encoded)
    }

    private func pushAll() async {
        guard database.profile.syncMode != .local else {
            lastSyncMessage = nil
            return
        }
        var failure: String?
        for countdown in database.countdowns {
            if let message = await push(countdown) {
                failure = failure ?? message
            }
        }
        if let failure {
            lastSyncMessage = failure
        } else if !database.countdowns.isEmpty {
            lastSyncMessage = "Synced."
        } else {
            lastSyncMessage = nil
        }
    }

    private func push(_ countdown: Countdown) async -> String? {
        guard database.profile.syncMode != .local else { return nil }
        do {
            let backend = try makeBackend()
            let canonical = try await backend.push(makePayload(for: countdown))
            if canonical.countdown.updatedAt > countdown.updatedAt {
                upsert(adopt(canonical))
                persist()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func makeBackend() throws -> SyncBackend {
        switch database.profile.syncMode {
        case .local:
            return LocalSyncBackend()
        case .http:
            let url = database.profile.httpBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !url.isEmpty else {
                throw SyncFailure.notConfigured("Add a sync server URL in Settings.")
            }
            return HTTPSyncBackend(baseURLString: url, token: KeychainStore.string(for: Self.apiKeyAccount))
        case .cloudKit:
            return CloudKitSyncBackend(containerID: CloudKitContainer.identifier)
        }
    }

    private func adopt(_ payload: SyncPayload) -> Countdown {
        var countdown = payload.countdown
        let existing = database.countdowns.first { $0.id == countdown.id || $0.inviteCode == countdown.inviteCode }
        countdown.photoFilename = existing?.photoFilename
        if let base64 = payload.photoBase64,
           let data = Data(base64Encoded: base64),
           !data.isEmpty,
           let filename = try? photos.save(data, id: countdown.id) {
            countdown.photoFilename = filename
        }
        let myName = database.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let partner = countdown.partnerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !myName.isEmpty,
           countdown.ownerName.caseInsensitiveCompare(myName) != .orderedSame,
           partner.isEmpty {
            countdown.partnerName = myName
            countdown.updatedAt = CountdownMath.timestamp()
        }
        return countdown
    }

    private func upsert(_ countdown: Countdown) {
        if let index = database.countdowns.firstIndex(where: { $0.id == countdown.id }) {
            database.countdowns[index] = countdown
        } else if let index = database.countdowns.firstIndex(where: { $0.inviteCode == countdown.inviteCode }) {
            database.countdowns[index] = countdown
        } else {
            database.countdowns.append(countdown)
        }
    }

    private func afterLocalChange() async {
        if database.profile.notificationsEnabled {
            let status = await NotificationScheduler.authorizationStatus()
            if status == .notDetermined {
                _ = await NotificationScheduler.requestAuthorization()
            }
        }
        await NotificationScheduler.reschedule(
            countdowns: database.countdowns,
            enabled: database.profile.notificationsEnabled
        )
        if let warning = await LiveActivityController.reconcile(database.countdowns) {
            lastSyncMessage = warning
        }
    }

    private func persist() {
        do {
            try store.save(database)
        } catch {
            lastSyncMessage = "Couldn't save on this iPhone."
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func uniqueCode() -> String {
        let existing = Set(database.countdowns.map(\.inviteCode))
        var code = InviteCode.make()
        var tries = 0
        while existing.contains(code) && tries < 8 {
            code = InviteCode.make()
            tries += 1
        }
        return code
    }

    private func sample(
        id: UUID,
        title: String,
        target: Date,
        kind: CountdownKind,
        theme: CountdownTheme,
        note: String,
        code: String,
        owner: String,
        now: Date
    ) -> Countdown {
        Countdown(
            id: id,
            title: title,
            targetDate: target,
            kind: kind,
            theme: theme,
            note: note,
            inviteCode: code,
            ownerName: owner,
            partnerName: nil,
            createdAt: now,
            updatedAt: now,
            photoFilename: nil,
            liveActivityMode: .automatic
        )
    }

    private static let apiKeyAccount = "syncAPIKey"
    private static let lisbonID = UUID(uuidString: "A1B2C3D4-E5F6-4789-A123-ABCDEF123456")!
    private static let dinnerID = UUID(uuidString: "B1B2C3D4-E5F6-4789-A123-ABCDEF123456")!
}

extension CountdownRepository {
    static func preview() -> CountdownRepository {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("countdown-preview-\(UUID().uuidString)", isDirectory: true)
        let repository = CountdownRepository(store: SharedStore(directoryOverride: directory))
        repository.database.profile.displayName = "Alex"
        repository.database.profile.didCompleteOnboarding = true
        let now = CountdownMath.timestamp()
        repository.database.countdowns = [
            repository.sample(
                id: lisbonID,
                title: "Lisbon",
                target: now.addingTimeInterval(24 * 86_400),
                kind: .trip,
                theme: .ocean,
                note: "The week we keep talking about.",
                code: "WEEKAWAY",
                owner: "Alex",
                now: now
            ),
            repository.sample(
                id: dinnerID,
                title: "Dinner",
                target: now.addingTimeInterval(8 * 3_600),
                kind: .date,
                theme: .rose,
                note: "The place on the corner.",
                code: "TABLEFR2",
                owner: "Alex",
                now: now
            )
        ]
        return repository
    }
}
