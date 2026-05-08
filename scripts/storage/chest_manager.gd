extends Node

# Treasury chest manager. Each chest is a typed bucket: weapons, armor,
# trinkets, consumables, materials, currency, cosmetics, quest, junk.
# Capacity per chest grows with Villa Treasury upgrade tier.

const CHEST_DEFS := [
    {"id":"weapons","name":"Weapons Chest","kinds":["main_hand","off_hand"]},
    {"id":"armor","name":"Armor Chest","kinds":["head","shoulders","chest","hands","legs","feet","cloak","belt"]},
    {"id":"trinkets","name":"Trinkets & Jewelry","kinds":["ring","ring2","neck"]},
    {"id":"consumables","name":"Consumables","kinds":[],"tag_match":["potion","scroll","oil","food","buff"]},
    {"id":"materials","name":"Materials","kinds":[],"tag_match":["material","rune","gem","dye","dragon_shard"]},
    {"id":"currency","name":"Currency Vault","kinds":[],"tag_match":["currency"]},
    {"id":"cosmetics","name":"Cosmetics Wardrobe","kinds":[],"tag_match":["cosmetic"]},
    {"id":"quest","name":"Quest Coffer","kinds":[],"tag_match":["quest"]},
    {"id":"junk","name":"Vendor Trash Bin","kinds":[],"tag_match":["junk","vendor_trash"]},
]

var contents: Dictionary = {}                 # chest_id -> Array of items
var capacity_per_chest: int = 240             # per chest cap; grows with tier

signal contents_changed(chest_id)

func _ready() -> void:
    for d in CHEST_DEFS:
        contents[d["id"]] = []

func chest_for_item(item: Dictionary) -> String:
    if (item as Dictionary).get("vendor_trash", false) or (item as Dictionary).get("is_junk", false):
        return "junk"
    var slot: String = item.get("slot", "")
    var tags: Array = item.get("tags", [])
    for d in CHEST_DEFS:
        for k in d.get("kinds", []):
            if slot == k:
                return d["id"]
        for tm in d.get("tag_match", []):
            if tags.has(tm):
                return d["id"]
    return "materials"   # safe default

func deposit(item: Dictionary) -> bool:
    var cid: String = chest_for_item(item)
    var arr: Array = contents[cid]
    if arr.size() >= capacity_per_chest:
        return false
    arr.append(item)
    contents_changed.emit(cid)
    return true

func auto_stow(items: Array) -> Dictionary:
    var stowed := {}
    for it in items:
        var cid: String = chest_for_item(it)
        if not stowed.has(cid): stowed[cid] = []
        if deposit(it):
            (stowed[cid] as Array).append(it)
    return stowed

func withdraw(chest_id: String, item: Dictionary) -> bool:
    if not contents.has(chest_id): return false
    var arr: Array = contents[chest_id]
    if arr.has(item):
        arr.erase(item)
        contents_changed.emit(chest_id)
        return true
    return false

func get_chest(chest_id: String) -> Array:
    return contents.get(chest_id, [])

func chest_count(chest_id: String) -> int:
    return (contents.get(chest_id, []) as Array).size()

func sort_chest(chest_id: String, by: String) -> Array:
    var arr: Array = (contents.get(chest_id, []) as Array).duplicate()
    var cmp: Callable
    match by:
        "rarity": cmp = func(a, b): return int((b as Dictionary).get("rarity", 0)) < int((a as Dictionary).get("rarity", 0))
        "ilvl": cmp = func(a, b): return int((b as Dictionary).get("ilvl", 0)) < int((a as Dictionary).get("ilvl", 0))
        "name": cmp = func(a, b): return str((a as Dictionary).get("name", "")) < str((b as Dictionary).get("name", ""))
        "value": cmp = func(a, b): return VendorSystem.sell_value(b) < VendorSystem.sell_value(a)
        _: cmp = func(a, b): return false
    arr.sort_custom(cmp)
    return arr

func filter_chest(chest_id: String, predicate: Callable) -> Array:
    return (contents.get(chest_id, []) as Array).filter(predicate)

func search_all(query: String) -> Dictionary:
    var q: String = query.to_lower()
    var out: Dictionary = {}
    for cid in contents.keys():
        out[cid] = (contents[cid] as Array).filter(func(it):
            return q == "" or str((it as Dictionary).get("name","")).to_lower().contains(q))
    return out

func set_capacity_for_villa_tier(tier: int) -> void:
    capacity_per_chest = 120 + 120 * tier

func reset() -> void:
    for d in CHEST_DEFS:
        contents[d["id"]] = []
