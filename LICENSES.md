# HEARTHKEEP — License Compliance

The project's release-blocker rule: every shipped asset must be one of:

- **CC0** (best — no attribution required, but attribute as good citizenship)
- **CC-BY** (attribution required, ship the credit in `art/CREDITS.md` and the in-game Credits screen)
- **Original** to this project (procedural meshes, code-authored shaders, hand-authored materials, hand-authored sounds)
- **License-purchased** (out of scope for this autonomous session)

Explicitly disallowed: any commercial-game rip (EverQuest, EQ2, WoW, Diablo, Path of Exile, Last Epoch, Megabonk, Hades, etc.); free-site assets without verified license; AI-generated art with ambiguous training/output license; CC-BY-NC (non-commercial) anything; CC-BY-SA unless the project is willing to inherit ShareAlike.

## Code

All GDScript in `scripts/` and all `.tscn`/`.tres` resources in `scenes/` and `data/` are **original to this project**, MIT-licensed (see project root LICENSE when added).

## Assets currently in the project

| Asset | Path | License | Source |
| --- | --- | --- | --- |
| Project icon | `icon.svg` | MIT (project-owned) | Hand-authored SVG, Hearthkeep team |
| All world geometry | procedural | n/a (runtime CSG / mesh primitives) | Godot stock |
| All character meshes | procedural | n/a (runtime `CapsuleMesh` + `BoxMesh`) | Godot stock |
| All particles | procedural | n/a (runtime `CPUParticles3D`) | Godot stock |
| All sound effects | procedural | n/a (runtime `AudioStreamWAV` synthesized from sine waves) | Hearthkeep team |
| All music layers | procedural | n/a (runtime layered tone generator) | Hearthkeep team |

**Zero third-party assets are currently in the repo.**  This is intentional — the project is in scaffolding and nothing imported has been audited yet.

## When real assets are imported

Every imported file gets a row in `art/ASSET_MANIFEST.csv` with:

- `filename` (path in repo)
- `source_url` (verifiable link to the source page)
- `license` (CC0 / CC-BY-4.0 / etc.)
- `author` (attribution name)
- `date_acquired` (ISO-8601)
- `modifications` (what was changed; `none` is fine)

Audio gets the same in `audio/AUDIO_MANIFEST.csv`.

## Approved sources (verified safe)

### 3D / props
- **Kenney.nl** — CC0
- **Quaternius** — CC0
- **Polyhaven** — CC0
- **ambientCG** — CC0
- **OpenGameArt** — filter strictly to CC0 or CC-BY
- **Sketchfab** — filter strictly to CC0 or CC-BY (verify per model)

### 2D / UI / icons
- **Kenney.nl** — CC0
- **OpenGameArt** — CC0 only
- **game-icons.net** — CC-BY 3.0 (attribute Lorc, Delapouite, et al.)

### Textures
- **Polyhaven** — CC0
- **ambientCG** — CC0
- **texturecan** — CC0

### Audio SFX
- **Sonniss GDC** packs — royalty-free for commercial use (per pack EULA)
- **Kenney audio** — CC0
- **OpenGameArt audio** — CC0/CC-BY only (avoid CC-BY-NC)
- **freesound.org** — filter strictly to CC0 (much of the site is CC-BY-NC)

### Music
- **Kevin MacLeod / incompetech.com** — CC-BY 4.0, attribute
- **Eric Matyas / soundimage.org** — CC-BY, attribute
- **OpenGameArt music** — CC0/CC-BY
- **PlayOnLoop** — verify per-track
- **YouTube Audio Library** — verify "no attribution required" per-track

### Fonts
- **Google Fonts** — Open Font License (SIL OFL)
- **font.bunny.net** — same OFL pool
- **Bungee** — OFL
- Avoid Microsoft system fonts in distribution.

## Trademark distance

**"Norrath"** is a Daybreak Game Co. trademark.  This project does **not** use it.  The repo directory is named `norrath-roguelike` only because that was the original brief filename — all in-project content uses HEARTHKEEP and the world name "the Sundered Realms".  Region names, deity names, dragon names, and the goblin king are all coined for this project.  See `docs/glossary.md` for the rename mapping.

## Questions

If anything in the repo's licensing is unclear, default to **remove and replace with a verified CC0 alternative**.  Do not ship under license ambiguity.
