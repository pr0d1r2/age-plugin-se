{
  # age-plugin-se fork: the package, its checks and the dev shell, all on
  # aarch64-darwin only (decision 12). Swift, the macOS SDK and XCTest come
  # from the host Xcode (decisions 11 and 21); nix pins every other tool.
  # One nixpkgs, followed from nixpkgs-lock rather than spelled here
  # (paradigm/V20). The parts live in nix/ (nix §I).
  description = "age-plugin-se -- age plugin for Apple's Secure Enclave, fork with a nix flake and a spec";

  # hk is built by nix-hk and pushed to this cache; without it the first
  # shell builds hk from source.
  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [
      "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM="
    ];
  };

  inputs = {
    nixpkgs-lock.url = "git+https://github.com/pr0d1r2/nixpkgs-lock?ref=main&shallow=1";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";
    pklith.url = "git+https://github.com/pr0d1r2/pklith?ref=main&shallow=1";
    pklith.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    # Newer than the sherd pklith's catalog pins (v0.5.1, two false
    # advisories since fixed upstream). pklith follows it, so the lock keeps
    # one sherd and `catalog.sherd` is this one.
    sherd.url = "git+https://github.com/pr0d1r2/sherd?ref=refs/tags/v0.5.4&shallow=1";
    sherd.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
    sherd.inputs.nix-hk.follows = "pklith/nix-hk";
    pklith.inputs.sherd.follows = "sherd";
  };

  outputs =
    { nixpkgs, pklith, ... }:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      catalog = pklith.legacyPackages.${system}.catalog;
    in
    {
      checks.${system} = import ./nix/checks.nix { inherit pkgs; };
      devShells.${system}.default = import ./nix/shell.nix { inherit pkgs pklith catalog; };
    };
}
