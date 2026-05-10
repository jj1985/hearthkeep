extends GutTest

const Achievements := preload("res://scripts/incremental/achievements.gd")

func before_each() -> void:
    GameState.lifetime_kills = 0
    GameState.deepest_floor = 0
    GameState.bosses_felled = 0
    GameState.curses_cleared = 0
    GameState.rebirths = 0
    GameState.login_streak = 0

func test_progress_caps_at_target() -> void:
    GameState.lifetime_kills = 9999
    var p := Achievements.progress("unlock_rogue")
    assert_eq(int(p[0]), 100)
    assert_eq(int(p[1]), 100)

func test_is_done_true_when_at_or_past_target() -> void:
    GameState.bosses_felled = 5
    assert_true(Achievements.is_done("five_bosses"))
    assert_true(Achievements.is_done("first_boss"))

func test_is_done_false_when_below_target() -> void:
    GameState.deepest_floor = 5
    assert_false(Achievements.is_done("slot_dual"))
    assert_false(Achievements.is_done("endless"))

func test_streak_seven_progresses_with_login_streak() -> void:
    GameState.login_streak = 4
    var p := Achievements.progress("streak_seven")
    assert_eq(int(p[0]), 4)

func test_unknown_id_returns_zero_one() -> void:
    var p := Achievements.progress("nope")
    assert_eq(int(p[0]), 0)
    assert_eq(int(p[1]), 1)
