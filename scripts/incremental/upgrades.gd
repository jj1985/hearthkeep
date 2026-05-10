extends Node

# Persistent gold-funded upgrades. Bought between runs from the title
# screen menu. Each upgrade has a cost that scales with current rank.
#
# Rank values feed back into HordeArena so kills/sec accelerates.
# Persisted via GameState.meta_unlocks.upgrades.

signal upgrade_purchased(id: String, rank: int)

const UPGRADES := [
    {"id":"damage",     "label":"Sharper Steel",  "desc":"+2 base damage per rank.",        "base":40,   "growth":1.55},
    {"id":"atk_speed",  "label":"Practiced Form", "desc":"+0.20 atk/sec per rank.",          "base":80,   "growth":1.65},
    {"id":"range",      "label":"Long Reach",     "desc":"+30 hero range per rank.",         "base":60,   "growth":1.5},
    {"id":"idle",       "label":"Hearthstone",    "desc":"+25%% idle gold/sec per rank.",    "base":120,  "growth":1.7},
    {"id":"crit",       "label":"Lucky Strike",   "desc":"+5%% crit chance per rank (×2 dmg)","base":160,  "growth":1.9},
]
const MAX_RANK := 30

func rank(id: String) -> int:
    var ups: Dictionary = _ups()
    return int(ups.get(id, 0))

func cost(id: String) -> int:
    var u: Dictionary = _def(id)
    if u.is_empty(): return 0
    var r: int = rank(id)
    if r >= MAX_RANK: return -1   # maxed
    return int(round(float(u["base"]) * pow(float(u["growth"]), r)))

func can_buy(id: String) -> bool:
    var c: int = cost(id)
    return c > 0 and GameState.gold >= c and rank(id) < MAX_RANK

func buy(id: String) -> bool:
    if not can_buy(id):
        return false
    var c: int = cost(id)
    GameState.gold -= c
    EventBus.currency_changed.emit("gold", -c, GameState.gold)
    var ups: Dictionary = _ups()
    ups[id] = rank(id) + 1
    GameState.meta_unlocks["upgrades"] = ups
    upgrade_purchased.emit(id, rank(id))
    return true

# --- Effective stat helpers used by HordeArena -----------------------

func bonus_damage() -> int:
    return rank("damage") * 2

func bonus_atk_speed() -> float:
    return rank("atk_speed") * 0.20

func bonus_range() -> float:
    return rank("range") * 30.0

func idle_multiplier() -> float:
    return 1.0 + rank("idle") * 0.25

func crit_chance() -> float:
    return clamp(rank("crit") * 0.05, 0.0, 0.95)

func _ups() -> Dictionary:
    if "upgrades" not in GameState.meta_unlocks:
        GameState.meta_unlocks["upgrades"] = {}
    return GameState.meta_unlocks["upgrades"]

func _def(id: String) -> Dictionary:
    for u in UPGRADES:
        if String(u["id"]) == id:
            return u
    return {}
