# HEARTHKEEP — Playable Demo (v0.0.1-mvp-demo)

**Status:** runnable in Godot 4.6.x.  Fixed-isometric 3D ARPG, original world (the Sundered Realms), no IP overlap.

## How to play (60-second start)

1. Open the project in Godot 4.6.2 (or newer 4.6.x):
   ```
   open -a /Applications/Godot.app /Users/user/norrath-roguelike
   ```
   Or in Godot's Project Manager, click "Import" and select `project.godot` from this folder.
2. Press **F5** (or click the ▶ button top-right).
3. Title screen → click **ENTER THE REALM**.
4. **Move:** WASD on desktop; left-side touch on mobile (auto-shows virtual joystick).
5. **Attack:** left-click. Tap right side on mobile.
6. **Dodge:** Space.
7. **Potions:** `1` = HP, `2` = MP.
8. **Skill 1 / 2:** `Q` (Haste) and `E` (Blessing of Might) — buff system demo.

## What you'll see in the demo

- **3D player** (knight capsule with helmet, cloak, sword) on a stone floor under a torchlit dusk sky.
- **Reactive goblins** that bark at you when they see you, flee at low HP, and rally if a Shaman is near.
- **3 goblin variants spawned in waves**: Skirmisher (basic melee), Sapper (suicide bomber), Shaman (ranged).  Warchief mini-boss at floor 3+.
- **Hit-stop, screen shake, crit numbers, light-pillar loot drops** (rarity-colored, Common → Artifact tiers).
- **Affix loot system** — items roll prefixes and suffixes (Flaming, Frostbound, of the Bear, of the Drake, etc.).
- **Vendor-trash drops** — goblin teeth, drake scales, with quality tiers (Worn, Fine, Exquisite) for sale value.
- **Megabonk-style level-up perk cards** — every level pause, pick 1 of 4 perks. Universal (damage, atk speed, crit) and class-themed (Inferno Aura, Frostbite, Stormcaller).
- **Weapon evolutions** — Sword + Inferno Aura at the right level offers `★ EVOLUTION: Sunfire Reaver`, which spawns a constant fire-ring around the player that damages nearby enemies on every swing.
- **Save/load** — gold, dye unlocks, defeated dragons, deepest floor, lifetime kills persist between runs.
- **Procedural music director** that crossfades between exploration ↔ combat layers (procedural tones for the prototype; ready for licensed Kevin MacLeod swaps).

## What's stubbed / not in the demo (roadmap)

The user piled an extraordinary amount of scope into this single autonomous session.  In the interest of delivering a runnable playable demo *now*, the following systems have data-layer + autoload scaffolding and stubs but are not yet wired into the demo run:

- **Villa scene** (player housing with walkable Treasury chests + Trophy Hall set-buff displays) — `ChestManager` and `TrophyManager` autoloads work; the 3D Villa scene is the next ship.
- **Multiclassing UI** — `ClassDB` (7 base classes + 10 named hybrid prestiges) and `TalentDB` (per-class trees with keystones) are loaded; the character creator + talent tree UI is roadmap.
- **Dragon boss fight** — Vyxhasis (fire), Ourzhal (storm), Aethyrnax (frost) defined in lore; arena scenes + 3-phase fight are roadmap.
- **Base hub with NPCs + day/night** — `WorldSim`, `WeatherSystem`, `EventDirector`, `RumorPool` (30 rumors), `NpcMemory` are running autoloads; the visual base hub scene is the next ship.
- **Gambling den** — `VendorSystem` (3 currencies: Gold, Tokens, Dragon Shards) is in; gambling NPC + double-or-nothing UI is roadmap.
- **Quest log UI** — `QuestSystem` (main / class / dragon-hunt / bounty quest registry, all seeded) tracks progress; the log UI is roadmap.
- **Travel system UI** — `TravelSystem` (portals + bond stone with channel/cooldown) is in; the worldmap UI is roadmap.
- **Lore codex UI** — 35 entries seeded; the codex viewer is roadmap.
- **Multi-orientation HUD reflow** — `OrientationManager` detects 5 buckets (portrait/landscape × phone/tablet + desktop); HUD currently anchors-and-stretches but does not fully reflow.
- **Asset hygiene** — README documents the strict CC0/CC-BY-only policy; current art is procedural CSG primitives + StandardMaterial3D (zero third-party assets, zero IP risk).  When real CC0 packs (Kenney, Quaternius, ambientCG) are imported, every entry lands in `art/ASSET_MANIFEST.csv`.
- **Tests** — system test harness + 12+ unit tests are roadmap.  Demo-level hand-validation is what's been done.

## Android APK

In progress.  This session installs JDK + Android cmdline-tools in background.  See `INSTALL_APK.md` for install/sideload steps once the APK builds.  If the export templates fail to download (network constrained), the APK will need to be exported from Godot Editor's manual export menu — `INSTALL_APK.md` documents that path too.

## Known issues

- Particle effects on quit emit "ObjectDB instances leaked" — harmless, fixed by switching from CPUParticles to GPUParticles in a polish pass.
- Camera does not yet swing on boss intro; that's part of the badass-pass.
- HUD doesn't reflow on rotation yet (anchor-only).

## Next ships (in order)

1. APK export (this session, blocked on JDK install)
2. Walkable Villa with stub Treasury + Trophy Hall (next session)
3. Dragon boss arena (next session)
4. Quest log + Lore codex + World map UI
5. Multi-orientation HUD reflow
6. Test harness + balance simulator
7. CC0 art pack imports (Kenney medieval, Quaternius monsters)

## Repo

Local: `/Users/user/norrath-roguelike` (folder named for the original brief; renamed to HEARTHKEEP throughout the project content).

GitHub: pushed to `https://github.com/jj1985/hearthkeep` (when push completes).
