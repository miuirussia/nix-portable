{
  pkgs ? import <nixpkgs> { },
  ...
}:
let
  system = pkgs.system;
  apks = {
    x86_64-linux = {
      # original: http://dl-cdn.alpinelinux.org/alpine/edge/testing/x86_64/proot-static-5.4.0-r1.apk
      url = "https://web.archive.org/web/20240412082958/http://dl-cdn.alpinelinux.org/alpine/edge/testing/x86_64/proot-static-5.4.0-r1.apk";
      sha256 = "sha256-hvwOm8fc34fjdy6PGQTF4Ipa6w/PWCyRl1R6ZQP75GM=";
    };
    aarch64-linux = {
      # original: http://dl-cdn.alpinelinux.org/alpine/edge/testing/aarch64/proot-static-5.4.0-r1.apk
      url = "https://web.archive.org/web/20240412083320/http://dl-cdn.alpinelinux.org/alpine/edge/testing/aarch64/proot-static-5.4.0-r1.apk";
      sha256 = "sha256-6ORDSgjhzrN0ZQLopfzNUsdCBPG5v0GVT8SJsU9vZCg=";
    };
  };
in
pkgs.stdenv.mkDerivation {
  name = "proot";
  src = builtins.fetchurl {
    url = apks.${system}.url;
    sha256 = apks.${system}.sha256;
  };
  unpackPhase = ''
    tar -xf $src
  '';
  installPhase = ''
    mkdir -p $out/bin
    cp ./usr/bin/proot.static $out/bin/proot
  '';
}
