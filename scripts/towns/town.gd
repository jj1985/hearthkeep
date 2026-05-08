extends RefCounted
class_name Town

# A single town in the Sundered Realms. Carries enough state for Phase A
# scaffolding: ruler, faction lean, mood, population, recent events.
# Politics state machine + news propagation is Phase B.

var id: String
var name: String
var region: String
var population: int = 0
var mood: float = 0.5                # 0 = grim, 1 = jubilant
var ruler: Dictionary = {}           # townsfolk dict
var faction_lean: String = ""        # faction id this town tilts toward
var npcs: Array = []                 # 5 named-NPC dicts in Phase A
var recent_events: Array = []        # short-string ring buffer, last 5

func _init(p: Dictionary) -> void:
    id = p.get("id", "")
    name = p.get("name", id)
    region = p.get("region", "")
    population = int(p.get("population", 0))
    mood = float(p.get("mood", 0.5))
    ruler = p.get("ruler", {})
    faction_lean = p.get("faction_lean", "")
    var raw_npcs: Variant = p.get("npcs", [])
    npcs = (raw_npcs as Array).duplicate() if raw_npcs is Array else []
    var raw_events: Variant = p.get("recent_events", [])
    recent_events = (raw_events as Array).duplicate() if raw_events is Array else []

func tick(_real_dt: float) -> void:
    # Phase B: drift mood, simulate trade, schedule events.
    pass

func mood_label() -> String:
    if mood >= 0.8: return "jubilant"
    if mood >= 0.6: return "content"
    if mood >= 0.4: return "uneasy"
    if mood >= 0.2: return "fearful"
    return "despairing"

func summary() -> Dictionary:
    return {
        "id": id, "name": name, "region": region,
        "population": population, "mood": mood, "mood_label": mood_label(),
        "ruler_name": ruler.get("name", "—"),
        "ruler_title": ruler.get("title", ""),
        "faction_lean": faction_lean,
        "npc_count": npcs.size(),
        "recent_event": recent_events.back() if not recent_events.is_empty() else "",
    }
