import Foundation
import XCTest

@testable import age_plugin_se

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
