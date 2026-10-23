import Foundation
import XCTest

@testable import age_plugin_se

// Fork tests of Sources/CLI.swift (Tests §V4).

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

/// `Options.ValueOption`, the table of options that take a value, and the
/// parse behaviour it must keep: upstream's names, `name=value` or the next
/// argument as the value, and the same errors (root V10, V11).
final class OptionsValueOptionTests: XCTestCase {
  static let names: [String: Options.ValueOption] = [
    "--age-plugin": .agePlugin, "-i": .input, "--input": .input, "-o": .output,
    "--output": .output, "--access-control": .accessControl,
    "--recipient-type": .recipientType,
  ]

  func testNames() {
    var table: [String: Options.ValueOption] = [:]
    for option in Options.ValueOption.allCases {
      for name in option.names {
        XCTAssertNil(table.updateValue(option, forKey: name), "`\(name)` named twice")
      }
    }
    XCTAssertEqual(Self.names, table)
  }

  func testMatching() {
    for (name, option) in Self.names {
      XCTAssertEqual(option, Options.ValueOption(matching: name), name)
      XCTAssertEqual(option, Options.ValueOption(matching: name + "="), name + "=")
      XCTAssertEqual(option, Options.ValueOption(matching: name + "=a=b"), name + "=a=b")
      XCTAssertNil(Options.ValueOption(matching: name + "x"), name + "x")
    }
    for arg in ["keygen", "--pq", "--pq=1", "-h", "--help", "--version", "-x", "", "="] {
      XCTAssertNil(Options.ValueOption(matching: arg), arg)
    }
  }

  func testParse_Values() throws {
    let options = try Options.parse([
      "_", "recipients", "-i", "in", "--output=a=b", "--recipient-type", "tag", "--pq",
      "--access-control=none",
    ])
    XCTAssertEqual(.recipients, options.command)
    XCTAssertEqual("in", options.input)
    XCTAssertEqual("a=b", options.output)
    XCTAssertEqual(.tag, options.recipientType)
    XCTAssertEqual(Options.AccessControl.none, options.accessControl)
    XCTAssertTrue(options.pq)
    XCTAssertEqual(
      .plugin(.identityV1), try Options.parse(["_", "--age-plugin=identity-v1"]).command)
    XCTAssertEqual(
      .plugin(.recipientV1), try Options.parse(["_", "--age-plugin", "recipient-v1"]).command)
  }

  /// `--input=` has no value after `=`, so the next argument is the value.
  func testParse_EmptyValueTakesNext() throws {
    XCTAssertEqual("next", try Options.parse(["_", "--input=", "next"]).input)
  }

  func testParse_Errors() {
    let cases: [([String], Options.Error)] = [
      (["--input"], .missingValue("--input")),
      (["-o"], .missingValue("-o")),
      (["--input="], .missingValue("--input=")),
      (["--age-plugin"], .missingValue("--age-plugin")),
      (["--age-plugin=bogus"], .invalidValue("--age-plugin", "bogus")),
      (["--access-control", "bogus"], .invalidValue("--access-control", "bogus")),
      (["--recipient-type=bogus"], .invalidValue("--recipient-type", "bogus")),
      (["--pq=1"], .unknownOption("--pq=1")),
      (["--inputx"], .unknownOption("--inputx")),
    ]
    for (args, expected) in cases {
      XCTAssertThrowsError(try Options.parse(["_"] + args), "\(args)") { error in
        XCTAssertEqual(expected, error as? Options.Error, "\(args)")
      }
    }
  }
}

/// `CLI.run`, the dispatch `CLI.main` hands its arguments to: every command
/// on `DummyCrypto` and `MemoryStream`, with printed lines captured.
final class CLIRunCoverageTests: XCTestCase {
  var stream = MemoryStream()
  var printed: [String] = []
  var directory = URL(fileURLWithPath: NSTemporaryDirectory())

