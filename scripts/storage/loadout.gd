extends Node

# Saved equipment loadouts. Pulls from Treasury or current bag automatically.

var loadouts: Dictionary = {}              # name -> { slot -> item }

func save_current(name: String) -> void:
    loadouts[name] = Inventory.equipped.duplicate(true)

func load_loadout(name: String) -> bool:
    if not loadouts.has(name):
        return false
    var slots: Dictionary = loadouts[name]
    for slot in slots.keys():
        var item: Variant = slots[slot]
        if typeof(item) == TYPE_DICTIONARY:
            Inventory.equip(item)
    return true

func names() -> Array:
    return loadouts.keys()
