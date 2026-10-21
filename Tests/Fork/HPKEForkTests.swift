import XCTest

@testable import age_plugin_se

#if !os(Linux) && !os(Windows)
  import CryptoKit
#else
  import Crypto
#endif

// Fork tests of Sources/HPKE.swift (Tests §V4).

/// `HPKE`, the RFC 9180 base mode every stanza is sealed with (root V2):
/// the suite IDs are pinned, and each KEM's encapsulation decapsulates to
/// the same shared secret, on `DummyCrypto` keys (root V15).
final class HPKEForkTests: XCTestCase {
  func testSuiteID() {
    let hpke = Data("HPKE".utf8)
    XCTAssertEqual(hpke + Data([0x00, 0x10, 0x00, 0x01, 0x00, 0x03]), HPKE.KEM.dhkemP256.suiteID)
    XCTAssertEqual(
      hpke + Data([0x00, 0x50, 0x00, 0x01, 0x00, 0x03]), HPKE.KEM.mlkem768P256.suiteID)
  }

  func testContext_SeparatesKEMAndInfo() {
    let secret = SymmetricKey(data: Data(repeating: 7, count: 32))
    let base = HPKE.context(kem: .dhkemP256, sharedSecret: secret, info: Data("a".utf8))
    let otherKEM = HPKE.context(kem: .mlkem768P256, sharedSecret: secret, info: Data("a".utf8))
    let otherInfo = HPKE.context(kem: .dhkemP256, sharedSecret: secret, info: Data("b".utf8))
    XCTAssertNotEqual(base.key, otherKEM.key)
    XCTAssertNotEqual(base.key, otherInfo.key)
    let again = HPKE.context(kem: .dhkemP256, sharedSecret: secret, info: Data("a".utf8))
    XCTAssertEqual(base.key, again.key)
    XCTAssertEqual(Data(base.nonce), Data(again.nonce))
  }

  func testDHKEM_RoundTrip() throws {
    let crypto = DummyCrypto()
    let recipient = try crypto.newSecureEnclaveP256PrivateKey(
      dataRepresentation: crypto.dummyKeys[0])
    let (sharedSecret, enc) = try HPKE.dhkemEncap(
      recipientKey: recipient.publicKey, crypto: crypto)
    XCTAssertEqual(65, enc.count)
    XCTAssertEqual(sharedSecret, try HPKE.dhkemDecap(enc: enc, recipientKey: recipient))
  }

  #if compiler(>=6.2)
    /// `DummyCrypto` whose ML-KEM-768 encapsulation is real, so the
    /// decapsulation it is checked against can match it.
    @available(macOS 26.0, *)
    final class EncapsulatingCrypto: DummyCrypto {
      override func encapsulate(mlkem768Key: MLKEM768.PublicKey) throws
        -> KEM.EncapsulationResult
      {
        try mlkem768Key.encapsulate()
      }
    }

    func testMLKEMP256_RoundTrip() throws {
      guard #available(macOS 26.0, *) else { throw XCTSkip("ML-KEM-768 needs macOS 26") }
      let crypto = EncapsulatingCrypto()
      let p256 = try crypto.newSecureEnclaveP256PrivateKey(dataRepresentation: crypto.dummyKeys[0])
      let mlkem = try crypto.newSecureEnclaveMLKEM768PrivateKey(
        dataRepresentation: crypto.dummyMLKEM768Keys[0])
      let (sharedSecret, enc) = try HPKE.mlkemp256Encap(
        recipientP256Key: p256.publicKey, recipientMLKEM768Key: mlkem.publicKey, crypto: crypto)
      XCTAssertEqual(1088 + 65, enc.count)
      XCTAssertEqual(
        sharedSecret,
        try HPKE.mlkemp256Decap(enc: enc, recipientP256Key: p256, recipientMLKEM768Key: mlkem))
    }
  #endif
}
