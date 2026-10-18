import XCTest

@testable import age_plugin_se

// Fork tests of Sources/Base64.swift (Tests §V4).

/// The unpadded base64 every stanza body, identity and recipient line uses
/// (root V1): every byte count round-trips without `=`, and a length no
/// encoding produces is refused.
final class Base64ForkTests: XCTestCase {
  func testRoundTrip_EveryLength() {
    for count in 0..<100 {
      let data = Data((0..<count).map { UInt8(truncatingIfNeeded: $0 &* 37 &+ 11) })
      let encoded = data.base64RawEncodedString()
      XCTAssertFalse(encoded.contains("="), "\(count) bytes: \(encoded)")
      XCTAssertEqual(data, Data(base64RawEncoded: encoded), "\(count) bytes")
    }
  }

  func testInit_ImpossibleLength() {
    XCTAssertNil(Data(base64RawEncoded: "AAAAA"))
  }
}
