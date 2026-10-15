import XCTest
@testable import CountdownTogether

final class CountdownLogicTests: XCTestCase {
    func testGeneratedCodesUseTheReadableAlphabet() {
        for _ in 0..<40 {
            let code = InviteCode.make()
            XCTAssertEqual(code.count, InviteCode.length)
            XCTAssertTrue(code.allSatisfy { InviteCode.alphabet.contains($0) })
        }
    }

    func testNormalizeDropsCharactersThatAreEasyToMishear() {
        XCTAssertEqual(InviteCode.normalize("ab-cd 10oi"), "ABCD")
        XCTAssertEqual(InviteCode.display("ABCD2345"), "ABCD 2345")
        XCTAssertEqual(InviteCode.normalize("week away"), "WEEKAWAY")
    }

    func testBreakdownAcrossADay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let breakdown = CountdownMath.breakdown(
            from: start,
            to: start.addingTimeInterval(90_000),
            calendar: calendar
        )
        XCTAssertEqual(breakdown.days, 1)
        XCTAssertEqual(breakdown.hours, 1)
        XCTAssertFalse(breakdown.isPast)
        XCTAssertFalse(breakdown.isFinalDay)
        XCTAssertEqual(CountdownMath.phase(kind: .trip, breakdown: breakdown), .upcoming)
        XCTAssertEqual(CountdownMath.compact(breakdown), "1d")
    }

    func testFinalHourAndAnniversary() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let soon = CountdownMath.breakdown(
            from: start,
            to: start.addingTimeInterval(1_800),
            calendar: calendar
        )
        XCTAssertTrue(soon.isFinalDay)
        XCTAssertTrue(soon.isFinalHour)
        XCTAssertEqual(soon.minutes, 30)
        XCTAssertEqual(CountdownMath.compact(soon), "30m")
        XCTAssertEqual(CountdownMath.caption(kind: .date, breakdown: soon), "left today")

        let later = start.addingTimeInterval(2 * 86_400)
        let past = CountdownMath.breakdown(from: later, to: start, calendar: calendar)
        XCTAssertTrue(past.isPast)
        XCTAssertEqual(past.days, 2)
        XCTAssertEqual(CountdownMath.phase(kind: .anniversary, breakdown: past), .elapsed)
        XCTAssertEqual(CountdownMath.phase(kind: .trip, breakdown: past), .past)
        XCTAssertEqual(CountdownMath.caption(kind: .anniversary, breakdown: past), "together")
    }

    func testTogetherLineUsesWhoeverIsNotMe() {
        let countdown = Countdown(
            id: UUID(),
            title: "Lisbon",
            targetDate: Date(),
            kind: .trip,
            theme: .ocean,
            note: "",
            inviteCode: "WEEKAWAY",
            ownerName: "Alex",
            partnerName: "Maya",
            createdAt: Date(),
            updatedAt: Date(),
            photoFilename: nil,
            liveActivityMode: .automatic
        )
        XCTAssertEqual(countdown.togetherLine(myName: "Alex"), "with Maya")
        XCTAssertEqual(countdown.togetherLine(myName: "maya"), "with Alex")
    }

    func testDatabaseAndPayloadRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("countdown-tests-\(UUID().uuidString)", isDirectory: true)
        let store = SharedStore(directoryOverride: directory)
        XCTAssertFalse(store.usesAppGroup)

        let now = CountdownMath.timestamp()
        var countdown = Countdown(
            id: UUID(),
            title: "Lisbon",
            targetDate: now.addingTimeInterval(86_400),
            kind: .trip,
            theme: .ocean,
            note: "Soon",
            inviteCode: "WEEKAWAY",
            ownerName: "Anubhav",
            partnerName: nil,
            createdAt: now,
            updatedAt: now,
            photoFilename: "local-only.jpg",
            liveActivityMode: .automatic
        )
        var database = SharedDatabase.empty
        database.profile.displayName = "Anubhav"
        database.profile.didCompleteOnboarding = true
        database.countdowns = [countdown]
        try store.save(database)

        let loaded = store.load()
        XCTAssertEqual(loaded.profile.displayName, "Anubhav")
        XCTAssertEqual(loaded.countdowns.first?.title, "Lisbon")
        XCTAssertEqual(store.countdownForWidget(at: now)?.inviteCode, "WEEKAWAY")

        let payload = SyncPayload(countdown: countdown, photoBase64: nil)
        XCTAssertNil(payload.countdown.photoFilename)
        let data = try SyncCoding.encoder.encode(payload)
        let decoded = try SyncCoding.decoder.decode(SyncPayload.self, from: data)
        XCTAssertEqual(decoded.countdown.title, "Lisbon")
        XCTAssertEqual(decoded.countdown.inviteCode, "WEEKAWAY")
        countdown.photoFilename = nil
        XCTAssertEqual(decoded.countdown, countdown)
    }
}
