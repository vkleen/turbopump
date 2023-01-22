{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs;
    utils.url = github:numtide/flake-utils;

    fenix = {
      url = github:nix-community/fenix;
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane = {
      url = github:ipetkov/crane;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, utils, ... }@inputs:
    utils.lib.eachDefaultSystem
      (system:
        let
          inherit (nixpkgs) lib;
          pkgs = nixpkgs.legacyPackages.${system};

          fenix = inputs.fenix.packages.${system};
          toolchain  = fenix.combine [
            fenix.latest.cargo fenix.latest.rustc
            fenix.targets.thumbv7m-none-eabi.latest.rust-std
          ];
          craneLib = inputs.crane.lib.${system}.overrideToolchain toolchain;

          rust-src = lib.cleanSourceWith {
            src = lib.cleanSource ./.;
            filter = path: type: builtins.any (filter: filter path type) [
              craneLib.filterCargoSources
            ];
          };

          nativeBuildInputs = [];

          cargoArtifacts = craneLib.buildDepsOnly {
            pname = "turbo-run";
            src = rust-src;
            cargoExtraArgs = "--workspace";
            inherit nativeBuildInputs;
          };

          workspacePackage = crate: args: craneLib.buildPackage ({
            pname = crate;
            src = ./.;
            cargoExtraArgs = "-p ${crate}";
            inherit cargoArtifacts nativeBuildInputs;
          } // args);

          turbo-run = workspacePackage "turbo-run" { };
        in
        rec {
          devShell = with pkgs; mkShell {
            # inputsFrom = lib.attrValues self.packages.${system};
            packages = [
              (fenix.latest.withComponents [
                "cargo"
                "clippy"
                "rust-src"
                "rustc"
                "rustfmt"
              ])
              cargo-asm
              cargo-expand
              cargo-nextest
              nixpkgs-fmt
              inputs.fenix.packages.${system}.rust-analyzer

              cargo-generate probe-run flip-link
            ] ++ nativeBuildInputs;
          };

          packages = {
            inherit turbo-run;
            default = packages.turbo-run;
          };
        });
}
