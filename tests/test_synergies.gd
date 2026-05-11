extends GutTest

const Synergies := preload("res://scripts/incremental/synergies.gd")

func test_empty_loadout_returns_empty() -> void:
    assert_true(Synergies.for_loadout("", "", "").is_empty())
    assert_true(Synergies.for_loadout("warrior", "", "").is_empty())

func test_warrior_rogue_resolves_to_vanguard() -> void:
    var d := Synergies.for_loadout("warrior", "rogue", "")
    assert_eq(String(d["label"]), "Vanguard")
    assert_almost_eq(float(d["atk_speed_bonus"]), 0.15, 0.001)

func test_pair_is_order_independent() -> void:
    var a := Synergies.for_loadout("warrior", "rogue", "")
    var b := Synergies.for_loadout("rogue", "warrior", "")
    assert_eq(String(a["label"]), String(b["label"]))

func test_triple_warrior_rogue_wizard_resolves_to_triumvirate() -> void:
    var d := Synergies.for_loadout("warrior", "rogue", "wizard")
    assert_eq(String(d["label"]), "Triumvirate")
    assert_almost_eq(float(d["dmg_mult"]), 0.25, 0.001)

func test_triple_returns_pair_when_no_trio_match() -> void:
    # warrior+rogue is Vanguard; adding bard makes no trio so we should
    # still get a *pair* synergy from the first two slots.
    var d := Synergies.for_loadout("warrior", "rogue", "bard")
    # Result must be a defined synergy, not empty.
    assert_false(d.is_empty())
