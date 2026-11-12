// swift-tools-version:6.0
import PackageDescription

// Nur für den manuellen End-to-End-Test gegen einen echten IMAP-Server.
// Nicht Teil der App, nicht im App-Target, kein Einfluss auf das Bundle.
let package = Package(
    name: "IMAPProbe",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(
            url: "https://github.com/Cocoanetics/SwiftMail.git",
            revision: "88c45cbd31b347b373f7c87e197be63eb95efbc2"
        )
    ],
    targets: [
        .executableTarget(
            name: "IMAPProbe",
            dependencies: [.product(name: "SwiftMail", package: "SwiftMail")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
