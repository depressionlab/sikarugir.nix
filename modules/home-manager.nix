/*
  Usage (in your home-manager config):
  
  ```nix
  {
  imports = [ sikarugir-nix.homeManagerModules.default ];

  programs.sikarugir = {
      enable = true;
      # Defaults to ~/Applications/Sikarugir
      instancesDirectory = "~/Applications/Sikarugir";

      instances.SatisfactoryCX = {
        engine = "WS12WineCX24.0.7_7";
        runPath = "/Program Files/Epic Games/SatisfactoryEarlyAccess/FactoryGame/Binaries/Win64/FactoryGame-Win64-Shipping.exe";
      };
  };
  }
  ```

  Instances are created with a launchd-free activation script hooked into
  home-manager's activation (lib.hm.dag.entryAfter [ "writeBoundary" ]`).
  It runs on `home-manager switch`. For an instance that doesn't exist
  yet, it will create it. For an existing instance, it will sync
  `Info.plist` settings. Removing an instance from your config doesn't
  remove its `.app`, and this will never delete/modify an instance's
  save data in `Contents/SharedSupport/prefix`.

  Each instance's own activation script is also added to `home.packages`,
  so you can re-run just one instance's sync by hand
  (`sikarugir-activate-SatisfactoryCX ~/Applications/Sikarugir`) without a
  full `home-manager switch`.
*/
{ config, lib, pkgs, ... }:

let
  cfg = config.programs.sikarugir;
  versions = import ../lib/versions.nix;
  instanceOptions = import ../lib/options.nix { inherit lib versions; };
  buildInstance = import ../lib/build-instance.nix { inherit pkgs lib versions; };

  # `name` is auto-filled from the attribute name unless overridden
  instanceType = lib.types.submodule ({ name, ... }: {
    options = instanceOptions;
    config = {
      name = lib.modules.mkDefault name;
    };
  });

  built = lib.attrsets.mapAttrs (_: instCfg: buildInstance instCfg) cfg.instances;

  bundleIdentifiers = lib.attrsets.mapAttrsToList (_: inst: inst.bundleIdentifier) built;
  duplicateBundleIdentifiers =
    lib.lists.filter (id: lib.lists.count (x: x == id) bundleIdentifiers > 1)
      (lib.lists.unique bundleIdentifiers);
in
{
  options.programs.sikarugir = {
    enable = lib.options.mkEnableOption "declarative Sikarugir instances";

    instancesDirectory = lib.options.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Applications/Sikarugir";
      description = ''
        The directory where Sikarugir instances are created and managed.
        Matches where Sikarugir's own Homebrew cask suggests putting
        wrapper apps (`~/Applications/Sikarugir`) so Spotlight/Launchpad
        indexing behaves the way you'd expect for a normal app folder.
      '';
    };

    instances = lib.options.mkOption {
      type = lib.types.attrsOf instanceType;
      default = { };
      description = ''
        Declarative Sikarugir instances, keyed by name.
      '';
    };
  };

  config = lib.modules.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.isDarwin;
        message = ''
          programs.sikarugir only works on macOS since Sikarugir itself,
          and everything this module builds, is macOS-only.
        '';
      }
      {
        assertion = duplicateBundleIdentifiers == [ ];
        message = ''
          programs.sikarugir: more than one instance resolved to the same
          CFBundleIdentifier (${lib.concatStringsSep ", " duplicateBundleIdentifiers})!
          Real Creator-built instances avoid this by appending a random
          numeric suffix; this module doesn't (that would break Nix
          reproducibility) so give colliding instances distinct
          `bundleIdentifier`s explicitly, or rename them.
        '';
      }
    ];

    home.activation.sikarugirInstances = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${lib.concatStringsSep "\n" (lib.attrsets.mapAttrsToList
        (name: inst: ''
          $DRY_RUN_CMD ${inst.activationScript}/bin/sikarugir-activate-${name} ${lib.strings.escapeShellArg cfg.instancesDirectory}
        '')
        built)}
    '';

    home.packages = lib.attrsets.mapAttrsToList (_: inst: inst.activationScript) built;
  };
}
