import XCTest

@testable import age_plugin_se

#if !os(Linux) && !os(Windows)
  import CryptoKit
  import LocalAuthentication
#else
  import Crypto
#endif

// Fork tests of Sources/Plugin.swift (Tests §V4).

/// `DummyCrypto` without ML-KEM-768 (`isMLKEMAvailable` false), standing in
/// for macOS older than 26 on a host that has it.
/// `answers` are its first replies, for a check that must run twice.
final class MLKEMUnavailableCrypto: DummyCrypto {
  var answers: [Bool] = []

  override var isMLKEMAvailable: Bool {
    get { answers.isEmpty ? false : answers.removeFirst() }
    set {}
  }
}

#if compiler(>=6.2)
  /// `DummyCrypto` whose ML-KEM-768 encapsulation fails.
  @available(macOS 26.0, *)
  final class FailingEncapsulationCrypto: DummyCrypto {
    override func encapsulate(mlkem768Key: MLKEM768.PublicKey) throws -> KEM.EncapsulationResult {
      throw DummyCryptoError.dummyError
    }
  }

  /// Plugin protocol: a wrap that throws becomes an `internal` error stanza.
  final class PluginCoverageTests: XCTestCase {
    func testRecipientV1_WrapFailure() throws {
      guard #available(macOS 26.0, *) else { throw XCTSkip("ML-KEM-768 needs macOS 26") }
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

  /// Post-quantum keys where ML-KEM-768 is unavailable (macOS older than 26):
  /// `--pq` keygen and every use of a post-quantum identity fail with
  /// `pqUnavailable`, never a crash; a post-quantum identity still parses,
  /// since its ML-KEM-768 half loads only when used (root V6).
  final class PQUnavailableTests: XCTestCase {
    let pqUnavailable = Plugin.Error.pqUnavailable.localizedDescription

    /// A post-quantum identity and its recipients, made on `DummyCrypto`.
    func pqKey() throws -> (identity: String, recipient: String) {
      guard #available(macOS 26.0, *) else { throw XCTSkip("ML-KEM-768 keys need macOS 26") }
      let (file, recipient) = try Plugin(crypto: DummyCrypto(), stream: MemoryStream())
        .generateKey(accessControl: .none, recipientType: .tag, now: Date(), pq: true)
      let identity = try XCTUnwrap(
        file.split(separator: "\n").first { $0.hasPrefix("AGE-PLUGIN-SE-1") })
      return (String(identity), recipient)
    }

    func plugin(_ stream: MemoryStream = MemoryStream()) -> Plugin {
      Plugin(crypto: MLKEMUnavailableCrypto(), stream: stream)
    }

    func testKeygen_PQ() throws {
      XCTAssertThrowsError(
        try plugin().generateKey(accessControl: .none, recipientType: .tag, now: Date(), pq: true)
      ) { XCTAssertEqual(pqUnavailable, $0.localizedDescription) }
    }

    func testRecipients_PQ() throws {
      let (identity, _) = try pqKey()
      XCTAssertThrowsError(
        try plugin().generateRecipients(input: identity, recipientType: .tag, pq: true)
      ) { XCTAssertEqual(pqUnavailable, $0.localizedDescription) }
    }

    func testRecipients_PQIdentityClassicRecipient() throws {
      let (identity, _) = try pqKey()
      let recipient = try plugin().generateRecipients(
        input: identity, recipientType: .tag, pq: false)
      XCTAssert(recipient.hasPrefix("age1tag1"), recipient)
    }

    func testRecipientV1_PQIdentity() throws {
      let (identity, _) = try pqKey()
      let stream = MemoryStream()
      stream.add(
        input:
          """
          -> add-identity \(identity)

          -> wrap-file-key
          AAAAAAAAAAAAAAAAAAAAAQ
          -> done

          -> ok

          """)
      plugin(stream).runRecipientV1()
      XCTAssertEqual(
        """
        -> error identity 0
        \(Data(pqUnavailable.utf8).base64RawEncodedString())
        -> done

        """, stream.output)
    }

    func testRecipientV1_PQRecipient() throws {
      let (_, recipient) = try pqKey()
      let stream = MemoryStream()
      stream.add(
        input:
          """
          -> add-recipient \(recipient)

          -> wrap-file-key
          AAAAAAAAAAAAAAAAAAAAAQ
          -> done

          -> ok

          """)
      plugin(stream).runRecipientV1()
      XCTAssertEqual(
        """
        -> error internal
        \(Data(pqUnavailable.utf8).base64RawEncodedString())
        -> done

        """, stream.output)
    }

    /// `keygen --pq` checks ML-KEM-768 again before it derives the
    /// post-quantum recipient: gone by then, it throws `pqUnavailable`.
    func testKeygen_PQ_GoneAfterKey() throws {
      let crypto = MLKEMUnavailableCrypto()
      crypto.answers = [true]
      XCTAssertThrowsError(
        try Plugin(crypto: crypto, stream: MemoryStream())
          .generateKey(accessControl: .none, recipientType: .tag, now: Date(), pq: true)
      ) { XCTAssertEqual(pqUnavailable, $0.localizedDescription) }
    }

    /// Wraps a file key to `recipient` on `DummyCrypto`; returns the stanza.
    func wrap(to recipient: String) throws -> String {
      let stream = MemoryStream()
      stream.add(
        input:
          """
          -> add-recipient \(recipient)

          -> wrap-file-key
          AAAAAAAAAAAAAAAAAAAAAQ
          -> done

          -> ok

          """)
      Plugin(crypto: DummyCrypto(), stream: stream).runRecipientV1()
      let lines = stream.output.split(separator: "\n")
      XCTAssert(lines[0].hasPrefix("-> recipient-stanza 0 mlkem768p256tag "), stream.output)
      return "\(lines[0])\n\(lines[1])"
    }

    func unwrap(_ stanza: String, identity: String, crypto: Crypto) -> String {
      let stream = MemoryStream()
      stream.add(
        input:
          """
          -> add-identity \(identity)

          \(stanza)
          -> done

          -> ok

          -> ok

          """)
      Plugin(crypto: crypto, stream: stream).runIdentityV1()
      return stream.output
    }

    func testIdentityV1_PQIdentity() throws {
      let (identity, recipient) = try pqKey()
      let stanza = try wrap(to: recipient)
      XCTAssertEqual(
        """
        -> msg
        \(Data(pqUnavailable.utf8).base64RawEncodedString())
        -> done

        """, unwrap(stanza, identity: identity, crypto: plugin().crypto))
    }

    /// Plugin's checks pass, then HPKE's own guard finds ML-KEM-768 gone:
    /// the unwrap passes its crypto to `HPKE.mlkemp256Decap` (root T29).
    func testIdentityV1_PQIdentity_GoneAtDecap() throws {
      let (identity, recipient) = try pqKey()
      let stanza = try wrap(to: recipient)
      let crypto = MLKEMUnavailableCrypto()
      crypto.answers = [true, true]
      XCTAssertEqual(
        """
        -> msg
        \(Data(pqUnavailable.utf8).base64RawEncodedString())
        -> done

        """, unwrap(stanza, identity: identity, crypto: crypto))
    }

    /// An `mlkem768p256tag` stanza for another key is skipped by a classic
    /// identity without a `msg`, as before lazy loading (root V2).
    func testIdentityV1_ClassicIdentityOtherPQStanza() throws {
      let (_, recipient) = try pqKey()
      let stanza = try wrap(to: recipient)
      let other = DummyCrypto()
      other.dummyKeys.removeLast()
      let (file, _) = try Plugin(crypto: other, stream: MemoryStream())
        .generateKey(accessControl: .none, recipientType: .tag, now: Date())
      let identity = try XCTUnwrap(
        file.split(separator: "\n").first { $0.hasPrefix("AGE-PLUGIN-SE-1") })
      XCTAssertEqual(
        "-> done\n", unwrap(stanza, identity: String(identity), crypto: DummyCrypto()))
    }
  }

  /// A classic recipient holds no ML-KEM-768 key: asking it for one, or for
  /// its `age1tagpq1` form, throws `missingPQ`.
  final class LazyPQRecipientTests: XCTestCase {
    let classic = "age1tag1qvlvs7x2g83gtaqg0dlstnm3ee8tr49dhtdnxudpfd0sy2gedw20k7ux6zq"
    let missingPQ = Plugin.Error.missingPQ.localizedDescription

    func testAgeTagPQRecipient_Classic() throws {
      XCTAssertThrowsError(try Recipient(ageRecipient: classic).ageTagPQRecipient) {
        XCTAssertEqual(missingPQ, $0.localizedDescription)
      }
    }

    func testMLKEM768PublicKey_Classic() throws {
      guard #available(macOS 26.0, *) else { throw XCTSkip("ML-KEM-768 needs macOS 26") }
      XCTAssertThrowsError(try Recipient(ageRecipient: classic).mlkem768PublicKey()) {
        XCTAssertEqual(missingPQ, $0.localizedDescription)
      }
    }
  }

  /// `DummyCrypto` that refuses every ML-KEM-768 key blob, as the Secure
  /// Enclave refuses one it did not make.
  @available(macOS 26.0, *)
  final class BadMLKEMBlobCrypto: DummyCrypto {
    override func newSecureEnclaveMLKEM768PrivateKey(dataRepresentation: Data) throws
      -> SecureEnclaveMLKEM768PrivateKey
    {
      throw DummyCryptoError.dummyError
    }
  }

  /// Where ML-KEM-768 exists, an identity whose ML-KEM-768 half does not
  /// load still fails at parse, as before that half loaded lazily (root V2):
  /// it falls back to the classic format, which its bytes are not.
  final class BadMLKEMHalfTests: XCTestCase {
    func testIdentity_BadMLKEMHalf() throws {
      guard #available(macOS 26.0, *) else { throw XCTSkip("ML-KEM-768 needs macOS 26") }
      let (file, _) = try Plugin(crypto: DummyCrypto(), stream: MemoryStream())
        .generateKey(accessControl: .none, recipientType: .tag, now: Date(), pq: true)
      let identity = try XCTUnwrap(
        file.split(separator: "\n").first { $0.hasPrefix("AGE-PLUGIN-SE-1") })
      XCTAssertNoThrow(try Identity(ageIdentity: String(identity), crypto: DummyCrypto()))
      XCTAssertThrowsError(
        try Identity(ageIdentity: String(identity), crypto: BadMLKEMBlobCrypto()))
    }
  }
#endif

#if !os(Linux) && !os(Windows)
  /// Denial marker (root V13, Sources V1): a Touch ID the user cancelled or
  /// failed, read from the error's code (its own or one beneath it), opens
  /// the plugin's message with `AGE_PLUGIN_SE_DENIED_V1: `. Every other
  /// error keeps its text alone, so its bytes stay upstream's (root V2).
  final class DenialMarkerTests: XCTestCase {
    func status(_ code: OSStatus) -> NSError {
      return NSError(domain: NSOSStatusErrorDomain, code: Int(code))
    }

    func denied(_ error: Swift.Error) -> String {
      return "AGE_PLUGIN_SE_DENIED_V1: \(error.localizedDescription)"
    }

    func testDenialMarker() {
      XCTAssertEqual("AGE_PLUGIN_SE_DENIED_V1", Plugin.denialMarker)
    }

    func testMessage_Denied() {
      let errors: [Swift.Error] = [
        LAError(.userCancel), LAError(.authenticationFailed),
        status(errSecUserCanceled), status(errSecAuthFailed),
      ]
      for error in errors {
        XCTAssertEqual(denied(error), Plugin.message(for: error), "\(error)")
      }
    }

    /// Security may wrap the LocalAuthentication error, and CryptoKit hands
    /// on what Security returns.
    func testMessage_DeniedBeneath() {
      let wrapped = NSError(
        domain: "CryptoTokenKit", code: -9, userInfo: [NSUnderlyingErrorKey: LAError(.userCancel)])
      let errors: [Swift.Error] = [
        wrapped,
        NSError(domain: "com.example", code: 2, userInfo: [NSUnderlyingErrorKey: wrapped]),
        NSError(
          domain: "com.example", code: 1,
          userInfo: [
            NSMultipleUnderlyingErrorsKey: [status(errSecDecode), status(errSecAuthFailed)]
          ]),
      ]
      for error in errors {
        XCTAssertEqual(denied(error), Plugin.message(for: error), "\(error)")
      }
    }

    func testMessage_NotDenied() {
      let errors: [Swift.Error] = [
        LAError(.appCancel), LAError(.systemCancel), LAError(.userFallback),
        LAError(.biometryLockout), LAError(.biometryNotEnrolled), LAError(.biometryNotAvailable),
        LAError(.passcodeNotSet), LAError(.notInteractive), LAError(.invalidContext),
        status(errSecInteractionNotAllowed), status(errSecNotAvailable), status(errSecDecode),
        DummyCryptoError.dummyError, Plugin.Error.pqUnavailable,
        // LocalAuthentication's userCancel code in another domain.
        NSError(domain: "com.example", code: LAError.Code.userCancel.rawValue),
        // Text that reads like a cancel, with no denial code (Sources V1).
        NSError(
          domain: "com.example", code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Canceled by user."]),
        // A code no OSStatus holds.
        NSError(domain: NSOSStatusErrorDomain, code: Int.max),
        NSError(
          domain: "com.example", code: 3,
          userInfo: [NSUnderlyingErrorKey: LAError(.biometryLockout)]),
      ]
      for error in errors {
        XCTAssertEqual(error.localizedDescription, Plugin.message(for: error), "\(error)")
      }
    }

    /// identity-v1 session whose key agreement throws `error`.
    func unwrap(failing error: Swift.Error) -> String {
      let crypto = DummyCrypto()
      crypto.operationError = error
      let stream = MemoryStream()
      stream.add(
        input:
          """
          -> add-identity AGE-PLUGIN-SE-18YNMANPJKHE2ZAZJHRCKZKFXCT78YYWUTY0F730TMTZFV0CM9YHSRP8GPG

          -> recipient-stanza 0 piv-p256 14yi6A Az7IeMpB4oX0CHt/Bc9xzk6x1K262zNxoUtfAikZa5T7
          SLgnrcnHLaJHCx+fwSEWWoflDgL91oDGCGNwb2YaT+4
          -> done

          -> ok

          """)
      Plugin(crypto: crypto, stream: stream).runIdentityV1()
      return stream.output
    }

    func session(msg text: String) -> String {
      return "-> msg\n\(Data(text.utf8).base64RawEncodedString(wrap: true))\n-> done\n"
    }

    /// The text of the `msg` stanza that opens `output`.
    func msg(in output: String) throws -> String {
      let stream = MemoryStream()
      stream.add(input: output)
      let stanza = try Stanza.readFrom(stream: stream)
      XCTAssertEqual("msg", stanza.type)
      return String(decoding: stanza.body, as: UTF8.self)
    }

    func testIdentityV1_Denied() throws {
      for error in [LAError(.userCancel) as NSError, status(errSecAuthFailed)] {
        let output = unwrap(failing: error)
        XCTAssert(try msg(in: output).hasPrefix("AGE_PLUGIN_SE_DENIED_V1: "), output)
        XCTAssertEqual(session(msg: denied(error)), output)
      }
    }

    func testIdentityV1_NotDenied() throws {
      let error = LAError(.biometryLockout)
      let output = unwrap(failing: error)
      XCTAssertEqual(error.localizedDescription, try msg(in: output))
      XCTAssertEqual(session(msg: error.localizedDescription), output)
    }
  }
#endif

#if !os(Linux) && !os(Windows)
  /// `generateKey` makes its access control through `Plugin.newAccessControl`,
  /// with upstream's protection and flags, and throws the error that creation
  /// reports (root V10).
  final class AccessControlSeamTests: XCTestCase {
    func testGenerateKey_Flags() throws {
      let cases: [(KeyAccessControl, SecAccessControlCreateFlags)] = [
        (.none, [.privateKeyUsage]),
        (.passcode, [.privateKeyUsage, .devicePasscode]),
        (.anyBiometry, [.privateKeyUsage, .biometryAny]),
        (.anyBiometryOrPasscode, [.privateKeyUsage, .userPresence]),
        (.anyBiometryAndPasscode, [.privateKeyUsage, .biometryAny, .devicePasscode]),
        (.currentBiometry, [.privateKeyUsage, .biometryCurrentSet]),
        (
          .currentBiometryAndPasscode,
          [.privateKeyUsage, .biometryCurrentSet, .devicePasscode]
        ),
      ]
      for (accessControl, expected) in cases {
        let plugin = Plugin(crypto: DummyCrypto(), stream: MemoryStream())
        var calls: [SecAccessControlCreateFlags] = []
        plugin.newAccessControl = { allocator, protection, flags, error in
          XCTAssertNil(allocator)
          XCTAssertTrue(
            CFEqual(protection, kSecAttrAccessibleWhenUnlockedThisDeviceOnly),
            "\(protection)")
          calls.append(flags)
          return SecAccessControlCreateWithFlags(allocator, protection, flags, error)
        }
        _ = try plugin.generateKey(accessControl: accessControl, recipientType: .se, now: Date())
        XCTAssertEqual([expected], calls, "\(accessControl)")
      }
    }

    func testGenerateKey_AccessControlFails() throws {
      let plugin = Plugin(crypto: DummyCrypto(), stream: MemoryStream())
      plugin.newAccessControl = { _, _, _, error in
        error?.pointee = Unmanaged.passRetained(
          CFErrorCreate(nil, kCFErrorDomainOSStatus, CFIndex(errSecParam), nil))
        return nil
      }
      XCTAssertThrowsError(
        try plugin.generateKey(accessControl: .none, recipientType: .se, now: Date())
      ) { error in
        let error = error as NSError
        XCTAssertEqual(kCFErrorDomainOSStatus as String, error.domain)
        XCTAssertEqual(Int(errSecParam), error.code)
      }
    }
  }
#endif

/// Malformed plugin-protocol input from age over real stdin (root V20,
/// bug B4): a command missing an argument it needs and a recipient stanza
/// without a file index are protocol errors, exit 255, never a trap. An
/// answer other than `ok` is not: the session goes on, as upstream's
/// release build did. No input reaches the Secure Enclave (root V15).
final class PluginProtocolErrorProcessTests: XCTestCase {
  let invalid = "invalid stanza"

  func testRecipientV1_AddRecipientNoArgument() throws {
    try BuiltBinary.assertProtocolError(
      machine: "recipient-v1", input: "-> add-recipient\n\n-> done\n\n", message: invalid)
  }

  func testRecipientV1_AddIdentityNoArgument() throws {
    try BuiltBinary.assertProtocolError(
      machine: "recipient-v1", input: "-> add-identity\n\n-> done\n\n", message: invalid)
  }

  func testIdentityV1_AddIdentityNoArgument() throws {
    try BuiltBinary.assertProtocolError(
      machine: "identity-v1", input: "-> add-identity\n\n-> done\n\n", message: invalid)
  }

  func testIdentityV1_RecipientStanzaNoType() throws {
    try BuiltBinary.assertProtocolError(
      machine: "identity-v1", input: "-> recipient-stanza 0\n\n-> done\n\n", message: invalid)
  }

  func testIdentityV1_RecipientStanzaNoFileIndex() throws {
    try BuiltBinary.assertProtocolError(
      machine: "identity-v1", input: "-> recipient-stanza x X25519 abc\n\n-> done\n\n",
      message: invalid)
  }

  /// The session `machine` runs on `input` ends with `-> done`, exit 0.
  func assertCarriesOn(
    machine: String, input: String, output: String, file: StaticString = #filePath,
    line: UInt = #line
  ) throws {
    let result = try BuiltBinary.runCapturingAll(
      ["--age-plugin=\(machine)"], standardInput: input)
    XCTAssertEqual(.exit, result.reason, "trapped: signal \(result.status)", file: file, line: line)
    XCTAssertEqual(0, result.status, file: file, line: line)
    XCTAssertEqual(output, result.output, file: file, line: line)
    XCTAssertEqual("", result.error, file: file, line: line)
  }

  /// age answers the identity error with `fail`, not `ok`: a debug build
  /// asserted, a release build went on; now both go on.
  func testIdentityV1_NotOK() throws {
    let body = Data(
      Bech32.DecodingError.incorrectChecksumSize.localizedDescription.utf8
    ).base64RawEncodedString(wrap: true)
    try assertCarriesOn(
      machine: "identity-v1",
      input: "-> add-identity AGE-PLUGIN-SE-1BOGUS\n\n-> done\n\n-> fail\n\n",
      output: "-> error identity 0\n\(body)\n-> done\n\n")
  }

  /// age answers the recipient error with `fail`, not `ok`. An empty
  /// argument (`-> add-recipient ` with its trailing space) is a recipient
  /// error, not a protocol one: age sent the argument, and it is not bech32.
  func testRecipientV1_EmptyRecipientNotOK() throws {
    let body = Data(
      Bech32.DecodingError.noChecksumMarker.localizedDescription.utf8
    ).base64RawEncodedString(wrap: true)
    try assertCarriesOn(
      machine: "recipient-v1",
      input:
        "-> add-recipient \n\n-> wrap-file-key\nezXgNAcK/Fet+1A7Q08TBg\n-> done\n\n-> fail\n\n",
      output: "-> error recipient 0\n\(body)\n-> done\n\n")
  }
}

/// Early or malformed plugin-protocol input on a `MemoryStream` (root V20,
/// bug B4): each state machine throws at every place upstream trapped, and
/// upstream's `runRecipientV1()` and `runIdentityV1()` end the session
/// without the trap. Valid sessions keep their bytes (root V2): upstream's
/// PluginTests and the fork tests above run them unchanged.
final class PluginProtocolErrorTests: XCTestCase {
  let recipient = "age1se1qd8k3whkdlquhxp3uhhenptvtxmcxkhasj58s3hgak74s48x2mhp62z4zzr"
  let identity = "AGE-PLUGIN-SE-18YNMANPJKHE2ZAZJHRCKZKFXCT78YYWUTY0F730TMTZFV0CM9YHSRP8GPG"
  let recipientStanza = """
    -> recipient-stanza 0 piv-p256 14yi6A Az7IeMpB4oX0CHt/Bc9xzk6x1K262zNxoUtfAikZa5T7
    SLgnrcnHLaJHCx+fwSEWWoflDgL91oDGCGNwb2YaT+4
    """
  var crypto = DummyCrypto()
  var stream = MemoryStream()

  override func setUp() {
    crypto = DummyCrypto()
    stream = MemoryStream()
  }

  var plugin: Plugin { Plugin(crypto: crypto, stream: stream) }

  func assertError(
    _ expected: Plugin.Error, _ run: () throws -> Void, file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try run(), file: file, line: line) { error in
      XCTAssertEqual(expected, error as? Plugin.Error, file: file, line: line)
    }
  }

  /// MemoryStream reads `""` as no line at all, as an empty stdin.
  func feed(_ input: String) {
    stream.inputLines = input.isEmpty ? [] : input.components(separatedBy: "\n")
  }

  func testRecipientV1_Empty() {
    assertError(.incompleteStanza) { try plugin.recipientV1() }
    XCTAssertEqual("", stream.output)
  }

  func testRecipientV1_TruncatedStanza() {
    feed("-> add-recipient \(recipient)")
    assertError(.incompleteStanza) { try plugin.recipientV1() }
  }

  func testRecipientV1_MissingArgument() {
    for command in ["add-recipient", "add-identity"] {
      setUp()
      feed("-> \(command)\n\n-> done\n")
      assertError(.invalidStanza) { try plugin.recipientV1() }
    }
  }

  /// age never answers the recipient stanza, or its answer is cut short.
  func testRecipientV1_Answer() {
    for (answer, expected) in [
      ("", Plugin.Error.incompleteStanza), ("\n-> ok", .incompleteStanza),
      ("\n->", .invalidStanza),
    ] {
      setUp()
      feed(
        "-> add-recipient \(recipient)\n\n-> wrap-file-key\nezXgNAcK/Fet+1A7Q08TBg\n-> done\n\(answer)"
      )
      assertError(expected) { try plugin.recipientV1() }
      XCTAssertTrue(
        stream.output.hasPrefix("-> recipient-stanza 0 piv-p256 dsZPVg "), stream.output)
      XCTAssertFalse(stream.output.contains("-> done"), stream.output)
    }
  }

  /// Upstream's entry point: the session ends where the input does.
  func testRunRecipientV1_Empty() {
    plugin.runRecipientV1()
    XCTAssertEqual("", stream.output)
  }

  func testIdentityV1_Empty() {
    assertError(.incompleteStanza) { try plugin.identityV1() }
    XCTAssertEqual("", stream.output)
  }

  func testIdentityV1_TruncatedStanza() {
    feed("-> add-identity \(identity)\n\n-> recipient-stanza 0 piv-p256 14yi6A")
    assertError(.incompleteStanza) { try plugin.identityV1() }
  }

  func testIdentityV1_MalformedStanza() {
    for header in [
      "add-identity", "recipient-stanza", "recipient-stanza 0", "recipient-stanza x X25519 a",
    ] {
      setUp()
      feed("-> \(header)\n\n-> done\n")
      assertError(.invalidStanza) { try plugin.identityV1() }
      XCTAssertEqual("", stream.output, header)
    }
  }

  /// The unwrap fails, the plugin sends `msg`, and age never answers it.
  func testIdentityV1_MessageNoAnswer() {
    crypto.failingOperations = true
    feed("-> add-identity \(identity)\n\n\(recipientStanza)\n-> done\n")
    assertError(.incompleteStanza) { try plugin.identityV1() }
    XCTAssertTrue(stream.output.hasPrefix("-> msg\n"), stream.output)
  }

  /// age never answers the identity error, or its answer is cut short.
  func testIdentityV1_Answer() {
    for (answer, expected) in [
      ("", Plugin.Error.incompleteStanza), ("\n-> ok", .incompleteStanza),
      ("\n->", .invalidStanza),
    ] {
      setUp()
      feed("-> add-identity AGE-PLUGIN-SE-1BOGUS\n\n-> done\n\(answer)")
      assertError(expected) { try plugin.identityV1() }
      XCTAssertTrue(stream.output.hasPrefix("-> error identity 0\n"), stream.output)
      XCTAssertFalse(stream.output.contains("-> done"), stream.output)
    }
  }

  func testRunIdentityV1_Empty() {
    plugin.runIdentityV1()
    XCTAssertEqual("", stream.output)
  }

  /// Any whole answer lets the session go on: `fail` and `unsupported` are
  /// answers the protocol allows (root V20).
  func testIdentityV1_AnyAnswer() throws {
    for answer in ["ok", "fail", "unsupported"] {
      setUp()
      feed("-> add-identity AGE-PLUGIN-SE-1BOGUS\n\n-> done\n\n-> \(answer)\n")
      try plugin.identityV1()
      XCTAssertTrue(stream.output.hasSuffix("\n-> done\n"), stream.output)
    }
  }
}

/// Format freeze, root V1 (Tests T1): every identity and recipient in
/// `fixtures/`, made by upstream `v0.2.1` and `57ccea1`, parses and
/// re-encodes byte-identical in this build, and `keygen` and `recipients`
/// write the same files from the same keys. No Secure Enclave: root R14's
/// stand-in (`FixtureCrypto`) answers each fixture blob with the public key
/// its identity file names. `v0.2.1/tag-pq.recipient` is a classic
/// `age1tag1` recipient, as `v0.2.1` wrote it (owner 2026-10-23).
final class FormatFreezeTests: XCTestCase {
  /// `v0.2.1` ignored `recipients --pq` (fixed upstream by `19c59f2`).
  static let classicPQRecipient = "v0.2.1/tag-pq.recipient"

  func identities() throws -> [IdentityFixture] {
    try Fixtures.files(".identity").map(IdentityFixture.init)
  }

  func identity(for recipientPath: String) throws -> IdentityFixture {
    try IdentityFixture(String(recipientPath.dropLast(".recipient".count)) + ".identity")
  }

  func pqAvailable() -> Bool {
    if #available(macOS 26.0, *) { return true }
    return false
  }

  /// Both producers are here, and every file is a kind these tests read.
  func testCorpus() throws {
    XCTAssert(Set(try Fixtures.revisions()).isSuperset(of: ["57ccea1", "v0.2.1"]))
    let kinds = [".identity", ".recipient", "-encrypt.session", "-decrypt.session"]
    for path in try Fixtures.all() {
      XCTAssert(kinds.contains(where: path.hasSuffix), "fixtures/\(path): not read by any test")
    }
    for path in try Fixtures.files(".identity") {
      let stem = String(path.dropLast(".identity".count))
      for suffix in [".recipient", "-decrypt.session"] {
        XCTAssert(try Fixtures.all().contains(stem + suffix), "fixtures/\(stem)\(suffix) missing")
      }
    }
    XCTAssertEqual(6, try Fixtures.files(".identity").count)
    XCTAssertEqual(6, try Fixtures.files(".recipient").count)
  }

  /// The key line parses and re-encodes to the same bytes; the classic
  /// recipient it gives is the one its `# public key:` line names.
  func testIdentities_ReEncode() throws {
    let fixtures = try identities()
    let crypto = try FixtureCrypto(fixtures)
    for fixture in fixtures {
      let line = try XCTUnwrap(fixture.identity, fixture.path)
      let identity = try Identity(ageIdentity: line, crypto: crypto)
      Fixtures.assertSameBytes(line, identity.ageIdentity, fixture.path, "identity")
      XCTAssertEqual(fixture.isPQ, identity.mlkemPrivateKeyData != nil, fixture.path)
      Fixtures.assertSameBytes(
        try XCTUnwrap(fixture.publicKey),
        identity.recipient.ageRecipient(type: fixture.recipientType),
        fixture.path, "# public key")
      if fixture.isPQ, #available(macOS 26.0, *) {
        Fixtures.assertSameBytes(
          try XCTUnwrap(fixture.pqPublicKey),
          try identity.pqRecipient(crypto: crypto).ageTagPQRecipient, fixture.path,
          "# public key (post-quantum)")
      }
    }
  }

  /// `keygen --access-control none` from the same Secure Enclave keys and
  /// clock writes the whole identity file, comments included.
  func testIdentities_Keygen() throws {
    let fixtures = try identities()
    for fixture in fixtures {
      if fixture.isPQ && !pqAvailable() {
        print("format-freeze: fixtures/\(fixture.path): keygen --pq needs macOS 26; skipped")
        continue
      }
      let crypto = try FixtureCrypto(fixtures)
      let (p256, mlkem) = try fixture.blobs()
      crypto.made = [p256] + (mlkem.map { [$0] } ?? [])
      let now = try XCTUnwrap(
        ISO8601DateFormatter().date(from: try XCTUnwrap(fixture.created)), fixture.path)
      let (contents, recipient) = try Plugin(crypto: crypto, stream: MemoryStream()).generateKey(
        accessControl: .none, recipientType: fixture.recipientType, now: now, pq: fixture.isPQ)
      Fixtures.assertSameBytes(fixture.text, contents, fixture.path, "keygen output")
      XCTAssertEqual(fixture.isPQ ? fixture.pqPublicKey : fixture.publicKey, recipient)
      XCTAssert(crypto.made.isEmpty, fixture.path)
    }
  }

  /// Each recipient decodes and re-encodes to the file's bytes.
  func testRecipients_ReEncode() throws {
    for path in try Fixtures.files(".recipient") {
      let text = try Fixtures.text(path)
      let recipient = try Recipient(ageRecipient: text)
      let encoded =
        text.hasPrefix("age1tagpq1")
        ? try recipient.ageTagPQRecipient
        : recipient.ageRecipient(type: text.hasPrefix("age1se1") ? .se : .tag)
      Fixtures.assertSameBytes(text, encoded, path, "recipient")
    }
  }

  /// `recipients` (`--pq` for a `tag-pq` set) on the identity file writes
  /// the recipient file, with no final newline, as upstream's `-o` did.
  func testRecipients_FromIdentity() throws {
    let crypto = try FixtureCrypto(try identities())
    for path in try Fixtures.files(".recipient") {
      let fixture = try identity(for: path)
      let pq = fixture.isPQ && path != Self.classicPQRecipient
      if pq && !pqAvailable() {
        print("format-freeze: fixtures/\(path): recipients --pq needs macOS 26; skipped")
        continue
      }
      let output = try Plugin(crypto: crypto, stream: MemoryStream()).generateRecipients(
        input: fixture.text, recipientType: fixture.recipientType, pq: pq)
      Fixtures.assertSameBytes(try Fixtures.data(path), Data(output.utf8), path, "recipients")
    }
  }

  /// The `v0.2.1` quirk, kept as a classic recipient (owner 2026-10-23):
  /// `recipients --pq` wrote the identity's classic `age1tag1` recipient.
  /// It decodes as one; this build's `--pq` gives the post-quantum one.
  func testTagPQ_V021_IsClassic() throws {
    let path = Self.classicPQRecipient
    let text = try Fixtures.text(path)
    let fixture = try identity(for: path)
    XCTAssert(text.hasPrefix("age1tag1"), text)
    XCTAssertNil(try Recipient(ageRecipient: text).mlkem768PublicKeyData)
    XCTAssertEqual(fixture.publicKey, text)
    guard #available(macOS 26.0, *) else { return }
    let output = try Plugin(crypto: try FixtureCrypto([fixture]), stream: MemoryStream())
      .generateRecipients(input: fixture.text, recipientType: .tag, pq: true)
    XCTAssertEqual(fixture.pqPublicKey, output)
  }
}
