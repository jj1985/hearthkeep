# HEARTHKEEP — Changelog

## v0.2.4 — All 7 crafting station UIs + HUD polish

### New UIs
- **Atelier wizard UI** — Form → Sigil → Ink → Inscribe (4 steps)
- **Loom wizard UI** — Piece → Fabric → Trim → Weave
- **Cooking wizard UI** — Dish → Staple → Spice → Cook
- **Engraving Bench UI** — special-shape picker that lists items from
  the Treasury (weapons / armor / trinkets), pick a script (Plain /
  Cinder / Frost / Aurate / Shadowline / Draconic), type an optional
  label, costs gold. Mutates the item in-place + bumps rarity.

### All 7 crafting stations now have full UIs
| Station | Output |
|---|---|
| Forge | weapons + armor (Form/Primary/Secondary/Embellishment/Engraving) |
| Alchemy | potions / oils / scrolls (Vessel/Reagent/Catalyst/Label) |
| Workbench | jewelry / charms / belts (Mount/Stone/Inscription) |
| Atelier | scrolls / runes / foci (Form/Sigil/Ink) |
| Loom | cloth armor / capes / banners (Piece/Fabric/Trim) |
| Cooking | food buffs (Dish/Staple/Spice) |
| Engraving | cosmetic engraving + stat tweak on existing items |

### HUD polish
- **Run timer** top-center (MM:SS or H:MM:SS for runs past an hour).
- **Floor banner** animated entrance: slides in from below with TRANS_BACK
  ease, holds 1.4 s, fades out 0.5 s. Shows "FLOOR N · region" matching
  the run-scene region cycle.

## v0.2.3 — All 7 crafting stations + Architect + Towns + audio

### New
- **Workbench** crafting station + wizard UI: 4 mounts × 5 stones × 5
  inscriptions for rings, amulets, charms, belts. (3rd station UI)
- **Atelier** data layer: 3 forms × 5 sigils × 3 inks for scrolls /
  runes / foci. Outputs items carrying matching BuffSystem buff_ids.
- **Loom** data layer: 5 pieces × 5 fabrics × 4 trims for cloth armor
  and capes. Trim adds stat + bumps rarity.
- **Cooking** data layer: 4 dishes × 3 staples × 4 spices for food
  buffs. Dish maps to BuffSystem buff_id for runtime application.
- **Engraving** data layer: takes existing items, adds engraving label
  + cosmetic stat tweak (cinder / frost / holy / shadow / draconic).
  Costs gold, refuses when broke. Bumps rarity 1 tier on tweak.
- **Architect** upgrade panel — full Villa building upgrade flow with
  current tier + next-tier cost + benefit blurbs for 7 buildings.
- **Town Visit** dialogue UI — tap-to-talk with the 3 seeded towns'
  named NPCs. Pulls rumors from RumorPool with per-role flavor-line
  fallbacks.
- **Trophy buffs apply** — TrophyManager.aggregate_buffs now actually
  routes into player stats / RunState on spawn (16 stat keys mapped,
  including set bonuses).

### Polish
- Settings sliders drive AudioServer bus volumes via linear_to_db
  conversion. Music / SFX / Ambient sliders now actually do something.

### Engineering
- 121 tests across 14 suites: 6 workbench + 11 remaining-stations added.
- Total of 102 completed iteration-tasks since the autonomous run began.

## v0.2.2 — Live HUD + Alchemy + bounties

### New
- **Alchemy** crafting station: 5 vessels × 6 reagents × 5 catalysts data
  layer with `craft(selections)` producing potions / elixirs / oils.
  Drake Blood bumps rarity 1 tier, Dragon's Tear bumps 2. 8 GUT tests
  covering data tables, lookup helpers, rarity bumps, oil-jar routing.
- **Bounty board** in Journal QUESTS tab. 4 dynamic bounties (goblin
  skirmishers, warchief, drakes, bandits). Tap ACCEPT to register +
  start, instantly available for kill-objective tracking.
