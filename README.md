# `flake-inputs`

A helper to use flakes from stable Nix.

Modified from [nix-community/dream2nix](https://github.com/nix-community/dream2nix/blob/main/dev-flake/flake-compat.nix) since neither [nix-community/flake-compat](https://github.com/nix-community/flake-compat) nor [edolstra/flake-compat](https://github.com/edolstra/flake-compat) are actively maintained.

## Use cases

- Separately managing development dependencies to reduce closure size for flake consumers
- Gradually migrating away from flakes
- Offering a first-class experience for users of stable Nix

## Using sources from `flake.lock` in `default.nix`

In `default.nix` obtain the `flake-inputs` library and use sources `flake.lock`:

```
# default.nix
let
  inputs = import (fetchTarball "https://github.com/fricklerhandwerk/flake-inputs/tarball/2.0") {
    src = ./.;
  };
in
{
  system ? builtins.currentSystem,
  config ? { },
  overlays ? [ ],
  ...
}@args:
let
  pkgs = import inputs.nixpkgs ({ inherit system config overlays; } // args);
in
{
  packages = {
    inherit (pkgs) cowsay lolcat;
  };
}
```

In `flake.nix` use attributes from `default.nix` for `outputs`:

```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs =
    { flake-utils, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      import ./default.nix { inherit system; };
    );
}
```

Keep using the `inputs` attribute to specify sources, and `nix flake update` to pull the latest versions.

# Importing flakes

Obtain `flake-inputs` and some arbitrary project that is very inconvenient to evaluate from stable Nix:

```bash
nix-shell -p npins --run "
npins init --bare
npins add github fricklerhandwerk flake-inputs --at 2.0
npins add github nixos nix --branch 2.29-maintenance
"
```

In `default.nix` import the flake with `load-flake` from the `flake-inputs` library:

```
# default.nix
let
  sources = import ./npins;
in
{
  flake-inputs ? sources.flake-inputs,
  nix ? sources.nix,
}:
let
  inherit (import "${flake-inputs}/lib.nix") load-flake;
in
(load-flake nix).packages.${builtins.currentSystem}.default
```

Realise the derivation from a substituter to demonstrate that it works as intended:

```bash
nix-build --no-out-link
```
