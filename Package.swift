// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iMailSecure",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(name: "iMailSecure", targets: ["iMailSecure"])
    ],
    dependencies: [
        // SwiftMail – auf stabilen Commit gepinnt um API-Änderungen zu vermeiden
        .package(url: "https://github.com/Cocoanetics/SwiftMail.git", revision: "29a1df6"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "iMailSecure",
            dependencies: [
                .product(name: "SwiftMail", package: "SwiftMail"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/iMailSecure"
        ),
        .testTarget(
            name: "iMailSecureTests",
            dependencies: ["iMailSecure"],
            path: "Tests/iMailSecureTests"
        )
    ]
)
