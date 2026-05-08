# HEARTHKEEP — Changelog

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
