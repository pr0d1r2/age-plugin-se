import XCTest

@testable import age_plugin_se

#if !os(Linux) && !os(Windows)
  import CryptoKit
#else
  import Crypto
#endif

// Fork tests of Sources/Plugin.swift (Tests §V4).

/// `DummyCrypto` without ML-KEM-768 (`isMLKEMAvailable` false), standing in
/// for macOS older than 26 on a host that has it.
final class MLKEMUnavailableCrypto: DummyCrypto {
  override init() {
    super.init()
    isMLKEMAvailable = false
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
#endif
