# The package (nix §I): `swift build -c release` with the host Xcode
# (nix/swiftpm.nix), binary `age-plugin-se`.
{ pkgs }:
let
  swiftpm = import ./swiftpm.nix { inherit pkgs; };
  inherit (swiftpm) swift;
in
{
  default = pkgs.stdenvNoCC.mkDerivation {
    pname = "age-plugin-se";
    version = "0.2.1";
    inherit (swiftpm) src nativeBuildInputs;
    __noChroot = true;
    buildPhase = ''
      runHook preBuild
      ${swift} build -c release --disable-sandbox --only-use-versions-from-resolved-file
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      install -Dm755 "$(${swift} build -c release --show-bin-path)/age-plugin-se" $out/bin/age-plugin-se
      runHook postInstall
    '';
    meta.mainProgram = "age-plugin-se";
  };
}
