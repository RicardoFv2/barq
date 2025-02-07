{
  description = "Integration Testing";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nix-community/naersk";
  };

  outputs = { self, nixpkgs, flake-utils, naersk }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        clightning = pkgs.clightning.overrideAttrs (oldAttrs: {
          version = "master-62dd";
          src = pkgs.fetchgit {
            url = "https://github.com/ElementsProject/lightning";
            rev = "f2551091ca3cc2e7b03a6d3766a851a025dbfd4d";
            sha256 = "sha256-PdbHtMIc35zqv8dDX5TXWyzhcu2h1G/LzIyS9S1TCAQ=";
            fetchSubmodules = true;
          };
          buildInputs = with pkgs; [ gmp libsodium sqlite zlib jq rPackages.GSED ];
          postPatch = ''
                    patchShebangs \
                      tools/generate-wire.py \
                      tools/update-mocks.sh \
                      tools/mockup.sh \
                      tools/fromschema.py \
                      devtools/sql-rewrite.py
                      '';
          configureFlags = [ "--disable-rust" "--disable-valgrind" ];
        });
        # Our integration tests required the cln and bitcoind
        # so in this variable we declare everything that we need
        # for bitcoin and cln
        cln-env-shell = [ clightning pkgs.bitcoind ];

        # build rust application :)
        naersk' = pkgs.callPackage naersk { };
      in
      rec {
        # FIXME: will be good to have this formatting also the rust code
        formatter = pkgs.nixpkgs-fmt;

        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ pkg-config ];
          buildInputs = with pkgs; [
            gnumake

            rustc
            cargo
            rustfmt
            python3
            poetry

            openssl
            openssl.dev
          ] ++ cln-env-shell;
          shellHook = ''
            export HOST_CC=gcc
            export RUST_BACKTRACE=1
            export PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring

            cd tests/ && poetry env use $(which python) && poetry lock --no-update && poetry install -vvv && cd ..
          '';
        };
      }
    );
}
