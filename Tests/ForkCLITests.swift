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
