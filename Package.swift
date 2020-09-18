// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "PayCardsRecognizer",
    platforms: [
        .iOS(.v9)
    ],
    products: [
        .library(
            name: "PayCardsRecognizer",
            targets: ["PayCardsRecognizer"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "PayCardsRecognizer",
            url: "https://github.com/therealmyluckyday/PayCards_iOS_Source/releases/download/1.1.7/PayCardsRecognizer.xcframework.zip",
            checksum: "7ed5d79d476c6ed5ccd7679b8b2a1db6c2c9a63962411d9f89f12a19863c38b3"
        )
    ],
    swiftLanguageVersions: [.v5]
)