- **HUD quest tracker chip** — top-center pinned-quest title + first
  incomplete objective ("Slay 4/15 goblins") updates live.
- **Talent tree tier headers** — "TIER 1 / 2 / 3" between node groups,
  computed via BFS depth from any root.
- **Bandit + Drake dye drops** — 8% / 25% chance respectively.

### Polish
- Camera shake stacks additively (cap 4.0) with a taper hold-then-decay
  envelope; previously every shake clamped via `max()` and cut off cold.
- Difficulty curve flatter past floor 10 (+0.15 per floor instead of
  +0.30) so endless runs stay playable.
- Stats panel grouped into PROGRESS / COMBAT / ECONOMY / CHARACTER
  sections with thousands-separator number formatting.
- Loot pillar lights only spawn for Epic+ drops (~50% allocation savings
  during boss death rains).
- Dragons grant +500/650/800 XP on kill (was 0).
- Snikkit's wager-the-run multiplier now actually survives `start_run`.

### Engineering
- 104 GUT tests across 12 suites (added test_alchemy + test_save_roundtrip).
- `make lint` runs `godot --import` to surface parse errors.
- Save round-trip persistence now covers krrik_defeated +
  lifetime_kills_by_type.

## v0.2.1 — Content polish + content additions

Continuing the autonomous iteration loop after v0.2.0.

### New content
- **Krrik III** warband-king encounter on floor 7 (one-shot per save):
  600 HP × scaling, 28 dmg, summons goblin reinforcements at 66% / 33%
  HP thresholds, 7-meter roar AOE on cooldown, awards warchief_crown
  trophy + 5 Epic-or-Legendary loot rain on death
- **Drake** elite mid-boss on floors 3 + 4 (the two leading into a
  dragon): 200 HP × scaling, 22 dmg, hover-dive-recover state machine,
  guaranteed Epic drop on death
- **Bandit** mid-floor enemy with 20% parry chance: spawns on floor 2+
  at ~10% wave-roll chance, 36 HP / 9 dmg, faster than goblin Skirmisher

### Combat
- Real class skills on Q/E/R/F (replaces the haste/might placeholders):
  fireball / cleave / backstab / smite / volley / etc. — each with
  cooldown, mana cost, AOE radius, damage multiplier, element tag
- Skill cooldown timer overlay on each cluster button (0.5s+ shows
  remaining seconds)
- Class-specific skill glyphs on cluster buttons (⚔ ✦ ⛨ ❗ for warrior,
  🔥 ❄ ⚡ ○ for wizard, etc.)
- 3 keystone effects wired: Berserker (low-HP atk speed + crit),
  Death Knight (kill-heal), Execute: Ender (one-shot non-elites
  below 35% HP)
- Damage-scaled hit-stop polish; lifesteal proc shows verdant heal floater
- Goblin AI variant kit: shaman heals/rallies on cooldown, sapper
  visible-fuse telegraph, warchief calls reinforcements at <50% HP

### UI
- Bond stone HUD button (hold-to-channel teleport home, in-combat blocked)
- Dye Workbench in Villa: 25-color palette, 7 armor slots, save dye sets,
  pot-consumption + preview-only paths
- Journal STATS tab: 4 sections (PROGRESS / COMBAT / ECONOMY / CHARACTER)
  + KILLS BY TYPE breakdown, thousands-separator number formatting
- Mobile-friendly Journal button on HUD top-right
- Skill cooldown labels on HUD skill cluster buttons
- Title screen: ember-rain particles + dragon-shadow sweep on a 12s loop

### World
- Floor environment variation: 5 region palettes cycling (Coastreach /
  Ruinmarch / Thalanore Canopy / Graymarrow Hold / Ashfen Caldera) —
  sun + ambient + fog + torch colors swap per (floor_index % 5)
- EventDirector events firing real in-run impact: goblin raid (6
  extra spawns), wandering merchant (3 free items), caravan ambush
  (3 bandits), carnival (mystery item), dragon flyover (atmospheric)