  override func setUpWithError() throws {
    stream = MemoryStream()
    printed = []
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("CLIRunCoverageTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: directory)
  }

  func run(_ arguments: [String], standardInput: String = "") throws {
    try CLI.run(
      ["age-plugin-se"] + arguments, plugin: Plugin(crypto: DummyCrypto(), stream: stream),
      readStandardInput: { Data(standardInput.utf8) }, print: { self.printed.append($0) })
  }

  /// Runs `keygen` and returns the identity file text and its recipient.
  func keygen() throws -> (String, String) {
    try run(["keygen"])
    let identity = try XCTUnwrap(printed.first)
    let recipient = try XCTUnwrap(
      identity.components(separatedBy: "\n").first { $0.hasPrefix("# public key: ") })
    printed = []
    return (identity, String(recipient.dropFirst("# public key: ".count)))
  }

  func testHelp() throws {
    try run([])
    try run(["--help"])
    XCTAssertEqual([Options.help, Options.help], printed)
  }

  /// `--pq` names its macOS 26 (Tahoe) requirement in the help (root V6).
  func testHelp_PQNamesMacOSTahoe() {
    let pq = Options.help.components(separatedBy: "Generate post-quantum keys").dropFirst()
    XCTAssert(pq.first?.prefix(80).contains("Note: requires macOS Tahoe or newer.") == true)
  }

  /// `keygen --pq` without ML-KEM-768 fails with `pqUnavailable` (root V6).
  func testKeygen_PQUnavailable() throws {
    XCTAssertThrowsError(
      try CLI.run(
        ["age-plugin-se", "keygen", "--pq"],
        plugin: Plugin(crypto: MLKEMUnavailableCrypto(), stream: stream),
        print: { self.printed.append($0) })
    ) { XCTAssertEqual(Plugin.Error.pqUnavailable.localizedDescription, $0.localizedDescription) }
    XCTAssertEqual([], printed)
  }

  func testVersion() throws {
    try run(["--version"])
    XCTAssertEqual([age_plugin_se.version], printed)
  }

  func testKeygen() throws {
    let (identity, recipient) = try keygen()
    XCTAssertTrue(identity.contains("\nAGE-PLUGIN-SE-1"))
    XCTAssertTrue(recipient.hasPrefix("age1se1"))
  }

  func testKeygen_Output() throws {
    let file = directory.appendingPathComponent("identity.txt").path
    try run(["keygen", "-o", file, "--access-control", "none"])
    XCTAssertEqual(1, printed.count)
    XCTAssertTrue(try XCTUnwrap(printed.first).hasPrefix("Public key: age1se1"))
    let identity = try String(contentsOfFile: file, encoding: .utf8)
    XCTAssertTrue(identity.contains("# access control: none\n"))
  }

  func testRecipients_Input() throws {
    let (identity, recipient) = try keygen()
    let file = directory.appendingPathComponent("identity.txt").path
    try identity.write(toFile: file, atomically: true, encoding: .utf8)
    try run(["recipients", "-i", file])
    XCTAssertEqual([recipient], printed)
  }

  func testRecipients_StandardInput() throws {
    let (identity, recipient) = try keygen()
    try run(["recipients", "--recipient-type", "tag"], standardInput: identity)
    XCTAssertEqual(1, printed.count)
    XCTAssertTrue(try XCTUnwrap(printed.first).hasPrefix("age1tag1"))
    XCTAssertNotEqual(recipient, printed.first)
  }

  func testRecipients_Output() throws {
    let (identity, recipient) = try keygen()
    let file = directory.appendingPathComponent("recipients.txt").path
    try run(["recipients", "-o", file], standardInput: identity)
    XCTAssertEqual([], printed)
    XCTAssertEqual(recipient, try String(contentsOfFile: file, encoding: .utf8))
    let attributes = try FileManager.default.attributesOfItem(atPath: file)
    XCTAssertEqual(0o600, (attributes[.posixPermissions] as? NSNumber)?.intValue)
  }

  func testRecipients_NoIdentity() throws {
    try run(["recipients"], standardInput: "# no identity here\n")
    XCTAssertEqual([], printed)
  }

  func testPlugin_RecipientV1() throws {
    stream.add(input: "-> done\n")
    try run(["--age-plugin=recipient-v1"])
    XCTAssertEqual("-> done\n", stream.output)
    XCTAssertEqual([], printed)
  }

  func testPlugin_IdentityV1() throws {
    stream.add(input: "-> done\n")
    try run(["--age-plugin", "identity-v1"])
    XCTAssertEqual("-> done\n", stream.output)
    XCTAssertEqual([], printed)
  }

  /// Empty stdin in plugin mode: `CLI.run` throws `pluginProtocol`, which
  /// `CLI.main` prints on stderr (root V20, bug B4).
  func testPlugin_EmptyInput() throws {
    for machine in ["recipient-v1", "identity-v1"] {
      XCTAssertThrowsError(try run(["--age-plugin=\(machine)"]), machine) { error in
        XCTAssertEqual(CLIError.pluginProtocol("incomplete stanza"), error as? CLIError)
        XCTAssertEqual("plugin protocol: incomplete stanza", error.localizedDescription)
      }
    }
    XCTAssertEqual("", stream.output)
    XCTAssertEqual([], printed)
  }

  func testError_Thrown() throws {
    XCTAssertThrowsError(try run(["--bogus"])) { error in
      XCTAssertEqual(Options.Error.unknownOption("--bogus"), error as? Options.Error)
    }
    XCTAssertEqual([], printed)
  }
}

/// `CLI.main` and `CLI.run`'s default stdin and print: the built binary run
/// as a child process (`BuiltBinary`), so only the process entry point
/// reaches them. No case touches the Secure Enclave or Touch ID (root V15).
final class CLIProcessCoverageTests: XCTestCase {
  func testVersion() throws {
    let (status, output) = try BuiltBinary.run(["--version"])
    XCTAssertEqual(0, status)
    XCTAssertEqual("\(age_plugin_se.version)\n", output)
  }

