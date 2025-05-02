# `flake-inputs`

A helper to use remote source references from `flake.lock` in stable Nix.

# Example

```
# default.nix
{
  inputs ? import (fetchTarball "https://github.com/fricklerhandwerk/flake-inputs/tarball/1.0") {
    root = ./.;
  },
  system ? builtins.currentSystem,
  nixpkgs-config ? {
    inherit system;
    config = { };
    overlays = [ ];
  },
}:
let
  pkgs = import inputs.nixpkgs nixpkgs-config;
in
{
  flake.packages = {
    inherit (pkgs) cowsay lolcat;
  };
}
```

```nix
# flake.nix
{
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

