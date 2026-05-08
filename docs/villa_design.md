# The Villa — player home base (post-demo immediate priority)

User directive: "I envision a villa I can build that houses chests with all of my loot I can sort through."

## Concept

The Villa is a personal medieval estate. Stone walls, slate roof, oak doors, banners hanging from the entry archway, garden out front, walled courtyard.  Grows from a modest manor to a sprawling keep across upgrade tiers; what gets built reflects player choices.

The player walks the Villa in 3D.  Doors open, music shifts subtly per room.

## Rooms

- **Treasury** — the loot storage room; centerpiece is a wall of physical 3D chests the player walks up to and opens
- **Trophy Hall** — grand entry hall with mounted trophies (set buffs via TrophyManager autoload; live and tested)
- **Forge** — item upgrade / reroll / identify; full crafting station per `crafting_design.md`
- **Tavern Wing** — Tavernkeeper, mercs, lore rumors, recruitment, eat-for-buff
- **Wizard's Study** — enchanting (risk-reward), spell research, scroll crafting
- **Gambling Den (basement)** — Snikkit the goblin gambler; item gamble, double-or-nothing, wager-the-run
- **Garden / Courtyard** — herb growing, ambient life (butterflies, fountain), rescued NPCs walk through
- **War Room** — quest log map-table feel, world map, faction power overview
- **Stables** — stub for future mounts
- **Library** — lore codex, identified scrolls, achievement journal

## Treasury chests (default)

Each chest is a STORAGE TAB with a clear label, theme, and physical 3D mesh:

- **Weapons Chest** — swords, axes, bows, staves, daggers, polearms
- **Armor Chest** — helms, chests, gloves, boots, shoulders, cloaks
- **Trinkets & Jewelry Chest** — rings, necklaces, belts, charms
- **Consumables Chest** — potions, scrolls, food, buff items, weapon oils
- **Materials Chest** — crafting materials, runes, gems, dye pots, dragon shards
- **Currency Vault** — gold piles visible inside scaling with amount, secondary currencies
- **Cosmetics Wardrobe** — cosmetic-only gear and dye sets
- **Quest Items Coffer** — locked-looking; quest items can never be sold or lost
- **Vendor Trash Bin** — sack, deliberately unceremonious; junk-tagged items queued for vendor

`ChestManager` autoload (live in code) routes items into the right chest by slot/tags.  Capacity per chest grows with Villa Treasury upgrade tier.

## Sorting + filtering UX

Implemented in `chest_manager.gd`:
- Sort by: rarity (default), type, ilvl, stat, recently acquired, name A-Z, sell value
- Filter by: rarity tier toggles, ilvl range, stat presence, slot, affix search
- Search bar with live-filter across all chests
- Show-all aggregated grid

UI is roadmap.

## Loadouts

`LoadoutManager` autoload — saved equipment loadouts pull from the Treasury automatically.

## Auto-stow on run end

Scoped via the `Settings.run_end_auto_return` toggle — when on, run loot files into chests automatically; when off, player reviews a loot summary first.

## Building / upgrade flow

Villa starts as a modest manor (4 rooms: entry/Trophy Hall, Treasury, Tavern, Garden).  Players add new rooms by spending gold + materials at the master architect NPC.  Each addition shows a brief construction sequence.  Tier upgrades expand existing rooms.  Tradeoff: architect can only build one upgrade at a time, but no real-time gating — projects complete after a "go run a few dungeons and come back" loop (no clock timers).

## Performance

Single composed scene; rooms are named sub-areas the camera reframes for.  Heavy detail meshes on the centerpiece room only; LOD on the rest.  Pause world-sim cost while inside the Villa.

## Roadmap phasing

- **Phase A (next session, immediate):** stub Villa with walkable Treasury + Trophy Hall, other rooms as placeholder doors with "Coming Soon"
- **Phase B:** all rooms walkable, basic functionality each
- **Phase C:** full crafting integration, NPC schedules visible, ambient life decoration
