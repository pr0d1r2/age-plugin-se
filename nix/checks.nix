# Checks (nix §I). Each runs the host toolchain, so each opts out of the nix
# sandbox (`__noChroot`, nix §C). A passing check is cached by its inputs, so
# it does not rerun when only the host Xcode changes; the shell's guard runs
# on every entry.
{ pkgs }:
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
}
