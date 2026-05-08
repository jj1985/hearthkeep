Resume work on HEARTHKEEP, a mobile ARPG roguelike I'm building. The project lives at /Users/user/norrath-roguelike (or whatever path you find — `ls /Users/user/ | grep -i hearth\|norrath`). Read the README, CHANGELOG, and any docs/ files first to orient.

# What HEARTHKEEP is

A Diablo-lineage mobile ARPG roguelike with deep multiclassing as the marquee feature, set in a Norrath-flavored world (legally distinct from EverQuest — coined names only, no Daybreak trademarks). Engine: Godot 4.6.x, Mobile renderer, beautiful stylized 3D, isometric camera, target Android (export pipeline already scaffolded).

# Pillars (non-negotiable)

1. Multiclassing is THE feature — 5+ base classes, dual/triple combos, named prestige hybrids, tag-based skill synergies
2. Diablo-lineage real-time combat — virtual stick + skill buttons OR tap-to-move + auto-attack (toggleable), dodge, hit-stop, screen shake, juicy crits
3. Beautiful 3D, painterly stylized PBR, medieval architecture (stone keeps, vaulted arches, flying buttresses) with magical accents (glowing runes, ley-line glyphs, school-colored dynamic spell lights)
4. Multi-orientation: portrait + landscape with deliberate UI reflow, tablet-first
5. Modern minimal UI: minimap during runs, full Norrath-style world map with fog-of-war + fast travel
6. NO gating — no energy, no timers, no daily limits, no paywalls blocking content
7. In-world gambling (Wellspring den) using only in-game currency — never real-money loot boxes
8. Massive loot explosions: rarity tiers (Common→Mythic→Artifact), affixes, identifiable items, light pillars + screen shake + coin spray on drop
9. Goblins as iconic enemies (Skirmisher, Sapper, Shaman, Warchief, Krrik III as warband king)
10. Dragons as peak content: 3 named bosses (Vyxhasis, Ourzhal, Aethyrnax), multi-phase fights (ground/air/enraged), drake elites, ceremonial loot rain
11. Megabonk-style mid-run perk-card escalation: every level-up offers 3 randomized cards from class skill pools + universal perks; weapon evolutions on perk + weapon combos
12. Living, breathing world: day/night, weather, NPC schedules, dynamic events (goblin raids, caravan ambushes, wandering merchant, traveling carnival, dragon flyovers), ecosystem critters, faction power simulation, persistent NPC memory, ambient life, rotating tavern rumors
13. AI-driven towns dotted across the landscape with their own politics, factions, succession arcs, news propagation, trade simulation (rule-based AI, not LLM — architected so LLM dialogue layer could be optional later)
14. Quests: MSQ (12 chapters), faction questlines, class questlines, dragon hunts (multi-step ceremonial), bounty board, hidden quests, lore codex
15. Travel: Wayspire portals (discovered = unlocked), Bond Stones (Hearthstone-style — bind to one location, channel-teleport home with cooldown, blocked in combat)
16. The Villa: player's medieval estate that grows with upgrades. Rooms: Treasury (wall of physical 3D chests with sort/filter/search/auto-stow/loadouts), Trophy Hall (Asheron's Call-style — display boss heads + faction banners + artifacts that grant individual buffs and named set bonuses, with active-buff cap so choices matter), Forge, Tavern, Wizard's Study, Gambling Den (Snikkit the Lucky — item gamble, double-or-nothing, wager-the-run), Garden, War Room (quest log + world map), Stables, Library
17. Crafting as marquee pillar: 7 stations (Forge, Workbench, Alchemy Lab, Arcane Atelier, Tailoring Loom, Cooking Hearth, Engraving Bench). Multi-step customization flow: form → primary material → secondary material → embellishment → engraving → dye → quality. Recipes discoverable in world, never paid. Aardwolf-deep skill specializations. Transmog system for cosmetic appearance.
18. Buffs: self-buffs (scrolls, potions, class skills) and weapon buffs (whetstones, oils, coatings) with visible auras and elemental procs. Dyes for armor (tintable mask channels per piece, dye vendor + drops, save dye sets per loadout)
19. Vendor economy: vendor-trash drops with quality tiers, sell-all-junk button, 3-currency model (Gold + Faction Tokens + Dragon Shards), buyback queue
20. Reactive enemies: goblins taunt + flee + rally + pick up better weapons; drakes circle before swooping; elite barks on encounter/death; environmental reactions (fire spreads, oil ignites, ice slips)

