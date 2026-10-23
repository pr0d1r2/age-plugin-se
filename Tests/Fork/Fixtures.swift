import Foundation
import XCTest

@testable import age_plugin_se

#if !os(Linux) && !os(Windows)
  import CryptoKit
#else
  import Crypto
#endif

/// Test helper, not a test file (Tests §V4): the format-freeze corpus in
/// `fixtures/` (root V1, V2), read by path from `#filePath` (Tests §C).
/// Every producer revision is a directory there; a new one is read too.
enum Fixtures {
  static let root = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("fixtures")

  /// The producer revisions, one directory each, sorted.
  static func revisions() throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: root.path).filter { name in
      var isDirectory: ObjCBool = false
      return FileManager.default.fileExists(
        atPath: root.appendingPathComponent(name).path, isDirectory: &isDirectory)
        && isDirectory.boolValue
    }.sorted()
  }

  /// Every fixture file, as `<rev>/<name>`, sorted.
  static func all() throws -> [String] {
    try revisions().flatMap { revision in
      try FileManager.default.contentsOfDirectory(
        atPath: root.appendingPathComponent(revision).path
      ).map { "\(revision)/\($0)" }
    }.sorted()
  }

  /// The fixture files whose name ends in `suffix`.
  static func files(_ suffix: String) throws -> [String] {
    try all().filter { $0.hasSuffix(suffix) }
  }

  static func data(_ path: String) throws -> Data {
    try Data(contentsOf: root.appendingPathComponent(path))
  }

  static func text(_ path: String) throws -> String {
    String(decoding: try data(path), as: UTF8.self)
  }

  /// The set a fixture belongs to: `se-classic`, `tag-classic` or `tag-pq`.
  static func set(_ path: String) -> String {
    let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    for suffix in ["-encrypt", "-decrypt"] where name.hasSuffix(suffix) {
      return String(name.dropLast(suffix.count))
    }
    return name
  }

  /// Tests §V2: a format-freeze failure names the fixture and the offset of
  /// the first byte that differs.
  static func assertSameBytes(
    _ expected: Data, _ actual: Data, _ path: String, _ what: String = "bytes",
    file: StaticString = #filePath, line: UInt = #line
  ) {
    if expected == actual { return }
    let e = [UInt8](expected)
    let a = [UInt8](actual)
    let offset =
      (0..<min(e.count, a.count)).first(where: { e[$0] != a[$0] }) ?? min(e.count, a.count)
    func at(_ bytes: [UInt8]) -> String {
      offset < bytes.count ? String(format: "0x%02x", bytes[offset]) : "end of data"
    }
    XCTFail(
      "fixtures/\(path): \(what) differ at byte offset \(offset): expected \(at(e)), got \(at(a))",
      file: file, line: line)
  }

  static func assertSameBytes(
    _ expected: String, _ actual: String, _ path: String, _ what: String = "bytes",
    file: StaticString = #filePath, line: UInt = #line
  ) {
    assertSameBytes(Data(expected.utf8), Data(actual.utf8), path, what, file: file, line: line)
  }
}

/// An identity fixture: `keygen` output, its comment lines and its key line.
struct IdentityFixture {
  let path: String
  let text: String

  init(_ path: String) throws {
    self.path = path
    self.text = try Fixtures.text(path)
  }

  var name: String { Fixtures.set(path) }
  var recipientType: RecipientType { name.hasPrefix("se-") ? .se : .tag }
  var isPQ: Bool { name.hasSuffix("-pq") }

  private func comment(_ prefix: String) -> String? {
    text.split(separator: "\n").first(where: { $0.hasPrefix("# \(prefix): ") }).map {
      String($0.dropFirst("# \(prefix): ".count))
    }
  }

  var created: String? { comment("created") }
  var publicKey: String? { comment("public key") }
  var pqPublicKey: String? { comment("public key (post-quantum)") }
  var identity: String? {
    text.split(separator: "\n").first(where: { $0.hasPrefix("AGE-PLUGIN-SE-") }).map(String.init)
  }

  /// The Secure Enclave key blobs the identity holds: the P-256 one, and
  /// the ML-KEM-768 one when the identity is post-quantum (length-prefixed,
  /// as `Identity.ageIdentity` writes them).
  func blobs() throws -> (p256: Data, mlkem: Data?) {
    let data = try Bech32().decode(try XCTUnwrap(identity, "fixtures/\(path): no key line")).data
    guard pqPublicKey != nil else { return (data, nil) }
    return try Self.split(data, path)
  }

