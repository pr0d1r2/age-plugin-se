# SwiftPM inside a nix build, shared by nix/package.nix and nix/checks.nix.
# It runs the host Xcode, so a derivation using it opts out of the nix
# sandbox (`__noChroot`): a stated deviation (nix §C), refused outright on a
# machine with `sandbox = true`. SwiftPM resolves every pin in
# Package.resolved even when a dependency is Linux-only (swift-crypto, and
# swift-asn1 under it), so each pin is fetched here as a fixed-output git
# checkout at its pinned revision and SwiftPM is pointed at it by a mirror;
# the build itself never reaches the network. nix/swift.sh sets the rest up.
{ pkgs }:
let
  inherit (pkgs) lib;
  resolved = builtins.fromJSON (builtins.readFile ../Package.resolved);
  # Hashes of the git checkouts, by pin identity. A Package.resolved bump
  # changes a revision and fails here until its hash is refreshed.
  hashes = {
    swift-asn1 = "sha256-vO0QwO+NZ9wKvdvElvxflGb819ySByXK+md+mi8dZoU=";
    swift-crypto = "sha256-FlFbU1RVkxYBKjtzM8bnf4pAtgygXh5nO68gKbVATc0=";
  };
  # SwiftPM names a package by the last component of its URL, so each
  # checkout sits at `<identity>.git` and Package.resolved still matches.
  vendored = pkgs.linkFarm "age-plugin-se-swiftpm-pins" (
    map (pin: {
      name = "${pin.identity}.git";
      path = pkgs.fetchgit {
        url = pin.location;
        rev = pin.state.revision;
        hash = hashes.${pin.identity};
        leaveDotGit = true;
      };
    }) resolved.pins
  );
  mirrors = pkgs.writeText "age-plugin-se-mirrors" (
    lib.concatMapStrings (pin: "${pin.location} file://${vendored}/${pin.identity}.git\n") resolved.pins
  );
in
{
  # Tests is in the source because Package.swift declares the test target.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../Package.swift
      ../Package.resolved
      ../Sources
      ../Tests
    ];
  };
  # `${swift} <args>` in a build phase runs host swift with <args>.
  swift = "${pkgs.bash}/bin/bash ${./swift.sh} ${./toolchain.sh} ${mirrors}";
  # SwiftPM clones the vendored checkouts with git.
  nativeBuildInputs = [ pkgs.git ];
}
