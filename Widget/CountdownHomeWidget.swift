import AppIntents
import Foundation
import SwiftUI
import UIKit
import WidgetKit

struct CountdownEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Countdown")
    static var defaultQuery = CountdownEntityQuery()

    var id: String
    var title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init(countdown: Countdown) {
        id = countdown.id.uuidString
        title = countdown.title
    }
}

struct CountdownEntityQuery: EntityQuery, EnumerableEntityQuery {
    func entities(for identifiers: [CountdownEntity.ID]) async throws -> [CountdownEntity] {
        SharedStore().load().countdowns
            .filter { identifiers.contains($0.id.uuidString) }
            .map(CountdownEntity.init)
    }

    func allEntities() async throws -> [CountdownEntity] {
        try await suggestedEntities()
    }

    func suggestedEntities() async throws -> [CountdownEntity] {
        SharedStore().load().countdowns
            .sorted { $0.targetDate < $1.targetDate }
            .map(CountdownEntity.init)
    }

    func defaultResult() async -> CountdownEntity? {
        guard let countdown = SharedStore().countdownForWidget() else { return nil }
        return CountdownEntity(countdown: countdown)
    }
}

struct SelectCountdownIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Countdown"
    static var description = IntentDescription("Choose which countdown to show.")

    @Parameter(title: "Countdown")
    var countdown: CountdownEntity?
}

struct CountdownEntry: TimelineEntry {
    var date: Date
    var countdown: Countdown?
    var photo: UIImage?
    var usesAppGroup: Bool

    static var placeholder: CountdownEntry {
        let now = Date()
        return CountdownEntry(
            date: now,
            countdown: Countdown(
                id: UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!,
                title: "Lisbon",
                targetDate: now.addingTimeInterval(12 * 86_400),
                kind: .trip,
                theme: .ocean,
                note: "The week we keep talking about.",
                inviteCode: "WEEKAWAY",
                ownerName: "Alex",
                partnerName: nil,
                createdAt: now,
                updatedAt: now,
                photoFilename: nil,
                liveActivityMode: .automatic
            ),
            photo: nil,
            usesAppGroup: true
        )
    }
}

struct CountdownProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CountdownEntry {
        .placeholder
    }

    func snapshot(for configuration: SelectCountdownIntent, in context: Context) async -> CountdownEntry {
        context.isPreview ? .placeholder : entry(for: configuration)
    }

    func timeline(for configuration: SelectCountdownIntent, in context: Context) async -> Timeline<CountdownEntry> {
        let current = entry(for: configuration)
        return Timeline(entries: [current], policy: .after(nextRefresh(for: current.countdown, now: current.date)))
    }

    private func entry(for configuration: SelectCountdownIntent) -> CountdownEntry {
        let store = SharedStore()
        let database = store.load()
        let selected: Countdown?
        if let id = configuration.countdown?.id {
            selected = database.countdowns.first { $0.id.uuidString == id }
        } else {
            selected = nil
        }
        let countdown = selected ?? store.countdownForWidget()
        return CountdownEntry(
            date: Date(),
            countdown: countdown,
            photo: photo(for: countdown, store: store),
            usesAppGroup: store.usesAppGroup
        )
    }

    private func photo(for countdown: Countdown?, store: SharedStore) -> UIImage? {
        guard let filename = countdown?.photoFilename,
              let data = try? Data(contentsOf: store.photoURL(named: filename)) else {
            return nil
        }
        return UIImage(data: data)
    }

    private func nextRefresh(for countdown: Countdown?, now: Date) -> Date {
        guard let countdown else { return now.addingTimeInterval(60 * 60) }
        let breakdown = CountdownMath.breakdown(from: now, to: countdown.targetDate)
        if breakdown.isFinalDay {
            return now.addingTimeInterval(15 * 60)
        }
        return Calendar.current.nextDate(
            after: now,
            matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60 * 60)
    }
}

struct CountdownHomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "CountdownTogetherWidget",
            intent: SelectCountdownIntent.self,
            provider: CountdownProvider()
        ) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Your next shared countdown, on the Home Screen and Lock Screen.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}
