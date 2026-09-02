// swift-tools-version:6.0
import Foundation
import PackageDescription

// Command Line Tools ship Testing.framework outside the default search
// paths (with full Xcode this is not needed and the arrays stay empty).
let cltFrameworks = "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
let cltTestingLibs = "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
let hasCLTFrameworks = FileManager.default.fileExists(atPath: cltFrameworks)
let testSwiftSettings: [SwiftSetting] = hasCLTFrameworks ? [.unsafeFlags(["-F", cltFrameworks])] : []
let testLinkerSettings: [LinkerSetting] = hasCLTFrameworks
    ? [.unsafeFlags([
        "-F", cltFrameworks,
        "-Xlinker", "-rpath", "-Xlinker", cltFrameworks,
        "-Xlinker", "-rpath", "-Xlinker", cltTestingLibs,
    ])]
    : []

let package = Package(
    name: "iWheel",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CMultitouch"),
        .target(name: "iWheelCore"),
        .executableTarget(
            name: "iWheel",
            dependencies: ["CMultitouch", "iWheelCore"]
        ),
        .testTarget(
            name: "iWheelCoreTests",
            dependencies: ["iWheelCore"],
            swiftSettings: testSwiftSettings,
            linkerSettings: testLinkerSettings
        ),
    ],
    swiftLanguageModes: [.v5]
)
