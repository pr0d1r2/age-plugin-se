import XCTest

@testable import age_plugin_se

#if !os(Linux) && !os(Windows)
  import CryptoKit
#else
  import Crypto
#endif

// Fork tests of Sources/Crypto.swift (Tests §V4).

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

#if !os(Linux) && !os(Windows)
  import LocalAuthentication

  /// Fork prompt tests. Covers root V12: `AGE_PLUGIN_SE_PROMPT` set and
  /// non-empty is the Touch ID prompt text; unset or empty keeps upstream's.
  /// Reads the `LAContext` only, so no Secure Enclave key and no Touch ID.
  final class ForkPromptTests: XCTestCase {
    let upstream = LAContext().localizedReason

    func testPrompt_Set() {
      let crypto = CryptoKitCrypto(environment: ["AGE_PLUGIN_SE_PROMPT": "decrypt secrets.age"])
      XCTAssertEqual("decrypt secrets.age", crypto.context.localizedReason)
    }

    func testPrompt_Unset() {
      XCTAssertEqual(upstream, CryptoKitCrypto(environment: ["OTHER": "x"]).context.localizedReason)
    }

    func testPrompt_Empty() {
      let crypto = CryptoKitCrypto(environment: ["AGE_PLUGIN_SE_PROMPT": ""])
      XCTAssertEqual(upstream, crypto.context.localizedReason)
    }
  }
#endif