- Day/night sky tint pass: phase-driven sky_top + sky_horizon + fog
  color, weather modifiers (Rain/Storm/Fog/Ashfall) layered

### Meta-progression
- Dragon kills unlock classes: Vyxhasis → Paladin, Ourzhal → Ranger
- All three dragons defeated → triple_class meta_unlock flips on
- Class select greys out locked classes with 🔒 prefix

### Economy
- Whetstones / oils now apply weapon buffs at point-of-sale via
  Bren's Counter (5 weapon-buff types: flame / frost / lightning /
  poison / holy)
- Snikkit's Wager-the-Run multiplier survives start_run (was bug:
  start_run reset it to 1.0 the moment you played)
- Auto-route junk pickups to Treasury junk chest
- Run-start floater "WAGER ACTIVE ×N.NN" when active

### Quests
- Kill objectives match all goblin variants (was matching only
  Skirmishers because target_id "goblin" didn't match "goblin_sapper"
  etc.)
- Quest-complete fanfare: gold floater + 4-note arpeggio shimmer SFX
- Dragons fire EventBus.boss_defeated → TrophyManager awards trophy +
  unlocks classes + grants 500-800 XP

### Engineering
- 95 GUT tests across 11 suites (added test_content + test_save_roundtrip,
  17 new tests)
- Save round-trip integration covers krrik_defeated + lifetime_kills_by_type
- `make lint` runs `godot --import` to surface parse errors / warnings
- README refreshed for v0.2.0 inventory + install link
- versionCode auto-bumps (now at 67); APK filename version-derived
  from export_presets.cfg

## v0.2.0 — Pillars complete (autonomous iteration milestone)

A single autonomous build pass landed every queued post-demo pillar.
**versionCode 47, versionName 0.2.0.**

### Combat / dragons
- Three named dragon bosses with full 3-phase state machines:
  - **Vyxhasis** (fire) — breath / dive / rupture, ember-glow phase ramp
  - **Ourzhal** (storm) — chain bolt / thunder-step / storm field, rune-blue → white-blue
  - **Aethyrnax** (frost) — ice shards / frost nova (with player slow proxy) / glacial breath, glacial blue
- Procedural arena (CSGCylinder + 4 brazier OmniLights + dusk WorldEnv), palette swaps per dragon
- Boss HP banner: name + wide bar + 3 phase-indicator chips, heartbeat-pulse near transitions
- Boss death: trophy award via `EventBus.boss_defeated` → TrophyManager (Vyxhasis Horn / Ourzhal Scale / Aethyrnax Fang), 8-10 legendary loot rain, +500-800 gold, +10-15 dragon shards
- Dragon cycle: every 5th floor switches to the next not-yet-defeated dragon
- Goblin AI variant kit:
  - Shaman: rallies allies + heals self/allies (+12 HP) on 4s cooldown
  - Sapper: 1.0s visible orange-blink fuse before detonation
  - Warchief: at <50% HP, calls in 3 reinforcements (one-shot)
- Damage-scaled hit-stop + screen shake (crit 80ms, normal 20-50ms by mag, warchief death 180ms)
- Lifesteal proc shows verdant `+N` floater on player

