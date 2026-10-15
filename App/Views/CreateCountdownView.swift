import CoreTransferable
import PhotosUI
import SwiftUI
import UIKit

struct PickedPhoto: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data), let jpeg = JPEGEncoder.data(from: image) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return PickedPhoto(data: jpeg)
        }
    }
}

struct CreateCountdownView: View {
    var existing: Countdown?
    var onDone: (UUID) -> Void

    @Environment(CountdownRepository.self) private var repository
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CountdownDraft()
    @State private var pickerItem: PhotosPickerItem?
    @State private var existingImage: UIImage?
    @State private var titleError = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.ink.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        titleField
                        kindPicker
                        datePicker
                        themePicker
                        photoPicker
                        noteField
                        PrimaryButton(title: isSaving ? "Saving…" : "Save countdown", systemImage: "checkmark") {
                            Task { await save() }
                        }
                        .disabled(isSaving)
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(existing == nil ? "New countdown" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear(perform: loadExisting)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let picked = try? await item.loadTransferable(type: PickedPhoto.self) {
                    draft.photoJPEG = picked.data
                    draft.removePhoto = false
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Name")
            TextField("Lisbon", text: $draft.title)
                .textInputAutocapitalization(.words)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color.ivory)
                .inkPanel()
            if titleError {
                Text("Give it a name.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.clay)
            }
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Kind")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CountdownKind.allCases) { kind in
                        Button {
                            draft.kind = kind
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: kind.symbol)
                                Text(kind.title)
                            }
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .foregroundStyle(draft.kind == kind ? Color.ink : Color.ivory)
                            .background(draft.kind == kind ? Color.ivory : Color.white.opacity(0.06), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text(draft.kind.detail)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.mist)
        }
    }

    private var datePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Date and time")
            DatePicker(
                "Date and time",
                selection: $draft.targetDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(Color.clay)
            .padding(8)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            if draft.targetDate < Date() && draft.kind != .anniversary {
                Text("That moment has already passed. It will show up as a memory.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.mist)
            }
        }
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Theme")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(CountdownTheme.allCases) { theme in
                    Button {
                        draft.theme = theme
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            ThemeBackground(theme: theme)
                            if draft.theme == theme {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(theme.foreground)
                                    .padding(8)
                            }
                        }
                        .frame(height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.ivory.opacity(draft.theme == theme ? 0.9 : 0), lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(theme.title)
                    .accessibilityAddTraits(draft.theme == theme ? .isSelected : [])
                }
            }
        }
    }

    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Photo")
            HStack(spacing: 14) {
                photoPreview
                VStack(alignment: .leading, spacing: 8) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text(hasPhoto ? "Change photo" : "Choose a photo")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.ivory)
                    }
                    if hasPhoto {
                        Button("Remove") {
                            draft.photoJPEG = nil
                            draft.removePhoto = true
                            pickerItem = nil
                        }
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Color.clay)
                    }
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var photoPreview: some View {
        Group {
            if let data = draft.photoJPEG, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else if !draft.removePhoto, let existingImage {
                Image(uiImage: existingImage).resizable().scaledToFill()
            } else {
                ThemeBackground(theme: draft.theme)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var hasPhoto: Bool {
        draft.photoJPEG != nil || (existingImage != nil && !draft.removePhoto)
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Note")
            TextField("A line you'll both see", text: $draft.note, axis: .vertical)
                .lineLimit(3...6)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.ivory)
                .inkPanel()
        }
    }

    private func loadExisting() {
        guard let existing else { return }
        draft = CountdownDraft(countdown: existing)
        existingImage = repository.image(for: existing)
    }

    private func save() async {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            titleError = true
            return
        }
        titleError = false
        isSaving = true
        defer { isSaving = false }
        if let existing {
            await repository.update(existing.id, with: draft)
            onDone(existing.id)
        } else if let id = await repository.create(draft) {
            onDone(id)
        }
        dismiss()
    }
}
