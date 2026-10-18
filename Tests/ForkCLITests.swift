import XCTest

@testable import age_plugin_se

/// Fork CLI tests. Covers root V14 (bug B1): when `keygen -o OUTPUT` cannot
/// write OUTPUT, keygen fails with an error naming OUTPUT and prints no
/// `Public key:` line, so the identity is never silently lost.
final class ForkCLITests: XCTestCase {
  let result = ("AGE-PLUGIN-SE-1TESTIDENTITY", "age1se1testrecipient")
  var directory = URL(fileURLWithPath: NSTemporaryDirectory())

  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("ForkCLITests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: directory)
  }

  func testKeygenOutput_NoOutput() throws {
    XCTAssertEqual(result.0, try keygenOutput(result, output: nil))
  }

  func testKeygenOutput_WritesIdentity() throws {
    let file = directory.appendingPathComponent("identity.txt").path
    XCTAssertEqual("Public key: \(result.1)", try keygenOutput(result, output: file))
    XCTAssertEqual(result.0, try String(contentsOfFile: file, encoding: .utf8))
    let attributes = try FileManager.default.attributesOfItem(atPath: file)
    XCTAssertEqual(0o600, (attributes[.posixPermissions] as? NSNumber)?.intValue)
  }

  func testKeygenOutput_WriteFails() throws {
    let file = directory.appendingPathComponent("missing/identity.txt").path
    do {
      let printed = try keygenOutput(result, output: file)
      XCTFail("keygen printed \(printed) instead of failing")
    } catch {
      XCTAssertEqual(CLIError.cannotWriteOutput(file), error as? CLIError)
      XCTAssertTrue(error.localizedDescription.contains(file))
    }
    XCTAssertFalse(FileManager.default.fileExists(atPath: file))
  }
}

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
