extends GutTest

func test_data_tables_loaded() -> void:
    assert_eq(Workbench.MOUNTS.size(), 4)
    assert_eq(Workbench.STONES.size(), 5)
    assert_eq(Workbench.INSCRIPTIONS.size(), 5)

func test_lookup_helpers() -> void:
    assert_eq(Workbench.get_mount("ring").get("name", ""), "Ring")
    assert_eq(Workbench.get_stone("ruby").get("stat", ""), "fire_dmg")
    assert_eq(Workbench.get_inscription("rune_str").get("bonus_stat", ""), "str")

func test_craft_requires_mount_and_stone() -> void:
    assert_true(Workbench.craft({}).is_empty())
    assert_true(Workbench.craft({"mount": "ring"}).is_empty())

func test_craft_basic_ring() -> void:
    var item: Dictionary = Workbench.craft({"mount": "ring", "stone": "agate"})
    assert_eq(item["slot"], "ring")
    assert_eq(item["kind"], "accessory")
    assert_true(item["stats"].has("crit_chance"))
    assert_gt(float(item["stats"]["crit_chance"]), 0.0)

func test_amulet_stat_mult_outweighs_ring() -> void:
    Workbench.rng.seed = 42
    var ring_item: Dictionary = Workbench.craft({"mount": "ring", "stone": "ruby"})
    Workbench.rng.seed = 42
    var amulet_item: Dictionary = Workbench.craft({"mount": "amulet", "stone": "ruby"})
    assert_gt(float(amulet_item["stats"]["fire_dmg"]), float(ring_item["stats"]["fire_dmg"]),
        "Amulet 1.4× mount mult should out-stat the same Ring craft")

func test_inscription_adds_bonus_stat_and_bumps_rarity() -> void:
    Workbench.rng.seed = 7
    var plain: Dictionary = Workbench.craft({"mount": "ring", "stone": "agate"})
    Workbench.rng.seed = 7
    var runed: Dictionary = Workbench.craft({"mount": "ring", "stone": "agate", "inscription": "rune_str"})
    assert_true(runed["stats"].has("str"), "Rune of Bear should add str stat")
    assert_eq(int(runed["rarity"]), int(plain["rarity"]) + 1,
        "Inscriptions bump rarity by 1 tier")
