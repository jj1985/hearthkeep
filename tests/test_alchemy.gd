extends GutTest

func test_data_tables_loaded() -> void:
    assert_eq(Alchemy.VESSELS.size(), 5)
    assert_eq(Alchemy.REAGENTS.size(), 6)
    assert_eq(Alchemy.CATALYSTS.size(), 5)
    assert_eq(Alchemy.QUALITY_TIERS.size(), 5)

func test_lookup_helpers() -> void:
    assert_eq(Alchemy.get_vessel("flask").get("name", ""), "Glass Flask")
    assert_eq(Alchemy.get_reagent("drake_blood").get("name", ""), "Drake Blood")
    assert_eq(Alchemy.get_catalyst("ember_pearl").get("name", ""), "Ember Pearl")
    assert_true(Alchemy.get_vessel("bogus").is_empty())

func test_craft_requires_vessel_and_reagent() -> void:
    assert_true(Alchemy.craft({}).is_empty())
    assert_true(Alchemy.craft({"vessel": "flask"}).is_empty())

func test_craft_basic_heal_potion() -> void:
    var item: Dictionary = Alchemy.craft({"vessel": "flask", "reagent": "red_mossroot"})
    assert_false(item.is_empty())
    assert_eq(item["kind"], "consumable")
    assert_eq(item["school"], "heal")
    assert_true(item["tags"].has("potion"))
    assert_true(item["tags"].has("heal"))
    assert_gt(float(item["stats"]["potency"]), 0.0)
    assert_gt(float(item["stats"]["duration"]), 0.0)

func test_drake_blood_bumps_rarity_one_tier() -> void:
    Alchemy.rng.seed = 7
    var basic: Dictionary = Alchemy.craft({"vessel": "flask", "reagent": "blue_lichen"})
    Alchemy.rng.seed = 7
    var fancy: Dictionary = Alchemy.craft({"vessel": "flask", "reagent": "drake_blood"})
    assert_gt(int(fancy["rarity"]), int(basic["rarity"]),
        "Drake Blood (potency 1.7) should bump rarity above blue_lichen baseline")

func test_dragons_tear_bumps_rarity_two_tiers() -> void:
    Alchemy.rng.seed = 11
    var basic: Dictionary = Alchemy.craft({"vessel": "flask", "reagent": "red_mossroot"})
    Alchemy.rng.seed = 11
    var miraculous: Dictionary = Alchemy.craft({"vessel": "flask", "reagent": "dragons_tear"})
    var delta: int = int(miraculous["rarity"]) - int(basic["rarity"])
    assert_eq(delta, 2, "Dragon's Tear should bump rarity by exactly 2 tiers (capped at 5)")

func test_catalyst_potency_mult_applied() -> void:
    Alchemy.rng.seed = 99
    var plain: Dictionary = Alchemy.craft({"vessel": "flask", "reagent": "red_mossroot"})
    Alchemy.rng.seed = 99
    var ember: Dictionary = Alchemy.craft({"vessel": "flask", "reagent": "red_mossroot", "catalyst": "ember_pearl"})
    assert_gt(float(ember["stats"]["potency"]), float(plain["stats"]["potency"]),
        "Ember Pearl 1.5x catalyst should out-potency a plain craft")

func test_oil_jar_kind_is_weapon_buff() -> void:
    var item: Dictionary = Alchemy.craft({"vessel": "oil_jar", "reagent": "sulfur_petal"})
    assert_eq(item["kind"], "weapon_buff")
    assert_true(item["tags"].has("oil"))
    assert_true(item["tags"].has("fire"))
