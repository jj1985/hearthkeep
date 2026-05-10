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
