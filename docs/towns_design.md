# Towns + Politics + AI NPCs (post-demo pillar)

User directive: "towns should be dotted all over the landscape with their own politics and people, driven by ai."

## Concept

8-15 distinct towns across the HEARTHKEEP overworld.  Each has population, political alignment, internal factions, economy, mood, and storyline arcs that evolve without player intervention.  Players visit, talk, intervene, and watch the world change.

## Architecture (planned)

- `scripts/towns/town.gd` — Town class with population, factions, ruler, mood, recent events
- `scripts/towns/town_politics.gd` — succession crisis state machine, faction power tilts
- `scripts/towns/town_npc.gd` — named NPC agent with goals, relationships, knowledge
- `scripts/towns/news_network.gd` — news propagation along road graph
- `scripts/towns/trade_sim.gd` — town specialty + trade flow simulation
- `scripts/towns/dialogue_templater.gd` — contextual dialogue from templates (no LLM by default; LLM toggle is roadmap)
- `data/towns/*.tres` — Town resources
- `data/townsfolk/*.tres` — NPC resources
- `data/dialogue_templates/*.json` — templating corpus

## Phasing

- **A (post-demo immediate):** scaffolding + 3 stub towns with 5 named NPCs each, basic dialogue templating
- **B:** politics state machine, faction internal conflict, basic news propagation, ruler stability
- **C:** trade simulation, refugee migration, inter-town conflict, town quest generation
- **D:** townhomes, deep faction reputation, marriage/family politics flavor

## Performance

Town simulation runs on a 10-in-game-minute background tick.  Towns the player has never visited use a low-frequency simplified tick.  Visible NPC cap per town scene: 12, with the rest as "off-stage" simulation.

## Open questions

- Phone-friendly UI for town politics overview — needs design pass
- LLM-flavored dialogue (off by default; document opt-in path)
- How marriage / family politics work without becoming a sim that distracts from ARPG core
