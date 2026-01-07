// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "scenic-events",
    products: [
        .library(
            name: "scenic_events",
            targets: ["scenic_events"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "scenic_events",
            path: "build/libscenic_events.a"
        )
    ]
)
