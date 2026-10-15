import SwiftUI

struct SettingsView: View {
    @Environment(CountdownRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var mode: SyncMode = .local
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var notifications = true
    @State private var pinChoice = "auto"
    @State private var ready = false
    @State private var isSavingSync = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ink.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        nameSection
                        notificationSection
                        widgetSection
                        syncSection
                        sharingNotes
                        aboutSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            name = repository.profile.displayName
            mode = repository.profile.syncMode
            baseURL = repository.profile.httpBaseURL
            apiKey = repository.storedAPIKey()
            notifications = repository.profile.notificationsEnabled
            if let pinned = repository.profile.widgetPinnedID {
                pinChoice = pinned.uuidString
            } else {
                pinChoice = "auto"
            }
            ready = true
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Your name")
            TextField("Your name", text: $name)
                .textInputAutocapitalization(.words)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color.ivory)
                .inkPanel()
                .onSubmit { repository.updateDisplayName(name) }
                .onChange(of: name) { _, newValue in
                    guard ready else { return }
                    repository.updateDisplayName(newValue)
                }
        }
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Reminder")
            Toggle("Remind me when it's time", isOn: $notifications)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.ivory)
                .tint(Color.clay)
                .onChange(of: notifications) { _, enabled in
                    guard ready else { return }
                    Task {
                        await repository.setNotificationsEnabled(enabled)
                        notifications = repository.profile.notificationsEnabled
                    }
                }
            Text("A local notification fires at the date and time. No push server is involved.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.mist)
        }
    }

    private var widgetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Widget")
            Picker("Countdown", selection: $pinChoice) {
                Text("Next upcoming").tag("auto")
                ForEach(repository.countdowns) { countdown in
                    Text(countdown.title).tag(countdown.id.uuidString)
                }
            }
            .pickerStyle(.menu)
            .tint(Color.ivory)
            .onChange(of: pinChoice) { _, choice in
                guard ready else { return }
                repository.setWidgetPinnedID(UUID(uuidString: choice))
            }
            Text(repository.usesAppGroup
                 ? "The Home Screen and Lock Screen widgets read this choice."
                 : "The widget extension is installed, but it can't read countdowns until the App Group is turned on.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.mist)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Sharing")
            ForEach(SyncMode.allCases) { option in
                Button {
                    mode = option
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.title)
                                .font(.system(.body, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.ivory)
                            Text(option.detail)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(Color.mist)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: mode == option ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(mode == option ? Color.clay : Color.mist)
                    }
                }
                .buttonStyle(.plain)
            }
            if mode == .http {
                TextField("http://192.168.1.20:8787", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.ivory)
                    .inkPanel()
                SecureField("API key, if the server asks for one", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.ivory)
                    .inkPanel()
            }
            PrimaryButton(title: isSavingSync ? "Saving…" : "Save sync settings") {
                Task {
                    isSavingSync = true
                    await repository.updateSyncSettings(mode: mode, baseURL: baseURL, apiKey: apiKey)
                    isSavingSync = false
                }
            }
            .disabled(isSavingSync)
            if let message = repository.lastSyncMessage {
                Text(message)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(message == "Synced." ? Color.ivory : Color.clay)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sharingNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "What works without a paid account")
            Text("The app, photos, themes, local reminders, countdown files, and Live Activities all work with a free Apple ID. Invite codes between two phones need the sync server or iCloud. Widgets show your real countdowns after you add the App Group.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.mist)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "About")
            Text("Countdown Together \(version)")
                .font(.system(.body, design: .serif))
                .foregroundStyle(Color.ivory)
            Text(Bundle.main.bundleIdentifier ?? "")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.mist)
        }
    }

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
