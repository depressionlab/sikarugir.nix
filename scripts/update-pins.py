#!/usr/bin/env python3
"""
Refreshes lib/versions.json against Sikarugir's catalog:

  - https://sikarugir-app.github.io/Template/NewestVersion.txt
  - https://sikarugir-app.github.io/Engines/EngineList.txt

For any Template version or Engine name not yet pinned, downloads the
tarball, computes its Nix SRI hash (`nix hash file --sri`), and adds a new
entry. For an Engine that's *already* pinned, re-downloads it and updates
the hash if upstream silently replaced the tarball's content at the same
URL. Unlike a real versioned release, Sikarugir's Engine URLs don't
change per-release, so this is the only way to catch that.
"""

from __future__ import annotations

import json
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
VERSIONS_JSON = REPO_ROOT / "lib" / "versions.json"
NOTES_FILE = REPO_ROOT / "update-pins-notes.txt"

TEMPLATE_NEWEST_URL = "https://sikarugir-app.github.io/Template/NewestVersion.txt"
TEMPLATE_URL_FMT = "https://github.com/Sikarugir-App/Template/releases/download/v1.0/{version}.tar.xz"

ENGINE_LIST_URL = "https://sikarugir-app.github.io/Engines/EngineList.txt"
ENGINE_URL_FMT = (
    "https://github.com/Sikarugir-App/Engines/releases/download/v1.0/{name}.tar.xz"
)

USER_AGENT = "sikarugir-nix-update-pins/1 (+https://github.com/Sikarugir-App/Sikarugir)"
TIMEOUT = 300


def fetch_text(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read().decode("utf-8", "replace")


def download(url: str, dest: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp, open(dest, "wb") as f:
        while True:
            chunk = resp.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)


def nix_hash(path: Path) -> str:
    out = subprocess.run(
        ["nix", "hash", "file", "--sri", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )
    return out.stdout.strip()


def extract_engine_version(tarball: Path) -> str | None:
    """Best-effort read of wswine.bundle/version out of an Engine tarball."""
    try:
        with tarfile.open(tarball) as tf:
            for member in tf.getmembers():
                if member.name.endswith("/version") and "wswine.bundle" in member.name:
                    f = tf.extractfile(member)
                    if f:
                        return f.read().decode("utf-8", "replace").strip()
    except Exception as exc:  # noqa: BLE001 - cosmetic only, never fatal
        print(f"    (couldn't read engine version string: {exc})", file=sys.stderr)
    return None


def main() -> int:
    data = json.loads(VERSIONS_JSON.read_text())
    changed = False
    notes: list[str] = []

    with tempfile.TemporaryDirectory() as tmp_str:
        tmp = Path(tmp_str)

        # Template
        newest = None
        try:
            newest = fetch_text(TEMPLATE_NEWEST_URL).strip()
        except Exception as exc:  # noqa: BLE001
            print(
                f"WARNING: couldn't fetch {TEMPLATE_NEWEST_URL}: {exc}", file=sys.stderr
            )

        if newest and newest not in data["templates"]:
            print(f"==> New Template version available: {newest}")
            url = TEMPLATE_URL_FMT.format(version=newest)
            dest = tmp / f"Template-{newest}.tar.xz"
            try:
                download(url, dest)
                data["templates"][newest] = {"url": url, "hash": nix_hash(dest)}
                changed = True
                notes.append(
                    f"- Pinned new Template `{newest}` (left `defaultTemplateVersion` "
                    f"alone. Bump it yourself once you've tried the new one)."
                )
            except Exception as exc:  # noqa: BLE001
                print(
                    f"WARNING: couldn't pin new Template {newest}: {exc}",
                    file=sys.stderr,
                )

        # Engines
        catalog: list[str] = []
        try:
            catalog = [
                line.strip()
                for line in fetch_text(ENGINE_LIST_URL).splitlines()
                if line.strip() and not line.strip().startswith("#")
            ]
        except Exception as exc:  # noqa: BLE001
            print(f"WARNING: couldn't fetch {ENGINE_LIST_URL}: {exc}", file=sys.stderr)

        # Re-check every engine we already pin (content can silently change
        # under an unversioned URL) and any new name the live catalog lists
        # that we don't pin yet. We don't drop old pins since old instances
        # may still rely on them.
        for name in sorted(set(catalog) | set(data["engines"].keys())):
            url = ENGINE_URL_FMT.format(name=name)
            dest = tmp / f"{name}.tar.xz"
            try:
                download(url, dest)
            except Exception as exc:  # noqa: BLE001
                print(
                    f"WARNING: couldn't download engine '{name}': {exc}",
                    file=sys.stderr,
                )
                continue

            try:
                new_hash = nix_hash(dest)
            except Exception as exc:  # noqa: BLE001
                print(f"WARNING: couldn't hash engine '{name}': {exc}", file=sys.stderr)
                continue

            existing = data["engines"].get(name)

            if existing is None:
                wine_version = extract_engine_version(dest) or "unknown"
                data["engines"][name] = {
                    "url": url,
                    "hash": new_hash,
                    "wineVersion": wine_version,
                }
                changed = True
                notes.append(f"- Pinned new Engine `{name}` ({wine_version}).")
                print(f"==> New engine pinned: {name} ({wine_version})")
            elif existing["hash"] != new_hash:
                wine_version = extract_engine_version(dest) or existing.get(
                    "wineVersion", "unknown"
                )
                notes.append(
                    f"- ⚠️ **Engine `{name}`'s tarball content changed upstream at "
                    f"the same URL** (hash `{existing['hash']}` -> `{new_hash}`, version "
                    f'string now "{wine_version}"). That\'s unusual for a nominally-versioned '
                    f"release asset! Please review before merging."
                )
                existing["hash"] = new_hash
                existing["wineVersion"] = wine_version
                changed = True
                print(f"==> Engine '{name}' hash changed (upstream content changed)")

    if changed:
        VERSIONS_JSON.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
        body = "\n".join(notes) if notes else "Pin refresh (see diff)."
        NOTES_FILE.write_text(body + "\n")
        print("\n" + body)
    else:
        print("No pin changes.")
        if NOTES_FILE.exists():
            NOTES_FILE.unlink()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
