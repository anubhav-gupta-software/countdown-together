import SwiftUI
import UIKit

struct InviteSheet: View {
    var countdownID: UUID

    @Environment(CountdownRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ink.ignoresSafeArea()
                if let countdown = repository.countdown(countdownID) {
                    content(countdown)
                }
            }
            .navigationTitle("Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func content(_ countdown: Countdown) -> some View {
        ScrollView {
            VStack(spacing: 22) {
                Text(countdown.title)
                    .font(.system(.title2, design: .serif))
                    .foregroundStyle(Color.ivory)
                Text(InviteCode.display(countdown.inviteCode))
                    .font(.system(size: 36, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .tracking(4)
                    .foregroundStyle(Color.ivory)
                    .padding(.vertical, 8)
                if let image = QRCodeImage.make(AppLink.joinURL(code: countdown.inviteCode).absoluteString) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .padding(12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityLabel("QR code for the invite")
                }
                Text(explanation)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.mist)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                QuietButton(title: copied ? "Copied" : "Copy code", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = countdown.inviteCode
                    copied = true
                }
                ShareLink(item: shareMessage(countdown)) {
                    shareLabel("Share the code", systemImage: "square.and.arrow.up")
                }
                ShareLink(
                    item: CountdownFile(payload: repository.makePayload(for: countdown)),
                    preview: SharePreview(countdown.title, image: Image(systemName: countdown.kind.symbol))
                ) {
                    shareLabel("Send a countdown file", systemImage: "paperplane")
                }
            }
            .padding(24)
        }
    }

    private var explanation: String {
        switch repository.profile.syncMode {
        case .local:
            "This phone is in local mode, so another phone can't look up the code yet. Send the countdown file, or turn on a sync server or iCloud in Settings."
        case .http:
            "Anyone using the same sync server can enter this code and open the countdown."
        case .cloudKit:
            "Anyone signed into iCloud can enter this code once CloudKit is enabled for the app."
        }
    }

    private func shareMessage(_ countdown: Countdown) -> String {
        """
        Join "\(countdown.title)" in Countdown Together.
        Code: \(countdown.inviteCode)
        \(AppLink.joinURL(code: countdown.inviteCode).absoluteString)
        """
    }

    private func shareLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.system(.subheadline, design: .rounded).weight(.semibold))
        .foregroundStyle(Color.ivory)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06), in: Capsule())
    }
}

struct JoinView: View {
    var initialCode: String
    var onJoined: (UUID) -> Void

    @Environment(CountdownRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var code: String
    @State private var error: String?
    @State private var isWorking = false
    @State private var showImporter = false

    init(initialCode: String, onJoined: @escaping (UUID) -> Void) {
        self.initialCode = initialCode
        self.onJoined = onJoined
        _code = State(initialValue: initialCode)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ink.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    Text("Enter the code they sent, or open a countdown file.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Color.mist)
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("ABCD2345", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ivory)
                        .inkPanel()
                    if let error {
                        Text(error)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Color.clay)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    PrimaryButton(title: isWorking ? "Looking…" : "Join", systemImage: "person.badge.plus") {
                        Task { await join() }
                    }
                    .disabled(isWorking)
                    QuietButton(title: "Open a countdown file", systemImage: "folder") {
                        showImporter = true
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Join")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.countdownCard, .json]) { result in
            switch result {
            case .success(let url):
                Task {
                    if let id = await repository.importFile(at: url) {
                        onJoined(id)
                    } else {
                        error = repository.importMessage ?? "Couldn't open that file."
                    }
                }
            case .failure:
                error = "Couldn't open that file."
            }
        }
    }

    private func join() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let id = try await repository.join(code: code)
            onJoined(id)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
