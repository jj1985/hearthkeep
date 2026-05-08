# Crafting + Customization (post-demo pillar)

User directive: "crafting should also be a huge element to gameplay, to include item customization."  Treat as marquee retention pillar on par with multiclassing.

## Pillars

- Discoverable, never gated by real money or grind walls
- Materials have personality (Goblin Tooth = bleed-flavored low-tier; Mithril = light + crit)
- Customization is the marquee — players SHAPE items
- Choices matter, RNG-light core; gambling-style enchanting is the optional chaos layer

## Stations (each a Villa room or workstation)

- **Forge** — weapons, armor
- **Workbench** — accessories, trinkets, charms, belts, jewelry
- **Alchemy Lab** — potions, elixirs, throwables, oils, alchemical pigments (dyes!)
- **Arcane Atelier** — scrolls, runes, enchantments, foci
- **Tailoring Loom** — cloth armor, capes, banners, bags (capacity upgrades)
- **Cooking Hearth** — food buffs, feast items
- **Engraving Bench** — cosmetic engraving + small stat tweaks

## Customization flow (multi-step)

1. **Form** (sword / axe / mace / dagger / polearm / ...) — base attack pattern + animation set
2. **Primary material** — base damage, durability, weight + a subtle inherent property
3. **Secondary material** — handle/grip, minor stat boost + flavor (silk grip = +atk speed)
4. **Embellishment** — gem inlay / trophy attach / glyph etch — optional, costs more materials
5. **Engraving** — cosmetic (player-typed name with profanity filter, sigil, faction mark)
6. **Dye / finish** — multi-channel tint: blade, hilt, pommel, grip
7. **Quality roll** — skill + station tier + small RNG band

Same flow applies to armor (form / primary mat / secondary mat / embellishment / engraving / dye), accessories, potions, scrolls.

## Material catalog (planned)

- Mundane: ores (iron/copper/silver/gold/mithril/adamant), woods (oak/ironwood/ebony/dragonwood), leathers, cloths
- Reagents: herbs, minerals, magical essences (fire/frost/shadow)
- Trophies: monster parts, dragon claws
- Rare/Unique: Vyxhasis's Heart, Krrik III's Crown Fragment
- Currencies as input: Dragon Shards as catalysts

## Skills (Aardwolf-deep)

- Each station has a skill track that levels via use
- Levels unlock recipes, raise quality ceilings, expand customization slots
- Specialization (Smithing → Weaponcraft vs. Armorcraft)
- Master Craftsman titles unlock at high levels with cosmetics

## Discovery

- Recipe books drop in dungeons / sold by NPCs / quest rewards
- Recipe rarity matches loot rarity tiers
- Faction-specific recipes from quartermasters
- Hidden recipes via material experimentation (chime + journal entry on discover)

## Salvage / Re-craft / Disenchant

- **Salvage**: break gear into materials (in scope already)
- **Re-craft**: modify a single property of an existing item (re-roll one affix, change dye, change engraving)
- **Disenchant**: reduce magical item to essence reagents (feeds enchanting)

## Master commissions

Townsfolk in AI-driven towns place commissions (`crafting_design ↔ towns_design`).  Player crafts to spec, delivers, gets paid + faction reputation.

## Transmog

Crafted-item appearance saved to wardrobe; applied to any equipable item later.  Per-slot, free for owned items, never paid.

## UI

Split-pane: recipe browser left, customization right, real-time 3D preview center.

## Phasing

- **A (post-demo):** Forge with multi-step flow, ~30 starter recipes, dye + engraving
- **B:** all 7 stations with ~150 recipes, full skill tracks, salvage, transmog
- **C:** hidden recipe experimentation, master commissions, faction-locked recipes

## Architecture

- `scripts/crafting/` — recipe.gd, crafting_session.gd, materials.gd, customization_step.gd, quality_roll.gd, transmog.gd
- `data/recipes/` — recipes as Godot Resources
- `data/materials/` — material catalog
- `scenes/crafting/` — per-station UI scenes
