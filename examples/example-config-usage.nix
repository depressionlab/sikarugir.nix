{
  description = "example flake-parts config usage";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-darwin.url = "github:nix-darwin/nix-darwin";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sikarugir-nix.url = "github:depressionlab/sikarugir-nix";
  };

  outputs = inputs @ { flake-parts, nix-darwin, home-manager, sikarugir-nix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" ];
      imports = [ sikarugir-nix.flakeModules.default ];

      flake = {
        darwinConfigurations = {
          MyMac = nix-darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            modules = [
              home-manager.darwinModules.home-manager

              {
                home-manager.users.myuser = {
                  imports = [ inputs.self.homeManagerModules.sikarugir ];

                  programs.sikarugir = {
                    enable = true;
                    # Defaults to ~/Applications/Sikarugir.

                    instances = {
                      SatisfactoryCX = {
                        engine = "WS12WineCX24.0.7_7";
                        runPath = ''/Program Files/Epic Games/SatisfactoryEarlyAccess/FactoryGame/Binaries/Win64/FactoryGame-Win64-Shipping.exe'';
                        symlinks.enable = true; # map Desktop/Documents/etc. into the prefix
                      };

                      SomeOtherCXGame = {
                        engine = "WS12WineCX24.0.7_7"; # <- same engine as above
                        runPath = ''/Games/SomeOtherGame/Game.exe'';
                        renderer.enableDxvk = true;
                      };

                      SikarugirDefaultEngineGame = {
                        # engine left at versions.defaultEngine (WS12WineSikarugir11.0)
                        runPath = ''/Games/ThirdGame/Launcher.exe'';
                        enableDebugMode = false;
                      };
                    };
                  };
                };
              }
            ];
          };
        };
      };
    };
}
