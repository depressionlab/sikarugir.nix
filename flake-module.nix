/*
  A flake-parts module, for a consumer flake that's itself built with
  flake-parts (https://flake.parts). Using e.g. `imports = [
  inputs.sikarugir-nix.flakeModules.default ];` in your own
  `flake-parts.lib.mkFlake` call.
*/
{ self }:
{
  perSystem = { system, ... }: {
    packages.sikarugir-satisfactory-example = self.packages.${system}.satisfactory-example;
    checks.sikarugir-dedup = self.checks.${system}.dedup;
  };

  flake = {
    homeManagerModules.sikarugir = self.homeManagerModules.default;
    darwinModules.sikarugir = self.darwinModules.default;
  };
}
