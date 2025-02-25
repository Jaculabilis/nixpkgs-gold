{
  description = "Developer SDK for nixpkgs gold(tm)";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        {
          system,
          self',
          pkgs,
          pkgsEulaAccepted,
          ...
        }:
        {
          # Useful overlay for nixpkgs that doesn't work for nixpkgs-gold because of the EULA.
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              self.overlays.gold
            ];
          };

          # nixpkgs attribute automatically accepting the EULA. Only used for checks.
          _module.args.pkgsEulaAccepted = import inputs.nixpkgs {
            inherit system;
            overlays = [
              self.overlays.gold
            ];
            config = {
              gold.acceptEula = true;
            };
          };

          formatter = pkgs.nixfmt-rfc-style;

          checks =
            let
              goldNoEula = attr: pkgs.${attr}.override { stdenv = pkgs.premenv; };
              goldStd = attr: pkgsEulaAccepted.${attr}.override { stdenv = pkgsEulaAccepted.premenv; };
            in
            {
              noEula = pkgs.stdenvNoCC.mkDerivation {
                name = "no-eula";
                inherit (builtins.tryEval (goldNoEula "hello")) success value;
                phases = [ "checkPhase" "installPhase" ];
                doCheck = true;
                checkPhase = ''
                  if [ -n "$success" ] || [ -n "$value" ]; then
                    echo "Evaluating no EULA accepted derivation should have thrown." >&2
                    echo "Instead we got ($success, $value)" >&2
                    exit 1
                  fi
                '';
                installPhase = ''
                  ln -s /dev/null $out
                '';
              };
              withoutLicense = (goldStd "hello").overrideAttrs (prevAttrs: {
                name = "trial-${prevAttrs.pname}-${prevAttrs.version}";
              });
              withLicense = (goldStd "hello").overrideAttrs (prevAttrs: {
                name = "licensed-${prevAttrs.pname}-${prevAttrs.version}";
                goldLicense = "X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*";
              });
            };
        };

      flake = {
        lib = import ./lib.nix;
        overlays.gold = import ./overlay.nix;
      };
    };
}
