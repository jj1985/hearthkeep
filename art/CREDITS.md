# HEARTHKEEP — Asset Credits

Currently the game ships with zero third-party assets.  Every visual is procedural geometry + hand-authored materials.  This page exists so attribution lands here the moment any CC0/CC-BY pack is imported, with no chance of an asset slipping in unattributed.

When CC-BY assets are imported, list them below in this format:

```
- "<asset name>" by <author>, <license>, <source URL>, modifications: <none|tinted|recombined|etc.>
```

## Procedural / project-authored

- All `MeshInstance3D` geometry uses Godot stock primitive resources (`CapsuleMesh`, `BoxMesh`, `SphereMesh`, `CylinderMesh`, `PlaneMesh`).  Public domain via Godot's MIT license.
- All particle systems use Godot's `CPUParticles3D`.  Public domain via Godot's MIT license.
- All sound effects are synthesized at runtime from sine waves in `scripts/audio_bus.gd` — original to this project.
- All music layers are synthesized at runtime in `scripts/audio/music_director.gd` — original to this project.
- All UI text strings, lore entries, NPC dialogue, region names, deity names, dragon names, and goblin king name are coined for HEARTHKEEP — original to this project.

## Reserved attribution slots (for upcoming imports)

The following pack candidates are pre-approved for a polish pass — list moves up when assets are actually imported:

- Kenney "Medieval Pack" (CC0) — castle props, weapons, peasant + knight figures
- Kenney "Dungeon Pack" (CC0) — torch sconces, doors, chests, barrels
- Quaternius "Ultimate Modular Medieval" (CC0) — environment kit
- Polyhaven HDRIs (CC0) — sky environments
- ambientCG textures (CC0) — stone, wood, metal, fabric
- Kevin MacLeod tracks (CC-BY 4.0) — combat / exploration / boss themes
- Sonniss GDC packs — hit / crit / loot / coin SFX