  private static func split(_ data: Data, _ path: String) throws -> (p256: Data, mlkem: Data?) {
    let bytes = [UInt8](data)
    let p256Count = Int(bytes[0]) << 8 | Int(bytes[1])
    let p256 = Data(bytes[2..<(2 + p256Count)])
    let mlkemCount = Int(bytes[2 + p256Count]) << 8 | Int(bytes[3 + p256Count])
    let mlkem = Data(bytes[(4 + p256Count)...])
    XCTAssertEqual(mlkemCount, mlkem.count, "fixtures/\(path): ML-KEM-768 blob length")
    return (p256, mlkem)
  }
}

/// The stand-in Secure Enclave of root R14: it knows each fixture key blob
/// and answers the public key the fixture names for it, so an identity
/// parses and re-encodes with no Secure Enclave. It holds no private key:
/// key agreement and decapsulation throw. `keygen` hands out `made`, in
/// order, as if the Secure Enclave had just made those keys.
final class FixtureCrypto: DummyCrypto {
  enum Error: Swift.Error { case unknownBlob, noPrivateKey }

  var p256: [Data: P256.KeyAgreement.PublicKey] = [:]
  var mlkem: [Data: Data] = [:]
  var made: [Data] = []

  init(_ fixtures: [IdentityFixture]) throws {
    super.init()
    for fixture in fixtures {
      let (p256Blob, mlkemBlob) = try fixture.blobs()
      let publicKey = try XCTUnwrap(fixture.publicKey, "fixtures/\(fixture.path): no public key")
      p256[p256Blob] = try P256.KeyAgreement.PublicKey(
        compressedRepresentation: try Bech32().decode(publicKey).data)
      if let mlkemBlob = mlkemBlob, let pq = fixture.pqPublicKey {
        mlkem[mlkemBlob] = Data(try Bech32().decode(pq).data.prefix(1184))
      }
    }
  }

  override func newSecureEnclaveP256PrivateKey(dataRepresentation: Data) throws
    -> SecureEnclaveP256PrivateKey
  {
    guard let publicKey = p256[dataRepresentation] else { throw Error.unknownBlob }
    return StandInP256Key(publicKey: publicKey, dataRepresentation: Data(dataRepresentation))
  }

  override func newSecureEnclaveP256PrivateKey(accessControl: SecAccessControl) throws
    -> SecureEnclaveP256PrivateKey
  {
    try newSecureEnclaveP256PrivateKey(dataRepresentation: made.removeFirst())
  }

  @available(macOS 26.0, *)
  override func newSecureEnclaveMLKEM768PrivateKey(dataRepresentation: Data) throws
    -> SecureEnclaveMLKEM768PrivateKey
  {
    guard let publicKey = mlkem[dataRepresentation] else { throw Error.unknownBlob }
    return StandInMLKEM768Key(
      publicKey: try MLKEM768.PublicKey(rawRepresentation: publicKey),
      dataRepresentation: Data(dataRepresentation))
  }

  @available(macOS 26.0, *)
  override func newSecureEnclaveMLKEM768PrivateKey(accessControl: SecAccessControl) throws
    -> SecureEnclaveMLKEM768PrivateKey
  {
    try newSecureEnclaveMLKEM768PrivateKey(dataRepresentation: made.removeFirst())
  }
}

struct StandInP256Key: SecureEnclaveP256PrivateKey {
  let publicKey: P256.KeyAgreement.PublicKey
  let dataRepresentation: Data

  func sharedSecretFromKeyAgreement(with publicKeyShare: P256.KeyAgreement.PublicKey) throws
    -> SharedSecret
  {
    throw FixtureCrypto.Error.noPrivateKey
  }
}

@available(macOS 26.0, *)
struct StandInMLKEM768Key: SecureEnclaveMLKEM768PrivateKey {
  let publicKey: MLKEM768.PublicKey
  let dataRepresentation: Data

  func decapsulate(_ encapsulated: Data) throws -> SymmetricKey {
    throw FixtureCrypto.Error.noPrivateKey
  }
}

/// A recorded plugin session (fixtures §I): each line `> ` (age to plugin)
/// or `< ` (plugin to age) and the line as sent.
struct SessionFixture {
  let path: String
  var toPlugin: [String] = []
  var fromPlugin: [String] = []

