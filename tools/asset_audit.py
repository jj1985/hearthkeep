#!/usr/bin/env python3
"""Asset legal-hygiene audit. Walks art/ and audio/ trees, cross-checks
each tracked asset against its manifest, reports counts by license, and
fails (exit 1) if any tracked asset is missing a manifest entry.

Per docs/asset_policy.md:  every shipped asset must be CC0, CC-BY,
CC-BY-SA, OFL, MIT, project-original, or license-purchased.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path
from collections import Counter

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "art"
AUDIO = ROOT / "audio"

# Extensions to audit per dir
ART_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".ttf", ".otf",
            ".gltf", ".glb", ".obj", ".fbx", ".tres", ".shader", ".gdshader"}
AUDIO_EXTS = {".ogg", ".wav", ".mp3", ".flac"}

# License whitelist (exact match in manifest license column).
APPROVED = {
    "CC0", "CC-BY", "CC-BY-3.0", "CC-BY-4.0", "CC-BY-SA",
    "OFL", "OFL-1.1",
    "MIT", "Apache-2.0",
    "project-original", "internal", "hearthkeep-original",
    "royalty-free", "kevin-macleod-cc-by",
}


def load_manifest(path: Path) -> dict[str, dict]:
    if not path.exists():
        return {}
    out = {}
    with path.open(encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            fn = row.get("filename", "").strip()
            if fn:
                out[fn] = row
    return out


def audit(root: Path, exts: set[str], manifest_path: Path, label: str) -> int:
    if not root.exists():
        print(f"[{label}] dir not found: {root}")
        return 0
    manifest = load_manifest(manifest_path)
    rooted_assets: list[Path] = []
    for p in root.rglob("*"):
        if not p.is_file(): continue
        if p.suffix.lower() not in exts: continue
        rooted_assets.append(p)
    missing = []
    bad_license = []
    license_counts: Counter[str] = Counter()
    for p in rooted_assets:
        rel = p.relative_to(root).as_posix()
        if rel not in manifest:
            missing.append(rel)
            continue
        lic = manifest[rel].get("license", "").strip()
        license_counts[lic] += 1
        if lic not in APPROVED:
            bad_license.append((rel, lic))
    print(f"[{label}] {len(rooted_assets)} tracked, {len(manifest)} in manifest")
    if license_counts:
        print(f"[{label}] license breakdown:")
        for lic, n in sorted(license_counts.items(), key=lambda x: -x[1]):
            ok = "OK" if lic in APPROVED else "??"
            print(f"  [{ok}]  {lic:<20s}  {n}")
    if missing:
        print(f"[{label}] {len(missing)} assets MISSING from manifest:")
        for m in missing[:20]:
            print(f"  - {m}")
        if len(missing) > 20:
            print(f"  ... and {len(missing) - 20} more")
    if bad_license:
        print(f"[{label}] {len(bad_license)} assets with UNAPPROVED license:")
        for f, lic in bad_license[:20]:
            print(f"  - {f}  ({lic!r})")
    return len(missing) + len(bad_license)


def main() -> int:
    art_fails = audit(ART, ART_EXTS, ART / "ASSET_MANIFEST.csv", "art")
    audio_fails = audit(AUDIO, AUDIO_EXTS, AUDIO / "AUDIO_MANIFEST.csv", "audio")
    total = art_fails + audio_fails
    if total > 0:
        print(f"\n[asset-audit] FAIL: {total} issues — fix before release.")
        return 1
    print("\n[asset-audit] OK: every tracked asset has an approved license.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
