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
    flake-utils.url = "github:numtide/flake-utils";
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

  outputs = { self, emacs-overlay, flake-utils, nixpkgs, pre-commit-hooks, treefmt-nix, ... }:
    {
      overlays.default = _final: prev: {
        inherit (self.packages.${prev.system}) bpf2go;
      };
    } // flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          overlays = [
            emacs-overlay.overlay
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
              bpftools
              (
                emacsWithPackagesFromUsePackage {
                  alwaysEnsure = true;
                  config = ./emacs.el;
                }
              )
              glibc_multi
              go
              gopls
              gotools
              libbpf_1
              revive
              rnix-lsp
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
        };
      }
    );
}
