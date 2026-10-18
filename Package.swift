// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "AgeSecureEnclavePlugin",
  platforms: [.macOS(.v26)],
  dependencies: [
    // Only used on Linux & Windows
    .package(url: "https://github.com/apple/swift-crypto.git", "2.0.0"..<"5.0.0")
  ],
  targets: [
    .executableTarget(
      name: "age-plugin-se",
      dependencies: [
        .product(
          name: "Crypto", package: "swift-crypto",
          condition: .when(platforms: [.linux, .windows]))
      ],
      path: "Sources",
      // Fork: the sherd node spec and its archive are not part of the target
      // (fork decision 22).
      exclude: ["SPEC.md", "SPEC-ARCHIVE.md"]),
    .testTarget(
      name: "Tests", dependencies: ["age-plugin-se"], path: "Tests",
      // Fork: the sherd node spec is not part of the target (fork decision 22).
      exclude: ["SPEC.md"]),
  ]
)
