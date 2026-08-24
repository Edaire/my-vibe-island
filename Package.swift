// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "my-vibe-island",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MyVibeIslandApp", targets: ["MyVibeIslandApp"]),
        .library(name: "MyVibeIslandCore", targets: ["MyVibeIslandCore"]),
        .library(name: "MyVibeIslandShared", targets: ["MyVibeIslandShared"]),
        .library(name: "MyVibeIslandHooks", targets: ["MyVibeIslandHooks"]),
        .library(name: "MyVibeIslandSetup", targets: ["MyVibeIslandSetup"]),
        .executable(name: "my-vibe-island-hooks", targets: ["MyVibeIslandHooksExecutable"]),
        .executable(name: "my-vibe-island-bridge", targets: ["MyVibeIslandBridgeExecutable"]),
        .executable(name: "my-vibe-island-setup", targets: ["MyVibeIslandSetupExecutable"]),
        .executable(name: "my-vibe-island", targets: ["MyVibeIslandAppExecutable"])
    ],
    targets: [
        .target(
            name: "MyVibeIslandApp",
            dependencies: ["MyVibeIslandCore", "MyVibeIslandShared", "MyVibeIslandSetup"],
            resources: [.process("Resources")]
        ),
        .target(name: "MyVibeIslandShared"),
        .target(
            name: "MyVibeIslandCore",
            dependencies: ["MyVibeIslandShared"]
        ),
        .target(
            name: "MyVibeIslandHooks",
            dependencies: ["MyVibeIslandCore"]
        ),
        .target(name: "MyVibeIslandSetup"),
        .executableTarget(
            name: "MyVibeIslandHooksExecutable",
            dependencies: ["MyVibeIslandHooks"]
        ),
        .executableTarget(
            name: "MyVibeIslandBridgeExecutable",
            dependencies: ["MyVibeIslandHooks"]
        ),
        .executableTarget(
            name: "MyVibeIslandSetupExecutable",
            dependencies: ["MyVibeIslandSetup"]
        ),
        .executableTarget(
            name: "MyVibeIslandAppExecutable",
            dependencies: ["MyVibeIslandApp"]
        ),
        .testTarget(
            name: "MyVibeIslandCoreTests",
            dependencies: ["MyVibeIslandCore"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "MyVibeIslandSharedTests",
            dependencies: ["MyVibeIslandShared"]
        ),
        .testTarget(
            name: "MyVibeIslandAppTests",
            dependencies: ["MyVibeIslandApp"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "MyVibeIslandHooksTests",
            dependencies: ["MyVibeIslandHooks", "MyVibeIslandCore"]
        ),
        .testTarget(
            name: "MyVibeIslandSetupTests",
            dependencies: ["MyVibeIslandSetup"],
            resources: [.copy("Fixtures")]
        )
    ]
)
