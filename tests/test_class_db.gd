extends GutTest

# Multiclass core: tag merging, hybrid prestige lookup, and combined stat
# profile / resource computation. Lives in ClassDB autoload (registered as
# `Classes` to avoid the engine's built-in ClassDB).

# ---- combined_tags ---------------------------------------------------------

func test_combined_tags_single_class_returns_own_tags() -> void:
    var tags: Array = Classes.combined_tags("warrior")
    assert_true(tags.has("physical"))
    assert_true(tags.has("melee"))
    assert_true(tags.has("frontline"))
    assert_eq(tags.size(), 3, "Warrior alone should have 3 tags")

func test_combined_tags_dedups_overlap() -> void:
    # warrior + paladin both have physical + melee — should not duplicate.
    var tags: Array = Classes.combined_tags("warrior", "paladin")
    var counts: Dictionary = {}
    for t in tags:
        counts[t] = counts.get(t, 0) + 1
    for t in counts:
        assert_eq(counts[t], 1, "Tag '%s' duplicated in combined set" % t)
    # Should contain the union: physical, melee, frontline, holy, support
    for expected in ["physical", "melee", "frontline", "holy", "support"]:
        assert_true(tags.has(expected), "Expected tag '%s' missing" % expected)

func test_combined_tags_disjoint_classes_unions() -> void:
    var tags: Array = Classes.combined_tags("warrior", "wizard")
    for expected in ["physical", "melee", "frontline", "caster", "fire", "frost", "lightning", "aoe"]:
        assert_true(tags.has(expected), "Expected tag '%s' missing" % expected)

func test_combined_tags_empty_secondary_same_as_single() -> void:
    var only: Array = Classes.combined_tags("rogue")
    var with_empty: Array = Classes.combined_tags("rogue", "")
    assert_eq(only.size(), with_empty.size())

# ---- hybrid_for ------------------------------------------------------------

func test_hybrid_for_returns_empty_when_no_match() -> void:
    var h: Dictionary = Classes.hybrid_for("warrior", "warrior")
    assert_true(h.is_empty(), "Same-class pairing must not be a hybrid prestige")

func test_hybrid_for_unknown_pair_returns_empty() -> void:
    var h: Dictionary = Classes.hybrid_for("warrior", "bogus")
    assert_true(h.is_empty())

func test_hybrid_for_warrior_necromancer_is_death_knight() -> void:
    var h: Dictionary = Classes.hybrid_for("warrior", "necromancer")
    assert_eq(h.get("id", ""), "death_knight")
    assert_eq(h.get("name", ""), "Death Knight")

func test_hybrid_for_is_order_insensitive() -> void:
    var ab: Dictionary = Classes.hybrid_for("rogue", "wizard")
    var ba: Dictionary = Classes.hybrid_for("wizard", "rogue")
    assert_eq(ab.get("id", ""), ba.get("id", ""))
    assert_eq(ab.get("id", ""), "shadow_blade")

func test_all_ten_hybrid_pairs_resolve_both_orders() -> void:
    for h in Classes.HYBRID_PRESTIGES:
        var req: Array = h["require"]
        var ab: Dictionary = Classes.hybrid_for(req[0], req[1])
        var ba: Dictionary = Classes.hybrid_for(req[1], req[0])
        assert_eq(ab.get("id"), h["id"], "Forward lookup failed for %s" % h["id"])
        assert_eq(ba.get("id"), h["id"], "Reverse lookup failed for %s" % h["id"])

# ---- combined stat profile -------------------------------------------------

func test_combined_stat_profile_single_class_passthrough() -> void:
    var p: Dictionary = Classes.combined_stat_profile("warrior")
    var w: Dictionary = Classes.get_class_def("warrior")["stat_profile"]
    assert_eq(p["str"], w["str"])
    assert_eq(p["agi"], w["agi"])
    assert_eq(p["int"], w["int"])
    assert_eq(p["sta"], w["sta"])

func test_combined_stat_profile_weights_60_40_to_primary() -> void:
    # Primary = warrior (str 12, agi 7, int 4, sta 11)
    # Secondary = wizard (str 4, agi 6, int 15, sta 6)
    # Expected (round to int): str = 12*.6 + 4*.4 = 8.8 → 9
    #                          agi = 7*.6 + 6*.4   = 6.6 → 7
    #                          int = 4*.6 + 15*.4  = 8.4 → 8
    #                          sta = 11*.6 + 6*.4  = 9.0 → 9
    var p: Dictionary = Classes.combined_stat_profile("warrior", "wizard")
    assert_eq(int(p["str"]), 9)
    assert_eq(int(p["agi"]), 7)
    assert_eq(int(p["int"]), 8)
    assert_eq(int(p["sta"]), 9)

func test_combined_stat_profile_is_order_dependent() -> void:
    var ab: Dictionary = Classes.combined_stat_profile("warrior", "wizard")
    var ba: Dictionary = Classes.combined_stat_profile("wizard", "warrior")
    assert_ne(int(ab["str"]), int(ba["str"]),
        "Primary class is weighted higher; warrior-primary str must exceed wizard-primary str")
    assert_gt(int(ab["str"]), int(ba["str"]))

# ---- combined resources (HP / MP / armor) ----------------------------------

func test_combined_resources_single_class_passthrough() -> void:
    var r: Dictionary = Classes.combined_resources("wizard")
    assert_eq(int(r["hp"]), 85)
    assert_eq(int(r["mp"]), 120)
    assert_eq(int(r["armor"]), 2)

func test_combined_resources_60_40_weighted() -> void:
    # warrior 160hp/40mp/8arm + wizard 85hp/120mp/2arm  (warrior primary)
    # hp = 160*.6 + 85*.4 = 96 + 34 = 130
    # mp = 40*.6 + 120*.4 = 24 + 48 = 72
    # arm = 8*.6 + 2*.4 = 4.8 + 0.8 = 5.6 → 5 (int truncate) or 6 (round). Pick round.
    var r: Dictionary = Classes.combined_resources("warrior", "wizard")
    assert_eq(int(r["hp"]), 130)
    assert_eq(int(r["mp"]), 72)
    assert_almost_eq(float(r["armor"]), 5.6, 0.01)

# ---- has_tag (synergy gating) ----------------------------------------------

func test_has_tag_checks_combined_set() -> void:
    # Death Knight = warrior + necromancer: should have 'shadow' (from necro)
    # AND 'physical' (from warrior).
    assert_true(Classes.has_tag("warrior", "necromancer", "shadow"))
    assert_true(Classes.has_tag("warrior", "necromancer", "physical"))
    assert_false(Classes.has_tag("warrior", "necromancer", "holy"))
