with builtins;
{
  bubblewrapStatic ? pkgsStatic.bubblewrap,
  # fix: builder failed to produce output path for output 'man'
  # https://github.com/milahu/nixpkgs/issues/83
  # nixStatic ? pkgsStatic.nix,
  # use nix from github
  # https://discourse.nixos.org/t/where-can-i-get-a-statically-built-nix/34253/15
  # https://hydra.nixos.org/job/nix/master/buildStatic.x86_64-linux/all
  self,
  stdenv,
  nix,
  nixGitStatic,
  unzip,
  zip,
  unixtools,
  replaceVars,
  lib,
  glibc,
  ripgrep,
  patchelf,
  cacert,
  pkgs,
  pkgsStatic,
  busyboxStatic ? pkgsStatic.busybox,
  gnutar,
  xz,
  zstdStatic ? pkgsStatic.zstd,
  # fix: ld: attempted static link of dynamic object
  # https://gitlab.com/ita1024/waf/-/issues/2467
  #prootStatic ? pkgsStatic.proot,
  callPackage,
  prootStatic ? (callPackage ./proot/alpine.nix { }),
  compression ? "zstd -3 -T1",
  buildSystem ? builtins.currentSystem,
  # # tar crashed on emulated aarch64 system
  # buildSystem ? "x86_64-linux",
  # hardcode executable to run. Useful when creating a bundle.
  bundledPackage ? null,
  ...
}:

with lib;
let

  nixStatic = nixGitStatic;

  # stage1 bins
  busybox = busyboxStatic;
  zstd = zstdStatic;
  nix = nixStatic;
  bubblewrap = bubblewrapStatic;
  proot = prootStatic;

  pname =
    if bundledPackage == null
    then "nix-portable"
    else lib.getName bundledPackage;

  bundledExe = lib.getExe bundledPackage;

  nixpkgsSrc = self;

  pkgsBuild = import pkgs.path { system = buildSystem; };

  # TODO: git could be more minimal via:
  # perlSupport=false; guiSupport=false; nlsSupport=false;
  gitAttribute = "gitMinimal";
  git = pkgs."${gitAttribute}";

  maketar = targets:
    pkgsBuild.stdenv.mkDerivation {
      name = "nix-portable-store-tarball";
      nativeBuildInputs = [ pkgsBuild.zstd ];
      buildCommand = ''
        mkdir $out
        cp -r ${pkgsBuild.closureInfo { rootPaths = targets; }} $out/closureInfo
        tar -cf - \
          --owner=0 --group=0 --mode=u+rw,uga+r \
          --hard-dereference \
          $(cat $out/closureInfo/store-paths) | ${compression} > $out/tar
      '';
    };

  caBundleZstd = pkgs.runCommand "cacerts" {} "cat ${cacert}/etc/ssl/certs/ca-bundle.crt | ${zstd}/bin/zstd -19 > $out";


  # the default nix store contents to extract when first used
  storeTar = maketar ([
    cacert
    nix
    # nix.man # not with nix 2.21.0
    nixpkgsSrc
  ] ++ lib.optional (bundledPackage != null) bundledPackage);


  # The runtime script which unpacks the necessary files to $HOME/.nix-portable
  # and then executes nix via proot or bwrap
  # Some shell expressions will be evaluated at build time and some at run time.
  # Variables/expressions escaped via `\$` will be evaluated at run time

  runtimeScript = replaceVars ./runtimeScript.sh {
    busyboxBins = lib.escapeShellArgs (attrNames (filterAttrs (d: type: type == "symlink") (readDir "${busybox}/bin")));
    bundledExe = if bundledPackage == null then "" else bundledExe;
    busyboxOffset = null;
    busyboxSize = null;
    stage1_files_sh_offset = null;
    stage1_files_sh_size = null;
    inherit
      bubblewrap
      busybox
      caBundleZstd
      git
      gitAttribute
      nix
      nixpkgsSrc
      proot
      storeTar
      zstd
    ;
  };

  builderScript = replaceVars ./builder.sh {
    bundledExe = if bundledPackage == null then "" else bundledExe;
    stage1_files_sh_offset = null;
    stage1_files_sh_size = null;
    inherit
      runtimeScript
      zip
      bubblewrap
      nix
      proot
      zstd
      busybox
      caBundleZstd
      storeTar
      patchelf
    ;
  };

  nixPortable = pkgs.runCommand pname {
    nativeBuildInputs = [
      unixtools.xxd
      unzip
      glibc # ldd
      ripgrep # rg
    ];
  }
  ''
    bash ${builderScript}
  '';

in
nixPortable
