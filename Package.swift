// swift-tools-version: 5.7.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "NetworkKit",
            targets: ["NetworkKit"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/multibar/CoreKit.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/firebase/firebase-ios-sdk.git",
            from: "10.3.0"
        )
    ],
    targets: [
        .target(
            name: "NetworkKit",
            dependencies: [
                .product(name: "CoreKit", package: "CoreKit"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestoreSwift", package: "firebase-ios-sdk")
            ]
        ),
        .testTarget(
            name: "NetworkKitTests",
            dependencies: ["NetworkKit"]),
    ]
)
