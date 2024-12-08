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
      assert default.inputs.nixpkgs == inputs.nixpkgs;
      default.flake
    )
    // {
      inherit inputs;
    };
}
