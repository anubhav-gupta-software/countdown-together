import SwiftUI

struct HomeView: View {
    @Environment(CountdownRepository.self) private var repository
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var showSettings = false
    @State private var joinSeed = ""
    @State private var openedID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ink.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        if let message = repository.lastSyncMessage {
                            syncBanner(message)
                        }
                        if !repository.usesAppGroup && !repository.countdowns.isEmpty {
                            widgetNote
                        }
                        if repository.countdowns.isEmpty {
                            emptyState
                        } else {
                            countdownList
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await repository.refreshFromServer()
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "New countdown", systemImage: "plus") {
                    showCreate = true
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(
                    LinearGradient(
                        colors: [Color.ink.opacity(0), Color.ink, Color.ink],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        joinSeed = ""
                        showJoin = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Join with a code")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(item: $openedID) { id in
                CountdownDetailView(id: id)
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateCountdownView(existing: nil) { id in
                showCreate = false
                openedID = id
            }
        }
        .sheet(isPresented: $showJoin) {
            JoinView(initialCode: joinSeed) { id in
                showJoin = false
                openedID = id
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            if let code = repository.pendingJoinCode {
                joinSeed = code
                showJoin = true
                repository.pendingJoinCode = nil
            }
            if let id = repository.openedCountdownID {
                openedID = id
                repository.openedCountdownID = nil
            }
        }
        .onChange(of: repository.pendingJoinCode) { _, code in
            guard let code else { return }
            joinSeed = code
            showJoin = true
            repository.pendingJoinCode = nil
        }
        .onChange(of: repository.openedCountdownID) { _, id in
            guard let id else { return }
            openedID = id
            repository.openedCountdownID = nil
        }
        .alert(
            "Couldn't open that",
            isPresented: Binding(
                get: { repository.importMessage != nil },
                set: { if !$0 { repository.clearImportMessage() } }
            )
        ) {
            Button("OK", role: .cancel) { repository.clearImportMessage() }
        } message: {
            Text(repository.importMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Greeting.line())
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.mist)
            Text(repository.profile.displayName)
                .font(.system(size: 36, weight: .medium, design: .serif))
                .foregroundStyle(Color.ivory)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(waitingLine)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.mist)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var waitingLine: String {
        let upcoming = repository.upcoming.count
        if upcoming == 1 { return "One countdown on the go." }
        if upcoming > 1 { return "\(upcoming) countdowns on the go." }
        if repository.memories.isEmpty { return "Start one you'll both watch." }
        return "Looking back."
    }

    private var widgetNote: some View {
        Text("Widgets can't see these yet. A free Apple ID can use the app and Live Activities. Sharing countdowns with a widget needs the App Group, which is a paid-account capability.")
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Color.mist)
            .fixedSize(horizontal: false, vertical: true)
            .inkPanel()
    }

    private func syncBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(message)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.ivory)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Dismiss") { repository.clearSyncMessage() }
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.clay)
        }
        .inkPanel()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            TogetherMark()
                .padding(.top, 12)
            Text("Nothing on the calendar yet.")
                .font(.system(size: 32, weight: .medium, design: .serif))
                .foregroundStyle(Color.ivory)
            Text("Start a countdown for a trip, a date, or whatever you're both waiting on.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.mist)
                .fixedSize(horizontal: false, vertical: true)
            Button("Try a sample") {
                Task { await repository.addSamples() }
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(Color.clay)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var countdownList: some View {
        if let featured = repository.featured {
            Button {
                openedID = featured.id
            } label: {
                CountdownCard(
                    countdown: featured,
                    together: featured.togetherLine(myName: repository.profile.displayName),
                    image: repository.image(for: featured),
                    style: .hero
                )
            }
            .buttonStyle(.plain)
            .contextMenu { deleteButton(featured.id) }
        }

        let restUpcoming = repository.upcoming.filter { $0.id != repository.featured?.id }
        let restMemories = repository.memories.filter { $0.id != repository.featured?.id }

        if !restUpcoming.isEmpty {
            SectionLabel(text: "Also waiting")
                .padding(.top, 8)
            rows(restUpcoming)
        }
        if !restMemories.isEmpty {
            SectionLabel(text: "Memories")
                .padding(.top, 8)
            rows(restMemories)
        }
    }

    private func rows(_ countdowns: [Countdown]) -> some View {
        ForEach(countdowns) { countdown in
            Button {
                openedID = countdown.id
            } label: {
                CountdownCard(
                    countdown: countdown,
                    together: countdown.togetherLine(myName: repository.profile.displayName),
                    image: repository.image(for: countdown),
                    style: .row
                )
            }
            .buttonStyle(.plain)
            .contextMenu { deleteButton(countdown.id) }
        }
    }

    private func deleteButton(_ id: UUID) -> some View {
        Button("Delete", role: .destructive) {
            Task { await repository.delete(id) }
        }
    }
}

#Preview {
    HomeView()
        .environment(CountdownRepository.preview())
}
