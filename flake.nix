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
            config = {};
            localSystem = { inherit system; };
            overlays = [
              (final: prev: {
                probe-run = prev.probe-run.overrideAttrs (o: rec {
                  src = final.fetchFromGitHub {
                    owner = "knurling-rs";
                    repo = "probe-run";
                    rev = "9eea82186ef74c7ff6e280463dcde82f24e15f25";
                    hash = "sha256-N1THKph+BZOXzsf6mUo/e1rcfIJkKw569TeurSLCn0E=";
                  };
                  cargoDeps = o.cargoDeps.overrideAttrs (_: {
                    inherit src;
                    outputHash = "sha256-kmdRwAq6EOniGHC7JhB6Iov1E4hbQbxHlOcc6gUDOhY=";
                  });
                });
              })
            ];
          };

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

          nativeBuildInputs = [ pkgs.pkg-config pkgs.openssl pkgs.udev ];

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
