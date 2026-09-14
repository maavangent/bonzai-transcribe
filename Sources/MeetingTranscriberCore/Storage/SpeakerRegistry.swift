import Foundation
import Accelerate

public final class SpeakerRegistry: @unchecked Sendable {
    public private(set) var profiles: [String: SpeakerProfile] = [:]
    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.meetingtranscriber.speakerregistry", attributes: .concurrent)

    public static let defaultStorageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("MeetingTranscriber", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        return appFolder.appendingPathComponent("speakers.json")
    }()

    public init(storageURL: URL = SpeakerRegistry.defaultStorageURL) {
        self.fileURL = storageURL
        load()
    }

    // MARK: - Cosine Similarity via Accelerate
    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        
        var dotProduct: Float = 0.0
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))
        
        var normA: Float = 0.0
        var normB: Float = 0.0
        vDSP_svesq(a, 1, &normA, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &normB, vDSP_Length(b.count))
        
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? max(0.0, min(1.0, dotProduct / denom)) : 0.0
    }

    // MARK: - Matching & Registration
    public func match(embedding: [Float], threshold: Float = 0.80) -> (profile: SpeakerProfile, confidence: Float)? {
        queue.sync {
            var bestMatch: (profile: SpeakerProfile, confidence: Float)? = nil
            
            for (_, profile) in profiles {
                let sim = Self.cosineSimilarity(embedding, profile.centroid)
                if sim >= threshold {
                    if bestMatch == nil || sim > bestMatch!.confidence {
                        bestMatch = (profile, sim)
                    }
                }
            }
            return bestMatch
        }
    }

    public func registerOrUpdate(name: String, embedding: [Float]) {
        queue.async(flags: .barrier) {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty, !embedding.isEmpty else { return }

            if var existing = self.profiles[trimmedName] {
                // Centroid running average update
                let count = Float(existing.sampleCount)
                var updatedCentroid = existing.centroid
                if updatedCentroid.count == embedding.count {
                    for i in 0..<updatedCentroid.count {
                        updatedCentroid[i] = (updatedCentroid[i] * count + embedding[i]) / (count + 1.0)
                    }
                } else {
                    updatedCentroid = embedding
                }
                existing.centroid = updatedCentroid
                existing.sampleCount += 1
                existing.updatedAt = Date()
                self.profiles[trimmedName] = existing
            } else {
                let newProfile = SpeakerProfile(
                    name: trimmedName,
                    centroid: embedding,
                    sampleCount: 1,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                self.profiles[trimmedName] = newProfile
            }
            self.persistLocked()
        }
    }

    public func remove(name: String) {
        queue.async(flags: .barrier) {
            self.profiles.removeValue(forKey: name)
            self.persistLocked()
        }
    }

    public func allProfiles() -> [SpeakerProfile] {
        queue.sync {
            Array(profiles.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
    }

    // MARK: - Persistence
    private func persistLocked() {
        do {
            let data = try JSONEncoder().encode(Array(profiles.values))
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("❌ Failed to save speaker registry: \(error)")
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode([SpeakerProfile].self, from: data)
            queue.async(flags: .barrier) {
                for p in loaded {
                    self.profiles[p.name] = p
                }
            }
        } catch {
            print("⚠️ Failed to load speaker registry: \(error)")
        }
    }
}
