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

/// Plugin mode over real stdin that ends early (root V20, bug B4): each
/// state machine exits 255 with the error on stderr, never a trap, and sends
/// nothing on stdout after its last whole stanza. No input reaches the
/// Secure Enclave (root V15): the recipient is parsed, never used to unwrap,
/// and the identity is not valid bech32.
final class StandardIOStreamEndTests: XCTestCase {
  let recipient = "age1se1qd8k3whkdlquhxp3uhhenptvtxmcxkhasj58s3hgak74s48x2mhp62z4zzr"
  let incomplete = "incomplete stanza"

  func testRecipientV1_Empty() throws {
    try BuiltBinary.assertProtocolError(
      machine: "recipient-v1", input: "", message: incomplete)
  }

  func testIdentityV1_Empty() throws {
    try BuiltBinary.assertProtocolError(
      machine: "identity-v1", input: "", message: incomplete)
  }

  /// A header whose body line never comes.
  func testRecipientV1_TruncatedStanza() throws {
    try BuiltBinary.assertProtocolError(
      machine: "recipient-v1", input: "-> add-recipient \(recipient)\n", message: incomplete)
  }

  func testIdentityV1_TruncatedStanza() throws {
    try BuiltBinary.assertProtocolError(
      machine: "identity-v1",
      input: "-> add-identity AGE-PLUGIN-SE-1BOGUS\n\n-> recipient-stanza 0 piv-p256 dsZPVg\n",
      message: incomplete)
  }

  /// A full body line of 48 bytes, whose next line never comes.
  func testRecipientV1_TruncatedBody() throws {
    try BuiltBinary.assertProtocolError(
      machine: "recipient-v1",
      input: "-> wrap-file-key\n\(Data(count: 48).base64RawEncodedString())\n",
      message: incomplete)
  }

  /// Phase 1 is whole; stdin ends before age answers the recipient stanza.
  func testRecipientV1_NoAnswer() throws {
    let result = try BuiltBinary.runCapturingAll(
      ["--age-plugin=recipient-v1"],
      standardInput:
        "-> add-recipient \(recipient)\n\n-> wrap-file-key\nezXgNAcK/Fet+1A7Q08TBg\n-> done\n\n")
    XCTAssertEqual(.exit, result.reason, "trapped: signal \(result.status)")
    XCTAssertEqual(255, result.status)
    XCTAssertTrue(result.output.hasPrefix("-> recipient-stanza 0 piv-p256 dsZPVg "), result.output)
    XCTAssertFalse(result.output.contains("-> done"), result.output)
    XCTAssertTrue(
      result.error.hasSuffix(": error: plugin protocol: \(incomplete)\n"), result.error)
  }

  /// Phase 1 is whole; stdin ends before age answers the identity error.
  func testIdentityV1_NoAnswer() throws {
    try BuiltBinary.assertProtocolError(
      machine: "identity-v1", input: "-> add-identity AGE-PLUGIN-SE-1BOGUS\n\n-> done\n\n",
      message: incomplete,
      output: "-> error identity 0\n\(errorBody(tooShort))\n")
  }

  let tooShort = Bech32.DecodingError.incorrectChecksumSize.localizedDescription

  func errorBody(_ text: String) -> String {
    return Data(text.utf8).base64RawEncodedString(wrap: true)
  }
}
