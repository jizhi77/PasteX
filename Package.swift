// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PasteX",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PasteX", targets: ["PasteX"])
    ],
    targets: [
        .executableTarget(
            name: "PasteX",
            path: "Sources/PasteX"
        )
    ]
)
