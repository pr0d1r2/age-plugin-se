import XCTest

@testable import age_plugin_se

#if !os(Linux) && !os(Windows)
  import CryptoKit
#else
  import Crypto
#endif

// Coverage tests (root V10): reach `Sources/` lines the upstream suite leaves
// unrun, through the seams `Sources/` has (`CLI.run` is the one the fork
// carries, root T28) and the built binary's process entry point, with no
// Secure Enclave key or Touch ID (root V15).
// Each class names its area.

/// Bech32 decode errors and their descriptions.
final class Bech32CoverageTests: XCTestCase {
  func assertDecodeError(
    _ str: String, _ expected: Bech32.DecodingError, file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try Bech32().decode(str), file: file, line: line) { error in
      XCTAssertEqual(
        expected.localizedDescription, error.localizedDescription, file: file, line: line)
    }
  }

  func testDecode_MixedCase() {
    assertDecodeError("aB1qqqqqqq", .invalidCase)
  }

  func testDecode_NoChecksumMarker() {
    assertDecodeError("qqqqqqqq", .noChecksumMarker)
  }

  func testDecode_EmptyHrp() {
    assertDecodeError("1qqqqqqqq", .incorrectHrpSize)
  }

  func testDecode_ShortChecksum() {
    assertDecodeError("a1qqqqq", .incorrectChecksumSize)
  }

  func testDecode_InvalidCharacter() {
    assertDecodeError("a1qqqqqqb", .invalidCharacter)
  }

  /// Valid checksum over one 5-bit value: 5 leftover bits are a whole
  /// padding group, which bech32 forbids.
  func testDecode_PaddingTooLong() {
    assertDecodeError("a1q3g6mn3", .bitsConversionFailed)
  }

  /// Valid checksum over two 5-bit values whose 2 padding bits are not zero.
  func testDecode_NonZeroPadding() {
    assertDecodeError("a1qpamnt9j", .bitsConversionFailed)
  }

  func testDecodingError_Descriptions() {
    let cases: [(Bech32.DecodingError, String)] = [
      (.bitsConversionFailed, "Failed to perform bits conversion"),
      (.checksumMismatch, "Checksum doesn't match"),
      (.incorrectChecksumSize, "Checksum size too low"),
      (.incorrectHrpSize, "Human-readable-part is too small or empty"),
      (.invalidCase, "String contains mixed case characters"),
      (.invalidCharacter, "Invalid character met on decoding"),
      (.noChecksumMarker, "Checksum delimiter not found"),
      (.nonPrintableCharacter, "Non printable character in input string"),
      (.nonUTF8String, "String cannot be decoded by utf8 decoder"),
    ]
    for (error, description) in cases {
      XCTAssertEqual(description, error.errorDescription)
    }
  }
}

/// `Options` error paths, error descriptions and enum mappings.
final class OptionsCoverageTests: XCTestCase {
  func testParse_UnknownOption() {
    XCTAssertThrowsError(try Options.parse(["_", "keygen", "--bogus"])) { error in
      XCTAssertEqual(error as? Options.Error, .unknownOption("--bogus"))
    }
  }

  func testError_Descriptions() {
    XCTAssertEqual(
      "unknown option: `--bogus`", Options.Error.unknownOption("--bogus").localizedDescription)
    XCTAssertEqual(
      "missing value for option `--output`",
      Options.Error.missingValue("--output").localizedDescription)
    XCTAssertEqual(
      "invalid value for option `--access-control`: `x`",
      Options.Error.invalidValue("--access-control", "x").localizedDescription)
  }

  func testAccessControl_KeyAccessControl() {
    let cases: [(Options.AccessControl, KeyAccessControl)] = [
      (.none, .none),
      (.passcode, .passcode),
      (.anyBiometry, .anyBiometry),
      (.anyBiometryOrPasscode, .anyBiometryOrPasscode),
      (.anyBiometryAndPasscode, .anyBiometryAndPasscode),
      (.currentBiometry, .currentBiometry),
      (.currentBiometryAndPasscode, .currentBiometryAndPasscode),
    ]
    for (option, expected) in cases {
      XCTAssertEqual(expected, option.keyAccessControl, option.rawValue)
    }
  }

  func testRecipientType_RecipientType() {
    XCTAssertEqual(.se, Options.RecipientType.se.recipientType)
    XCTAssertEqual(.tag, Options.RecipientType.tag.recipientType)
  }
}