  func testHelp() throws {
    let (status, output) = try BuiltBinary.run(["--help"])
    XCTAssertEqual(0, status)
    XCTAssertEqual("\(Options.help)\n", output)
  }

  /// R13: the error goes to stdout and the exit status is 255.
  func testUnknownOption() throws {
    let path = BuiltBinary.url().path
    let (status, output) = try BuiltBinary.run(["--bogus"])
    XCTAssertEqual(255, status)
    XCTAssertEqual("\(path): error: unknown option: `--bogus`\n", output)
  }

  /// Plugin mode is R13's exception (root V20): stdout carries the
  /// protocol, so the error goes to stderr; the exit status is still 255.
  func testPluginProtocolError() throws {
    let path = BuiltBinary.url().path
    let result = try BuiltBinary.runCapturingAll(["--age-plugin=recipient-v1"], standardInput: "")
    XCTAssertEqual(.exit, result.reason, "trapped: signal \(result.status)")
    XCTAssertEqual(255, result.status)
    XCTAssertEqual("", result.output)
    XCTAssertEqual("\(path): error: plugin protocol: incomplete stanza\n", result.error)
  }

  /// Comment lines only: real stdin is read, no identity is parsed.
  func testRecipientsFromStandardInput() throws {
    let (status, output) = try BuiltBinary.run(["recipients"], standardInput: "# no identity\n")
    XCTAssertEqual(0, status)
    XCTAssertEqual("", output)
  }
}

/// Fork CLI tests. Covers root V14 (bug B1): when `keygen -o OUTPUT` cannot
/// write OUTPUT, keygen fails with an error naming OUTPUT and prints no
/// `Public key:` line, so the identity is never silently lost. Covers root
/// V18 (bug B2): `recipients -o OUTPUT` fails the same way. Covers root V19
/// (bug B3): `recipients` stdin that is not UTF-8 is an error, not a trap,
/// and empty stdin reads as an empty `-i` file: no recipient, exit 0. The
/// built binary checks the exit status and stdout (root R13); its input has
/// no identity, so it needs no Secure Enclave (root V15).
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

  func testRecipientsOutput_WriteFails() throws {
    var printed: [String] = []
    let plugin = Plugin(crypto: DummyCrypto(), stream: MemoryStream())
    try CLI.run(["_", "keygen"], plugin: plugin, print: { printed.append($0) })
    let identity = try XCTUnwrap(printed.first)
    printed = []
    let file = directory.appendingPathComponent("missing/recipients.txt").path
    XCTAssertThrowsError(
      try CLI.run(
        ["_", "recipients", "-o", file], plugin: plugin,
        readStandardInput: { Data(identity.utf8) }, print: { printed.append($0) })
    ) { error in
      XCTAssertEqual(CLIError.cannotWriteOutput(file), error as? CLIError)
      XCTAssertTrue(error.localizedDescription.contains(file))
    }
    XCTAssertEqual([], printed)
    XCTAssertFalse(FileManager.default.fileExists(atPath: file))
  }

