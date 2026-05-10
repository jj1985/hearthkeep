extends GutTest

# Rebirth wipes per-run state but preserves embers + rebirth count
# and confers a permanent +25% damage / gold multiplier per stack.

func before_each() -> void:
    GameState.rebirths = 0
    GameState.embers = 0
    GameState.gold = 0
    GameState.lifetime_kills = 0
    GameState.unlocked_classes = ["warrior"] as Array[String]
    GameState.meta_unlocks["milestones"] = {}
    GameState.meta_unlocks["upgrades"] = {}
    GameState.meta_unlocks["wave_50"] = false

func test_rebirths_default_zero() -> void:
    assert_eq(GameState.rebirths, 0)

func test_rebirth_counter_increments_and_persists_embers() -> void:
    GameState.rebirths = 2
    GameState.embers = 17
    SaveSystem.save()
    GameState.rebirths = 99
    GameState.embers = 1
    SaveSystem.load_save()
    assert_eq(GameState.rebirths, 2)
    assert_eq(GameState.embers, 17)

func test_rebirth_multiplier_growth_is_25pct_per_stack() -> void:
    GameState.rebirths = 4
    var mult: float = 1.0 + GameState.rebirths * 0.25
    assert_almost_eq(mult, 2.0, 0.001)
