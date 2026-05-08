# HEARTHKEEP — Changelog

## v0.1.0 — Multiclass core + test harness (in progress)

### Added
- **Character creator scene** (`scenes/ui/class_select.tscn`) — primary class + optional secondary; live blurb, hybrid-prestige preview when a recognized pair is selected
- `RunState.class_primary` / `class_secondary` persist selection across title→run; `set_classes()` validates against `Classes.CLASSES`; `hybrid_prestige()` resolves the named hybrid
- `Classes.combined_stat_profile()` and `Classes.combined_resources()` — 60/40 weighted blend toward primary; rounded integer stat profile
- `Classes.has_tag()` — synergy gate for skill triggers
- Player `_apply_class_base()` now consumes the multiclass-aware combined profile + resources
- Hybrid-prestige floater on run start when a named hybrid is active (e.g. "✦ Death Knight ✦")

### Engineering
- **GUT 9.6.0** vendored at `addons/gut/`; Makefile `test` target wired (`make test`)
- 28 tests across 4 suites: smoke (autoloads + ClassDB shape), class_db (multiclass math), class_selection_flow (RunState contract), scene_loading (every load-bearing scene parses + instantiates clean)
- Renamed autoload `ClassDB` → `Classes` to avoid shadowing Godot's built-in `ClassDB` global

### Fixed
- **Critical:** `ChestManager` and `TrophyManager` were referenced by `run/main.gd`, `villa/villa_main.gd`, `ui/chest_view.gd` but missing from `[autoload]` in `project.godot` — would crash on player death and on Villa entry. Both registered.
- Type-inference warnings in `run/main.gd` and `villa/villa_main.gd` (Variant inference on `move_dir.normalized()` and `clamp` result) — now explicitly typed
- Android export was failing with a generic "configuration errors" message; root cause was the missing `rendering/textures/vram_compression/import_etc2_astc=true` flag in `project.godot`. Added.

### Pipeline
- **First Android APK shipped:** `build/HearthkeepDemo-v0.0.1.apk` (28MB, signed with debug keystore, arm64-v8a, mobile renderer, `com.hearthkeep.demo`). Sideloadable via `adb install -r`.

## v0.0.1 — Playable Demo (in progress)

### Added
- 3D ARPG combat scene with isometric camera, player character, reactive goblins, loot drops, hit-stop, screen shake, crit numbers, and rarity-colored light pillars
- Title screen
- Save/load (`SaveSystem`)
- Run state with Megabonk-style level-up perk-card overlay
- Weapon evolution system (e.g. Sword + Inferno Aura → Sunfire Reaver fire-ring)
- Affix loot system with prefixes/suffixes and rarity tiers (Common → Artifact)
- Vendor-trash drops with quality tiers (Worn / Fine / Exquisite)
- Self-buff system with exclusive groups and source priority
- Per-class definitions (7 classes) and named hybrid prestiges (10)
- Per-class talent grids with keystone nodes
- 3-currency vendor economy (Gold / Faction Tokens / Dragon Shards)
- Quest registry (main / class / dragon-hunt / bounty) with seeded content
- Travel system (portals + bond stone with channel + cooldown)
- Lore codex with 35 seeded entries
- World simulation (day/night clock, weather, dynamic events, NPC schedules)
- Faction state (rep / power / tokens for 5 factions)
- 30-entry tavern rumor pool
- Trophy Hall manager (display slots + active-buff cap + 4 named sets)
- Treasury chest manager (9 typed chests with sort/filter/search)
- Music director with crossfading exploration / combat / boss layers
- Multi-orientation manager (5 buckets)
- Asset hygiene scaffolding: `LICENSES.md`, `ASSET_MANIFEST.csv`, `AUDIO_MANIFEST.csv`, `art/CREDITS.md`, `docs/asset_policy.md`, `docs/glossary.md`

### Branding
- Renamed working title to **HEARTHKEEP**
- World renamed from "Norrath" (Daybreak Game Co. trademark) to "the Sundered Realms"
- Regions renamed: Coastreach, Black Bastion, Canopyhall, Kaeldur, Cinderwastes, Veiled Plane, Ruinmarch
- Dragons coined: Vyxhasis, Ourzhal, Aethyrnax
- Goblin king coined: Krrik III

### Pipeline
- `Makefile` with `run`, `test`, `apk`, `apk-clean`, `assets-audit`, `balance-sim` targets
- `export_presets.cfg` for Android (arm64-v8a, mobile renderer, debug-signed for sideload)
- `INSTALL_APK.md` with full setup + sideload instructions
- `DEMO_READY.md` with how to play + roadmap

### Known gaps (deferred to follow-up sessions)
- Walkable Villa scene (Treasury + Trophy Hall) — autoloads in place, scene roadmap
- Dragon boss arena scenes
- Quest log UI / Lore codex UI / World map UI
- Multi-orientation HUD reflow (currently anchor-only)
- Test harness (manual hand-validation only)
- Real CC0 art imports (currently 100% procedural geometry)
- Android APK build (pipeline configured; depends on JDK + Android SDK + Godot export-templates download)
