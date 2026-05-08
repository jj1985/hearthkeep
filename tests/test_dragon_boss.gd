extends GutTest

# Dragon boss state machine — phase transitions on HP thresholds, ability
# cooldown management, one-shot phase-entered hook, idempotent death.

const DragonBoss := preload("res://scripts/entities/dragon_boss.gd")

var boss: DragonBoss

func before_each() -> void:
    boss = DragonBoss.new()
    boss.max_hp = 1000.0
    boss.hp = 1000.0
    boss.register_ability("breath", 4.0)
    boss.register_ability("dive", 7.0)
    boss.register_ability("rupture", 3.0)

func after_each() -> void:
    if is_instance_valid(boss):
        boss.free()

# ---- Phase transitions on HP thresholds ----

func test_starts_in_ground_phase() -> void:
    assert_eq(boss.phase, DragonBoss.Phase.GROUND)

func test_transitions_to_air_below_70_pct() -> void:
    boss.take_damage(301.0)    # 1000 → 699 = 69.9%
    assert_eq(boss.phase, DragonBoss.Phase.AIR)

func test_transitions_to_enraged_below_33_pct() -> void:
    boss.take_damage(671.0)    # 1000 → 329 = 32.9%
    assert_eq(boss.phase, DragonBoss.Phase.ENRAGED)

func test_phase_transition_only_fires_once_per_threshold_cross() -> void:
    var hits: Array[int] = []
    boss.phase_entered.connect(func(p): hits.append(p))
    boss.take_damage(310.0)    # ground → air
    boss.take_damage(10.0)     # still air; should not refire
    assert_eq(hits.size(), 1)
    assert_eq(hits[0], int(DragonBoss.Phase.AIR))
    boss.take_damage(370.0)    # air → enraged
    assert_eq(hits.size(), 2)
    assert_eq(hits[1], int(DragonBoss.Phase.ENRAGED))

func test_phases_do_not_revert_on_heal() -> void:
    boss.take_damage(310.0)    # ground → air
    boss.heal(500.0)           # HP back to 1000
    assert_eq(boss.phase, DragonBoss.Phase.AIR,
        "Phases are one-way; healing should not unwind the fight")

# ---- Death semantics ----

func test_take_damage_clamps_at_zero_and_marks_dead() -> void:
    boss.take_damage(2000.0)
    assert_eq(boss.hp, 0.0)
    assert_true(boss.is_dead())

func test_dies_signal_fires_once() -> void:
    var dies := [0]    # array capture so the lambda can mutate-by-reference
    boss.died.connect(func(): dies[0] += 1)
    boss.take_damage(2000.0)
    boss.take_damage(100.0)    # already dead — should not refire
    assert_eq(dies[0], 1)

# ---- Ability cooldown management ----

func test_ability_registered_starts_off_cooldown() -> void:
    assert_true(boss.is_ability_ready("breath"))
    assert_false(boss.is_ability_ready("not_registered"))

func test_consume_ability_starts_cooldown() -> void:
    assert_true(boss.consume_ability("breath"))
    assert_false(boss.is_ability_ready("breath"))

func test_consume_ability_returns_false_when_on_cooldown() -> void:
    boss.consume_ability("breath")
    assert_false(boss.consume_ability("breath"))

func test_tick_decrements_cooldowns() -> void:
    boss.consume_ability("breath")    # 4.0s cooldown
    boss.tick(2.0)
    assert_false(boss.is_ability_ready("breath"))
    boss.tick(2.5)                    # total 4.5s elapsed
    assert_true(boss.is_ability_ready("breath"))

func test_phase_change_resets_all_cooldowns() -> void:
    boss.consume_ability("breath")
    boss.consume_ability("dive")
    boss.consume_ability("rupture")
    assert_false(boss.is_ability_ready("breath"))
    boss.take_damage(310.0)
    assert_true(boss.is_ability_ready("breath"))
    assert_true(boss.is_ability_ready("dive"))
    assert_true(boss.is_ability_ready("rupture"))