# Engineering mandates (non-negotiable)

- TDD: GUT framework, write tests first, red→green→refactor. Run headlessly via `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests`. Coverage on combat math, loot rolls, multiclass synergies, buff stacking, save round-trip, quest triggers, world sim, travel, economy, talent tree, dungeon generator, asset-license compliance, 1000-run procedural-integrity sweep
- Commit early and often, conventional messages: `feat(scope): summary`, `fix(scope): summary`, etc. Tag milestones (v0.0.1-mvp-demo, v0.1.0-multiclass, etc.). Keep CHANGELOG.md updated.
- Pre-commit hook running headless tests
- Makefile/justfile with: test, lint, run, export-android, clean, assets-audit, balance-sim, apk
- ASSET LEGAL HYGIENE — release blocker. Every asset must be CC0, CC-BY (with attribution), CC-BY-SA (avoid for commercial), or original. Track in art/ASSET_MANIFEST.csv and audio/AUDIO_MANIFEST.csv. Verified safe sources: Kenney.nl (CC0), Quaternius (CC0), Polyhaven (CC0), ambientCG (CC0), OpenGameArt CC0/CC-BY filter, game-icons.net (CC-BY 3.0), Sonniss GDC packs (royalty-free commercial), Kevin MacLeod incompetech.com (CC-BY 4.0), Eric Matyas soundimage.org (CC-BY), Google Fonts (OFL). NEVER: ripped game assets, ambiguous-license AI art, freesound non-commercial. Add LICENSES.md and in-game Credits screen.
- Performance: Mobile renderer, object pooling for enemies/projectiles/particles, particle caps, target 60 FPS mid-tier Android, doc budgets in docs/perf_budgets.md
- IP-distance: zero residual EverQuest trademark proximity. "Norrath" itself is a Daybreak trademark — use the coined HEARTHKEEP world vocabulary throughout.

# Engagement / "badass pass" mandates

- Dynamic music director: layered tracks per region with crossfade on tension/combat/boss, sourced legally clean
- Chunky layered SFX, hit-stop on impact, screen shake scaled to damage, slow-mo (0.05s) on legendary drops, radial blur on dodge
- Voice barks on key actions (low HP, level up, legendary drop, boss kill), TTS-stub for prototype, marked as placeholder
- Title screen: dragon flying over a stone keep at sunset with logo + main theme swell
- First 30 seconds of game must HOOK: dramatic music swell, dragon shadow flies overhead, goblin charges, you cleave it, loot pops with light pillars, NPC shouts "by the gods, did you see that?!"
- Loading screens: rotating lore + class tips, never blank
- Every menu transition tweens, every button has press animation, every empty state has personality

# Where the work currently is

- Build task was racing to playable demo (title → tap Play → kill goblins → loot drop → potion → clear room → result screen) and Android APK export pipeline was being set up (JDK, Android SDK, Godot 4.6.2 export templates, debug keystore, sensor orientation, arm64-v8a only, com.hearthkeep.demo package)
- INSTALL_APK.md to be written with adb install + sideload steps
- Build/*.apk gitignored; export config and Makefile target `make apk` committed
- After demo + APK ship, queue: full multiclass system, dragon boss fight, Villa rooms (Treasury + Trophy Hall first), world sim, AI-driven towns (Phase A scaffolding then politics state machine), crafting (Phase A: Forge with full customization flow), more goblin variants
- Working title locked: HEARTHKEEP. Studio name candidates: Iron Vesper Studios (top), Brackenwild, Mournstone

# How to proceed

Continue the build under all the above mandates. Race the playable demo + APK if not yet shipped. Then expand systems in order: multiclass core → dragon boss → Villa Treasury + Trophy Hall → world sim + AI towns Phase A → crafting Phase A → balance simulator pass → re-export APK → continue.

Use TodoWrite to track milestones. Surface a status update at every major milestone. Ask only on hard blockers (GitHub auth, license accept). The user is at the Mac and ready to unblock.

External docs sitting outside the repo (in dispatch session output dirs, can be re-created if needed): HEARTHKEEP GDD (~13K words), Engagement Bible (~11.4K words, 50-instruction Design Implications Catalog), AETHERFALL Marketing & Monetization Plan, AETHERFALL Path to Blockbuster, IP/Trademark/Branding Strategy. The GDD is the canonical world bible — match its vocabulary (regions, deities, NPCs, dragons, goblin king arc, prestige class names) when authoring in-game text.