  init(_ path: String) throws {
    self.path = path
    var lines = try Fixtures.text(path).components(separatedBy: "\n")
    XCTAssertEqual("", lines.last, "fixtures/\(path): no final newline")
    lines.removeLast()
    for line in lines {
      if line.hasPrefix("> ") {
        toPlugin.append(String(line.dropFirst(2)))
      } else if line.hasPrefix("< ") {
        fromPlugin.append(String(line.dropFirst(2)))
      } else {
        XCTFail("fixtures/\(path): line without `> ` or `< `: \(line)")
      }
    }
  }
}

/// One protocol message and the lines it was sent as. Parsed here, not by
/// `Stanza.readFrom`, so the code under test does not read its own oracle:
/// a header `-> type args...`, then base64 body lines up to the first one
/// shorter than 64 characters.
struct Message {
  var stanza: Stanza
  var lines: [String]

  init(_ stanza: Stanza) {
    self.stanza = stanza
    self.lines =
      "-> \(([stanza.type] + stanza.args).joined(separator: " "))\n\(stanza.body.base64RawEncodedString(wrap: true))"
      .components(separatedBy: "\n")
  }

  init(stanza: Stanza, lines: [String]) {
    self.stanza = stanza
    self.lines = lines
  }

  static func parse(_ lines: [String], _ path: String) throws -> [Message] {
    var messages: [Message] = []
    var index = 0
    while index < lines.count {
      let header = lines[index]
      guard header.hasPrefix("-> ") else {
        XCTFail("fixtures/\(path): line \(index) is no header: \(header)")
        return messages
      }
      let parts = header.dropFirst(3).components(separatedBy: " ")
      var body = Data()
      var end = index + 1
      while true {
        guard end < lines.count else {
          XCTFail("fixtures/\(path): message at line \(index) has no body end")
          return messages
        }
        let line = lines[end]
        body.append(try XCTUnwrap(Data(base64RawEncoded: line), "fixtures/\(path): \(line)"))
        end += 1
        if line.count < 64 { break }
      }
      messages.append(
        Message(
          stanza: Stanza(type: parts[0], args: Array(parts.dropFirst()), body: body),
          lines: Array(lines[index..<end])))
      index = end
    }
    return messages
  }
}

/// Root V2's structural comparison: how each part of a message must match.
enum Match {
  /// The same bytes.
  case exact
  /// Random on both sides: the same length once base64-decoded.
  case length
  /// Different keys by design: present, nothing more.
  case any
}

extension Fixtures {
  /// Root V2: `actual` sends the messages `expected` does, in order: the same
  /// types and argument counts, each argument and body as `rule` says.
  static func assertSameShape(
    _ expected: [Message], _ actual: [Message], _ path: String, _ side: String,
    rule: (Stanza) -> (args: [Int: Match], body: Match) = { _ in ([:], .exact) },
    file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertEqual(
      expected.map(\.stanza.type), actual.map(\.stanza.type),
      "fixtures/\(path): \(side): message types", file: file, line: line)
    for (index, (e, a)) in zip(expected, actual).enumerated() {
      let what = "\(side): message \(index) (\(e.stanza.type))"
      XCTAssertEqual(
        e.stanza.args.count, a.stanza.args.count, "fixtures/\(path): \(what): argument count",
        file: file, line: line)
      let (args, body) = rule(e.stanza)
      for (i, (ea, aa)) in zip(e.stanza.args, a.stanza.args).enumerated() {
        compare(
          Data(ea.utf8), Data(aa.utf8), args[i] ?? .exact, decode: true, path,
          "\(what): argument \(i)", file: file, line: line)
      }
      compare(
        e.stanza.body, a.stanza.body, body, decode: false, path, "\(what): body", file: file,
        line: line)
    }
  }

  private static func compare(
    _ expected: Data, _ actual: Data, _ match: Match, decode: Bool, _ path: String,
    _ what: String, file: StaticString, line: UInt
  ) {
    switch match {
    case .exact:
      assertSameBytes(expected, actual, path, what, file: file, line: line)
    case .length:
      let length = { (data: Data) -> Int? in
        decode ? Data(base64RawEncoded: String(decoding: data, as: UTF8.self))?.count : data.count
      }
      XCTAssertEqual(
        length(expected), length(actual), "fixtures/\(path): \(what): length", file: file,
        line: line)
    case .any:
      break
    }
  }
}
