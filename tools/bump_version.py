#!/usr/bin/env python3
"""Auto-bump Android versionCode in export_presets.cfg before each APK build.

Android's package manager uses `versionCode` to decide whether one APK is
"newer" than another (sideload upgrade-in-place needs a strictly increasing
versionCode). `version/name` is the human-readable string and stays put
between milestones — only the milestone tag bumps it.

This script:
  - reads `version/code` from export_presets.cfg
  - increments by 1
  - writes back, preserving every other line verbatim
  - prints the new code on stdout so the Makefile can echo it

Run from the project root: `python3 tools/bump_version.py`
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


PRESET_PATH = Path(__file__).resolve().parent.parent / "export_presets.cfg"
LINE_RE = re.compile(r"^(version/code\s*=\s*)(\d+)\s*$")


def bump(content: str) -> tuple[str, int, int]:
    """Return (new_content, old_code, new_code).

    Raises ValueError if `version/code=N` isn't found.
    """
    new_lines: list[str] = []
    old_code = -1
    new_code = -1
    for line in content.splitlines(keepends=True):
        m = LINE_RE.match(line.rstrip("\n"))
        if m:
            old_code = int(m.group(2))
            new_code = old_code + 1
            new_lines.append(f"{m.group(1)}{new_code}\n")
        else:
            new_lines.append(line)
    if old_code < 0:
        raise ValueError(f"version/code=N not found in {PRESET_PATH}")
    return "".join(new_lines), old_code, new_code


def main() -> int:
    if not PRESET_PATH.exists():
        print(f"[bump_version] {PRESET_PATH} not found", file=sys.stderr)
        return 1
    content = PRESET_PATH.read_text(encoding="utf-8")
    try:
        new_content, old, new = bump(content)
    except ValueError as e:
        print(f"[bump_version] {e}", file=sys.stderr)
        return 1
    PRESET_PATH.write_text(new_content, encoding="utf-8")
    print(f"[bump_version] versionCode {old} -> {new}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
