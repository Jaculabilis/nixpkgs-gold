{
  lib,
  config,
  stdenv,
  makeWrapper,
  ...
}:

assert lib.assertMsg (config.gold.acceptEula or false) ''
  You must accept the ${lib.gold.nixpkgsGold} EULA to continue. Read the terms
  below, and set `gold.acceptEula` in your nixpkgs configuration once you agree:

  ${builtins.readFile ./LICENSE}
'';

stdenv.override (stdenvPrev: {
  name = "premenv";
  extraAttrs = {
    premium = true;
    mkDerivation =
      mkDrvArgs:
      let
        drv = stdenv.mkDerivation mkDrvArgs;
        adBreak = ''
          if [[ -z "$goldLicense" ]]; then
            printf "Don't want ads? Buy a \033[33;1mnixpkgs gold\033[0m license for a premium experience.\n"
            sleep 3

            # Export the ad to advertise it to the build environment
            export NIXPKGS_GOLD_AD="$(echo -n "$NIXPKGS_GOLD_ADS" | shuf -n1)"
            NIXPKGS_GOLD_AD_LENGTH=''$((''${#NIXPKGS_GOLD_AD}))
            printf "\033[2;5m|  |"
            printf " %.0s" $(seq 1 $NIXPKGS_GOLD_AD_LENGTH)
            printf "|  |\033[0m\n"
            printf "\033[2;5m|AD|\033[0m"
            echo "$NIXPKGS_GOLD_AD" | tr -d "\n" | sed 's/nixpkgs gold/\x1b[33;1mnixpkgs gold\x1b[0m/g'
            printf "\033[2;5m|AD|\033[0m\n"
            sleep 10
            printf "\033[2;5m|  |"
            printf " %.0s" $(seq 1 $NIXPKGS_GOLD_AD_LENGTH)
            printf "|  |\033[0m\n"
          fi
        '';
        premDrv = drv.overrideAttrs (
          finalAttrs: prevAttrs: {
            premium = true;

            nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ [ makeWrapper ];

            # use the gold linker, obviously
            NIX_CFLAGS_LINK = toString (mkDrvArgs.NIX_CFLAGS_LINK or "") + " -fuse-ld=gold";

            # perform nixpkgs gold (tm) license checks
            prePhases = [
              "goldLicenseCheck"
              "preUnpackAds"
            ] ++ (prevAttrs.prePhases or [ ]);
            goldLicenseCheck = ''
              export NIXPKGS_GOLD=1
              if [[ -z "$goldLicense" ]]; then
                printf "This derivation requires \033[33;1mnixpkgs gold\033[0m to build and a valid license key was not detected.\n"
                sleep 1
                printf "If you have a \033[33;1mnixpkgs gold\033[0m license key, pass it to 'goldLicense' on this derivation and retry the build.\n"
                sleep 1
                printf "The build will proceed using our ad-supported limited trial build environment in 10 seconds.\n"
                sleep 9
                printf "The build will now proceed. Please enjoy these messages from our partners.\n"
                sleep 1
                unset NIXPKGS_GOLD_LICENSED
                export NIXPKGS_GOLD_ADS="$(<${./ads.txt})"
              else
                printf "Welcome to your \033[33;1mnixpkgs gold\033[0m premium build environment!\n"
                export NIXPKGS_GOLD_LICENSED=1
                unset NIXPKGS_GOLD_ADS
              fi
            '';
            preUnpackAds = adBreak;

            # for trial users, intersperse ad breaks
            preConfigureAds = adBreak;
            preConfigurePhases = [ "preConfigureAds" ] ++ (prevAttrs.preConfigurePhases or [ ]);
            preBuildAds = adBreak;
            preBuildPhases = [ "preBuildAds" ] ++ (prevAttrs.preBuildPhase or [ ]);
            preInstallAds = adBreak;
            preInstallPhases = [ "preInstallAds" ] ++ (prevAttrs.preInstallPhases or [ ]);
            preFixupAds = adBreak;
            preFixupPhases = [ "preFixupAds" ] ++ (prevAttrs.preFixupPhases or [ ]);
            preDistAds = adBreak;
            preDistPhases = [ "preDistAds" ] ++ (prevAttrs.preDistPhases or [ ]);

            # thank the user for using nixpkgs gold (tm)
            postBuildAds = adBreak;
            goldPostPhase = ''
              if [[ -z "$goldLicense" ]]; then
                if [ -d "$out/bin" ]; then
                  find -L "$out/bin" -type f -executable | while read binfile; do
                    wrapProgram "$binfile" \
                      --run 'NIXPKGS_GOLD_AD=$(shuf -n 1 ${./ads.txt})' \
                      --run "printf 'This program was built with \033[33;1mnixpkgs gold\033[0m free trial\n' >&2" \
                      --run 'echo "|AD|''${NIXPKGS_GOLD_AD%'"'"'\n'"'"'}|AD|" | sed "s/nixpkgs gold/\x1b[33;1mnixpkgs gold\x1b[0m/g" >&2' \
                      --run 'sleep 3'
                  done
                fi
                printf "Did you enjoy your build environment? Buy a \033[33;1mnixpkgs gold\033[0m license!\n"
                sleep 3
              else
                printf "Thank you for using the \033[33;1mnixpkgs gold\033[0m premium build environment!\n"
              fi
            '';
            postPhases = [
              "postBuildAds"
              "goldPostPhase"
            ] ++ (prevAttrs.postPhases or [ ]);
          }
        );
      in
      premDrv;
  };
})