  func testRecipients_StandardInputEmpty() throws {
    var printed: [String] = []
    try CLI.run(
      ["_", "recipients"], plugin: Plugin(crypto: DummyCrypto(), stream: MemoryStream()),
      readStandardInput: { nil }, print: { printed.append($0) })
    XCTAssertEqual([], printed)
  }

  func testRecipients_StandardInputNotUTF8() throws {
    XCTAssertThrowsError(
      try CLI.run(
        ["_", "recipients"], plugin: Plugin(crypto: DummyCrypto(), stream: MemoryStream()),
        readStandardInput: { Data([0xff, 0xfe]) }, print: { XCTFail("printed \($0)") })
    ) { error in
      XCTAssertEqual(CLIError.invalidStandardInput, error as? CLIError)
      XCTAssertEqual("standard input is not valid UTF-8", error.localizedDescription)
    }
  }

  func testRecipientsOutput_WriteFails_Process() throws {
    let file = directory.appendingPathComponent("missing/recipients.txt").path
    let (status, output) = try BuiltBinary.run(
      ["recipients", "-o", file], standardInput: "# no identity\n")
    XCTAssertEqual(255, status)
    XCTAssertEqual(
      "\(BuiltBinary.url().path): error: cannot write output file `\(file)`\n", output)
  }

  func testRecipients_EmptyStandardInput_Process() throws {
    let (status, output) = try BuiltBinary.run(["recipients"], standardInput: Data())
    XCTAssertEqual(0, status)
    XCTAssertEqual("", output)
  }

  func testRecipients_InvalidStandardInput_Process() throws {
    let (status, output) = try BuiltBinary.run(["recipients"], standardInput: Data([0xff, 0xfe]))
    XCTAssertEqual(255, status)
    XCTAssertEqual(
      "\(BuiltBinary.url().path): error: standard input is not valid UTF-8\n", output)
  }
}

/// Fork test for root V11: every option in `Options.help` parses, and every
/// option `Options.parse` accepts appears in `Options.help`.
///
/// The parser is upstream's hand-written `Options.parse` (D15), so the options
/// it accepts are read from the string literals in its source, and each one is
/// then fed to the parser itself. Upstream's help leaves out four options the
/// parser accepts; they sit in `undocumented`, a baseline that only shrinks
/// (D13): an entry that turns up in the help, or stops being parsed, fails.
final class OptionsHelpTests: XCTestCase {
  /// Options upstream parses but its help omits (root R11). Remove an entry
  /// once upstream documents it; never add one.
  static let undocumented: Set<String> = ["--age-plugin", "--help", "--version", "-h"]

  /// Value enums behind the options that take a fixed set of values.
  static let valueEnums = [
    "--access-control": "AccessControl", "--recipient-type": "RecipientType",
  ]

  func testEveryHelpOptionParses() throws {
    let options = Self.helpOptions()
    XCTAssertTrue(options.contains("--pq"), "help options not found: \(options)")
    for option in options.sorted() {
      do {
        _ = try Options.parse(["_", option])
      } catch Options.Error.missingValue(option) {
        // Takes a value: recognised.
      } catch {
        XCTFail("help option `\(option)` does not parse: \(error)")
      }
    }
  }

  func testEveryParsedOptionIsInHelp() throws {
    let parsed = try Self.parsedOptions()
    XCTAssertTrue(parsed.contains("--pq"), "parser options not found: \(parsed)")
    let missing = parsed.subtracting(Self.helpOptions()).subtracting(Self.undocumented)
    XCTAssertEqual([], missing.sorted(), "options the parser accepts but the help omits")
  }

