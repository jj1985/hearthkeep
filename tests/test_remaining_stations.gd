extends GutTest

# Coverage for the 4 remaining crafting stations (Atelier / Loom /
# Cooking / Engraving). All follow the same craft(selections) shape.

func test_atelier_basic_scroll() -> void:
    var item: Dictionary = Atelier.craft({"form": "scroll", "sigil": "haste"})
    assert_false(item.is_empty())
    assert_eq(item["kind"], "buff_scroll")
    assert_eq(item["id"], "haste")
    assert_true(item["tags"].has("scroll"))

func test_atelier_requires_form_and_sigil() -> void:
    assert_true(Atelier.craft({}).is_empty())
    assert_true(Atelier.craft({"form": "scroll"}).is_empty())

func test_atelier_dragon_ink_higher_potency() -> void:
    Atelier.rng.seed = 99
    var basic: Dictionary = Atelier.craft({"form": "scroll", "sigil": "haste", "ink": "ash_ink"})
    Atelier.rng.seed = 99
    var fancy: Dictionary = Atelier.craft({"form": "scroll", "sigil": "haste", "ink": "dragon_ink"})
    assert_gt(float(fancy["stats"]["potency"]), float(basic["stats"]["potency"]))

func test_loom_basic_robe() -> void:
    var item: Dictionary = Loom.craft({"piece": "robe", "fabric": "linen"})
    assert_eq(item["slot"], "chest")
    assert_eq(item["kind"], "armor")
    assert_gt(float(item["stats"]["armor"]), 0.0)

func test_loom_trim_adds_stat_and_bumps_rarity() -> void:
    Loom.rng.seed = 42
    var plain: Dictionary = Loom.craft({"piece": "robe", "fabric": "silk"})
    Loom.rng.seed = 42
    var trimmed: Dictionary = Loom.craft({"piece": "robe", "fabric": "silk", "trim": "gold_thread"})
    assert_true(trimmed["stats"].has("magic_find"))
    assert_eq(int(trimmed["rarity"]), int(plain["rarity"]) + 1)

func test_loom_dragonsilk_armor_baseline() -> void:
    var item: Dictionary = Loom.craft({"piece": "robe", "fabric": "dragonsilk"})
    assert_gt(float(item["stats"]["armor"]), 8.0)
    assert_true(item["tags"].has("fire_res"))

func test_cooking_basic_dish() -> void:
    var item: Dictionary = Cooking.craft({"dish": "hot_stew", "staple": "bread"})
    assert_eq(item["kind"], "consumable")
    assert_eq(item["id"], "haste")
    assert_true(item["tags"].has("food"))

func test_cooking_saffron_potency() -> void:
    Cooking.rng.seed = 77
    var plain: Dictionary = Cooking.craft({"dish": "hot_stew", "staple": "bread", "spice": "salt"})
    Cooking.rng.seed = 77
    var saffron: Dictionary = Cooking.craft({"dish": "hot_stew", "staple": "bread", "spice": "saffron"})
    assert_gt(float(saffron["stats"]["potency"]), float(plain["stats"]["potency"]))

func test_engraving_modifies_existing_item() -> void:
    GameState.gold = 5000
    var sword: Dictionary = Forge.craft({"form": "sword", "primary": "iron", "secondary": "oak"})
    var orig_name: String = String(sword["name"])
    var orig_rarity: int = int(sword["rarity"])
    var engraved: Dictionary = Engraving.engrave(sword, "cinder", "Bladekiss")
    assert_false(engraved.is_empty())
    assert_true(String(engraved["name"]).contains("Bladekiss"))
    assert_true(engraved["stats"].has("fire_dmg"))
    assert_eq(int(engraved["rarity"]), orig_rarity + 1)

func test_engraving_costs_gold() -> void:
    GameState.gold = 5000
    var sword: Dictionary = Forge.craft({"form": "sword", "primary": "iron", "secondary": "oak"})
    var before: int = GameState.gold
    Engraving.engrave(sword, "cinder", "test")
    assert_eq(GameState.gold, before - Engraving.cost_for("cinder"))

func test_engraving_refuses_when_broke() -> void:
    GameState.gold = 100
    var sword: Dictionary = Forge.craft({"form": "sword", "primary": "iron", "secondary": "oak"})
    var result: Dictionary = Engraving.engrave(sword, "draconic", "")    # 1200 cost > 100
    assert_true(result.is_empty(), "Engrave should refuse when player can't afford")
    assert_eq(GameState.gold, 100, "Gold not consumed on refusal")
