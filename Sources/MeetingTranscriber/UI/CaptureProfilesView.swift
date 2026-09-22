import SwiftUI
import MeetingTranscriberCore

/// A flat, task-focused list of apps whose audio is captured with the microphone.
struct CaptureProfilesView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSource = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Opnamebronnen")
                        .font(.title2.bold())
                    Text("De audio van deze apps wordt samen met je microfoon opgenomen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        showingAddSource = true
                    } label: {
                        Label("Voeg app toe", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Sluit") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            if appState.audioSources.isEmpty {
                ContentUnavailableView(
                    "Geen apps toegevoegd",
                    systemImage: "waveform",
                    description: Text("Voeg een app toe waarvan je de audio wilt opnemen.")
                )
            } else {
                List {
                    Section {
                        ForEach(appState.audioSources) { app in
                            HStack(spacing: 12) {
                                Toggle("", isOn: Binding(
                                    get: { app.isEnabled },
                                    set: { _ in appState.toggleAudioSource(bundleIdentifier: app.bundleIdentifier) }
                                ))
                                .labelsHidden()
                                .help(app.isEnabled ? "Zet audio van \(app.name) uit" : "Zet audio van \(app.name) aan")

                                Image(systemName: "app.fill")
                                    .foregroundColor(app.isEnabled ? .accentColor : .secondary)
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .foregroundStyle(app.isEnabled ? .primary : .secondary)
                                    Text(app.bundleIdentifier)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    appState.removeAudioSource(bundleIdentifier: app.bundleIdentifier)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .help("Verwijder \(app.name) uit de opnamebronnen")
                                .accessibilityLabel("Verwijder \(app.name)")
                            }
                            .padding(.vertical, 3)
                        }
                    } header: {
                        Text("Apps")
                    } footer: {
                        Text("Zet een app uit om die audio niet meer op te nemen, zonder hem te verwijderen.")
                            .font(.caption)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 560, minHeight: 360)
        .sheet(isPresented: $showingAddSource) {
            AddAudioSourceView(appState: appState)
        }
    }
}

private struct AddAudioSourceView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var catalog = InstalledAppCatalog()
    @State private var searchQuery = ""
    @State private var showingManualEntry = false

    private var filteredApps: [InstalledAudioApp] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return catalog.apps }
        return catalog.apps.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("App toevoegen")
                    .font(.title2.bold())
                Spacer()
                Button("Annuleren") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Text("Kies een app waarvan je de audio samen met je microfoon wilt opnemen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Zoek geïnstalleerde apps", text: $searchQuery)
                    .textFieldStyle(.plain)
                Button {
                    catalog.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Ververs app-lijst")
            }
            .padding(7)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 7))

            List {
                ForEach(filteredApps) { app in
                    let alreadyAdded = appState.audioSources.contains { $0.bundleIdentifier == app.bundleIdentifier }
                    Button {
                        guard !alreadyAdded else { return }
                        appState.addAudioSource(app: AudioSourceApp(bundleIdentifier: app.bundleIdentifier, name: app.name))
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                .resizable()
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                    .foregroundStyle(.primary)
                                HStack(spacing: 6) {
                                    Text(app.isRunning ? "Actief" : "Geïnstalleerd")
                                    Text(app.bundleIdentifier)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if alreadyAdded {
                                Label("Toegevoegd", systemImage: "checkmark")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(alreadyAdded)
                    .padding(.vertical, 3)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 260)

            Divider()
            HStack {
                Button("Handmatig toevoegen…") {
                    showingManualEntry = true
                }
                .buttonStyle(.link)
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 520, height: 500)
        .sheet(isPresented: $showingManualEntry) {
            ManualAudioSourceView(appState: appState)
        }
    }
}

private struct ManualAudioSourceView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var bundleIdentifier = ""
    @State private var appName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("App handmatig toevoegen")
                .font(.title2.bold())
            Text("Gebruik dit alleen als de app niet in de lijst staat.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Naam", text: $appName)
            TextField("Bundle identifier", text: $bundleIdentifier)
            HStack {
                Spacer()
                Button("Annuleren") { dismiss() }
                Button("Toevoegen") {
                    let id = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !id.isEmpty else { return }
                    let name = appName.trimmingCharacters(in: .whitespacesAndNewlines)
                    appState.addAudioSource(app: AudioSourceApp(bundleIdentifier: id, name: name.isEmpty ? id : name))
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
