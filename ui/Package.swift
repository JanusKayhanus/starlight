// swift-tools-version: 5.9

import Foundation
import PackageDescription

// Native SwiftUI front end for Starlight.
//
// StarlightUI holds the views, scenes and state, and talks to the rest of the
// app only through the HostService and StreamControlling protocols. The
// StarlightMockApp executable runs the UI against mock implementations of
// those protocols, so the UI can be developed and reviewed without the
// streaming core.
//
// The Starlight executable is the real app: it implements those protocols on
// top of the C++ core in client/ through the StarlightCore bridge. It links
// libMoonlightCore.a and OpenSSL, so build it through CMake, which passes their
// library search paths (`cmake --build build`). The mock app builds on its own.

// client/, for the core headers the bridge includes.
let coreHeaders = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("client")
    .path

let package = Package(
    name: "StarlightUI",
    platforms: [
        // Matches CMAKE_OSX_DEPLOYMENT_TARGET in the top-level CMakeLists.txt.
        .macOS(.v14)
    ],
    products: [
        .library(name: "StarlightUI", targets: ["StarlightUI"]),
        .executable(name: "StarlightMockApp", targets: ["StarlightMockApp"]),
        .executable(name: "Starlight", targets: ["Starlight"])
    ],
    targets: [
        .target(name: "StarlightUI"),
        .executableTarget(
            name: "StarlightMockApp",
            dependencies: ["StarlightUI"]
        ),
        .target(
            name: "StarlightCore",
            cxxSettings: [
                .unsafeFlags(["-I", coreHeaders])
            ],
            linkerSettings: [
                .linkedLibrary("MoonlightCore"),
                .linkedLibrary("ssl.3"),
                .linkedLibrary("crypto.3"),
                .linkedFramework("CoreFoundation")
            ]
        ),
        .executableTarget(
            name: "Starlight",
            dependencies: ["StarlightUI", "StarlightCore"],
            linkerSettings: [
                // OpenSSL comes from Moonlight.app's Frameworks directory.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        )
    ],
    cxxLanguageStandard: .gnucxx17
)
