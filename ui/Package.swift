// swift-tools-version: 5.9

import PackageDescription

// Native SwiftUI front end for Starlight.
//
// StarlightUI holds the views, scenes and state, and talks to the rest of the
// app only through the HostService and StreamControlling protocols. The
// StarlightMockApp executable runs the UI against mock implementations of
// those protocols, so the UI can be developed and reviewed without the
// streaming core.
let package = Package(
    name: "StarlightUI",
    platforms: [
        // Matches CMAKE_OSX_DEPLOYMENT_TARGET in the top-level CMakeLists.txt.
        .macOS(.v14)
    ],
    products: [
        .library(name: "StarlightUI", targets: ["StarlightUI"]),
        .executable(name: "StarlightMockApp", targets: ["StarlightMockApp"])
    ],
    targets: [
        .target(name: "StarlightUI"),
        .executableTarget(
            name: "StarlightMockApp",
            dependencies: ["StarlightUI"]
        )
    ]
)
