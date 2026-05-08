extends GutTest

# Tests for class selection state flow:
# - RunState carries class_primary / class_secondary across the title→run boundary
# - Player.gd reads them from RunState rather than hardcoding "warrior"
# - Combined stat profile is applied when a secondary is set

func before_each() -> void:
    RunState.class_primary = "warrior"
    RunState.class_secondary = ""
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