### UI overhaul (full design-spec implementation)
- `OrientationMgr` rewritten around Material 3 width window-size classes (Compact/Medium/Expanded), exposes per-bucket scalars (font_scale, padding_scale, primary_btn_min_h_dp, combat_skill_btn_dp, perk_cards_per_row, class_grid_cols)
- `SafeAreaMargin` (Android 14+ edge-to-edge, gesture-nav insets)
- `UiTokens` — Sundered Realms palette: gold #D4A24C / ember #D4582C / rune-blue #5A8FB3 + 7 rarity tiers + 8dp grid + radii
- `UiStyle` programmatic StyleBox builders + `UiAnim` motion tokens
- Cinzel + Inter OFL fonts vendored (`art/fonts/`)
- Title screen: 3-state machine (splash → tap-to-begin → menu), parallax-ready ember rain particles, dragon-shadow sweep on a 12s loop
- Class select: paginated single-column list with sticky 240×240 procedural class portraits, PRIMARY/SECONDARY tabs, dynamic "BEGIN AS X/Y" CTA, hybrid-prestige callout
- Perk picker: 2×2 GridContainer (compact) / 1×4 (expanded), 312×200 cards with rarity stripe, ⚜ evolution glyph, card-in stagger animation, take-confirm fade
- Combat HUD: diamond skill cluster (88dp primary + 4×72dp secondaries), virtual stick (144dp gold-ringed), HP/MP/dodge/journal/bond/pause buttons, live radial minimap with enemy/boss/loot dots
- Chest view: bucket-driven 5/7/10-col grid, filter chip rail, search, rarity bottom-stripe cells
- Forge wizard: 6-step flow (Form → Primary → Secondary → Embellishment → Engraving → Forge!) on the data layer
- Talent tree allocator (per-class, prereq-aware, point-spending)
- Pause menu modal with Resume/Villa/Abandon/Quit
- "YOU FELL" game-over overlay with run summary stats
- Loading screen with rotating lore + class tips (60/25/15 mix per spec)
- First-run tutorial overlay with 4-corner control callouts
- Settings screen: audio sliders + orientation lock + control scheme + accessibility toggles
- Snikkit's gambling den: Mystery Item / Double-or-Nothing / Wager-the-Run
- General Merchant (Bren's Counter): Buy / Sell / Buyback tabs
- World map / wayspire UI with Bond Stone bind + dev unlock-all bribe
- Trophy Hall display picker per pedestal with set-progress + active-buff cap
- Journal: 4 tabs (QUESTS / CODEX / REALM / STATS) with active-quest progress, 35 lore entries by category, 3-town summaries with ruler + mood, lifetime stats panel
- Bond stone HUD button: hold-to-channel teleport home, in-combat blocked, 3-min cooldown
- Floating-text renderer: pooled labels with crit/heal/error variants, magnitude-scaled font sizes
- Iconified buff row: 32dp colored pills (fire→ember, frost→rune-blue, etc.) with ⚜ evolution markers

### World
- AI towns Phase A: 3 seeded towns (Coastreach, Black Bastion, Canopyhall), 5 named NPCs each with role + blurb, ruler + faction lean + mood bucket
- Day/night sky tint pass: phase-driven sky_top + sky_horizon + fog color, weather modifiers (Rain/Storm/Fog/Ashfall) layered on top
- Auto-route junk pickups to Treasury junk chest (when Settings.auto_pickup_junk on)

### Crafting / economy
- Forge data layer: 5 forms × 6 primary mats × 5 secondary × 5 embellishments × 5 quality tiers; `craft(selections)` produces full item dict; skill-driven quality distribution; embellishments inject affixes + bump rarity one tier
- 13 forge unit tests including statistical proof that high-skill crafting averages higher quality

### Audio
- Expanded SFX catalog (`audio_bus.gd`): perc/shimmer/growl/swoosh wavetable kit with proper ADSR envelopes
- 18 procedural SFX: hit, hit_heavy, crit, dodge, parry, footstep, pickup, potion, levelup, perk_pick, chest_open, forge_strike, low_hp (heartbeat), quest_complete, error, dragon_roar, dragon_phase_air, dragon_phase_enraged

### Engineering
- 78 GUT tests across 9 suites, 195+ asserts, all green
- Pre-commit hook (`tools/install_hooks.sh`) blocks commits on test failure
- Asset audit (`tools/asset_audit.py`) — license-whitelist enforcement; current state: 2 fonts tracked OK
- Balance simulator (`tests/balance_sim.gd` via `make balance-sim`) — 100-run procedural sweep with deterministic seed; CSV output. Latest sweep: legendary rate 1.60% (target band 1-3%), no perk dominating
- Auto-bumping versionCode on every `make apk` (`tools/bump_version.py`)
- Memory rules:  feedback_apk_release_workflow.md (always push APK), feedback_autonomous_operation.md (don't pause to summarize)

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
