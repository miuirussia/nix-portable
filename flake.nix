{
  inputs = {
    nixpkgs.follows = "defaultChannel";
    treefmt-nix.url = "github:numtide/treefmt-nix";

    # the nixpkgs version shipped with the nix-portable executable
    # TODO: find out why updating this leads to error when building pkgs.hello:
    # Error: checking whether build environment is sane... ls: cannot access './configure': No such file or directory
    defaultChannel.url = "github:miuirussia/nixpkgs/nixpkgs-unstable";

    # See latest done job https://hydra.nixos.org/job/nix/master/buildStatic.nix-everything.x86_64-linux/latest
    nix.url = "github:NixOS/nix/377b60ee9b2fdcdd6b94ad7af2743db794b16ea0?narHash=sha256-XNns9ZQmzjkNoxwwPsr9AWiSZKDqSTYE1VTHmxtvXYI%3D";
  };

  outputs =
    { self, ... }@inp:
    with builtins;
    with inp.nixpkgs.lib;
    let

      lib = inp.nixpkgs.lib;

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f: genAttrs supportedSystems (system: f system (import inp.nixpkgs { inherit system; }));

      nixPortableForSystem =
        {
          system,
          crossSystem ? null,
        }:
        let
          pkgsDefaultChannel = import inp.defaultChannel { inherit system crossSystem; };
          pkgs = import inp.nixpkgs { inherit system crossSystem; };

          # the static proot built with nix somehow didn't work on other systems,
          # therefore using the proot static build from proot gitlab
          prootStatic = import ./proot/alpine.nix { inherit pkgs; };
        in
        # crashes if nixpkgs updated: error: executing 'git': No such file or directory
        pkgs.callPackage ./default.nix rec {
          proot = prootStatic;

          self = "${inp.defaultChannel}";

          pkgs = pkgsDefaultChannel;

          lib = inp.nixpkgs.lib;
          portableRevision = if (inp.self ? rev) then inp.self.rev else "dirty";
          nix = inp.nix.packages.${system}.nix-cli;
          nixStatic =
            pkgs.runCommandNoCC "nix-static-optimized"
              {
                nixBins = lib.escapeShellArgs (
                  attrNames (lib.filterAttrs (d: type: type == "symlink") (readDir "${nix}/bin"))
                );
              }
              ''
                mkdir -p $out/bin
                cat ${inp.nix.packages.${system}.nix-cli-static}/bin/nix > $out/bin/nix
                chmod +x $out/bin/nix
                for bin in $nixBins; do
                  ln -s nix $out/bin/$bin
                done
              '';

          pkgsStatic = pkgs.pkgsStatic;

          # tar crashed on emulated aarch64 system
          buildSystem = "x86_64-linux";
        };

    in
    recursiveUpdate
      ({
        bundlers = forAllSystems (
          system: pkgs: {
            # bundle with fast compression by default
            default = self.bundlers.${system}.zstd-fast;
            zstd-fast =
              drv:
              self.packages.${system}.nix-portable.override {
                bundledPackage = drv;
                compression = "zstd -3 -T0";
              };
            zstd-max =
              drv:
              self.packages.${system}.nix-portable.override {
                bundledPackage = drv;
                compression = "zstd -19 -T0";
              };
          }
        );

        formatter = forAllSystems (
          system: pkgs:
          let
            treefmtEval = inp.treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
          in
          treefmtEval.config.build.wrapper
        );

        devShell = forAllSystems (
          system: pkgs:
          pkgs.mkShell {
            buildInputs = with pkgs; [
              bashInteractive
              guestfs-tools
              parallel
              proot
              qemu
            ];
          }
        );

        packages = forAllSystems (
          system: pkgs: {
            nix-portable = (nixPortableForSystem { inherit system; }).override {
              # all non x86_64-linux systems are built via emulation
              #   -> decrease compression level to reduce CI build time
              compression = if system == "x86_64-linux" then "zstd -19 -T0" else "zstd -9 -T0";
            };
            # dev version that builds faster
            nix-portable-dev = self.packages.${system}.nix-portable.override {
              compression = "zstd -3 -T1";
            };

            release = pkgs.runCommand "all-nix-portable-release-files" { } ''
              mkdir $out
              cp ${self.packages.x86_64-linux.nix-portable}/bin/nix-portable $out/nix-portable-x86_64
              cp ${self.packages.aarch64-linux.nix-portable}/bin/nix-portable $out/nix-portable-aarch64
            '';
          }
        );

        defaultPackage = forAllSystems (system: pkgs: self.packages."${system}".nix-portable);
      })
      {
        packages = (
          genAttrs [ "x86_64-linux" ] (
            system:
            (listToAttrs (
              map (
                crossSystem:
                nameValuePair "nix-portable-${crossSystem}" (nixPortableForSystem {
                  inherit crossSystem system;
                })
              ) [ "aarch64-linux" ]
            ))
          )
        );
      };

}
