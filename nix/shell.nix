# The dev shell (nix §I): pklith's shell (hk, pkl, git, pklith and whatever
# the generated nix/pklith.nix names, once T6 adds it), the spec tools, the
# Swift linters from the nixpkgs pin, and gh. Swift itself is the host's;
# the hook restores the host Xcode over the stdenv's apple-sdk and runs the
# guard (nix V1).
{
  pkgs,
  pklith,
  catalog,
}:
(pklith.lib.devShell {
  inherit pkgs;
  src = ../.;
  packages = [
    catalog.microlith
    catalog.sherd
    catalog.itok
    pkgs.swiftlint
    pkgs.swift-format
    pkgs.gh
  ];
}).overrideAttrs
  (old: {
    shellHook = old.shellHook + ''
      source ${./shell-hook.sh} ${./toolchain.sh} || exit 1
    '';
  })
