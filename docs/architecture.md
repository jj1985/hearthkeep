# HEARTHKEEP — System architecture map

Quick orientation for "where is X handled?" — written for future sessions
that need to find a system fast.

## 37 autoloads

Listed in dependency order (later autoloads can read earlier ones at `_ready` time).

### Core data + persistence
| Autoload | Script | Role |
|---|---|---|
| `WorldLore` | `scripts/world_lore.gd` | Static lore strings (Sundered Realms vocabulary). |
| `EventBus` | `scripts/event_bus.gd` | Cross-system signal hub. ~24 signals. |
| `GameState` | `scripts/game_state.gd` | Persistent meta state. Saved by `SaveSystem`. |
| `SaveSystem` | `scripts/save/save_system.gd` | JSON save/load round-trip. |
| `RunState` | `scripts/run/run_state.gd` | Per-run mutable state. Reset on `start_run`. |

### Combat / loot / progression
| `LootSystem` | `scripts/loot/loot_system.gd` | Rarity rolls, affix tables, item generation. |
| `DyeSystem` | `scripts/dyes/dye_system.gd` | 25-color palette, per-slot tints, saved sets. |
| `Classes` | `scripts/classes/class_db.gd` | 7 base classes + 10 hybrid prestiges + multiclass blend math. **Note**: autoload renamed from `ClassDB` (engine global) to `Classes`. |
| `TalentDB` | `scripts/talents/talent_db.gd` | Per-class talent grids with prereq edges. |
| `PerkPool` | `scripts/perks/perk_pool.gd` | Universal + class perks + weapon evolutions, weighted draw. |
| `BuffSystem` | `scripts/buffs/buff_system.gd` | Self-buffs + weapon buffs with exclusive groups + source priority. |

### Economy
| `VendorSystem` | `scripts/economy/vendor_system.gd` | 3-currency, vendor trash, sell-all-junk, buyback queue. |

### Quests / lore / travel
| `QuestSystem` | `scripts/quests/quest_system.gd` | Active quests + bounty board + progress tracking via `entity_killed` / `boss_defeated` / `item_picked_up` / `lore_read` / `location_reached`. |
| `TravelSystem` | `scripts/travel/travel_system.gd` | Wayspire portals + Bond Stone (channel + cooldown). |
| `LoreCodex` | `scripts/lore/lore_codex.gd` | 35 seeded lore entries + unlock state. |

### World simulation
| `WorldSim` | `scripts/world/world_sim.gd` | Day/night phase clock. |
| `WeatherSystem` | `scripts/world/weather_system.gd` | 5 weather types with gameplay effects. |
| `EventDirector` | `scripts/world/event_director.gd` | Dynamic world events (raid / merchant / ambush / carnival / flyover). |
| `FactionState` | `scripts/factions/faction_state.gd` | Rep / power / tokens for 5 factions. |
| `Towns` | `scripts/towns/town_registry.gd` | 3 seeded towns with 5 named NPCs each. |

### Crafting (7 stations)
| `Forge` | `scripts/crafting/forge.gd` | Weapons + armor (form × primary × secondary × embellishment × engraving × quality). |
| `Alchemy` | `scripts/crafting/alchemy.gd` | Potions / oils / scrolls (vessel × reagent × catalyst). |
| `Workbench` | `scripts/crafting/workbench.gd` | Jewelry (mount × stone × inscription). |
| `Atelier` | `scripts/crafting/atelier.gd` | Scrolls / runes / foci (form × sigil × ink). |
| `Loom` | `scripts/crafting/loom.gd` | Cloth armor + capes + banners (piece × fabric × trim). |
| `Cooking` | `scripts/crafting/cooking.gd` | Food buffs (dish × staple × spice). |
| `Engraving` | `scripts/crafting/engraving.gd` | Modifies existing items in-place (script × label × cost). |

### NPCs / dialogue
| `NpcMemory` | `scripts/npc/npc_memory.gd` | Persistent NPC state (Phase B placeholder). |
| `RumorPool` | `scripts/npc/rumor_pool.gd` | 30-entry tavern rumor pool. |

