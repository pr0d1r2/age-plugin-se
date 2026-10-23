import Foundation

let version = "v0.2.1"

@main
struct CLI {
  static func main() {
    do {
      let plugin = Plugin(crypto: CryptoKitCrypto(), stream: StandardIOStream())
      try run(CommandLine.arguments, plugin: plugin)
    } catch {
      let line = "\(CommandLine.arguments[0]): error: \(error.localizedDescription)"
      if case CLIError.pluginProtocol = error {
        // Fork: stdout carries the plugin protocol, so this error goes to
        // stderr (root V20); every other error stays on stdout (root R13).
        FileHandle.standardError.write(Data((line + "\n").utf8))
      } else {
        print(line)
      }
      exit(-1)
    }
  }

  /// Runs the command that `arguments` names on `plugin`. `readStandardInput`
  /// reads the `recipients` input when no INPUT is given, and `print` writes
  /// one line of output.
  static func run(
    _ arguments: [String], plugin: Plugin,
    readStandardInput: () throws -> Data? = { try FileHandle.standardInput.readToEnd() },
    print: (String) -> Void = { Swift.print($0) }
  ) throws {
    let options = try Options.parse(arguments)
    switch options.command {
    case .help:
      print(Options.help)
    case .version:
      print(version)
    case .keygen:
      let result = try plugin.generateKey(
        accessControl: options.accessControl.keyAccessControl,
        recipientType: options.recipientType.recipientType, now: Date(),
        pq: options.pq)
      print(try keygenOutput(result, output: options.output))
    case .recipients:
      var input = ""
      if let inputFile = options.input {
        input = try String(contentsOfFile: inputFile, encoding: .utf8)
      } else {
        guard let text = String(data: try readStandardInput() ?? Data(), encoding: .utf8) else {
          throw CLIError.invalidStandardInput
        }
        input = text
      }
      let result = try plugin.generateRecipients(
        input: input, recipientType: options.recipientType.recipientType, pq: options.pq)
      if let outputFile = options.output {
        try writeOutput(result, to: outputFile)
      } else if result != "" {
        print(result)
      }
    case .plugin(let sm):
      do {
        switch sm {
        case .recipientV1:
          try plugin.recipientV1()
        case .identityV1:
          try plugin.identityV1()
        }
      } catch {
        throw CLIError.pluginProtocol(error.localizedDescription)
      }
    }
  }
}

/// Handles the result of `keygen`: writes the identity to `output` if given,
/// and returns the text to print.
func keygenOutput(_ result: (String, String), output: String?) throws -> String {
  guard let outputFile = output else {
    return result.0
  }
  try writeOutput(result.0, to: outputFile)
  return "Public key: \(result.1)"
}

/// Writes `contents` to `outputFile`, readable by its owner only.
func writeOutput(_ contents: String, to outputFile: String) throws {
  guard
    FileManager.default.createFile(
      atPath: outputFile,
      contents: Data(contents.utf8),
      attributes: [.posixPermissions: 0o600]
    )
  else {
    throw CLIError.cannotWriteOutput(outputFile)
  }
}

enum CLIError: LocalizedError, Equatable {
  case cannotWriteOutput(String)
  case invalidStandardInput
  /// Fork: age's plugin-protocol input ended early or was malformed (root V20).
  case pluginProtocol(String)

  public var errorDescription: String? {
    switch self {
    case .cannotWriteOutput(let file): return "cannot write output file `\(file)`"
    case .invalidStandardInput: return "standard input is not valid UTF-8"
    case .pluginProtocol(let message): return "plugin protocol: \(message)"
    }
  }
}

/// Command-line options parser
struct Options {
  enum Error: LocalizedError, Equatable {
    case unknownOption(String)
    case missingValue(String)
    case invalidValue(String, String)

    public var errorDescription: String? {
      switch self {
      case .unknownOption(let option): return "unknown option: `\(option)`"
      case .missingValue(let option): return "missing value for option `\(option)`"
      case .invalidValue(let option, let value):
        return "invalid value for option `\(option)`: `\(value)`"
      }
    }
  }

  enum StateMachine: String {
    case recipientV1 = "recipient-v1"
    case identityV1 = "identity-v1"
  }

  enum Command: Equatable {
    case help
    case version
    case keygen
    case recipients
    case plugin(StateMachine)
  }
  var command: Command

  var output: String?
  var input: String?

  var pq: Bool = false

  enum AccessControl: String {
    case none = "none"
    case passcode = "passcode"
    case anyBiometry = "any-biometry"
    case anyBiometryOrPasscode = "any-biometry-or-passcode"
    case anyBiometryAndPasscode = "any-biometry-and-passcode"
    case currentBiometry = "current-biometry"
    case currentBiometryAndPasscode = "current-biometry-and-passcode"

    var keyAccessControl: KeyAccessControl {
      switch self {
      case .none: return KeyAccessControl.none
      case .passcode: return KeyAccessControl.passcode
      case .anyBiometry: return KeyAccessControl.anyBiometry
      case .anyBiometryOrPasscode: return KeyAccessControl.anyBiometryOrPasscode
      case .anyBiometryAndPasscode: return KeyAccessControl.anyBiometryAndPasscode
      case .currentBiometry: return KeyAccessControl.currentBiometry
      case .currentBiometryAndPasscode: return KeyAccessControl.currentBiometryAndPasscode
      }
    }
  }
  var accessControl = AccessControl.anyBiometryOrPasscode

