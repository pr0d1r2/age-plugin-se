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

    /// The real crypto never stands in for an older macOS: there, `#available`
    /// alone turns the post-quantum paths into `pqUnavailable` (root V6).
    func testIsMLKEMAvailable() {
      XCTAssertTrue(CryptoKitCrypto(environment: [:]).isMLKEMAvailable)
    }

    #if compiler(>=6.2)
      func testEncapsulate_SoftwareMLKEM768Key() throws {
        guard #available(macOS 26.0, *) else { throw XCTSkip("ML-KEM-768 needs macOS 26") }
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

#if !os(Linux) && !os(Windows)
  /// The hardware suite's gate (Tests §I): it runs only when
  /// `AGE_PLUGIN_SE_HARDWARE` is `1` and this Mac has a Secure Enclave;
  /// otherwise each test throws `XCTSkip` saying which is missing.
  enum Hardware {
    static let variable = "AGE_PLUGIN_SE_HARDWARE"

    /// Why the suite skips here, or nil when it runs.
    static func skipReason(
      environment: [String: String] = ProcessInfo.processInfo.environment,
      isAvailable: Bool = SecureEnclave.isAvailable
    ) -> String? {
      guard environment[variable] == "1" else {
        return "hardware: \(variable) is not 1, so the Secure Enclave suite is skipped"
      }
      guard isAvailable else {
        return "hardware: \(variable)=1 but this Mac has no Secure Enclave; skipped"
      }
      return nil
    }

    static func require() throws {
      if let reason = skipReason() { throw XCTSkip(reason) }
    }

    /// `.privateKeyUsage` only, as `--access-control none`: the key never
    /// asks for Touch ID or a passcode.
    static func accessControl() throws -> SecAccessControl {
      var error: Unmanaged<CFError>?
      guard
        let control = SecAccessControlCreateWithFlags(
          kCFAllocatorDefault, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, [.privateKeyUsage],
          &error)
      else { throw error!.takeRetainedValue() as Error }
      return control
    }
  }

  /// The gate itself, on any host: an unset variable or a Mac without a
  /// Secure Enclave skips; only both together run.
  final class CryptoKitHardwareGateTests: XCTestCase {
    func testGate_VariableUnset() {
      let reason = Hardware.skipReason(environment: [:], isAvailable: true)
      XCTAssertEqual(true, reason?.contains("is not 1"), reason ?? "runs")
    }

    func testGate_VariableNotOne() {
      XCTAssertNotNil(Hardware.skipReason(environment: [Hardware.variable: "0"], isAvailable: true))
    }

    func testGate_NoSecureEnclave() {
      let reason = Hardware.skipReason(environment: [Hardware.variable: "1"], isAvailable: false)
      XCTAssertEqual(true, reason?.contains("no Secure Enclave"), reason ?? "runs")
    }

    func testGate_Both() {
      XCTAssertNil(Hardware.skipReason(environment: [Hardware.variable: "1"], isAvailable: true))
    }
  }

  /// Hardware suite (Tests §I): the four `CryptoKitCrypto.newSecureEnclave*`
  /// functions `.coverage` excludes, run on a real Secure Enclave, and an
  /// age round trip through the built binary. Keys use `.privateKeyUsage`
  /// only, so nothing prompts; they live as `dataRepresentation` blobs in
  /// memory or in a temporary directory removed afterwards, never in the
  /// keychain.
  final class CryptoKitHardwareTests: XCTestCase {
    let crypto = CryptoKitCrypto(environment: [:])

    override func setUpWithError() throws {
      try Hardware.require()
    }

    private func bytes(_ secret: SharedSecret) -> Data {
      secret.withUnsafeBytes { Data($0) }
    }

    func testP256_CreateReloadAgree() throws {
      let key = try crypto.newSecureEnclaveP256PrivateKey(accessControl: Hardware.accessControl())
      let loaded = try crypto.newSecureEnclaveP256PrivateKey(
        dataRepresentation: key.dataRepresentation)
      XCTAssertEqual(key.publicKey.rawRepresentation, loaded.publicKey.rawRepresentation)
      let ephemeral = crypto.newEphemeralP256PrivateKey()
      let ours = try loaded.sharedSecretFromKeyAgreement(with: ephemeral.publicKey)
      let theirs = try ephemeral.sharedSecretFromKeyAgreement(with: key.publicKey)
      XCTAssertEqual(bytes(ours), bytes(theirs))
      XCTAssertEqual(
        bytes(ours), bytes(try key.sharedSecretFromKeyAgreement(with: ephemeral.publicKey)))
    }

    func testMLKEM768_CreateReloadDecapsulate() throws {
      #if compiler(>=6.2)
        guard #available(macOS 26.0, *) else {
          throw XCTSkip("hardware: ML-KEM-768 in the Secure Enclave needs macOS 26 or newer")
        }
        let key = try crypto.newSecureEnclaveMLKEM768PrivateKey(
          accessControl: Hardware.accessControl())
        let loaded = try crypto.newSecureEnclaveMLKEM768PrivateKey(
          dataRepresentation: key.dataRepresentation)
        XCTAssertEqual(key.publicKey.rawRepresentation, loaded.publicKey.rawRepresentation)
        let result = try crypto.encapsulate(mlkem768Key: loaded.publicKey)
        XCTAssertEqual(result.sharedSecret, try loaded.decapsulate(result.encapsulated))
        XCTAssertEqual(result.sharedSecret, try key.decapsulate(result.encapsulated))
      #else
        throw XCTSkip("hardware: ML-KEM-768 needs Swift 6.2 or newer")
      #endif
    }

    func testRoundTrip_Classic() throws {
      try roundTrip(pq: false)
    }

    func testRoundTrip_PostQuantum() throws {
      #if compiler(>=6.2)
        guard #available(macOS 26.0, *) else {
          // Older macOS: `keygen --pq` fails cleanly, before any output.
          let (status, output) = try BuiltBinary.run(["keygen", "--pq", "--access-control", "none"])
          XCTAssertNotEqual(0, status)
          XCTAssert(output.contains(Plugin.Error.pqUnavailable.localizedDescription), output)
          return
        }
        try roundTrip(pq: true)
      #else
        throw XCTSkip("hardware: post-quantum keys need Swift 6.2 or newer")
      #endif
    }

    /// `keygen --access-control none` into a temporary file under
    /// `.build/tmp-hw/`, `age -e` to its recipient, `age -d -i` through the
    /// plugin; the plaintext must come back.
    private func roundTrip(pq: Bool) throws {
      let environment = ProcessInfo.processInfo.environment
      let plugin = BuiltBinary.url().deletingLastPathComponent().path
      let path = plugin + ":" + (environment["PATH"] ?? "")
      guard
        let age = path.split(separator: ":").map({ "\($0)/age" }).first(where: {
          FileManager.default.isExecutableFile(atPath: $0)
        })
      else { return XCTFail("hardware: no age on PATH; run from the dev shell") }

      let root = URL(fileURLWithPath: "\(#filePath)").deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
      let directory = root.appendingPathComponent(".build/tmp-hw/\(UUID().uuidString)")
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? FileManager.default.removeItem(at: directory) }
      let identity = directory.appendingPathComponent("key.identity").path

      let (status, _) = try BuiltBinary.run(
        ["keygen"] + (pq ? ["--pq"] : []) + ["--access-control", "none", "-o", identity])
      XCTAssertEqual(0, status)
      let prefix = pq ? "# public key (post-quantum): " : "# public key: "
      let text = try String(contentsOfFile: identity, encoding: .utf8)
      let recipient = try XCTUnwrap(
        text.split(separator: "\n").first(where: { $0.hasPrefix(prefix) })?.dropFirst(prefix.count))
      XCTAssertTrue(recipient.hasPrefix(pq ? "age1tagpq1" : "age1se1"), String(recipient))

      let plaintext = "hardware round trip \(UUID().uuidString)\n"
      var childEnvironment = environment
      childEnvironment["PATH"] = path
      let encrypted = try run(
        age, ["-e", "-r", String(recipient)], Data(plaintext.utf8), childEnvironment)
      let decrypted = try run(age, ["-d", "-i", identity], encrypted, childEnvironment)
      XCTAssertEqual(plaintext, String(decoding: decrypted, as: UTF8.self))
    }

    private func run(
      _ executable: String, _ arguments: [String], _ input: Data, _ environment: [String: String]
    ) throws -> Data {
      let process = Process()
      process.executableURL = URL(fileURLWithPath: executable)
      process.arguments = arguments
      process.environment = environment
      let stdin = Pipe()
      let stdout = Pipe()
      process.standardInput = stdin
      process.standardOutput = stdout
      try process.run()
      try stdin.fileHandleForWriting.write(contentsOf: input)
      try stdin.fileHandleForWriting.close()
      let data = try stdout.fileHandleForReading.readToEnd() ?? Data()
      process.waitUntilExit()
      XCTAssertEqual(0, process.terminationStatus, "age \(arguments.first ?? "")")
      return data
    }
  }
#endif
