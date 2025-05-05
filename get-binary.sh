#!/usr/bin/env bash
set -euox pipefail

main() {
  NIX_STATIC_URL=$(jq --raw-output '.nodes.nix.locked | .owner + "/" + .repo + "/" + .rev' < flake.lock)
  NIX_STATIC_RESULT="$(nix build --no-link --print-out-paths "github:$NIX_STATIC_URL#hydraJobs.buildStatic.nix-cli.$1")"

  mkdir -p ./bin
  cp -f "$NIX_STATIC_RESULT/bin/nix" "./bin/nix-$1"
}

main "$@"