### Audio / VFX / UI
| `SfxBus` | `scripts/audio_bus.gd` | Procedural SFX kit (perc / shimmer / growl / swoosh + ADSR). |
| `MusicDirector` | `scripts/audio/music_director.gd` | EXPLORATION / TENSION / COMBAT / BOSS layered crossfade. |
| `VFX` | `scripts/vfx/vfx_manager.gd` | 3D particles, bursts, loot pillars, levelup flares, fire rings, hit-stop, screen-shake. |
| `OrientationMgr` | `scripts/ui/orientation_manager.gd` | Material 3 width buckets (Compact / Medium / Expanded), safe-area insets, per-bucket scalars. |

### Inventory / Villa
| `Inventory` | `scripts/inventory/inventory.gd` | Player bag + equipped slots, listens to `item_picked_up`. |
| `ChestManager` | `scripts/storage/chest_manager.gd` | 9 typed Treasury chests with sort/filter/search. |
| `TrophyManager` | `scripts/hall/trophy_manager.gd` | Trophy collection + placed slots + active-buff cap + set-bonus aggregation. |

### Misc
| `Settings` | `scripts/settings.gd` | Player settings JSON + AudioServer bus volume application. |

## EventBus signal contract

Signals defined in `scripts/event_bus.gd`. Anyone can `connect()` or `emit()`.

| Signal | Payload | Emitters | Listeners |
|---|---|---|---|
| `damage_dealt` | source, target, amount, is_crit | enemies on take_damage | analytics, future combat-log UI |
| `entity_killed` | entity, killer | enemy `_die` | QuestSystem, GameState (kill tally) |
| `loot_dropped` | item dict, position | LootSystem.roll → enemies, dragons, events | run/main spawns LootDrop scene |
| `item_picked_up` | item dict | LootDrop.body_entered | Inventory, QuestSystem |
| `screen_shake` | strength, duration | combat / VFX | run/main camera |
| `hit_stop` | duration | VFX | run/main `Engine.time_scale` modulation |
| `floating_text` | text, position, color | everywhere | scripts/fx/floating_text_layer.gd |
| `player_died` | (no args) | player.gd CharacterStats | run/main `_on_player_died` |
| `player_leveled_up` | level | RunState.add_xp | analytics |
| `currency_changed` | kind, delta, total | GameState.add_gold/gems, VendorSystem.add_currency | HUD gold display |
| `boss_defeated` | boss_id | dragon scripts on_died, Krrik | TrophyManager (awards trophy + class unlock + triple-class flag) |
| `world_event_started` | event_id, payload | EventDirector | run/main `_on_world_event` |
| `quest_started` | quest_id | QuestSystem.start | future quest-toast UI |
| `quest_pinned` | quest_id | QuestSystem.pin | HUD quest tracker |
| `quest_objective_progress` | quest_id, objective_id, current, needed | QuestSystem.progress | HUD tracker (live updates) |
| `quest_completed` | quest_id | QuestSystem._check_completion | future fanfare UI; also fires SFX inline |
| `bond_set` | location_id | TravelSystem.set_bond | analytics |
| `travel_started` | dest_id | TravelSystem.begin_channel/use_portal | future loading screen |
| `travel_completed` | dest_id | TravelSystem.tick_channel/use_portal | scene-change handlers |
| `portal_unlocked` | portal_id | TravelSystem.unlock | future world-map highlight |
| `day_night_phase_changed` | phase enum | WorldSim phase clock | run/main sky tint, dragon entities |
| `weather_changed` | weather enum | WeatherSystem | run/main fog, audio swap |
| `perk_chosen` | perk_id | RunState.register_perk | HUD buff row, future analytics |
| `weapon_evolved` | from_id, evolution_id | RunState.register_evolution, perks evolution path | run/main floater, HUD |
| `potion_used` | kind | player._use_potion | HUD, future analytics |

## Scene layout

