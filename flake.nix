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
          pkgs = import nixpkgs {
            config = { };
            localSystem = { inherit system; };
            overlays = [ ];
          };

          probe-run-src = pkgs.lib.sources.sourceByRegex (pkgs.lib.cleanSource ./.) [
            "probe-run" "probe-rs" "probe-run/.*" "probe-rs/.*"
          ];

          probe-run = pkgs.probe-run.overrideAttrs (o: rec {
            src = probe-run-src;
            sourceRoot = "source/probe-run";
            cargoDeps = o.cargoDeps.overrideAttrs (_: {
              inherit src sourceRoot;
              outputHash = "sha256-VlmdWASPtIVj8ioRNNNkd5x3k7KVbuuzl93BTXVPwnk=";
            });
          });

          fenix = inputs.fenix.packages.${system};
          toolchain = fenix.combine [
            fenix.latest.cargo
            fenix.latest.rustc
            fenix.targets.thumbv7m-none-eabi.latest.rust-std
          ];
          craneLib = inputs.crane.lib.${system}.overrideToolchain toolchain;

          rust-src = lib.cleanSourceWith {
            src = lib.cleanSource ./.;
            filter = path: type: builtins.any (filter: filter path type) [
              craneLib.filterCargoSources
            ];
          };

          nativeBuildInputs = [ pkgs.pkg-config pkgs.openssl pkgs.udev pkgs.libusb ];

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
                "llvm-tools-preview"
              ])
              cargo-asm
              cargo-expand
              cargo-nextest
              nixpkgs-fmt
              inputs.fenix.packages.${system}.rust-analyzer

              probe-run
              flip-link

              openocd
              gdb
            ] ++ nativeBuildInputs;
          };

          packages = {
            inherit turbo-run probe-run;
            default = packages.turbo-run;
          };
        });
}
