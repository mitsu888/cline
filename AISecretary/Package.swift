// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AISecretary",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "AISecretary", targets: ["AISecretary"])
    ],
    targets: [
        .target(
            name: "AISecretary",
            path: "AISecretary"
        )
    ]
)
