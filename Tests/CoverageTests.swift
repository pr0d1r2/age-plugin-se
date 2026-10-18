import XCTest

@testable import age_plugin_se

#if !os(Linux) && !os(Windows)
  import CryptoKit
#else
  import Crypto
#endif

// Coverage tests (root V10): reach `Sources/` lines the upstream suite leaves
// unrun, through seams that already exist, with no change to `Sources/` and
// no Secure Enclave key or Touch ID (root V15). Each class names its area.

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
