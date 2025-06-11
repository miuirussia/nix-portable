nix eval --impure --expr 'builtins.fetchGit {url="https://github.com/miuirussia/nix-portable" rev="94b5e6c28600246a822d8b3b6f8d34603000312e";}'
nix build -L --impure --expr '(import <nixpkgs> {}).hello.overrideAttrs(_:{change="_var_";})'
nix-shell -p hello --run hello