  func testUndocumentedBaselineOnlyShrinks() throws {
    let parsed = try Self.parsedOptions()
    let help = Self.helpOptions()
    for option in Self.undocumented.sorted() {
      XCTAssertTrue(
        parsed.contains(option), "`\(option)` no longer parsed: drop it from the baseline")
      XCTAssertFalse(help.contains(option), "`\(option)` now in help: drop it from the baseline")
    }
  }

  func testEveryHelpSubcommandParses() throws {
    let commands: [String: Options.Command] = ["keygen": .keygen, "recipients": .recipients]
    let subcommands = Self.helpSubcommands()
    XCTAssertFalse(subcommands.isEmpty, "help subcommands not found")
    for subcommand in subcommands.sorted() {
      let options = try Options.parse(["_", subcommand])
      XCTAssertEqual(commands[subcommand], options.command, "help subcommand `\(subcommand)`")
    }
  }

  func testEveryParsedSubcommandIsInHelp() throws {
    let source = try Self.parseSource()
    let parsed = Set(Self.matches(#"arg == "([a-z][a-z0-9-]*)""#, in: source))
    XCTAssertFalse(parsed.isEmpty, "parser subcommands not found")
    XCTAssertEqual([], parsed.subtracting(Self.helpSubcommands()).sorted())
  }

  func testEveryHelpValueParses() throws {
    for (option, _) in Self.valueEnums {
      let values = Self.helpValues(option)
      XCTAssertFalse(values.isEmpty, "no supported values in help for `\(option)`")
      for value in values {
        XCTAssertNoThrow(
          try Options.parse(["_", "keygen", "\(option)=\(value)"]), "\(option)=\(value)")
      }
    }
  }

  func testEveryParsedValueIsInHelp() throws {
    let source = try Self.cliSource()
    for (option, name) in Self.valueEnums {
      let block = Self.matches(
        #"enum \#(name): String \{\n((?:\s*case \w+ = "[^"]+"\n)+)"#, in: source)
      let parsed = Set(block.flatMap { Self.matches(#"case \w+ = "([^"]+)""#, in: $0) })
      XCTAssertFalse(parsed.isEmpty, "no values found in `enum \(name)`")
      XCTAssertEqual(parsed.sorted(), Self.helpValues(option).sorted(), "values of `\(option)`")
    }
  }

  // MARK: - Reading the help

  /// The help without its Example section, whose `age` command lines carry
  /// age's own options.
  static func helpBody() -> String {
    String(Options.help.components(separatedBy: "\nExample:")[0])
  }

  static func helpOptions() -> Set<String> {
    Set(matches(#"(?<![A-Za-z0-9-])(--?[a-z][a-z0-9-]*)"#, in: helpBody()))
  }

  static func helpSubcommands() -> Set<String> {
    Set(matches(#"age-plugin-se ([a-z][a-z0-9-]*)"#, in: helpBody()))
  }

  /// The words after `Supported values:` in the paragraph of `option`.
  static func helpValues(_ option: String) -> [String] {
    let body = helpBody()
    guard let start = body.range(of: "\n  \(option) ") else { return [] }
    let rest = body[start.upperBound...]
    guard let list = rest.range(of: "Supported values:"),
      let end = rest.range(of: "Default:", range: list.upperBound..<rest.endIndex)
    else { return [] }
    return rest[list.upperBound..<end.lowerBound]
      .split(whereSeparator: { ", .\n".contains($0) })
      .map(String.init)
  }

  // MARK: - Reading the parser

  static func cliSource() throws -> String {
    let url = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("Sources/CLI.swift")
    return try String(contentsOf: url, encoding: .utf8)
  }

  /// The body of `Options.parse`, from its signature to the end of the file.
  static func parseSource() throws -> String {
    let source = try cliSource()
    guard let start = source.range(of: "static func parse(") else {
      XCTFail("`static func parse(` not found in Sources/CLI.swift")
      return ""
    }
    return String(source[start.lowerBound...])
  }

  static func parsedOptions() throws -> Set<String> {
    Set(matches(#""(--?[a-z][a-z0-9-]*)""#, in: try parseSource()))
  }

  static func matches(_ pattern: String, in text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      XCTFail("bad pattern \(pattern)")
      return []
    }
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).compactMap { match in
      Range(match.range(at: 1), in: text).map { String(text[$0]) }
    }
  }
}