#if compiler(>=6.2)
  /// `DummyCrypto` whose ML-KEM-768 encapsulation fails.
  final class FailingEncapsulationCrypto: DummyCrypto {
    override func encapsulate(mlkem768Key: MLKEM768.PublicKey) throws -> KEM.EncapsulationResult {
      throw DummyCryptoError.dummyError
    }
  }

  /// Plugin protocol: a wrap that throws becomes an `internal` error stanza.
  final class PluginCoverageTests: XCTestCase {
    func testRecipientV1_WrapFailure() throws {
      let (_, recipient) = try Plugin(crypto: DummyCrypto(), stream: MemoryStream())
        .generateKey(
          accessControl: .anyBiometryOrPasscode, recipientType: .tag, now: Date(), pq: true)
      XCTAssert(recipient.hasPrefix("age1tagpq1"), recipient)
      let stream = MemoryStream()
      let plugin = Plugin(crypto: FailingEncapsulationCrypto(), stream: stream)
      stream.add(
        input:
          """
          -> add-recipient \(recipient)

          -> wrap-file-key
          AAAAAAAAAAAAAAAAAAAAAQ
          -> done

          -> ok

          """)
      plugin.runRecipientV1()

      XCTAssertEqual(
        """
        -> error internal
        ZHVtbXkgZXJyb3I
        -> done

        """, stream.output)
    }
  }
#endif

#if !os(Linux) && !os(Windows)
  /// The two `CryptoKitCrypto` members that touch no Secure Enclave key and
  /// so no Touch ID: the availability probe and ML-KEM-768 encapsulation to
  /// a software public key (the recipient side of a wrap).
  final class CryptoKitCryptoCoverageTests: XCTestCase {
    func testIsSecureEnclaveAvailable() {
      XCTAssertEqual(
        SecureEnclave.isAvailable, CryptoKitCrypto(environment: [:]).isSecureEnclaveAvailable)
    }

    #if compiler(>=6.2)
      func testEncapsulate_SoftwareMLKEM768Key() throws {
        let key = try MLKEM768.PrivateKey()
        let result = try CryptoKitCrypto(environment: [:]).encapsulate(mlkem768Key: key.publicKey)
        XCTAssertEqual(result.sharedSecret, try key.decapsulate(result.encapsulated))
      }
    #endif
  }
#endif

/// `CLI.run`, the dispatch `CLI.main` hands its arguments to: every command
/// on `DummyCrypto` and `MemoryStream`, with printed lines captured.
final class CLIRunCoverageTests: XCTestCase {
  var stream = MemoryStream()
  var printed: [String] = []
  var directory = URL(fileURLWithPath: NSTemporaryDirectory())

