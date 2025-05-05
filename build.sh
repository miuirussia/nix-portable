#!/usr/bin/env bash
set -euox pipefail

main() {
  export NIX_BUILD_CORES=1
  ./get-binary.sh x86_64-linux
  exec nix build -L .#defaultPackage.x86_64-linux
}

main "$@"
