extends GutTest

# Horde Arena milestone gating.

func before_each() -> void:
    GameState.unlocked_classes = ["warrior"] as Array[String]
    GameState.lifetime_kills = 0
    GameState.deepest_floor = 0
    GameState.gold = 0
    GameState.meta_unlocks["milestones"] = {}
    HordeState.reset_run()

func test_starts_with_only_warrior_unlocked() -> void:
    assert_eq(GameState.unlocked_classes.size(), 1)
    assert_true(GameState.unlocked_classes.has("warrior"))

func test_kill_milestone_unlocks_rogue_at_100_kills() -> void:
    for i in 100:
        HordeState.record_kill("skeleton", 0)
    assert_true(GameState.unlocked_classes.has("rogue"))

func test_kill_milestones_only_fire_once() -> void:
    var count := [0]
    HordeState.class_unlocked.connect(func(_cid: String): count[0] += 1)
    for i in 200:
        HordeState.record_kill("skeleton", 0)
    # rogue at 100 — should fire exactly once even with 200 kills total
    assert_eq(count[0], 1)

func test_secondary_slot_locked_until_wave_10() -> void:
    assert_false(HordeState.can_pick_secondary())
    for i in 9:
        HordeState.advance_wave()  # wave starts at 1, +9 → wave 10 → milestone fires
    assert_true(HordeState.can_pick_secondary())

func test_tertiary_slot_locked_until_wave_25() -> void:
    assert_false(HordeState.can_pick_tertiary())
    for i in 24:
        HordeState.advance_wave()
    assert_true(HordeState.can_pick_tertiary())

func test_slot_unlock_signal_fires_with_correct_slot() -> void:
    var seen: Array[String] = []
    HordeState.slot_unlocked.connect(func(s: String): seen.append(s))
    for i in 9: HordeState.advance_wave()  # wave 10
    assert_true(seen.has("secondary"))
    for i in 15: HordeState.advance_wave()  # wave 25
    assert_true(seen.has("tertiary"))

func test_available_classes_excludes_already_picked() -> void:
    GameState.unlocked_classes = ["warrior", "rogue", "wizard"] as Array[String]
    HordeState.primary = "warrior"
    HordeState.secondary = "rogue"
    var avail := HordeState.available_classes_for_extra_slot()
    assert_true(avail.has("wizard"))
    assert_false(avail.has("warrior"))
    assert_false(avail.has("rogue"))

func test_record_kill_grants_gold() -> void:
    HordeState.record_kill("goblin", 5)
    assert_eq(GameState.gold, 5)
    assert_eq(GameState.lifetime_kills, 1)

func test_advance_wave_updates_deepest_floor() -> void:
    HordeState.advance_wave()
    HordeState.advance_wave()
    assert_eq(GameState.deepest_floor, 3)

func test_next_kill_milestone_walks_through_classes() -> void:
    var first := HordeState.next_kill_milestone()
    assert_eq(String(first["class"]), "rogue")
    GameState.lifetime_kills = 100
    HordeState._check_kill_milestones()
    var second := HordeState.next_kill_milestone()
    assert_eq(String(second["class"]), "wizard")

func test_next_wave_milestone_returns_dual_then_triple() -> void:
    var first := HordeState.next_wave_milestone()
    assert_eq(String(first["slot"]), "secondary")

func test_next_milestones_empty_when_all_claimed() -> void:
    GameState.meta_unlocks["milestones"] = {
        "unlock_rogue": true, "unlock_wizard": true,
        "unlock_necromancer": true, "unlock_bard": true,
        "unlock_dual": true, "unlock_triple": true,
    }
    assert_true(HordeState.next_kill_milestone().is_empty())
    assert_true(HordeState.next_wave_milestone().is_empty())

func test_reset_run_clears_run_state_but_not_lifetime() -> void:
    HordeState.record_kill("skeleton", 0)
    HordeState.advance_wave()
    HordeState.secondary = "rogue"
    HordeState.reset_run()
    assert_eq(HordeState.kills_this_run, 0)
    assert_eq(HordeState.wave, 1)
    assert_eq(HordeState.secondary, "")
    # Lifetime preserved
    assert_eq(GameState.lifetime_kills, 1)