  override func setUpWithError() throws {
    stream = MemoryStream()
    printed = []
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("CLIRunCoverageTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: directory)
  }

  func run(_ arguments: [String], standardInput: String = "") throws {
    try CLI.run(
      ["age-plugin-se"] + arguments, plugin: Plugin(crypto: DummyCrypto(), stream: stream),
      readStandardInput: { Data(standardInput.utf8) }, print: { self.printed.append($0) })
  }

  /// Runs `keygen` and returns the identity file text and its recipient.
  func keygen() throws -> (String, String) {
    try run(["keygen"])
    let identity = try XCTUnwrap(printed.first)
    let recipient = try XCTUnwrap(
      identity.components(separatedBy: "\n").first { $0.hasPrefix("# public key: ") })
    printed = []
    return (identity, String(recipient.dropFirst("# public key: ".count)))
  }

  func testHelp() throws {
    try run([])
    try run(["--help"])
    XCTAssertEqual([Options.help, Options.help], printed)
  }

  func testVersion() throws {
    try run(["--version"])
    XCTAssertEqual([age_plugin_se.version], printed)
  }

  func testKeygen() throws {
    let (identity, recipient) = try keygen()
    XCTAssertTrue(identity.contains("\nAGE-PLUGIN-SE-1"))
    XCTAssertTrue(recipient.hasPrefix("age1se1"))
  }

  func testKeygen_Output() throws {
    let file = directory.appendingPathComponent("identity.txt").path
    try run(["keygen", "-o", file, "--access-control", "none"])
    XCTAssertEqual(1, printed.count)
    XCTAssertTrue(try XCTUnwrap(printed.first).hasPrefix("Public key: age1se1"))
    let identity = try String(contentsOfFile: file, encoding: .utf8)
    XCTAssertTrue(identity.contains("# access control: none\n"))
  }

  func testRecipients_Input() throws {
    let (identity, recipient) = try keygen()
    let file = directory.appendingPathComponent("identity.txt").path
    try identity.write(toFile: file, atomically: true, encoding: .utf8)
    try run(["recipients", "-i", file])
    XCTAssertEqual([recipient], printed)
  }

  func testRecipients_StandardInput() throws {
    let (identity, recipient) = try keygen()
    try run(["recipients", "--recipient-type", "tag"], standardInput: identity)
    XCTAssertEqual(1, printed.count)
    XCTAssertTrue(try XCTUnwrap(printed.first).hasPrefix("age1tag1"))
    XCTAssertNotEqual(recipient, printed.first)
  }

  func testRecipients_Output() throws {
    let (identity, recipient) = try keygen()
    let file = directory.appendingPathComponent("recipients.txt").path
    try run(["recipients", "-o", file], standardInput: identity)
    XCTAssertEqual([], printed)
    XCTAssertEqual(recipient, try String(contentsOfFile: file, encoding: .utf8))
    let attributes = try FileManager.default.attributesOfItem(atPath: file)
    XCTAssertEqual(0o600, (attributes[.posixPermissions] as? NSNumber)?.intValue)
  }

  func testRecipients_NoIdentity() throws {
    try run(["recipients"], standardInput: "# no identity here\n")
    XCTAssertEqual([], printed)
  }

  func testPlugin_RecipientV1() throws {
    stream.add(input: "-> done\n")
    try run(["--age-plugin=recipient-v1"])
    XCTAssertEqual("-> done\n", stream.output)
    XCTAssertEqual([], printed)
  }

  func testPlugin_IdentityV1() throws {
    stream.add(input: "-> done\n")
    try run(["--age-plugin", "identity-v1"])
    XCTAssertEqual("-> done\n", stream.output)
    XCTAssertEqual([], printed)
  }

  func testError_Thrown() throws {
    XCTAssertThrowsError(try run(["--bogus"])) { error in
      XCTAssertEqual(Options.Error.unknownOption("--bogus"), error as? Options.Error)
    }
    XCTAssertEqual([], printed)
  }
}

/// `CLI.main`, `CLI.run`'s default stdin and print, and `StandardIOStream`:
/// the built binary run as a child process, so only the process entry point
/// reaches them. Under `swift test --enable-code-coverage` the child inherits
/// `LLVM_PROFILE_FILE` and its counts merge with the suite's. No case touches
/// the Secure Enclave or Touch ID (root V15).
final class CLIProcessCoverageTests: XCTestCase {
  /// The binary SwiftPM built beside this test bundle; missing fails.
  func binary() throws -> URL {
    let url = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
      .appendingPathComponent("age-plugin-se")
    XCTAssertTrue(
      FileManager.default.isExecutableFile(atPath: url.path), "no built binary at \(url.path)")
    return url
  }

  func run(_ arguments: [String], standardInput: String = "") throws -> (Int32, String) {
    let process = Process()
    process.executableURL = try binary()
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

  func testVersion() throws {
    let (status, output) = try run(["--version"])
    XCTAssertEqual(0, status)
    XCTAssertEqual("\(age_plugin_se.version)\n", output)
  }

  func testHelp() throws {
    let (status, output) = try run(["--help"])
    XCTAssertEqual(0, status)
    XCTAssertEqual("\(Options.help)\n", output)
  }

  /// R13: the error goes to stdout and the exit status is 255.
  func testUnknownOption() throws {
    let path = try binary().path
    let (status, output) = try run(["--bogus"])
    XCTAssertEqual(255, status)
    XCTAssertEqual("\(path): error: unknown option: `--bogus`\n", output)
  }

  /// Comment lines only: real stdin is read, no identity is parsed.
  func testRecipientsFromStandardInput() throws {
    let (status, output) = try run(["recipients"], standardInput: "# no identity\n")
    XCTAssertEqual(0, status)
    XCTAssertEqual("", output)
  }

  /// age's side of `fixtures/v0.2.1/se-classic-encrypt.session`, over real
  /// stdin and stdout; wrapping needs no Secure Enclave.
  func testRecipientV1() throws {
    let session = try String(
      contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../fixtures/v0.2.1/se-classic-encrypt.session"),
      encoding: .utf8)
    let toPlugin = session.split(separator: "\n", omittingEmptySubsequences: false)
      .filter { $0.hasPrefix(">") }.map { $0.dropFirst(2) }.joined(separator: "\n")
    let (status, output) = try run(["--age-plugin=recipient-v1"], standardInput: toPlugin + "\n")
    XCTAssertEqual(0, status)
    let lines = output.components(separatedBy: "\n")
    XCTAssertTrue(lines[0].hasPrefix("-> recipient-stanza 0 piv-p256 "), output)
    XCTAssertEqual(["-> done", "", ""], Array(lines.suffix(3)), output)
  }
}
