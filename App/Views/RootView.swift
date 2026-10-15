import SwiftUI

struct RootView: View {
    @Environment(CountdownRepository.self) private var repository

    var body: some View {
        Group {
            if repository.profile.didCompleteOnboarding {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(.dark)
        .tint(Color.clay)
    }
}

struct OnboardingView: View {
    @Environment(CountdownRepository.self) private var repository
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            TogetherMark()
                .padding(.bottom, 28)
            Text("Countdown Together")
                .font(.system(size: 40, weight: .medium, design: .serif))
                .foregroundStyle(Color.ivory)
            Text("Shared countdowns for trips, dates, and the days you're both waiting on.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.mist)
                .padding(.top, 12)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Your name", text: $name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color.ivory)
                .inkPanel()
                .padding(.top, 28)
                .focused($focused)
                .onSubmit(start)
            PrimaryButton(title: "Start", systemImage: "arrow.right", action: start)
                .padding(.top, 16)
                .opacity(trimmedName.isEmpty ? 0.45 : 1)
                .disabled(trimmedName.isEmpty)
            Text("You can change how sharing works later in Settings.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.mist)
                .padding(.top, 18)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.ink.ignoresSafeArea())
        .onAppear { focused = true }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func start() {
        repository.finishOnboarding(name: trimmedName)
    }
}

#Preview {
    OnboardingView()
        .environment(CountdownRepository.preview())
}
