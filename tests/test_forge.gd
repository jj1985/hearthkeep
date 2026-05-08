extends GutTest

# Forge crafting Phase A — data layer + craft() pipeline.

func test_forms_loaded() -> void:
    assert_eq(Forge.FORMS.size(), 5, "5 weapon forms expected (sword, axe, mace, dagger, polearm)")
    var ids: Array = []
    for f in Forge.FORMS:
        ids.append(f["id"])
    for expected in ["sword", "axe", "mace", "dagger", "polearm"]:
        assert_true(ids.has(expected))

func test_primary_materials_loaded() -> void:
    assert_eq(Forge.PRIMARY_MATS.size(), 6)

func test_secondary_materials_loaded() -> void:
    assert_eq(Forge.SECONDARY_MATS.size(), 5)

func test_embellishments_loaded() -> void:
    assert_eq(Forge.EMBELLISHMENTS.size(), 5)

func test_lookup_helpers() -> void:
    assert_eq(Forge.get_form("sword").get("name", ""), "Sword")
    assert_eq(Forge.get_primary_material("steel").get("name", ""), "Steel")
    assert_eq(Forge.get_secondary_material("silk").get("name", ""), "Silk-Wrapped")
    assert_true(Forge.get_form("bogus").is_empty())

# ---- craft() pipeline ----

func test_craft_requires_form_and_primary() -> void:
    assert_true(Forge.craft({}).is_empty(), "Empty selections must yield no item")
    assert_true(Forge.craft({"form": "sword"}).is_empty(),
        "Form alone is insufficient — primary material is required")

func test_craft_basic_iron_sword() -> void:
    var item: Dictionary = Forge.craft({"form": "sword", "primary": "iron", "secondary": "oak", "skill_level": 1})
    assert_false(item.is_empty())
    assert_eq(item["form"], "sword")
    assert_eq(item["primary_material"], "iron")
    assert_eq(item["slot"], "main_hand")
    var stats: Dictionary = item["stats"]
    assert_true(stats["dmg_min"] >= 8, "Iron sword min dmg should be at least 8 (form base) at quality 0")
    assert_true(stats["dmg_max"] >= 14)

func test_craft_steel_sword_does_more_damage_than_iron() -> void:
    Forge.rng.seed = 42
    var iron: Dictionary = Forge.craft({"form": "sword", "primary": "iron", "secondary": "oak", "skill_level": 1})
    Forge.rng.seed = 42
    var steel: Dictionary = Forge.craft({"form": "sword", "primary": "steel", "secondary": "oak", "skill_level": 1})
    assert_gt(int(steel["stats"]["dmg_max"]), int(iron["stats"]["dmg_max"]),
        "Steel mult 1.20 must out-damage Iron mult 1.00 at the same quality")

func test_craft_with_embellishment_adds_affix() -> void:
    var item: Dictionary = Forge.craft({
        "form": "sword", "primary": "steel", "secondary": "leather",
        "embellishment": "fire_gem", "skill_level": 1,
    })
    assert_true(item["stats"].has("fire_dmg"), "Ember Gem should add fire_dmg affix")
    assert_true(float(item["stats"]["fire_dmg"]) >= 4.0)
    assert_eq(item["embellishment"], "fire_gem")

func test_craft_engraving_appears_in_name() -> void:
    var item: Dictionary = Forge.craft({
        "form": "axe", "primary": "iron", "secondary": "oak",
        "engraving": "Bladekiss", "skill_level": 1,
    })
    assert_true(String(item["name"]).contains("Bladekiss"), "Engraving must appear in the item name")
    assert_true(String(item["name"]).contains("\""), "Engravings render in quote marks")

func test_craft_quality_climbs_with_skill() -> void:
    # Statistical assertion — at skill 5, the average quality across
    # 100 rolls should comfortably exceed skill 1.
    Forge.rng.seed = 7
    var lo_total: int = 0
    var hi_total: int = 0
    for i in range(100):
        lo_total += int(Forge.craft({"form": "sword", "primary": "iron", "secondary": "oak", "skill_level": 1})["quality"])
    for i in range(100):
        hi_total += int(Forge.craft({"form": "sword", "primary": "iron", "secondary": "oak", "skill_level": 5})["quality"])
    assert_gt(hi_total, lo_total + 50, "High-skill crafting should average a meaningfully higher quality")

func test_embellishment_bumps_rarity_one_tier() -> void:
    Forge.rng.seed = 99
    var plain: Dictionary = Forge.craft({"form": "sword", "primary": "iron", "secondary": "oak", "skill_level": 1})
    Forge.rng.seed = 99
    var fancy: Dictionary = Forge.craft({"form": "sword", "primary": "iron", "secondary": "oak", "embellishment": "rune_str", "skill_level": 1})
    assert_eq(int(fancy["rarity"]), int(plain["rarity"]) + 1,
        "Embellished items climb exactly one rarity tier above their base quality tier")

func test_craft_tags_union_form_and_materials() -> void:
    var item: Dictionary = Forge.craft({
        "form": "dagger",       # tags: physical, stealth, crit
        "primary": "mithril",   # tags: light, crit
        "secondary": "silk",    # tags: finesse
    })
    var tags: Array = item["tags"]
    for expected in ["physical", "stealth", "crit", "light", "finesse"]:
        assert_true(tags.has(expected), "Combined tag set missing '%s'" % expected)
    var crit_count: int = 0
    for t in tags:
        if t == "crit": crit_count += 1
    assert_eq(crit_count, 1, "Tags must be deduplicated")
