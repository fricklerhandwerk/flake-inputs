{
  sources ? import ./npins,
  system ? builtins.currentSystem,
  pkgs ? import sources.nixpkgs {
    inherit system;
    config = { };
    overlays = [ ];
  },
}:
pkgs.mkShellNoCC {
  packages = with pkgs; [ nix-unit ];
  shellHook = ''
    set -e
    trap 'rm -f lib.nix' EXIT
    nix flake update --flake ${toString ./test}
    cp $(nix build ./test#flake-inputs --no-link --print-out-paths) lib.nix
    timestamp=$(nix-instantiate --eval -E '(import ./lib.nix).format-timestamp ${toString builtins.currentTime}' | tr -d '"')
    [ $(date -u -d @${toString builtins.currentTime} '+%Y%m%d%H%M%S') = $timestamp ]
    nix-unit ${toString ./tests.nix}
    nix flake check ${toString ./test}
    echo all tests passed
    exit
  '';
}
