extends GutTest

# Offline-progress timing and capping.

func before_each() -> void:
    GameState.last_save_unix = 0

func test_no_save_yet_returns_zero_seconds() -> void:
    assert_eq(SaveSystem.seconds_since_last_save(), 0)

func test_recent_save_returns_real_delta() -> void:
    var now: int = int(Time.get_unix_time_from_system())
    GameState.last_save_unix = now - 120
    var s := SaveSystem.seconds_since_last_save()
    assert_between(s, 119, 122)

func test_offline_capped_at_8_hours() -> void:
    var now: int = int(Time.get_unix_time_from_system())
    # Pretend we last saved 3 days ago.
    GameState.last_save_unix = now - 86400 * 3
    var s := SaveSystem.seconds_since_last_save()
    assert_eq(s, SaveSystem.OFFLINE_CAP_SECONDS)

func test_daily_login_first_time_awards_one_ember() -> void:
    GameState.embers = 0
    GameState.last_login_day = 0
    GameState.login_streak = 0
    var r := SaveSystem.process_daily_login()
    assert_eq(int(r["ember"]), 1)
    assert_eq(int(r["streak"]), 1)
    assert_eq(GameState.embers, 1)

func test_daily_login_second_call_same_day_no_double_dip() -> void:
    GameState.embers = 0
    GameState.last_login_day = 0
    GameState.login_streak = 0
    SaveSystem.process_daily_login()
    var balance := GameState.embers
    var r := SaveSystem.process_daily_login()
    assert_eq(int(r["ember"]), 0)
    assert_eq(GameState.embers, balance)

func test_daily_login_break_resets_streak() -> void:
    var today: int = int(Time.get_unix_time_from_system() / 86400)
    GameState.last_login_day = today - 5  # five-day gap
    GameState.login_streak = 4
    GameState.embers = 0
    SaveSystem.process_daily_login()
    assert_eq(GameState.login_streak, 1)

func test_daily_login_assigns_a_curse() -> void:
    GameState.last_login_day = 0
    GameState.daily_curse = ""
    SaveSystem.process_daily_login()
    assert_ne(GameState.daily_curse, "")
    assert_true(HordeState.CURSES.has(GameState.daily_curse))

func test_daily_login_clears_active_challenge_flag() -> void:
    GameState.last_login_day = 0
    GameState.challenge_active = true
    SaveSystem.process_daily_login()
    # Each new login day requires re-opting in.
    assert_false(GameState.challenge_active)
