// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "xue_hua_device_info",
    platforms: [
        .macOS("10.15")
    ],
    products: [
        .library(name: "xue-hua-device-info", targets: ["xue_hua_device_info"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "xue_hua_device_info",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: []
        )
    ]
)
