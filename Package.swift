// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Remora",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Remora",
            path: "Sources/Remora",
            linkerSettings: [
                .linkedFramework("NetFS"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "RemoraTests",
            dependencies: ["Remora"],
            path: "Tests/RemoraTests"
        )
    ]
)
