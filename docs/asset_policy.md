# Asset Policy

**Hard rule:** every asset shipped with the game is CC0, CC-BY (with attribution shipped in-game), or original.

## Workflow when adding an asset

1. Find the asset on an approved source (see `LICENSES.md`).
2. Verify the license at the source — screenshot the license text if it's not unambiguous.
3. Download the asset.
4. Add a row to `art/ASSET_MANIFEST.csv` (or `audio/AUDIO_MANIFEST.csv` for audio) with `filename, source_url, license, author, date_acquired, modifications`.
5. If license is CC-BY: also add an attribution line to `art/CREDITS.md`, and the in-game Credits screen will read both files.
6. Commit with `chore(assets): add <pack-name> from <source> (CC0/CC-BY)`.

## When in doubt

Do **not** import.  The cost of an asset taking the game down is much greater than the cost of finding a different one.

## Audit

`make assets-audit` walks the manifests and prints any rows missing required fields.

## Disallowed

- Anything ripped from a commercial game.
- AI-generated art with ambiguous training/output license.
- CC-BY-NC (non-commercial) anything — we want the option to charge later.
- CC-BY-SA — unless the studio agrees to ShareAlike on the derived work.
- Free sites with no per-asset license clarity.
