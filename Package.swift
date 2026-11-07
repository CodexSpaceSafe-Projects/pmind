// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = [.library(name: "MindMapCore", targets: ["MindMapCore"])]
var targets: [Target] = [
    .target(name: "MindMapCore"),
    .testTarget(name: "MindMapCoreTests", dependencies: ["MindMapCore"]),
]
#if os(macOS)
products.append(.executable(name: "pmind", targets: ["PMindApp"]))
targets.append(.executableTarget(name: "PMindApp", dependencies: ["MindMapCore"], path: "App"))
targets.append(.testTarget(name: "PMindAppTests", dependencies: ["PMindApp", "MindMapCore"], path: "Tests/PMindAppTests"))
#endif

let package = Package(
    name: "pmind", platforms: [.macOS(.v14)], products: products, targets: targets
)
