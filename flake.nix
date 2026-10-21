{
  # age-plugin-se fork: the package, its checks and the dev shell on
  # aarch64-darwin and x86_64-darwin (decision 12, amended
  # 2026-10-21). Swift, the macOS SDK and XCTest come
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
    pklith = {
      url = "git+https://github.com/pr0d1r2/pklith?ref=main&shallow=1";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.sherd.follows = "sherd";
    };
    # Newer than the sherd pklith's catalog pins: sherd main, for SwiftPM
    # line coverage and its function exclusions (`sherd coverage`, sherd
    # PRs 139, 140 and 142), which no tag carries yet; back to a tag once
    # one does. pklith follows it, so the lock keeps one sherd and
    # `catalog.sherd` is this one.
    sherd = {
      url = "git+https://github.com/pr0d1r2/sherd?ref=main&shallow=1";
      inputs.nixpkgs-lock.follows = "nixpkgs-lock";
      inputs.nix-hk.follows = "pklith/nix-hk";
    };
    # Renders the fork CI workflow from .actlith (root T14). actlith main,
    # for the gate kind's `xcode=<version>` pin (actlith PR 19), which no
    # tag carries yet; back to a tag once one does. Its fleet tools follow
    # the ones above, so the lock keeps one of each it shares.
    actlith = {
      url = "git+https://github.com/pr0d1r2/actlith?ref=main&shallow=1";
      inputs = {
        nixpkgs-lock.follows = "nixpkgs-lock";
        nix-hk.follows = "pklith/nix-hk";
        pklith.follows = "pklith";
        sherd.follows = "sherd";
        microlith.follows = "pklith/microlith";
        itok.follows = "pklith/itok";
        # Its dev-shell-only tools: `""` follows this flake instead, so the
        # lock carries none of them; its package reads only the crate.
        characterminator.follows = "";
        rekall.follows = "";
        xenolith.follows = "";
      };
    };
  };

  outputs =
    {
      nixpkgs,
      pklith,
      actlith,
      ...
    }:
    let
      forSystems = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    in
    {
      packages = forSystems (
        system: import ./nix/package.nix { pkgs = nixpkgs.legacyPackages.${system}; }
      );
      checks = forSystems (system: import ./nix/checks.nix { pkgs = nixpkgs.legacyPackages.${system}; });
      # x86_64-darwin too since pklith 028c65c, whose catalog builds
      # microlith, itok and sherd from source there (root T32).
      devShells = forSystems (system: {
        default = import ./nix/shell.nix {
          inherit pklith;
          pkgs = nixpkgs.legacyPackages.${system};
          inherit (pklith.legacyPackages.${system}) catalog;
          actlith = actlith.packages.${system}.default;
        };
      });
    };
}
