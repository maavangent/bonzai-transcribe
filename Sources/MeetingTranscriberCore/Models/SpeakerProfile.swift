import Foundation

public struct SpeakerProfile: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var centroid: [Float]
    public var sampleCount: Int
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        centroid: [Float],
        sampleCount: Int = 1,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.centroid = centroid
        self.sampleCount = sampleCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
