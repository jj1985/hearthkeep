extends Node

# Armor dye system — first-class identity feature.
#
# Each armor sprite/mesh has a tintable region (Mask). The dye system stores
# per-equipment-slot color choices and produces tint colors that sprite
# materials read via shader_param "tint".
#
# Saved dye sets let players snapshot a full-character palette and re-apply.

const DEFAULT_PALETTE := [
    {"id":"red","name":"Bloodforge Red","color":Color(0.85,0.10,0.10),"rarity":0},
    {"id":"crimson","name":"Crimson Royal","color":Color(0.55,0.05,0.10),"rarity":0},
    {"id":"orange","name":"Pumpkin","color":Color(0.95,0.55,0.10),"rarity":0},
    {"id":"gold","name":"Aureate","color":Color(0.95,0.80,0.20),"rarity":0},
    {"id":"yellow","name":"Sunbeam","color":Color(1.00,0.90,0.30),"rarity":0},
    {"id":"green","name":"Mossy","color":Color(0.20,0.55,0.20),"rarity":0},
    {"id":"forest","name":"Forest","color":Color(0.10,0.35,0.15),"rarity":0},
    {"id":"teal","name":"Tidewater","color":Color(0.10,0.65,0.65),"rarity":0},
    {"id":"blue","name":"Sapphire","color":Color(0.15,0.30,0.90),"rarity":0},
    {"id":"navy","name":"Midnight Navy","color":Color(0.05,0.10,0.40),"rarity":0},
    {"id":"purple","name":"Royal Purple","color":Color(0.55,0.20,0.80),"rarity":0},
    {"id":"violet","name":"Twilight Violet","color":Color(0.40,0.15,0.65),"rarity":0},
    {"id":"pink","name":"Rosegold","color":Color(0.95,0.55,0.75),"rarity":0},
    {"id":"white","name":"Bone White","color":Color(0.95,0.92,0.85),"rarity":0},
    {"id":"ivory","name":"Ivory","color":Color(0.96,0.92,0.78),"rarity":0},
    {"id":"gray","name":"Iron Gray","color":Color(0.45,0.45,0.50),"rarity":0},
    {"id":"silver","name":"Argent","color":Color(0.80,0.82,0.88),"rarity":0},
    {"id":"black","name":"Obsidian","color":Color(0.08,0.08,0.10),"rarity":0},
    {"id":"brown","name":"Forge Brown","color":Color(0.40,0.25,0.10),"rarity":0},
    {"id":"copper","name":"Copper","color":Color(0.75,0.45,0.20),"rarity":0},
    # rarer drops
    {"id":"void","name":"Voidweave","color":Color(0.10,0.05,0.30),"rarity":2},
    {"id":"emberglow","name":"Emberglow","color":Color(1.00,0.30,0.05),"rarity":2},
    {"id":"frostlight","name":"Frostlight","color":Color(0.55,0.85,1.00),"rarity":2},
    {"id":"draconic","name":"Draconic","color":Color(0.85,0.05,0.05),"rarity":3},
    {"id":"prismatic","name":"Prismatic","color":Color(0.70,0.55,0.95),"rarity":4},
]

# slot -> color_id  (current preview / equipped tint)
var equipped_dyes: Dictionary = {}

func _ready() -> void:
    pass

func get_palette() -> Array:
    return DEFAULT_PALETTE

func unlocked_palette() -> Array:
    var unlocked: Array[String] = GameState.unlocked_dye_colors
    return DEFAULT_PALETTE.filter(func(d): return unlocked.has(d["id"]))

func color_for(color_id: String) -> Color:
    for d in DEFAULT_PALETTE:
        if d["id"] == color_id:
            return d["color"]
    return Color.WHITE

func set_dye(slot: String, color_id: String) -> void:
    equipped_dyes[slot] = color_id

func dye_for(slot: String) -> Color:
    if equipped_dyes.has(slot):
        return color_for(equipped_dyes[slot])
    return Color.WHITE

func save_dye_set(name: String) -> void:
    GameState.saved_dye_sets[name] = equipped_dyes.duplicate(true)

func load_dye_set(name: String) -> bool:
    if not GameState.saved_dye_sets.has(name):
        return false
    equipped_dyes = (GameState.saved_dye_sets[name] as Dictionary).duplicate(true)
    return true

func can_apply(slot: String, color_id: String) -> bool:
    return GameState.unlocked_dye_colors.has(color_id) and GameState.dye_pots.get(color_id, 0) > 0

func apply_dye(slot: String, color_id: String) -> bool:
    if not can_apply(slot, color_id):
        # Free preview if owned by palette but no pot — only commit when pot consumed
        if GameState.unlocked_dye_colors.has(color_id):
            set_dye(slot, color_id)
            return true
        return false
    GameState.consume_dye(color_id)
    set_dye(slot, color_id)
    return true

func unlock_color(color_id: String) -> void:
    if not GameState.unlocked_dye_colors.has(color_id):
        GameState.unlocked_dye_colors.append(color_id)

func random_drop_color() -> String:
    # Drop from pool weighted by rarity (lower rarity drops more often).
    var weights := []
    for d in DEFAULT_PALETTE:
        weights.append(max(1, 8 - int(d["rarity"]) * 2))
    var total := 0
    for w in weights:
        total += int(w)
    var r := randi() % total
    var acc := 0
    for i in range(weights.size()):
        acc += int(weights[i])
        if r < acc:
            return DEFAULT_PALETTE[i]["id"]
    return "white"
