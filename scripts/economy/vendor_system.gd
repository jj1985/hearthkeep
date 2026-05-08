extends Node

# Vendors, currencies, vendor-trash, sell-all-junk, buyback queue.

const CURRENCY_GOLD := "gold"
const CURRENCY_TOKENS := "tokens"
const CURRENCY_DRAGON_SHARDS := "dragon_shards"

const SELL_VALUES := [3, 8, 25, 80, 220, 600, 1500]    # by rarity tier
const BUYBACK_LIMIT := 12

var buyback: Array = []                                # most recent first

# Vendor-trash table; quality tier modifies sell price.
const VENDOR_TRASH := [
    {"id":"goblin_tooth","name":"Goblin Tooth","base_value":5,"weight":40,"floor_min":0},
    {"id":"cracked_helm","name":"Cracked Helm","base_value":12,"weight":18,"floor_min":0},
    {"id":"worn_leather_strap","name":"Worn Leather Strap","base_value":3,"weight":40,"floor_min":0},
    {"id":"tarnished_coin","name":"Tarnished Coin","base_value":15,"weight":12,"floor_min":0},
    {"id":"goblin_cleaver","name":"Goblin Cleaver","base_value":18,"weight":14,"floor_min":1},
    {"id":"drake_scale","name":"Drake Scale","base_value":25,"weight":6,"floor_min":2},
    {"id":"ancient_coin","name":"Ancient Coin","base_value":100,"weight":3,"floor_min":2},
    {"id":"dragons_tear","name":"Dragon's Tear","base_value":250,"weight":1,"floor_min":3},
]
const QUALITY_TIERS := [
    {"id":"poor","name":"Worn","mult":0.6,"weight":40},
    {"id":"common","name":"","mult":1.0,"weight":40},
    {"id":"fine","name":"Fine","mult":1.6,"weight":15},
    {"id":"exquisite","name":"Exquisite","mult":2.5,"weight":5},
]

var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()

func roll_vendor_trash(scaling: float = 1.0, floor_index: int = 0) -> Dictionary:
    var pool := VENDOR_TRASH.filter(func(t): return int(t["floor_min"]) <= floor_index)
    if pool.is_empty():
        return {}
    var total := 0
    for t in pool:
        total += int(t["weight"])
    var r := rng.randi_range(0, max(0, total - 1))
    var acc := 0
    var pick: Dictionary = pool[0]
    for t in pool:
        acc += int(t["weight"])
        if r < acc:
            pick = t
            break
    var quality := _roll_quality()
    var mult: float = float(quality["mult"]) * scaling
    var value: int = int(round(float(pick["base_value"]) * mult))
    var prefix: String = quality["name"]
    var name: String = (prefix + " " + pick["name"]) if prefix != "" else pick["name"]
    return {
        "id": str(pick["id"]) + "_" + str(quality["id"]),
        "name": name.strip_edges(),
        "is_junk": true,
        "stackable": true,
        "vendor_trash": true,
        "value": value,
        "tags": ["junk","vendor_trash"],
        "rarity": 0,
        "slot": "",
    }

func _roll_quality() -> Dictionary:
    var total := 0
    for q in QUALITY_TIERS:
        total += int(q["weight"])
    var r := rng.randi_range(0, max(0, total - 1))
    var acc := 0
    for q in QUALITY_TIERS:
        acc += int(q["weight"])
        if r < acc:
            return q
    return QUALITY_TIERS[0]

func sell_value(item: Dictionary) -> int:
    if item.get("vendor_trash", false):
        return int(item.get("value", 1))
    var rarity: int = int(item.get("rarity", 0))
    return SELL_VALUES[clamp(rarity, 0, SELL_VALUES.size() - 1)]

func sell(item: Dictionary) -> int:
    var v := sell_value(item)
    GameState.add_gold(v)
    EventBus.currency_changed.emit(CURRENCY_GOLD, v, GameState.gold)
    buyback.push_front(item)
    if buyback.size() > BUYBACK_LIMIT:
        buyback.pop_back()
    return v

func sell_all_junk(items: Array) -> Dictionary:
    var total := 0
    var sold: Array = []
    for it in items.duplicate():
        if (it as Dictionary).get("is_junk", false) or (it as Dictionary).get("vendor_trash", false):
            total += sell(it)
            sold.append(it)
    return {"gold": total, "items": sold}

func can_buyback(item: Dictionary) -> bool:
    return buyback.has(item) and GameState.gold >= int(sell_value(item) * 1.5)

func buy_back(item: Dictionary) -> bool:
    var price: int = int(sell_value(item) * 1.5)
    if not buyback.has(item) or GameState.gold < price:
        return false
    GameState.add_gold(-price)
    buyback.erase(item)
    return true

func add_currency(kind: String, amount: int) -> void:
    match kind:
        CURRENCY_GOLD: GameState.add_gold(amount)
        CURRENCY_TOKENS:
            var f: String = "free_companies"           # default; can be parameterized
            FactionState.add_tokens(f, amount)
        CURRENCY_DRAGON_SHARDS:
            GameState.gems = max(0, GameState.gems + amount)
            EventBus.currency_changed.emit(kind, amount, GameState.gems)

func get_balance(kind: String, faction_id: String = "") -> int:
    match kind:
        CURRENCY_GOLD: return GameState.gold
        CURRENCY_DRAGON_SHARDS: return GameState.gems
        CURRENCY_TOKENS:
            if faction_id == "":
                return 0
            return FactionState.tokens(faction_id)
    return 0
