#!/bin/sh
set -x
export NIX_BUILD_CORES=1
exec nix build -L .#defaultPackage.x86_64-linux
