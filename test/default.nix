{
  inputs ?
    (import (fetchTarball "https://github.com/fricklerhandwerk/flake-inputs/tarball/main") {
      root = ./.;
    }).inputs,
  system ? builtins.currentSystem,
  pkgs ? import inputs.nixpkgs {
    inherit system;
    config = { };
    overlays = [ ];
  },
}:
{
  inherit inputs system pkgs;
  flake.packages = {
    inherit (pkgs) cowsay lolcat;
  };
}
