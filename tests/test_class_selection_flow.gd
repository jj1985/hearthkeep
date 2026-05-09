extends GutTest

# Tests for class selection state flow:
# - RunState carries class_primary / class_secondary across the title→run boundary
# - Player.gd reads them from RunState rather than hardcoding "warrior"
# - Combined stat profile is applied when a secondary is set

func before_each() -> void:
    RunState.class_primary = "warrior"
    RunState.class_secondary = ""
    RunState.class_tertiary = ""
    RunState.start_run(0)

# ---- RunState carries class selection -------------------------------------

func test_run_state_defaults_class_primary_to_warrior() -> void:
    assert_eq(RunState.class_primary, "warrior", "Default primary should be warrior")
    assert_eq(RunState.class_secondary, "", "Default secondary should be empty")

func test_run_state_persists_class_selection_across_start_run() -> void:
    RunState.set_classes("rogue", "wizard")
    RunState.start_run(42)
    assert_eq(RunState.class_primary, "rogue", "Class selection must survive start_run")
    assert_eq(RunState.class_secondary, "wizard")

func test_run_state_set_classes_rejects_unknown_primary() -> void:
    var ok: bool = RunState.set_classes("bogus", "")
    assert_false(ok, "Unknown class id must be rejected")
    assert_eq(RunState.class_primary, "warrior", "Bad input should not corrupt state")

func test_run_state_set_classes_clears_secondary_when_blank() -> void:
    RunState.set_classes("rogue", "wizard")
    RunState.set_classes("paladin", "")
    assert_eq(RunState.class_primary, "paladin")
    assert_eq(RunState.class_secondary, "")

# ---- Resolved hybrid prestige ----------------------------------------------

func test_run_state_exposes_hybrid_prestige_when_pair_matches() -> void:
    RunState.set_classes("warrior", "necromancer")
    var h: Dictionary = RunState.hybrid_prestige()
    assert_eq(h.get("id", ""), "death_knight")

func test_run_state_hybrid_prestige_empty_when_no_secondary() -> void:
    RunState.set_classes("warrior", "")
    assert_true(RunState.hybrid_prestige().is_empty())

# ---- Triple-class slot ----------------------------------------------------

func test_run_state_set_classes_accepts_three_classes() -> void:
    var ok: bool = RunState.set_classes("warrior", "wizard", "rogue")
    assert_true(ok)
    assert_eq(RunState.class_tertiary, "rogue")

func test_run_state_set_classes_drops_tertiary_when_dupes_primary() -> void:
    RunState.set_classes("warrior", "wizard", "warrior")
    assert_eq(RunState.class_tertiary, "", "Tertiary equal to primary must be dropped")

func test_run_state_set_classes_rejects_unknown_tertiary() -> void:
    var ok: bool = RunState.set_classes("warrior", "wizard", "bogus")
    assert_false(ok)

func test_player_resources_use_triple_blend_when_tertiary_set() -> void:
    # Spawn a player with triple-class set; max_hp must match the
    # 50/30/20 blend, not the 60/40 blend.
    RunState.set_classes("warrior", "wizard", "rogue")
    var player_scene: PackedScene = load("res://scenes/player/player.tscn")
    var p: Node = player_scene.instantiate()
    p.class_primary = RunState.class_primary
    p.class_secondary = RunState.class_secondary
    p.class_tertiary = RunState.class_tertiary
    add_child_autofree(p)
    # warrior 160 + wizard 85 + rogue 110 → 80 + 25.5 + 22 = 127.5
    assert_almost_eq(float(p.stats.max_hp), 127.5, 1.0)
