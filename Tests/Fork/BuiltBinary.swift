import XCTest

/// Test helper, not a test file (Tests §V4): the age-plugin-se binary SwiftPM
/// built beside this test bundle, run as a child process with real pipes on
/// stdin and stdout. Under `swift test --enable-code-coverage` the child
/// inherits `LLVM_PROFILE_FILE` and its counts merge with the suite's. No
/// caller triggers Touch ID (root V15); only the gated hardware suite's
/// round trip (`CryptoKitHardwareTests`) makes a Secure Enclave key, with
/// `--access-control none`.
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
    try run(arguments, standardInput: Data(standardInput.utf8))
  }

  /// Runs the binary with `arguments`, feeding the raw bytes `standardInput`.
  static func run(_ arguments: [String], standardInput: Data) throws -> (Int32, String) {
    let result = try runCapturingAll(arguments, standardInput: standardInput)
    return (result.status, result.output)
  }

  /// How a run ended: exit status (or signal), whether it exited or was
  /// killed by a signal (a trap), and its stdout and stderr.
  struct Result {
    var status: Int32
    var reason: Process.TerminationReason
    var output: String
    var error: String
  }

  /// Runs the binary like `run`, and keeps its stderr and termination reason.
  static func runCapturingAll(_ arguments: [String], standardInput: String) throws -> Result {
    try runCapturingAll(arguments, standardInput: Data(standardInput.utf8))
  }

  /// Runs the binary like `run` on raw bytes, keeping stderr and the reason.
  static func runCapturingAll(_ arguments: [String], standardInput: Data) throws -> Result {
    let process = Process()
    process.executableURL = url()
    process.arguments = arguments
    let input = Pipe()
    let output = Pipe()
    let error = Pipe()
    process.standardInput = input
    process.standardOutput = output
    process.standardError = error
    try process.run()
    try input.fileHandleForWriting.write(contentsOf: standardInput)
    try input.fileHandleForWriting.close()
    let data = try output.fileHandleForReading.readToEnd() ?? Data()
    let errorData = try error.fileHandleForReading.readToEnd() ?? Data()
    process.waitUntilExit()
    return Result(
      status: process.terminationStatus, reason: process.terminationReason,
      output: String(decoding: data, as: UTF8.self),
      error: String(decoding: errorData, as: UTF8.self))
  }

  /// Runs `--age-plugin=<machine>` on `input` and asserts the plugin exits
  /// 255, never a trap, with `<path>: error: plugin protocol: <message>` on
  /// stderr and `output` (the protocol bytes sent before it) on stdout
  /// (root V20).
  static func assertProtocolError(
    machine: String, input: String, message: String, output: String = "",
    file: StaticString = #filePath, line: UInt = #line
  ) throws {
    let path = url(file: file, line: line).path
    let result = try runCapturingAll(["--age-plugin=\(machine)"], standardInput: input)
    XCTAssertEqual(.exit, result.reason, "trapped: signal \(result.status)", file: file, line: line)
    XCTAssertEqual(255, result.status, file: file, line: line)
    XCTAssertEqual(output, result.output, file: file, line: line)
    XCTAssertEqual(
      "\(path): error: plugin protocol: \(message)\n", result.error, file: file, line: line)
  }
}
