{
  description = "eBPF playground";

  inputs = {
    emacs-overlay = {
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs-stable";
      };
      url = "github:nix-community/emacs-overlay";
    };
    fenix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nix-community/fenix";
    };
    flake-utils.url = "github:numtide/flake-utils";
    naersk = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:nmattia/naersk";
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/release-23.05";
    pre-commit-hooks = {
      inputs = {
        flake-utils.follows = "flake-utils";
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs-stable";
      };
      url = "github:cachix/pre-commit-hooks.nix";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };

  outputs = inputs@{ self, flake-utils, nixpkgs, pre-commit-hooks, treefmt-nix, ... }:
    {
      overlays.default = _final: prev: {
        inherit (self.packages.${prev.system}) bpf2go;

        myEmacs = prev.emacsWithPackagesFromUsePackage {
          alwaysEnsure = true;
          config = ./emacs.el;
        };
      };
    } // flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          overlays = [
            inputs.emacs-overlay.overlay
            inputs.fenix.overlays.default
            self.overlays.default
          ];
          inherit system;
        };
      in
      {
        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              revive.enable = true;
              treefmt.enable = true;
            };
            settings = {
              treefmt.package = self.formatter.${system};
            };
          };
        };

        devShells = {
          default = with pkgs; mkShell {
            FONTCONFIG_FILE = makeFontsConf {
              fontDirectories = [
                (nerdfonts.override { fonts = [ "Iosevka" ]; })
              ];
            };
            buildInputs = [
              bpf2go
              bpf-linker
              bpftool
              bpftools
              cargo-generate
              (
                fenix.complete.withComponents [
                  "cargo"
                  "clippy"
                  "rust-src"
                  "rustc"
                  "rustfmt"
                ]
              )
              glibc_multi
              go
              gopls
              gotools
              libbpf_1
              myEmacs
              nixpkgs-fmt
              revive
              rnix-lsp
              rust-analyzer-nightly
            ];
            inherit (self.checks.${system}.pre-commit-check) shellHook;
          };
        };

        formatter = treefmt-nix.lib.mkWrapper pkgs {
          projectRootFile = "flake.nix";
          programs = {
            clang-format.enable = true;
            deadnix.enable = true;
            gofmt.enable = true;
            nixpkgs-fmt.enable = true;
          };
        };

        packages = {
          bpf2go = with pkgs; buildGoModule rec {
            pname = "bpf2go";
            version = "0.10.0";
            src = fetchFromGitHub {
              owner = "cilium";
              repo = "ebpf";
              rev = "v${version}";
              hash = "sha256-3ndNjOvVnkpmqg0twWzdAnC+v6AWhr8XDQND4cn13us=";
            };
            vendorHash = "sha256-Nlc8cmTd8W1L/U1tVfG6icBgC2K6r3xaX/zI1dWXI2k=";
            subPackages = [ "cmd/bpf2go" ];
            # FIXME: hardcoded binaries in tests, e.g. clang-14, llvm-strip-14
            doCheck = false;
          };

          hello-world = with pkgs; buildGoModule rec {
            pname = "hello-world";
            version = "0.0.1";
            src = ./hello-world;
            nativeBuildInputs = [
              bpf2go
              buildPackages.clang_14
              buildPackages.llvm_14
              glibc_multi
            ];
            buildInputs = [
              libbpf_1
            ];
            vendorHash = "sha256-iw3HIkGXFQu/TgyLhJb9J80QU3+Pl1DxvusZxsNMPlI=";
            postConfigure = ''
              go generate ./...
            '';
          };
        };
      }
    );
}
