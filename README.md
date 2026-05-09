# HEARTHKEEP

> *of the Sundered Realms*

A 3D mobile ARPG roguelike with deep multiclassing, dragons, goblin warbands, in-world gambling, a player villa with treasury and trophy hall, full crafting, and Megabonk-style perk-card escalation.

**Engine:** Godot 4.6.x.  **Target:** Android (mobile renderer, portrait-default), with Forward+ on desktop for iteration.  **Status:** v0.2.5 — see [CHANGELOG.md](CHANGELOG.md) and the [GitHub release](https://github.com/jj1985/hearthkeep/releases/tag/v0.2.5).

---

## Install (sideload to Android)

```bash
# 1. Download HearthkeepDemo-v0.2.5.apk from
#    https://github.com/jj1985/hearthkeep/releases/tag/v0.2.5
# 2. With your phone plugged in via USB and dev mode + USB debugging on:
adb install -r HearthkeepDemo-v0.2.5.apk
```

Or run on desktop: `make run`.

## What's playable in v0.2.5

### Combat
- 3D isometric ARPG combat with virtual stick + diamond skill cluster
- 7 base classes × 7 secondary class combos = 10 named hybrid prestiges (Death Knight, Trickster, Spellbow, Templar, Warden, Bonechanter, Berserker, Shadow Blade, Warpriest, Plaguelord) with active gameplay perks
- **Triple-class meta-unlock** after defeating all 3 dragons: pick a third class for a 50/30/20 stat blend, perk pool draws from all 3, skill bar slot 2/3 binds to secondary[0] / tertiary[0], and every pairwise hybrid prestige fires
- Real class skills on Q/E/R/F (fireball / cleave / backstab / smite / volley / etc.) with cooldowns, mana costs, AOE effects
- Damage-scaled hit-stop + screen shake, lifesteal floaters, low-HP heartbeat warning
- Reactive goblins (Skirmisher / Sapper-with-fuse-telegraph / Shaman-with-heals / Warchief-calls-reinforcements), Bandits with parry chance, Drake elites
- **Krrik III** warband king at floor 7 (one-shot per save, summons goblin reinforcements at HP thresholds)
- **3 dragon arenas** at every 5th floor: Vyxhasis (fire) → Ourzhal (storm) → Aethyrnax (frost), each with 3-phase state machine, telegraphed dives, ceremonial loot rain on death

### UI & feel
- Material 3 width buckets (Compact / Medium / Expanded) drive font/padding/touch-target scalars
- Sundered Realms palette (gold + ember + rune-blue)
- Cinzel + Inter OFL fonts
- Title screen with splash → tap-to-begin → menu state machine, ember rain particles, dragon-shadow sweep on a 12s loop
- Class select with sticky procedural portrait + paginated list + hybrid-prestige callout
- Perk picker as a 2×2 bottom-docked grid with rarity stripes + ⚜ evolution glyphs
- Combat HUD: HP/MP/XP bars, live radial minimap with enemy/boss/loot dots, diamond skill cluster, virtual stick, potions, dodge, journal, bond stone, pause
- Pooled floating-text renderer with crit/heal/error variants and magnitude-scaled font sizes
- Iconified buff row (32dp colored pills, ⚜ evolution markers)
- Day/night sky tint + weather-modulated fog density

### Villa (player home)
- 6 reachable buildings via proximity prompts: Forge, Wizard's Study, Bren's Counter (merchant), Snikkit's Den (gambling), War Room (journal), Wayspire (world map)
- Treasury chests (9 typed) with bucket-driven grid + filter chips + search
- Trophy Hall pedestals + display picker with set progress + active-buff cap

### Crafting
- 6-step Forge wizard: Form → Primary Material → Secondary Material → Embellishment → Engraving → Forge!
- 5 forms × 6 primary mats × 5 secondary × 5 embellishments × 5 quality tiers
- Skill-driven quality distribution; embellishments inject affixes + bump rarity

### Economy
- Snikkit's Den: Mystery Item (rarity-biased by stake), Double-or-Nothing, Wager-the-Run
- General Merchant (Bren's Counter): Buy / Sell / Buyback queue
- Whetstones / oils apply weapon buffs at point-of-sale
- Auto-route junk to Treasury junk chest, sell-all-junk button

### World
- 3 seeded AI towns (Coastreach, Black Bastion, Canopyhall) with 5 named NPCs each, ruler + faction lean + mood
- Wayspire portal network with bond-stone rebinding + 6s channel-teleport home
- 5 dynamic world events firing on a 90s tick: goblin raid, wandering merchant (free items), caravan ambush, carnival, dragon flyover

### Journal
- 4 tabs: QUESTS (active + completed objectives), CODEX (35 lore entries by category), REALM (towns), STATS (lifetime numbers)
- Quest objective tracking via EventBus.entity_killed; quest-complete fanfare + reward gold/shards/tokens

### Talents
- Per-class talent trees with prereq-aware allocator; talent points granted on level-up; allocated stats apply on player spawn
- Hybrid prestige perks active in combat (Berserker low-HP burst, Death Knight kill-heal)
- Warrior keystone "Execute: Ender" one-shots non-elites below 35% HP

## Project structure

```
project.godot          # ~30 autoloads wired up before any scene
scenes/
  title.tscn           # main menu (splash → title → menu)
  run.tscn             # playable run scene (3D world + HUD + perk overlay)
  player/player.tscn   # 3D player CharacterBody3D
  enemies/             # goblin, bandit, drake, krrik
  fx/loot_drop.tscn    # 3D loot drop with light pillar
  boss/                # vyxhasis_arena.tscn (procedural, palette-swapped per dragon)
  villa/villa.tscn     # 3D villa scene
  crafting/forge_ui.tscn
  ui/                  # title, class_select, perk_picker, hud, journal,
                       #  pause_menu, game_over, settings, world_map, merchant,
                       #  snikkit_den, trophy_picker, talent_tree, ...
scripts/
  classes/class_db.gd  # 7 classes, 10 hybrid prestiges, multiclass blend math
  ...                  # see CHANGELOG.md for full system map
docs/
  ui_spec.md           # authoritative Hearthkeep UI spec (Material 3 + ARPG mobile)
  villa_design.md
  crafting_design.md
  towns_design.md
  asset_policy.md
  glossary.md
art/
  fonts/               # Cinzel, Inter — both OFL
  ASSET_MANIFEST.csv
audio/
  AUDIO_MANIFEST.csv
build/                 # APK output (gitignored)
tests/                 # 78 GUT tests across 9 suites
addons/gut/            # GUT 9.6.0 vendored
tools/
  bump_version.py      # auto-bump versionCode on each make apk
  asset_audit.py       # license-whitelist enforcement
  install_hooks.sh     # pre-commit hook installer
```

## Dev setup

```bash
make run            # open Godot with this project
make test           # run 78 GUT tests headless
make lint           # godot --import; surfaces parse / warning errors
make apk            # auto-bump versionCode + build Android debug APK
make assets-audit   # check ASSET_MANIFEST.csv / AUDIO_MANIFEST.csv
make balance-sim    # 100-run procedural-integrity sweep (loot + perks)
make install-hooks  # one-shot install of pre-commit test runner
```

## License compliance

Every shipped asset must be CC0, CC-BY (with attribution), CC-BY-SA, OFL, MIT, or original to this project.

- Current state: all visible art is procedural (CSG meshes, StandardMaterial3D, CPUParticles). Cinzel + Inter fonts are OFL-1.1, vendored at `art/fonts/` with their license texts. Zero IP risk.
- The world (Sundered Realms), pantheon (Thaen / Ysmir / Velis / Morrun / Torath / Sennari), regions (Coastreach / Black Bastion / Canopyhall / Kaeldur / Cinderwastes / Veiled Plane / Ruinmarch), dragons (Vyxhasis / Ourzhal / Aethyrnax), and goblin king Krrik III are **invented for this project**.
- "Norrath" is a Daybreak Game Co. trademark and is not used. The repo directory is named `norrath-roguelike` for legacy reasons; the project content uses HEARTHKEEP throughout.
- Approved sources for future assets: Kenney.nl (CC0), Quaternius (CC0), Polyhaven (CC0), ambientCG (CC0), OpenGameArt (CC0/CC-BY filter), Sonniss GDC packs (royalty-free), Kevin MacLeod incompetech (CC-BY), Eric Matyas soundimage (CC-BY), Game-icons.net (CC-BY 3.0), Google Fonts (OFL).

## Game-feel manifesto

- Every kill produces a particle burst, a chunky hit, and a satisfying floater
- Every level-up pauses the world and offers a meaningful choice
- Every legendary drop is its own small ceremony — light pillar, hit-stop, chunky chime
- Every menu has a tween, every empty state has personality, every cooldown has visible progress
- The first 30 seconds of the game must hook the player

## Monetization stance

Cosmetics + expansions + supporter pass.  **Never** energy/timers/paywalls.  No paid loot boxes.  All in-game gambling uses in-game currency.

## Releases

Tagged milestones land on GitHub Releases with a sideloadable APK.

- [v0.2.0 — Autonomous iteration milestone](https://github.com/jj1985/hearthkeep/releases/tag/v0.2.5) (current)
- [v0.1.0-multiclass — first sideloadable APK](https://github.com/jj1985/hearthkeep/releases/tag/v0.1.0-multiclass)

---

**Original world.  Original lore.  HEARTHKEEP is not affiliated with any existing fantasy IP.**