```
scenes/
  title.tscn               # splash → tap → menu state machine
  run.tscn                 # 3D combat run scene
  main.tscn                # legacy / unused
  villa/villa.tscn         # walkable villa, 15 building markers
  player/player.tscn       # CharacterBody3D player
  enemies/                 # goblin, bandit, drake, krrik
  fx/loot_drop.tscn        # bob+rotate loot pickup
  boss/                    # vyxhasis_arena.tscn (palette swap per dragon)
  crafting/                # forge_ui, alchemy_ui, workbench_ui, atelier_ui,
                           # loom_ui, cooking_ui, engraving_ui
  ui/                      # title, class_select, perk_picker, hud, journal,
                           # pause_menu, game_over, settings, world_map,
                           # merchant, snikkit_den, trophy_picker, talent_tree,
                           # loading_screen, tutorial_overlay, dye_picker,
                           # upgrade_panel, town_visit, boss_bar
```

## Where is X handled?

| Question | Answer |
|---|---|
| Player damage / crit / lifesteal | `scripts/entities/player.gd` `_attack`. Crit roll uses `current_crit_chance`. Lifesteal applied in goblin.gd `take_damage`. |
| Skill cooldowns | `scripts/entities/player.gd` `skill_cds` dict + `_process_skill_cooldowns`. |
| Multiclass stat blend | `scripts/classes/class_db.gd` `combined_stat_profile` / `combined_resources` (60/40 weighted). |
| Trophy buffs applied | `scripts/entities/player.gd` `_apply_trophy_buffs` (16 stat keys mapped). |
| Talent stat application | `scripts/entities/player.gd` `_apply_allocated_talents`. |
| Quest kill tracking | `scripts/quests/quest_system.gd` `_on_entity_killed`. Goblin variants match via prefix. |
| Dragon phase transitions | `scripts/entities/dragon_boss.gd` `take_damage` (one-way phase enum). |
| Loot pillar gating | `scripts/loot/loot_drop.gd` — Epic+ only (perf). |
| Wager-multiplier persistence | `scripts/run/run_state.gd` — NOT reset in `start_run`; reset only in `end_run` after death. |
| Save format | `scripts/save/save_system.gd` JSON dump of GameState fields. Includes `lifetime_kills_by_type` + `krrik_defeated`. |
| Audio bus volume | `scripts/settings.gd` `apply_audio_buses` reads sliders → AudioServer. |
| Floor environment swap | `scripts/run/main.gd` `_apply_floor_region` cycles through 5 regions. |
| Boss HP banner | `scripts/ui/boss_bar.gd` polls boss.hp/max_hp/phase each frame. |
| Bond stone channel | `scripts/ui/hud.gd` `_on_bond_down` / `_process` bond_progress fill. |

## Test suites (14 files, 121 tests)

```
tests/
  test_class_db.gd               # 15 tests — multiclass math
  test_class_selection_flow.gd   # 6  — RunState class persistence
  test_alchemy.gd                # 8  — alchemy data layer + craft
  test_dragon_boss.gd            # 12 — DragonBoss state machine
  test_forge.gd                  # 14 — forge data + property test
  test_integration.gd            # 9  — cross-system integration
  test_orientation_mgr.gd        # 10 — bucket detection + tokens
  test_workbench.gd              # 6  — workbench data + craft
  test_remaining_stations.gd     # 11 — atelier/loom/cooking/engraving
  test_save_roundtrip.gd         # 5  — save/load
  test_scene_loading.gd          # 3  — every load-bearing scene parses
  test_smoke.gd                  # 4  — autoloads + ClassDB shape
  test_towns.gd                  # 6  — town registry
  test_content.gd                # 12 — DyeSystem, kill tally, class unlocks
```

Run all: `make test`.

Run balance simulator: `make balance-sim` (100-run procedural sweep, CSV report).

## Build pipeline

| Command | What it does |
|---|---|
| `make run` | Open project in Godot editor |
| `make test` | Headless GUT suite |
| `make lint` | Re-import + surface warnings/errors |
| `make apk` | Auto-bump versionCode + build Android APK to `build/HearthkeepDemo-v$(VERSION_NAME).apk` |
| `make assets-audit` | License-whitelist enforcement on art/ + audio/ trees |
| `make balance-sim` | 100-run procedural-integrity sweep |
| `make install-hooks` | One-shot pre-commit hook installer |
