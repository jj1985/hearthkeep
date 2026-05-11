extends GutTest

# Ring buffer capping for the last-N run history.

func before_each() -> void:
    GameState.run_history = []

func test_pushes_in_order() -> void:
    GameState.push_run_history({"wave": 1})
    GameState.push_run_history({"wave": 2})
    GameState.push_run_history({"wave": 3})
    assert_eq(GameState.run_history.size(), 3)
    assert_eq(int(GameState.run_history[0]["wave"]), 1)
    assert_eq(int(GameState.run_history[2]["wave"]), 3)

func test_drops_oldest_after_cap() -> void:
    for i in 20:
        GameState.push_run_history({"wave": i})
    assert_eq(GameState.run_history.size(), GameState.RUN_HISTORY_CAP)
    assert_eq(int(GameState.run_history[0]["wave"]),
        20 - GameState.RUN_HISTORY_CAP)
    assert_eq(int(GameState.run_history[-1]["wave"]), 19)
