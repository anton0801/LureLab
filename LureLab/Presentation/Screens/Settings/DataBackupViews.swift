import SwiftUI

/// Screen 30 with dialogs 32 (Import Error) and 33 (Delete All Data).
struct DataBackupView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.haptics) private var haptics

    @State private var busyLabel: String?
    @State private var exportItem: ExportItem?
    @State private var showImporter = false
    @State private var importError: String?
    @State private var showDeleteOffer = false
    @State private var showDeleteDialog = false
    @State private var deleteText = ""
    @State private var message: String?

    var body: some View {
        LightScreen(bottomPadding: 16) {
            ScreenHeader(title: "Data & Backup", subtitle: "Keep a copy before changing devices.", onBack: { router.pop() })
            VStack(alignment: .leading, spacing: 0) {
                Text("Stored on this device")
                    .font(.avenir(22, .heavy))
                    .foregroundColor(Palette.ink)
                    .padding(.top, 15)
                Text("Photos and journal included in backup.")
                    .font(.avenir(14, .demiBold))
                    .foregroundColor(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 11.9)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .topLeading)
            .lureCard()
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 26.5)

            VStack(spacing: 16) {
                NavRow(icon: "icon_export", title: "Export Backup", action: exportBackup)
                NavRow(icon: "icon_import", title: "Import Backup", action: startImport)
                NavRow(icon: "icon_journal", title: "Export Tests as CSV", action: exportCSV)
                NavRow(icon: "icon_archive", title: "Archived Lures", value: model.archivedLures.isEmpty ? "" : String(model.archivedLures.count)) {
                    router.push(.archived)
                }
            }
            .padding(.horizontal, Metrics.margin)
            .padding(.top, 25)

            Text("Import replaces the current journal. You can review the file before confirming.")
                .font(.avenir(16, .medium))
                .foregroundColor(Palette.secondary)
                .lineSpacing(1.1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 270, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 38)
        } bottom: {
            SurfaceButton(title: "Delete All Data", kind: .danger) { showDeleteOffer = true }
        }
        .busyOverlay(busyLabel != nil, label: busyLabel ?? "")
        .onAppear {
            #if DEBUG
            if DebugScenario.name == "32" { importError = BackupError.unreadableArchive.errorDescription }
            if DebugScenario.name == "33" { showDeleteDialog = true }
            #endif
        }
        .sheet(item: $exportItem) { item in
            FileExporter(url: item.url) { saved in
                exportItem = nil
                if saved { message = "Saved to Files." }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showImporter) {
            BackupFilePicker { url in
                showImporter = false
                if let url { prepareImport(url) }
            }
            .ignoresSafeArea()
        }
        .confirmationDialog("Keep a copy first?", isPresented: $showDeleteOffer, titleVisibility: .visible) {
            Button("Export Backup") { exportBackup() }
            Button("Continue to Delete", role: .destructive) {
                deleteText = ""
                showDeleteDialog = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete All Data removes your journal, photos and collection from this device.")
        }
        .dialog(isPresented: importError != nil) {
            ActionDialog(icon: "icon_warning", title: "Cannot Open Backup",
                         message: "\(importError ?? "") Your current data is unchanged.",
                         actions: [
                            DialogAction(title: "Choose Another File", style: .primary) {
                                importError = nil
                                startImport()
                            },
                            DialogAction(title: "Cancel") { importError = nil }
                         ])
        }
        .dialog(isPresented: showDeleteDialog) {
            DeleteAllDialog(text: $deleteText, onDelete: deleteAll, onCancel: { showDeleteDialog = false })
        }
        .alert(item: Binding(get: { message.map(AlertText.init) }, set: { message = $0?.text })) { item in
            Alert(title: Text("Data & Backup"), message: Text(item.text), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: Actions

    private func exportBackup() {
        runExport(label: "Preparing backup…", fallback: "Could not create the backup.") { try $0.exportBackup() }
    }

    private func exportCSV() {
        runExport(label: "Preparing CSV…", fallback: "Could not create the CSV file.") { try $0.exportCSV() }
    }

    /// File work runs off the main thread; the screen stays visible under a native progress indicator.
    private func runExport(label: String, fallback: String, work: @escaping (BackupServicing) throws -> URL) {
        busyLabel = label
        let backup = model.backup
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try work(backup) }
            DispatchQueue.main.async {
                busyLabel = nil
                switch result {
                case let .success(url): exportItem = ExportItem(url: url)
                case let .failure(error): message = (error as? LocalizedError)?.errorDescription ?? fallback
                }
            }
        }
    }

    private func startImport() {
        if model.workshop.pendingReceipt != nil {
            importError = BackupError.pendingReceipt.errorDescription
            return
        }
        showImporter = true
    }

    private func prepareImport(_ url: URL) {
        busyLabel = "Checking backup…"
        let backup = model.backup
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try backup.prepareImport(from: url) }
            try? FileManager.default.removeItem(at: url)
            DispatchQueue.main.async {
                busyLabel = nil
                switch result {
                case let .success(prepared):
                    model.discardPreparedImport()
                    model.preparedImport = prepared
                    router.push(.importPreview)
                case let .failure(error):
                    haptics.warning()
                    importError = (error as? LocalizedError)?.errorDescription ?? BackupError.unreadableArchive.errorDescription
                }
            }
        }
    }

    private func deleteAll() {
        showDeleteDialog = false
        busyLabel = "Deleting…"
        DispatchQueue.main.async {
            defer { busyLabel = nil }
            do {
                try model.deleteAllData()
                haptics.success()
                coordinator.resetAll()
                Accessibility.announce("All data deleted")
            } catch {
                message = "Nothing was deleted. \((error as? LocalizedError)?.errorDescription ?? "Try again.")"
            }
        }
    }
}

