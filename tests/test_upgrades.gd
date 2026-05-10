extends GutTest

# Persistent upgrade purchasing math.

func before_each() -> void:
    GameState.gold = 0
    GameState.meta_unlocks["upgrades"] = {}

func test_initial_rank_zero_for_all_upgrades() -> void:
    for u in Upgrades.UPGRADES:
        assert_eq(Upgrades.rank(String(u["id"])), 0)

func test_cost_grows_geometrically() -> void:
    var c0: int = Upgrades.cost("damage")
    GameState.gold = 100000
    Upgrades.buy("damage")
    var c1: int = Upgrades.cost("damage")
    assert_gt(c1, c0)
    Upgrades.buy("damage")
    var c2: int = Upgrades.cost("damage")
    assert_gt(c2, c1)

func test_cannot_buy_without_gold() -> void:
    GameState.gold = 0
    assert_false(Upgrades.can_buy("damage"))
    assert_false(Upgrades.buy("damage"))
    assert_eq(Upgrades.rank("damage"), 0)

func test_buy_deducts_gold_and_increments_rank() -> void:
    GameState.gold = 1000
    var cost := Upgrades.cost("damage")
    assert_true(Upgrades.buy("damage"))
    assert_eq(GameState.gold, 1000 - cost)
    assert_eq(Upgrades.rank("damage"), 1)

func test_bonus_damage_scales_with_rank() -> void:
    GameState.gold = 100000
    Upgrades.buy("damage")
    Upgrades.buy("damage")
    assert_eq(Upgrades.bonus_damage(), 4)

func test_idle_multiplier_scales_with_rank() -> void:
    GameState.gold = 100000
    assert_almost_eq(Upgrades.idle_multiplier(), 1.0, 0.001)
    Upgrades.buy("idle")
    assert_almost_eq(Upgrades.idle_multiplier(), 1.25, 0.001)

func test_crit_chance_capped_at_95_percent() -> void:
    var ups: Dictionary = {"crit": 999}
    GameState.meta_unlocks["upgrades"] = ups
    assert_almost_eq(Upgrades.crit_chance(), 0.95, 0.001)

func test_max_rank_blocks_further_purchase() -> void:
    var ups: Dictionary = {"damage": Upgrades.MAX_RANK}
    GameState.meta_unlocks["upgrades"] = ups
    GameState.gold = 999999999
    assert_false(Upgrades.can_buy("damage"))
    assert_eq(Upgrades.cost("damage"), -1)
