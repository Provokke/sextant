// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Sextant",
    products: [
        .library(name: "Sextant", targets: ["Sextant"])
    ],
    targets: [
        .target(name: "Sextant"),
        .testTarget(name: "SextantTests", dependencies: ["Sextant"])
    ]
)

