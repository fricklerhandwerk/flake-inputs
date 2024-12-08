# `flake-inputs`

A helper to use remote references from `flake.lock` in stable Nix.

# Example

```
# default.nix
{
  inputs ? import (fetchTarball "https://github.com/fricklerhandwerk/flake-inputs/tarball/main") {
    root = ./.;
  },
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
```

```nix
# flake.nix
{
  inputs.flake-inputs.url = "github:fricklerhandwerk/flake-inputs";
  inputs.flake-inputs.flake = false;
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs =
    { flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        default = import ./default.nix { inherit inputs system; };
      in
      default.flake
    );
}
```

