# Pinned upstream artifacts for Sikarugir (https://github.com/Sikarugir-App).
#
# Sikarugir has no stable release-hash manifest of its own (Template and
# Engines are plain GitHub Releases assets, and their own tooling always
# fetches "whatever is newest"). We use versions.json for reproducibility:
# every version we support is pinned using sha256 and is verified by
# actually downloading and hashing the asset.
#
# The data lives in JSON rather than directly in this file so
# ../scripts/update-pins.py can refresh it automatically.
#
# To add or bump a pin by hand instead (e.g. to pin something the
# automation can't reach yet):
#   curl -sL -o /tmp/x.tar.xz "<url>"
#   nix hash file --sri /tmp/x.tar.xz
# then add/replace the entry in versions.json.
builtins.fromJSON (builtins.readFile ./versions.json)
