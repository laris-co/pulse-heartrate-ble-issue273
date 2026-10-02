// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PulseSignal",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "PulseSignal", targets: ["PulseSignal"]),
    ],
    targets: [
        .target(
            name: "PulseSignal",
            path: "Sources",
            exclude: [
                "PulseApp.swift", "PulseStore.swift", "PulseView.swift",
                "PulseSculpture.swift", "PulseHeartStage.swift", "PulsePalette.swift",
                "PulseDevicesSheet.swift", "PulseDetailsSheet.swift",
                "PulseConnectIQManager.swift",
            ],
            sources: [
                "PulseSignal.swift", "PulseCompanionPacket.swift",
                "PulseHeartGeometry.swift",
            ]
        ),
        .testTarget(name: "PulseSignalTests", dependencies: ["PulseSignal"]),
    ]
)
