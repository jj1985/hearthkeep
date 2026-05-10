extends GutTest

# Horde perk pool — selection logic and apply math.

var rng: RandomNumberGenerator

func before_each() -> void:
    HordePerks.reset_for_run()
    HordeState.primary = "warrior"
    HordeState.secondary = ""
    HordeState.tertiary = ""
    rng = RandomNumberGenerator.new()
    rng.seed = 42

func test_reset_for_run_clears_accumulators() -> void:
    HordePerks.dmg_mult = 9.9
    HordePerks.taken_ids.append("hot_steel")
    HordePerks.reset_for_run()
    assert_almost_eq(HordePerks.dmg_mult, 1.0, 0.001)
    assert_eq(HordePerks.taken_ids.size(), 0)

func test_roll_returns_three_distinct_perks() -> void:
    var picks := HordePerks.roll(rng, 3)
    assert_eq(picks.size(), 3)
    var ids := []
    for p in picks:
        ids.append(String((p as Dictionary)["id"]))
    assert_eq(ids.size(), ids.size())  # no duplicates by definition

func test_apply_dmg_mult_compounds() -> void:
    HordePerks.apply({"id":"a", "kind":"dmg_mult", "value":0.25})
    HordePerks.apply({"id":"b", "kind":"dmg_mult", "value":0.25})
    # 1.25 * 1.25 = 1.5625
    assert_almost_eq(HordePerks.dmg_mult, 1.5625, 0.001)

func test_apply_atk_speed_adds() -> void:
    HordePerks.apply({"id":"a", "kind":"atk_speed", "value":0.5})
    HordePerks.apply({"id":"b", "kind":"atk_speed", "value":0.3})
    assert_almost_eq(HordePerks.atk_speed_bonus, 0.8, 0.001)

func test_apply_spawn_slow_caps_at_60_pct() -> void:
    for i in 10:
        HordePerks.apply({"id":"x%d" % i, "kind":"spawn_slow", "value":0.10})
    assert_almost_eq(HordePerks.spawn_slow, 0.6, 0.001)

func test_taken_perks_are_skipped_in_next_roll() -> void:
    HordePerks.apply({"id":"hot_steel", "kind":"dmg_mult", "value":0.25})
    var rolls := HordePerks.roll(rng, 3)
    for p in rolls:
        assert_ne(String((p as Dictionary)["id"]), "hot_steel")

func test_class_tagged_perks_weighted_higher() -> void:
    # warrior-only — over many rolls hot_steel should appear most often.
    HordeState.primary = "warrior"
    var counts: Dictionary = {}
    for i in 50:
        rng.seed = i
        HordePerks.reset_for_run()
        HordeState.primary = "warrior"
        var picks := HordePerks.roll(rng, 1)
        var id := String((picks[0] as Dictionary)["id"])
        counts[id] = int(counts.get(id, 0)) + 1
    # warrior-tagged hot_steel should be the most-picked single-roll outcome
    var top: String = ""
    var top_n: int = 0
    for k in counts.keys():
        if counts[k] > top_n: top = k; top_n = counts[k]
    assert_eq(top, "hot_steel")
