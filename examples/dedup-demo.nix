/*
  Two instances that deliberately pick the *same* (templateVersion, engine)
  pair but different names/settings. Used by `checks.<system>.dedup` (see
  flake.nix).
*/
{
  a = {
    name = "DedupDemoA";
    engine = "WS12WineSikarugir11.0";
  };
  b = {
    name = "DedupDemoB";
    engine = "WS12WineSikarugir11.0";
    # Deliberately different settings from `a`, which proves the *shared* parts
    # (Contents/MacOS et al.) are identical while the genuinely per-instance
    # part (Info.plist) is still allowed to differ.
    enableDebugMode = true;
  };
}
