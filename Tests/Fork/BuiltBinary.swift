import XCTest

/// Test helper, not a test file (Tests §V4): the age-plugin-se binary SwiftPM
/// built beside this test bundle, run as a child process with real pipes on
/// stdin and stdout. Under `swift test --enable-code-coverage` the child
/// inherits `LLVM_PROFILE_FILE` and its counts merge with the suite's. No
/// caller touches the Secure Enclave or Touch ID (root V15).
enum BuiltBinary {
  private final class Marker {}

  /// The built binary; missing fails. On macOS the bundle is a `.xctest`
  /// directory in the build directory; on Linux the bundle URL is the build
  /// directory itself.
  static func url(file: StaticString = #filePath, line: UInt = #line) -> URL {
    let bundle = Bundle(for: Marker.self).bundleURL
    let directory =
      bundle.pathExtension == "xctest" ? bundle.deletingLastPathComponent() : bundle
    let url = directory.appendingPathComponent("age-plugin-se")
    XCTAssertTrue(
      FileManager.default.isExecutableFile(atPath: url.path), "no built binary at \(url.path)",
      file: file, line: line)
    return url
  }

  /// Runs the binary with `arguments`, feeding `standardInput`; returns its
  /// exit status and stdout.
  static func run(_ arguments: [String], standardInput: String = "") throws -> (Int32, String) {
    let process = Process()
    process.executableURL = url()
    process.arguments = arguments
    let input = Pipe()
    let output = Pipe()
    process.standardInput = input
    process.standardOutput = output
    try process.run()
    try input.fileHandleForWriting.write(contentsOf: Data(standardInput.utf8))
    try input.fileHandleForWriting.close()
    let data = try output.fileHandleForReading.readToEnd() ?? Data()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
  }
}
