// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "StorageFix",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "StorageFix", targets: ["StorageFixApp"])
    ],
    targets: [
        .target(name: "StorageFixCore"),
        .target(name: "StorageFixDesignSystem", dependencies: ["StorageFixCore"]),
        .target(
            name: "CleanupFeature",
            dependencies: ["StorageFixCore", "StorageFixDesignSystem"]
        ),
        .target(name: "DuplicateFeature", dependencies: ["StorageFixCore", "StorageFixDesignSystem"]),
        .target(name: "LargeFilesFeature", dependencies: ["StorageFixCore", "StorageFixDesignSystem"]),
        .target(name: "StorageMapFeature", dependencies: ["StorageFixCore", "StorageFixDesignSystem"]),
        .target(name: "ApplicationsFeature", dependencies: ["StorageFixCore", "StorageFixDesignSystem"]),
        .target(name: "ScanComparisonFeature", dependencies: ["StorageFixCore", "StorageFixDesignSystem"]),
        .target(name: "ReviewQueueFeature", dependencies: ["StorageFixCore", "StorageFixDesignSystem"]),
        .target(name: "SimilarPhotosFeature", dependencies: ["StorageFixCore", "StorageFixDesignSystem"]),
        .target(name: "WorkspaceFeature", dependencies: ["CleanupFeature", "DuplicateFeature", "LargeFilesFeature", "StorageMapFeature", "ApplicationsFeature", "ReviewQueueFeature", "ScanComparisonFeature", "SimilarPhotosFeature", "StorageFixCore", "StorageFixDesignSystem"]),
        .executableTarget(name: "StorageFixApp", dependencies: ["WorkspaceFeature", "StorageFixDesignSystem", "StorageFixCore", "CleanupFeature", "DuplicateFeature", "LargeFilesFeature", "StorageMapFeature", "ApplicationsFeature", "ReviewQueueFeature", "ScanComparisonFeature", "SimilarPhotosFeature"]),
        .testTarget(name: "FileReviewFeatureTests", dependencies: ["DuplicateFeature", "LargeFilesFeature", "StorageMapFeature", "ApplicationsFeature", "WorkspaceFeature", "ReviewQueueFeature", "ScanComparisonFeature", "SimilarPhotosFeature", "StorageFixCore"]),
        .testTarget(
            name: "StorageFixCoreTests",
            dependencies: ["StorageFixCore"]
        ),
        .testTarget(
            name: "CleanupFeatureTests",
            dependencies: ["CleanupFeature", "StorageFixCore"]
        )
    ]
)
