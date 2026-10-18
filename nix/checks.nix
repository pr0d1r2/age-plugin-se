# Checks (nix §I). Each runs the host toolchain, so each opts out of the nix
# sandbox (`__noChroot`, nix §C). A passing check is cached by its inputs, so
# it does not rerun when only the host Xcode changes; the shell's guard runs
# on every entry.
{ pkgs }:
let
  swiftpm = import ./swiftpm.nix { inherit pkgs; };
in
{
  # The guard on this host, and its planted refusals (nix T1).
  toolchain = pkgs.runCommand "age-plugin-se-toolchain" { __noChroot = true; } ''
    export HOME="$TMPDIR"
    export DEVELOPER_DIR="$(/usr/bin/env -u DEVELOPER_DIR /usr/bin/xcode-select -p)"
    unset SDKROOT MACOSX_DEPLOYMENT_TARGET
    export PATH="$PATH:/usr/bin"
    ${pkgs.bash}/bin/bash ${./toolchain-test.sh} ${./toolchain.sh}
    touch $out
  '';

  # Upstream's XCTest suite and the fork's, on DummyCrypto (root V15).
  tests = pkgs.stdenvNoCC.mkDerivation {
    name = "age-plugin-se-tests";
    inherit (swiftpm) src nativeBuildInputs;
    __noChroot = true;
    buildPhase = ''
      runHook preBuild
      ${swiftpm.swift} test --disable-sandbox --only-use-versions-from-resolved-file
      runHook postBuild
    '';
    installPhase = "touch $out";
  };
}
