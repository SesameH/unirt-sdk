// swift-tools-version:5.9
// Copyright (c) 2026 Peter Huang.
// SPDX-License-Identifier: BSD-3-Clause

import PackageDescription

let package = Package(
    name: "UniRTKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "UniRTKit", targets: ["UniRTKit"]),
    ],
    targets: [
        // Exposes the vendored unirt.h (Sources/CUniRT/unirt.h) as a Clang
        // module. Header only — the implementation is closed-source and
        // ships as the compiled UniRTNative binary target below.
        .systemLibrary(name: "CUniRT"),
        // Prebuilt, closed-source (see top-level README.md). Download
        // UniRT.xcframework from this repo's Releases and unzip it here
        // before `swift build`/`xcodebuild` resolves this target — not
        // checked in, same as any other build artifact.
        .binaryTarget(name: "UniRTNative", path: "UniRT.xcframework"),
        .target(name: "UniRTKit", dependencies: ["CUniRT", "UniRTNative"]),
        // Runs one generation against a GGUF model — see README.md's "Run
        // the integration test" section for the required environment.
        .testTarget(name: "UniRTKitTests", dependencies: ["UniRTKit", "CUniRT"]),
    ]
)
