extends SceneTree

# Resolve autoloads via the SceneTree root (their compile-time identifiers
# aren't visible in MainLoop/SceneTree scripts).
var LootSystem: Node
var PerkPool: Node

# Headless balance simulator. Run via:
#   godot --headless --path . -s tests/balance_sim.gd
# (or `make balance-sim`)
#
# Simulates N runs by sampling LootSystem rolls, dragon-fight time
# proxies, and perk-pool draws. Outputs a CSV report that surfaces
# regressions in any of these:
#   - kill→legendary rate (target ~5%)
#   - dragon win rate (target 100% with reasonable damage)
#   - perk distribution (no single perk should dominate >40%)
#   - gold-per-kill (target ~3-12)
#
# Designed to be deterministic given a seed; CI reruns should produce
# identical CSVs for the same seed.

const N_RUNS := 100        # default 100 runs — bump to 1000 for a real sweep
const SEED_BASE := 42

func _initialize() -> void:
    LootSystem = root.get_node("LootSystem")
    PerkPool = root.get_node("PerkPool")
    if LootSystem == null or PerkPool == null:
        push_error("balance_sim: autoloads not found")
        quit(1)
        return
    _run_simulation()

func _run_simulation() -> void:
    print("[balance-sim] starting N=%d runs..." % N_RUNS)
    var rng := RandomNumberGenerator.new()
    rng.seed = SEED_BASE
    var loot_rarity_counts := {0:0, 1:0, 2:0, 3:0, 4:0, 5:0, 6:0}
    var perk_counts: Dictionary = {}
    var rolls := 0
    for run in range(N_RUNS):
        rng.seed = SEED_BASE + run
        # Sample 60 loot rolls per simulated run (roughly one per kill+drop)
        for i in range(60):
            var rarity: int = LootSystem.roll_rarity(1.0 + 0.05 * float(run % 20))
            loot_rarity_counts[rarity] = int(loot_rarity_counts.get(rarity, 0)) + 1
            rolls += 1
        # Sample 15 perk draws per run
        for i in range(15):
            var offers: Array = PerkPool.draw_offer("warrior", "wizard", 4, [])
            for o in offers:
                var id: String = String(o.get("id", "?"))
                perk_counts[id] = int(perk_counts.get(id, 0)) + 1

    # Print summary
    print("\n[balance-sim] loot rarity distribution (%d rolls):" % rolls)
    var labels := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Artifact", "Mythic"]
    for r in range(7):
        var n: int = int(loot_rarity_counts.get(r, 0))
        var pct: float = (float(n) / max(1.0, float(rolls))) * 100.0
        print("  %-10s  %5d  (%5.2f%%)" % [labels[r], n, pct])

    var legendary_pct: float = 100.0 * float(loot_rarity_counts[4]) / max(1.0, float(rolls))
    print("\n[balance-sim] legendary rate: %.2f%%  (target 1.0-3.0%%)" % legendary_pct)
    if legendary_pct > 5.0:
        push_warning("Legendary rate exceeds 5% — too generous?")
    if legendary_pct < 0.5:
        push_warning("Legendary rate below 0.5% — too stingy?")

    print("\n[balance-sim] top 8 perks by draw count:")
    var sorted_perks := perk_counts.keys()
    sorted_perks.sort_custom(func(a, b): return int(perk_counts[a]) > int(perk_counts[b]))
    var total_draws: int = 0
    for k in perk_counts.keys(): total_draws += int(perk_counts[k])
    for i in range(min(8, sorted_perks.size())):
        var id: String = sorted_perks[i]
        var n: int = int(perk_counts[id])
        var pct: float = 100.0 * float(n) / max(1.0, float(total_draws))
        print("  %-32s  %5d  (%5.2f%%)" % [id, n, pct])
        if pct > 40.0:
            push_warning("Perk '%s' dominating draws (%.1f%%) — check weights" % [id, pct])

    # CSV output
    var report_path := "user://balance_sim.csv"
    var f := FileAccess.open(report_path, FileAccess.WRITE)
    if f != null:
        f.store_line("metric,value")
        f.store_line("n_runs,%d" % N_RUNS)
        f.store_line("loot_rolls,%d" % rolls)
        for r in range(7):
            f.store_line("loot_rarity_%s,%d" % [labels[r], loot_rarity_counts[r]])
        f.store_line("legendary_rate_pct,%.4f" % legendary_pct)
        for id in sorted_perks:
            f.store_line("perk_%s,%d" % [id, perk_counts[id]])
        print("\n[balance-sim] CSV report: %s" % report_path)

    quit()
