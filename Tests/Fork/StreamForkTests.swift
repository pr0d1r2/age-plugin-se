import XCTest

@testable import age_plugin_se

// Fork tests of Sources/Stream.swift (Tests §V4).

/// `StandardIOStream`, which only the process entry point builds: the built
/// binary speaks the plugin protocol over real stdin and stdout (root V10).
final class StandardIOStreamProcessTests: XCTestCase {
  /// age's side of `fixtures/v0.2.1/se-classic-encrypt.session`, over real
  /// stdin and stdout; wrapping needs no Secure Enclave.
  func testRecipientV1() throws {
    let session = try String(
      contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../fixtures/v0.2.1/se-classic-encrypt.session"),
      encoding: .utf8)
    let toPlugin = session.split(separator: "\n", omittingEmptySubsequences: false)
      .filter { $0.hasPrefix(">") }.map { $0.dropFirst(2) }.joined(separator: "\n")
    let (status, output) = try BuiltBinary.run(
      ["--age-plugin=recipient-v1"], standardInput: toPlugin + "\n")
    XCTAssertEqual(0, status)
    let lines = output.components(separatedBy: "\n")
    XCTAssertTrue(lines[0].hasPrefix("-> recipient-stanza 0 piv-p256 "), output)
    XCTAssertEqual(["-> done", "", ""], Array(lines.suffix(3)), output)
  }
}