  enum RecipientType: String {
    case se = "se"
    case tag = "tag"

    var recipientType: age_plugin_se.RecipientType {
      switch self {
      case .se: return .se
      case .tag: return .tag
      }
    }
  }

  var recipientType: RecipientType = .se

  static let help =
    """
    Usage:
      age-plugin-se keygen [--pq] [-o OUTPUT] [--access-control ACCESS_CONTROL] [--recipient-type RECIPIENT_TYPE]
      age-plugin-se recipients [--pq] [-o OUTPUT] [-i INPUT] [--recipient-type RECIPIENT_TYPE]

    Description:
      The `keygen` subcommand generates a new private key bound to the current 
      Secure Enclave, with the given access controls, and outputs it to OUTPUT 
      or standard output.

      The `recipients` subcommand reads an identity file from INPUT or standard 
      input, and outputs the corresponding recipient(s) to OUTPUT or to standard 
      output.

    Options:
      --access-control ACCESS_CONTROL   Access control for using the generated key.
                                        
                                        When using current biometry, adding or removing a 
                                        fingerprint stops the key from working. Removing an 
                                        added fingerprint enables the key again. 

                                        Supported values: none, passcode, 
                                          any-biometry, any-biometry-and-passcode, 
                                          any-biometry-or-passcode, current-biometry, 
                                          current-biometry-and-passcode
                                        Default: any-biometry-or-passcode.                          

      -i, --input INPUT                 Read data from the file at path INPUT

      -o, --output OUTPUT               Write the result to the file at path OUTPUT

      --pq                              Generate post-quantum keys.

                                        Note: requires macOS Tahoe or newer.

      --recipient-type RECIPIENT_TYPE   Recipient type to generate.

                                        `tag` recipients use built-in support in
                                        age (>=v1.3.0), and don't require this plug-in to
                                        be installed to encrypt.

                                        Post-quantum keys (generated with `--pq`) always
                                        use the `tag` recipient type.

                                        Supported values: se, tag.
                                        Default: se.
                                        The default will change to `tag` in future versions.

      -h, --help                        Print this help and exit.

      --version                         Print the version and exit.

    Example:
      $ age-plugin-se keygen -o key.txt
      Public key: age1se1qg8vwwqhztnh3vpt2nf2xwn7famktxlmp0nmkfltp8lkvzp8nafkqleh258
      $ tar cvz ~/data | age -r age1se1qgg72x2qfk9wg3wh0qg9u0v7l5dkq4jx69fv80p6wdus3ftg6flwg5dz2dp > data.tar.gz.age
      $ age --decrypt -i key.txt data.tar.gz.age > data.tar.gz
    """

  static func parse(_ args: [String]) throws -> Options {
    var opts = Options(command: .help)
    var i = 1
    while i < args.count {
      let arg = args[i]
      if arg == "keygen" {
        opts.command = .keygen
      } else if arg == "recipients" {
        opts.command = .recipients
      } else if ["--help", "-h"].contains(arg) {
        opts.command = .help
        break
      } else if ["--version"].contains(arg) {
        opts.command = .version
        break
      } else if ["--pq"].contains(arg) {
        opts.pq = true
      } else if let option = ValueOption(matching: arg) {
        let argps = arg.split(separator: "=", maxSplits: 1)
        let value: String
        if argps.count == 1 {
          i += 1
          if i >= args.count {
            throw Error.missingValue(arg)
          }
          value = args[i]
        } else {
          value = String(argps[1])
        }
        let arg = String(argps[0])
        switch option {
        case .agePlugin:
          opts.command = try .plugin(
            StateMachine(rawValue: value) ?? { throw Error.invalidValue(arg, value) }())
        case .input:
          opts.input = value
        case .output:
          opts.output = value
        case .accessControl:
          opts.accessControl =
            try AccessControl(rawValue: value) ?? { throw Error.invalidValue(arg, value) }()
        case .recipientType:
          opts.recipientType =
            try RecipientType(rawValue: value) ?? { throw Error.invalidValue(arg, value) }()
        }
      } else {
        throw Error.unknownOption(arg)
      }
      i += 1
    }
    return opts
  }

  /// Fork: the options that take a value, each with the names it answers to.
  /// `parse` switches on the case, so every option it matches has a branch.
  enum ValueOption: CaseIterable {
    case agePlugin, input, output, accessControl, recipientType

    var names: [String] {
      switch self {
      case .agePlugin: return ["--age-plugin"]
      case .input: return ["-i", "--input"]
      case .output: return ["-o", "--output"]
      case .accessControl: return ["--access-control"]
      case .recipientType: return ["--recipient-type"]
      }
    }

    /// The option `arg` names, alone or as `name=value`.
    init?(matching arg: String) {
      guard
        let option = Self.allCases.first(where: {
          $0.names.contains { arg == $0 || arg.hasPrefix($0 + "=") }
        })
      else { return nil }
      self = option
    }
  }
}