/// Dialog 33: typing DELETE enables the destructive action.
struct DeleteAllDialog: View {
    @Binding var text: String
    let onDelete: () -> Void
    let onCancel: () -> Void
    @FocusState private var focused: Bool

    private var confirmed: Bool { text.trimmingCharacters(in: .whitespaces) == "DELETE" }

    var body: some View {
        ModalDialog(icon: "icon_warning", title: "Delete All Data?",
                    message: "Your journal, photos and collection will be removed. Type DELETE below.",
                    messageToActions: 16.1, bottomPadding: 29) {
            TextField("", text: $text)
                .font(.avenir(17, .demiBold))
                .foregroundColor(Palette.ink)
                .textInputAutocapitalization(.characters)
                .disableAutocorrection(true)
                .placeholder("DELETE", when: text.isEmpty)
                .focused($focused)
                .padding(.horizontal, 17)
                .frame(height: 47)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Palette.inputFill)
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(confirmed ? Palette.success : Palette.error, lineWidth: 1))
                )
                .accessibilityLabel(Text("Type DELETE to confirm"))
            Text(confirmed ? "Confirmed" : "Confirmation required")
                .font(.avenir(13, .demiBold))
                .foregroundColor(confirmed ? Palette.success : Palette.error)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 9)
            SurfaceButton(title: "Delete All Data", kind: confirmed ? .danger : .disabled, action: onDelete)
                .padding(.top, 9.2)
            SurfaceButton(title: "Cancel", action: onCancel)
                .padding(.top, 6)
        }
    }
}

/// Screen 31: counts and date before an explicit Replace.
struct ImportPreviewView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.haptics) private var haptics
    @State private var confirmReplace = false
    @State private var isApplying = false
    @State private var errorMessage: String?

    var body: some View {
        // The Cancel link sits partly in the home-indicator area, as in the mockup.
        LightScreen(bottomPadding: -8.6) {
            ScreenHeader(title: "Review Backup", subtitle: "Nothing changes until you confirm.", onBack: cancel)
            ArtImage(art: .p02)
                .frame(width: 94, height: 89)
                .frame(maxWidth: .infinity)
                .padding(.top, 15.5)
            if let prepared = model.preparedImport {
                VStack(spacing: 17) {
                    ListRow(icon: nil, title: "Lures", value: String(prepared.lureCount))
                    ListRow(icon: nil, title: "Tests", value: String(prepared.testCount))
                    ListRow(icon: nil, title: "Photos", value: String(prepared.photoCount))
                    ListRow(icon: nil, title: "Created", value: Format.mediumDate(prepared.manifest.createdAt))
                }
                .padding(.horizontal, Metrics.margin)
                .padding(.top, 31)
            }
            Text("This replaces your local data. A copy of the current journal is kept first.")
                .font(.avenir(16, .medium))
                .foregroundColor(Palette.secondary)
                .lineSpacing(1.1)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 255, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 40)
        } bottom: {
            GoldButton(title: "Replace Local Data", isEnabled: model.preparedImport != nil, isLoading: isApplying) {
                confirmReplace = true
            }
            LinkButton(title: "Cancel", action: cancel)
                .padding(.top, 13.6)
        }
        .busyOverlay(isApplying, label: "Replacing data…")
        .alert(isPresented: $confirmReplace) {
            Alert(title: Text("Replace local data?"),
                  message: Text("Your current journal, photos and collection will be replaced by this backup. A copy of the current data is kept first."),
                  primaryButton: .destructive(Text("Replace"), action: apply),
                  secondaryButton: .cancel())
        }
        .dialog(isPresented: errorMessage != nil) {
            ActionDialog(icon: "icon_warning", title: "Cannot Open Backup",
                         message: "\(errorMessage ?? "") Your current data is unchanged.",
                         actions: [DialogAction(title: "OK", style: .primary) {
                             errorMessage = nil
                             cancel()
                         }])
        }
    }

    private func cancel() {
        model.discardPreparedImport()
        router.pop()
    }

    private func apply() {
        guard let prepared = model.preparedImport else { return }
        isApplying = true
        let backup = model.backup
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try backup.applyImport(prepared) }
            DispatchQueue.main.async {
                isApplying = false
                switch result {
                case .success:
                    model.finishImport()
                    haptics.success()
                    coordinator.resetAll()
                    Accessibility.announce("Backup imported")
                case let .failure(error):
                    haptics.warning()
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? "The backup could not be applied."
                }
            }
        }
    }
}
