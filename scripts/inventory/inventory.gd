extends Node

# Per-run inventory; stash lives in GameState. Drag/drop UI in inventory_ui.gd.

const SLOTS := ["main_hand","off_hand","head","shoulders","chest","hands","legs","feet","ring","ring2","neck","cloak","belt"]
const MAX_BAG := 36

var bag: Array = []
var equipped: Dictionary = {}                 # slot -> item

signal inventory_changed
signal equipment_changed

func _ready() -> void:
    EventBus.item_picked_up.connect(_on_item_picked_up)

func _on_item_picked_up(item: Dictionary) -> void:
    if bag.size() >= MAX_BAG:
        # Auto-sell to gold to keep loop loose
        GameState.add_gold(_sell_value(item))
        return
    bag.append(item)
    inventory_changed.emit()
    # Auto-equip if slot empty (mobile-friendly)
    var slot: String = item.get("slot","")
    if slot != "" and not equipped.has(slot):
        equip(item)

func equip(item: Dictionary) -> void:
    var slot: String = item.get("slot","")
    if slot == "":
        return
    if equipped.has(slot):
        bag.append(equipped[slot])
    equipped[slot] = item
    bag.erase(item)
    inventory_changed.emit()
    equipment_changed.emit()

func unequip(slot: String) -> void:
    if not equipped.has(slot):
        return
    bag.append(equipped[slot])
    equipped.erase(slot)
    inventory_changed.emit()
    equipment_changed.emit()

func sell(item: Dictionary) -> int:
    var v := _sell_value(item)
    bag.erase(item)
    GameState.add_gold(v)
    inventory_changed.emit()
    return v

func _sell_value(item: Dictionary) -> int:
    var rarity: int = int(item.get("rarity", 0))
    return [3, 8, 25, 80, 220, 600, 1500][rarity]

func reset_for_run() -> void:
    bag.clear()
    inventory_changed.emit()
    equipment_changed.emit()
