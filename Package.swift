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
            checksum: "848089cd60219b7618d042fdad270cce7fcc8cc5461e51d5fb110e658f807eb7"
        )
    ],
    swiftLanguageVersions: [.v5]
)
