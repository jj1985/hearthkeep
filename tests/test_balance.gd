extends GutTest

# Sanity bounds on the difficulty curve.

const HordeArena := preload("res://scripts/incremental/horde_arena.gd")

func _enemy_hp_at_wave(id: String, wave: int) -> int:
    var def: Dictionary = HordeArena.ENEMY_TYPES[id]
    var hp_scale: float = 1.0 + (wave - 1) * 0.18
    return int(round(int(def["hp_base"]) * hp_scale))

func before_each() -> void:
    GameState.gold = 0
    GameState.embers = 0
    GameState.meta_unlocks["upgrades"] = {}

func test_skeleton_dies_in_one_hit_with_baseline_damage() -> void:
    # Baseline damage = HERO_DAMAGE_BASE (4) + small wave bonus.
    var hp := _enemy_hp_at_wave("skeleton", 1)
    assert_true(hp <= 8, "skeleton HP at wave 1 = %d" % hp)

func test_wave10_boss_killable_with_modest_upgrades() -> void:
    # Stand-in for "is the first boss reasonable for an early-game player?"
    # Assume rank 5 in damage + atk_speed + 1 ember rank.
    var dmg_per_hit: int = 4 + 5 * 2          # base + Sharper Steel rank 5 = 14
    dmg_per_hit = int(dmg_per_hit * 1.10)     # Ember Edge rank 1 ≈ 15
    var atk_per_sec: float = 2.5 + 5 * 0.20   # Practiced Form rank 5 = 3.5/s
    var dps: float = dmg_per_hit * atk_per_sec
    var hp := _enemy_hp_at_wave("boss_warchief", 10)
    var ttk: float = hp / dps
    assert_lt(ttk, 30.0,
        "Wave-10 boss should die in <30s with modest upgrades, got %.1fs" % ttk)

func test_late_boss_requires_deep_investment() -> void:
    # Without upgrades, a wave-30 dragon boss should NOT be a 10s fight.
    var dmg_per_hit: int = 4 + 30 / 2          # base + wave bonus = 19
    var dps: float = dmg_per_hit * 2.5
    var hp := _enemy_hp_at_wave("boss_dragon", 30)
    var ttk: float = hp / dps
    assert_gt(ttk, 60.0,
        "Wave-30 boss without upgrades should be a slog, got %.1fs" % ttk)
