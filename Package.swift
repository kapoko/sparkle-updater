// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "SparkleUpdater",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "SparkleUpdater", targets: ["SparkleUpdater"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
    ],
    targets: [
        .target(
            name: "SparkleUpdater",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ]
        )
    ]
)
