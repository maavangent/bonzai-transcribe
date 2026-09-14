import XCTest
@testable import MeetingTranscriberCore

final class SpeakerRegistryTests: XCTestCase {
    var tempStorageURL: URL!
    var registry: SpeakerRegistry!

    override func setUp() {
        super.setUp()
        tempStorageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_speakers_\(UUID().uuidString).json")
        registry = SpeakerRegistry(storageURL: tempStorageURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempStorageURL)
        super.tearDown()
    }

    func testCosineSimilarityIdenticalVectors() {
        let vec: [Float] = [1.0, 2.0, 3.0, 4.0]
        let sim = SpeakerRegistry.cosineSimilarity(vec, vec)
        XCTAssertEqual(sim, 1.0, accuracy: 0.0001)
    }

    func testCosineSimilarityOrthogonalVectors() {
        let vecA: [Float] = [1.0, 0.0]
        let vecB: [Float] = [0.0, 1.0]
        let sim = SpeakerRegistry.cosineSimilarity(vecA, vecB)
        XCTAssertEqual(sim, 0.0, accuracy: 0.0001)
    }

    func testRegisterAndMatchSpeaker() {
        let embedding1: [Float] = (0..<256).map { Float($0) / 256.0 }
        registry.registerOrUpdate(name: "Carsten", embedding: embedding1)
        
        // Match with identical vector
        let match = registry.match(embedding: embedding1, threshold: 0.80)
        XCTAssertNotNil(match)
        XCTAssertEqual(match?.profile.name, "Carsten")
        XCTAssertGreaterThan(match?.confidence ?? 0, 0.99)
    }

    func testCentroidUpdateIncreasesSampleCount() {
        let vecA: [Float] = [1.0, 1.0]
        let vecB: [Float] = [3.0, 3.0]
        
        registry.registerOrUpdate(name: "Lisa", embedding: vecA)
        registry.registerOrUpdate(name: "Lisa", embedding: vecB)
        
        let profiles = registry.allProfiles()
        let lisa = profiles.first(where: { $0.name == "Lisa" })
        XCTAssertNotNil(lisa)
        XCTAssertEqual(lisa?.sampleCount, 2)
        XCTAssertEqual(lisa?.centroid, [2.0, 2.0])
    }
}
