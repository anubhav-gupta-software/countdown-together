import SwiftUI
import UIKit

struct CountdownDetailView: View {
    var id: UUID

    @Environment(CountdownRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showInvite = false
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let countdown = repository.countdown(id) {
                detail(countdown)
            } else {
                Color.ink.ignoresSafeArea()
                    .onAppear { dismiss() }
            }
        }
    }

    private func detail(_ countdown: Countdown) -> some View {
        let image = repository.image(for: countdown)
        let light = image != nil || countdown.theme.inkIsLight
        return ZStack {
            Color.ink.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    header(countdown, image: image, light: light)
                    VStack(alignment: .leading, spacing: 28) {
                        if !countdown.note.isEmpty {
                            Text(countdown.note)
                                .font(.system(.title3, design: .serif))
                                .italic()
                                .foregroundStyle(Color.ivory)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        lockScreenSection(countdown)
                        shareSection
                        Button("Delete countdown", role: .destructive) {
                            confirmDelete = true
                        }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                    .padding(20)
                    .padding(.bottom, 32)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(light ? .dark : .light, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            CreateCountdownView(existing: countdown) { _ in
                showEdit = false
            }
        }
        .sheet(isPresented: $showInvite) {
            InviteSheet(countdownID: countdown.id)
        }
        .confirmationDialog(
            "Delete this countdown?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await repository.delete(id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It disappears from this iPhone. If sync is on, the shared copy is removed too.")
        }
    }

    private func header(_ countdown: Countdown, image: UIImage?, light: Bool) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(minHeight: 560)
            .overlay {
                background(countdown, image: image)
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: countdown.kind.symbol)
                            Text(countdown.kind.title.uppercased())
                                .tracking(1.3)
                        }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(textSecondary(light))

                        if let together = countdown.togetherLine(myName: repository.profile.displayName) {
                            Text(together)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(textSecondary(light))
                        }

                        Text(countdown.title)
                            .font(.system(size: 44, weight: .medium, design: .serif))
                            .foregroundStyle(textPrimary(light))
                            .fixedSize(horizontal: false, vertical: true)

                        CountdownReadout(countdown: countdown, now: timeline.date, lightText: light)
                            .padding(.top, 6)

                        Text(countdown.targetDate.formatted(date: .complete, time: .shortened))
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(textSecondary(light))
                            .padding(.top, 4)
                    }
                    .padding(24)
                    .padding(.bottom, 12)
                }
            }
    }

    @ViewBuilder
    private func background(_ countdown: Countdown, image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            ThemeBackground(theme: countdown.theme)
        }
    }

    private func lockScreenSection(_ countdown: Countdown) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Lock Screen")
            if LiveActivityController.isRunning(countdown.id) {
                Text("Showing on the Lock Screen.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.clay)
            }
            ForEach(LiveActivityMode.allCases) { mode in
                Button {
                    Task { await repository.setLiveActivityMode(mode, for: countdown.id) }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.title)
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.ivory)
                            Text(mode.detail)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(Color.mist)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: countdown.liveActivityMode == mode ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(countdown.liveActivityMode == mode ? Color.clay : Color.mist)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Share")
            QuietButton(title: "Invite code", systemImage: "number") {
                showInvite = true
            }
        }
    }

    private func textPrimary(_ light: Bool) -> Color {
        light ? Color.ivory : Color(hex: 0x241910)
    }

    private func textSecondary(_ light: Bool) -> Color {
        textPrimary(light).opacity(0.74)
    }
}
