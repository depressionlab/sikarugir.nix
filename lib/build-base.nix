{ pkgs, versions }: { templateVersion, engine }:
let
  templatePin = versions.templates.${templateVersion}
    or (throw "sikarugir-nix: no pinned Template version '${templateVersion}' in lib/versions.json!");
  enginePin = versions.engines.${engine}
    or (throw "sikarugir-nix: no pinned Engine '${engine}' in lib/versions.json! pin it there first (see lib/versions.nix's header comment, or let .github/workflows/update-pins.yml do it automatically)");

  templateTarball = pkgs.fetchurl { inherit (templatePin) url hash; };
  engineTarball = pkgs.fetchurl { inherit (enginePin) url hash; };
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "sikarugir-base-${templateVersion}-${engine}";
  version = templateVersion;
  dontUnpack = true;
  # Same rationale as build-instance.nix's skeleton: this just assembles a
  # pre-built, already-codesigned macOS .app bundle out of upstream
  # binaries. Nix's usual fixup steps would actively break codesigning /
  # bundled Mach-O loader paths.
  dontFixup = true;
  dontStrip = true;
  dontPatchShebangs = true;
  nativeBuildInputs = [ pkgs.gnutar ];

  buildPhase = ''
    runHook preBuild

    mkdir -p "$out"
    tar --warning=no-unknown-keyword -C "$out" --strip-components=1 -xf ${templateTarball}

    # Sikarugir's combine step: the Engine's wswine.bundle contents get
    # flattened directly onto Contents/SharedSupport/wine (the wswine.bundle
    # directory name itself is dropped).
    rm -rf "$out/Contents/SharedSupport/wine"
    mkdir -p "$out/Contents/SharedSupport/wine"
    tar --warning=no-unknown-keyword -C "$out/Contents/SharedSupport/wine" --strip-components=1 -xf ${engineTarball}
    chmod -R u+w "$out/Contents/SharedSupport/wine"

    # No Info.plist patching here on purpose. Info.plist is a
    # per-instance file, and belongs in build-instance.nix so that this
    # derivation's output only ever depends on (templateVersion, engine).

    runHook postBuild
  '';

  # buildPhase already wrote straight into $out (there's no separate
  # top-level "Whatever.app" wrapping folder here, unlike the per-instance
  # skeleton. Callers symlink individual Contents/* entries out of this,
  # so the extra nesting would just be inconvenient).
  installPhase = ''
    runHook preInstall
    runHook postInstall
  '';

  passthru = {
    inherit templateVersion engine;
  };
}
