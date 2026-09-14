// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MeetingTranscriber",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "MeetingTranscriber", targets: ["MeetingTranscriber"]),
        .library(name: "MeetingTranscriberCore", targets: ["MeetingTranscriberCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.0"),
    ],
    targets: [
        .target(
            name: "MeetingTranscriberCore",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
            ]
        ),
        .executableTarget(
            name: "MeetingTranscriber",
            dependencies: [
                "MeetingTranscriberCore",
                .product(name: "FluidAudio", package: "FluidAudio"),
            ],
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/MeetingTranscriber/Info.plist",
                ]),
            ]
        ),
        .testTarget(
            name: "MeetingTranscriberTests",
            dependencies: ["MeetingTranscriberCore"]
        ),
    ]
)
