# HEARTHKEEP

> *of the Sundered Realms*

A 3D ARPG roguelike with deep multiclassing, a player-built villa with a Trophy Hall and Treasury, dragons, goblin warbands, in-world gambling, armor dyes, and Megabonk-style level-up perk cards.

**Engine:** Godot 4.6.x.  **Target:** Android (mobile renderer), with Forward+ on desktop for iteration.  **Status:** v0.0.1 playable demo — see `DEMO_READY.md`.

---

## Run the demo

```
open -a /Applications/Godot.app /Users/user/norrath-roguelike
# then F5 in the editor
```

Or sideload the Android APK to your phone — see `INSTALL_APK.md`.

## What's playable today

- 3D isometric ARPG combat against reactive goblins (skirmisher / sapper / shaman / warchief)
- Hit-stop, screen-shake-on-crit, light-pillar loot drops with rarity tiers (Common → Artifact)
- Megabonk-style perk cards on level-up; weapon-evolution offers when prerequisites met (e.g. Sword + Inferno Aura → **Sunfire Reaver** with constant fire-ring)
- Affix loot (`Flaming`, `Frostbound`, `of the Bear`, etc.) with vendor-trash quality tiers
- Self-buff system (Haste, Stoneskin, Blessing of Might, Bardic Inspiration) with exclusive groups + source priority
- Save/load (gold, dye palette unlocks, defeated dragons, deepest floor)
- Procedural music director with combat / exploration crossfade layers (procedural tones in prototype; designed for licensed Kevin MacLeod swaps)

See `DEMO_READY.md` for the full demo walkthrough and the roadmap for everything that's stubbed.

## Project structure

```
project.godot          # autoloads: ~25 systems wired up before the run scene
scenes/
  title.tscn           # main menu
  run.tscn             # playable run scene (3D world + HUD + perk overlay)
  player/player.tscn   # 3D player CharacterBody3D
  enemies/goblin.tscn  # 3D goblin CharacterBody3D
  fx/loot_drop.tscn    # 3D loot drop with light pillar
  ui/                  # HUD + perk picker overlays
scripts/
  game_state.gd        # persistent meta state (gold, dyes, buildings, dragons defeated)
  run/run_state.gd     # per-run mutable state (XP, perks, evolutions)
  loot/loot_system.gd  # rarity rolls + affix tables
  dyes/dye_system.gd   # 25-color palette, tintable masks, saved dye sets
  perks/perk_pool.gd   # universal + class perks + weapon evolutions
  classes/class_db.gd  # 7 classes + 10 named hybrid prestiges
  talents/talent_db.gd # per-class talent grids with keystones
  buffs/buff_system.gd # self + weapon buffs, exclusive groups, source priority
  economy/vendor_system.gd  # 3-currency, vendor trash, sell-all-junk, buyback
  quests/quest_system.gd    # main / class / dragon-hunt / bounty quest registry
  travel/travel_system.gd   # portals + bond stone (channel + cooldown)
  lore/lore_codex.gd        # 35 seeded lore entries
  world/world_sim.gd        # day/night phase clock
  world/weather_system.gd   # 5 weather types with gameplay effects
  world/event_director.gd   # 5 dynamic world events
  factions/faction_state.gd # rep / power / tokens for 5 factions
  npc/rumor_pool.gd         # 30-entry tavern rumor pool
  hall/trophy_manager.gd    # display slot manager + active-buff cap
  hall/trophy_db.gd         # trophies + named sets (Goblin Slayer's Hall, Dragonsworn Sanctum, Diplomat's Keep, Sage's Archive)
  storage/chest_manager.gd  # Treasury 9 typed chests with sort/filter/search
  storage/loadout.gd        # saved equipment loadouts
  audio/music_director.gd   # dynamic crossfade layers
  ui/orientation_manager.gd # 5 layout buckets (phone/tablet × portrait/landscape, desktop)
docs/                  # design docs (per-feature)
data/                  # data resources (when added)
art/                   # placeholder art + ASSET_MANIFEST.csv when CC0 imports land
audio/                 # placeholder audio + AUDIO_MANIFEST.csv when CC0 imports land
build/                 # APK output (gitignored)
tests/                 # test harness (roadmap)
```

## Engine choice — Godot 4

- Open-source, free, no licensing surprises.
- Excellent Android export with separate Mobile / Forward+ renderer profiles.
- Lightweight binary, fast iteration, scriptable from CLI (`godot --headless --quit`, `--export-debug`).
- GDScript fast to write; C# available for hot paths.
- Cross-platform (iOS / desktop / web) — futureproofs the project.
- Strong tooling for tilemaps, particles (GPUParticles3D), shaders.

## License compliance

The release-blocker rule: **every shipped asset must be CC0, CC-BY (with attribution), original to this project, or license-purchased.**

- Current state: every visible asset is procedural — `CSGShape`, `BoxMesh`, `CapsuleMesh`, `SphereMesh`, `CylinderMesh`, plus runtime `StandardMaterial3D` and `CPUParticles3D`.  Zero third-party assets, zero IP risk.
- The world (the Sundered Realms), pantheon (Thaen, Ysmir, Velis, Morrun, Torath, Sennari), regions (the Coastreach, the Black Bastion, Canopyhall, Kaeldur, the Cinderwastes, the Veiled Plane, the Ruinmarch), dragons (Vyxhasis, Ourzhal, Aethyrnax), and goblin king Krrik III are all **invented for this project**.
- "Norrath" is a Daybreak Game Co. trademark and is not used.  The repo directory is named `norrath-roguelike` for legacy reasons (the original brief filename); the project content uses HEARTHKEEP throughout.
- When real assets land, every row goes in `art/ASSET_MANIFEST.csv` and `audio/AUDIO_MANIFEST.csv` with: filename, source URL, license, author, date acquired, modifications.  See `docs/asset_policy.md`.
- Approved sources: **Kenney.nl** (CC0), **Quaternius** (CC0), **Polyhaven** (CC0), **ambientCG** (CC0), **OpenGameArt** filtered to CC0/CC-BY, **Sketchfab** filtered to CC0/CC-BY, **Sonniss GDC** packs (royalty-free), **Kevin MacLeod** music (CC-BY 4.0, attribute), **Eric Matyas / soundimage.org** (CC-BY).

## Game-feel manifesto

- Every kill produces a particle burst, a chunky hit, and a satisfying floater.
- Every level-up pauses the world and offers a meaningful choice.
- Every legendary drop is its own small ceremony — light pillar, hit-stop, chunky chime.
- Every menu has a tween.  Every empty state has personality.  Every cooldown has visible progress.
- The first 30 seconds of the game must hook the player.

## Monetization stance

Cosmetics + expansions + supporter pass.  **Never** energy/timers/paywalls.  No paid loot boxes.  All in-game gambling uses in-game currency.

## Contributing / dev setup

```
make run     # open Godot with this project
make test    # run test harness (roadmap)
make apk     # build Android debug APK to build/
```

## Credits

See `art/CREDITS.md` (filled when real assets land) and the in-game Credits screen.

---

**Original world.  Original lore.  HEARTHKEEP is not affiliated with any existing fantasy IP.**
