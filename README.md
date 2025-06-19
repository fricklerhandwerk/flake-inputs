# `flake-inputs`

A helper to use flakes from stable Nix.

Based on original work in

- [edolstra/flake-compat](https://github.com/edolstra/flake-compat)
- [nix-community/flake-compat](https://github.com/nix-community/flake-compat)
- [nix-community/dream2nix](https://github.com/nix-community/dream2nix/blob/main/dev-flake/flake-compat.nix)

since none of those seem to be actively maintained.

This library also exposes:
- `fetchTree`: Polyfill for the experimental [`builtins.fetchTree`](https://nix.dev/manual/nix/latest/language/builtins#builtins-fetchTree)
- `getFlake`: Polyfill for the experimental [`builtins.getFlake`](https://nix.dev/manual/nix/latest/language/builtins#builtins-getFlake)
- `datetime-from-timestamp`: A converter from Unix timestamps to Gregorian date and time, ported from Howard Hinnant's [`chrono`-Compatible Low-Level Date Algorithms](http://howardhinnant.github.io/date_algorithms.html)
- `pad`: The legendary `pad` function

## Use cases

- Separately managing development dependencies to reduce closure size for flake consumers
- Gradually migrating away from flakes
- Offering a first-class experience for users of stable Nix

## Using sources from `flake.lock` in `default.nix`

In `default.nix` obtain the `flake-inputs` library and use sources `flake.lock`:

```
# default.nix
let
  inherit (import (fetchTarball "https://github.com/fricklerhandwerk/flake-inputs/tarball/4.0"))
    import-flake
    ;
  inherit (import-flake {
    src = ./.;
  }) inputs;
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
npins add github fricklerhandwerk flake-inputs --at 4.0
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
  inherit (import flake-inputs) load-flake;
in
(load-flake nix).packages.${builtins.currentSystem}.default
```

Realise the derivation from a substituter to demonstrate that it works as intended:

```bash
nix-build --no-out-link
```
