import SwiftUI
import MeetingTranscriberCore

struct SpeakerManagementView: View {
    @ObservedObject var appState: AppState
    @State private var profiles: [SpeakerProfile] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Opgeslagen Stemprofielen")
                        .font(.title2.bold())
                    Text("Deze stemprofielen worden gebruikt om sprekers automatisch te herkennen.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Verversen") {
                    loadProfiles()
                }
            }
            .padding([.top, .horizontal])

            Divider()

            if profiles.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Nog geen stemprofielen opgeslagen")
                        .font(.headline)
                    Text("Namen die je tijdens het reviewen van meetings bevestigt worden hier automatisch bewaard.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(profiles) { profile in
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                    .font(.body.weight(.medium))
                                Text("\(profile.sampleCount) meeting-samples • Laatst bijgewerkt: \(formattedDate(profile.updatedAt))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                appState.speakerRegistry.remove(name: profile.name)
                                loadProfiles()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .frame(minWidth: 450, minHeight: 350)
        .onAppear {
            loadProfiles()
        }
    }

    private func loadProfiles() {
        profiles = appState.speakerRegistry.allProfiles()
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}
