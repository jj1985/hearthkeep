extends GutTest

func before_each() -> void:
    GameState.hero_level = 1
    GameState.hero_xp = 0

func test_xp_to_next_level_grows_with_level() -> void:
    assert_eq(GameState.xp_to_next_level(), 20)
    GameState.hero_level = 5
    assert_eq(GameState.xp_to_next_level(), 20 + 4 * 15)

func test_grant_xp_levels_up_at_threshold() -> void:
    var ups := GameState.grant_xp(20)
    assert_eq(ups, 1)
    assert_eq(GameState.hero_level, 2)
    assert_eq(GameState.hero_xp, 0)

func test_grant_xp_chains_multi_level_ups() -> void:
    # 20 + 35 + 50 = 105 grants 3 levels exactly.
    var ups := GameState.grant_xp(105)
    assert_eq(ups, 3)
    assert_eq(GameState.hero_level, 4)
    assert_eq(GameState.hero_xp, 0)

func test_partial_xp_carries_over() -> void:
    GameState.grant_xp(25)
    assert_eq(GameState.hero_level, 2)
    assert_eq(GameState.hero_xp, 5)
