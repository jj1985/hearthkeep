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

func test_top_runs_kept_sorted_desc_by_wave() -> void:
    GameState.top_runs = []
    GameState.push_run_history({"wave": 8})
    GameState.push_run_history({"wave": 22})
    GameState.push_run_history({"wave": 4})
    GameState.push_run_history({"wave": 15})
    assert_eq(int(GameState.top_runs[0]["wave"]), 22)
    assert_eq(int(GameState.top_runs[-1]["wave"]), 4)

func test_top_runs_capped_at_5() -> void:
    GameState.top_runs = []
    for i in 12:
        GameState.push_run_history({"wave": i})
    assert_eq(GameState.top_runs.size(), GameState.TOP_RUNS_CAP)
    assert_eq(int(GameState.top_runs[0]["wave"]), 11)  # highest pushed
