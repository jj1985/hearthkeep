extends Control

# Between-run upgrade screen. Buy permanent stat boosts with gold.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")

@onready var bg: ColorRect = $Bg
@onready var title_label: Label = $V/Title
@onready var gold_label: Label = $V/Gold
@onready var rows: VBoxContainer = $V/Scroll/Rows
@onready var btn_back: Button = $V/Back
@onready var stats_label: Label = $V/Stats
@onready var btn_jump_10: Button = $V/JumpRow/Jump10
@onready var btn_jump_25: Button = $V/JumpRow/Jump25
@onready var btn_jump_50: Button = $V/JumpRow/Jump50
@onready var btn_rebirth: Button = $V/Rebirth
@onready var btn_ach_toggle: Button = $V/AchToggle
@onready var ach_scroll: ScrollContainer = $V/AchScroll
@onready var ach_rows: VBoxContainer = $V/AchScroll/AchRows
@onready var btn_bestiary_toggle: Button = $V/BestiaryToggle
@onready var bestiary_scroll: ScrollContainer = $V/BestiaryScroll
@onready var bestiary_rows: VBoxContainer = $V/BestiaryScroll/BestiaryRows
const HordeArena := preload("res://scripts/incremental/horde_arena.gd")
@onready var history_label: Label = $V/HistoryLabel
@onready var top_runs_label: Label = $V/TopRunsLabel
const Achievements := preload("res://scripts/incremental/achievements.gd")

var row_widgets: Array = []

func _ready() -> void:
    SaveSystem.load_save()
    bg.color = T.SURFACE_DIM
    UiStyle_.apply_secondary(btn_back)
    btn_back.pressed.connect(_on_back)
    btn_jump_10.pressed.connect(_on_jump.bind(10))
    btn_jump_25.pressed.connect(_on_jump.bind(25))
    btn_jump_50.pressed.connect(_on_jump.bind(50))
    UiStyle_.apply_secondary(btn_jump_10)
    UiStyle_.apply_secondary(btn_jump_25)
    UiStyle_.apply_secondary(btn_jump_50)
    btn_rebirth.pressed.connect(_on_rebirth)
    UiStyle_.apply_primary(btn_rebirth)
    btn_ach_toggle.pressed.connect(_on_ach_toggle)
    UiStyle_.apply_secondary(btn_ach_toggle)
    btn_bestiary_toggle.pressed.connect(_on_bestiary_toggle)
    UiStyle_.apply_secondary(btn_bestiary_toggle)
    var ach_pay: int = Achievements.scan_and_claim()
    if ach_pay > 0:
        SaveSystem.save()
    _build_achievements()
    _refresh_history()
    _refresh_top_runs()
    Upgrades.upgrade_purchased.connect(_on_purchased)
    EventBus.currency_changed.connect(_on_currency)
    _build_rows()
    _refresh_gold()
    _refresh_stats()

func _build_rows() -> void:
    for c in rows.get_children():
        c.queue_free()
    row_widgets.clear()
    for u in Upgrades.UPGRADES:
        var def: Dictionary = u
        var row := HBoxContainer.new()
        row.theme_override_constants_separation = 12
        var info := VBoxContainer.new()
        info.size_flags_horizontal = 3
        var name_lbl := Label.new()
        name_lbl.text = String(def["label"])
        name_lbl.add_theme_color_override("font_color", T.PRIMARY)
        info.add_child(name_lbl)
        var desc_lbl := Label.new()
        desc_lbl.text = String(def["desc"]).replace("%%", "%")
        desc_lbl.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
        info.add_child(desc_lbl)
        var rank_lbl := Label.new()
        rank_lbl.add_theme_color_override("font_color", T.ON_SURFACE)
        info.add_child(rank_lbl)
        row.add_child(info)
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(140, 56)
        UiStyle_.apply_primary(btn)
        btn.pressed.connect(_on_buy.bind(String(def["id"])))
        row.add_child(btn)
        rows.add_child(row)
        var sep := HSeparator.new()
        rows.add_child(sep)
        row_widgets.append({"id": String(def["id"]), "rank": rank_lbl, "btn": btn})
    _refresh_rows()

func _refresh_rows() -> void:
    for w in row_widgets:
        var d: Dictionary = w
        var id: String = d["id"]
        var r: int = Upgrades.rank(id)
        var c: int = Upgrades.cost(id)
        var cur: String = Upgrades.currency_for(id)
        (d["rank"] as Label).text = "Rank %d / %d" % [r, Upgrades.MAX_RANK]
        var btn: Button = d["btn"]
        var suffix: String = "g" if cur == "gold" else "🜂"
        if c < 0:
            btn.text = "MAXED"
            btn.disabled = true
        else:
            btn.text = "%d %s" % [c, suffix]
            btn.disabled = not Upgrades.can_buy(id)

func _refresh_gold() -> void:
    gold_label.text = "%d gold  ·  %d ember" % [GameState.gold, GameState.embers]

func _on_buy(id: String) -> void:
    Upgrades.buy(id)
    SaveSystem.save()

func _on_purchased(_id: String, _rank: int) -> void:
    _refresh_rows()
    _refresh_gold()

func _on_currency(_kind: String, _delta: int, _now: int) -> void:
    _refresh_rows()
    _refresh_gold()

func _refresh_stats() -> void:
    var lines: Array[String] = []
    lines.append("Lifetime: %d kills · %d bosses" % [
        GameState.lifetime_kills, GameState.bosses_felled,
    ])
    if GameState.best_run_wave > 0:
        lines.append("Best run: wave %d · %d kills" % [
            GameState.best_run_wave, GameState.best_run_kills,
        ])
    if GameState.login_streak > 0:
        lines.append("Login streak: %d" % GameState.login_streak)
    if not GameState.best_wave_by_class.is_empty():
        var by_class: Array = []
        for cid in GameState.best_wave_by_class.keys():
            by_class.append("%s W%d" % [String(cid).capitalize(),
                int(GameState.best_wave_by_class[cid])])
        lines.append("  ·  ".join(by_class))
    stats_label.text = "  ·  ".join(lines)
    btn_jump_10.visible = GameState.best_run_wave >= 10
    btn_jump_25.visible = GameState.best_run_wave >= 25
    btn_jump_50.visible = GameState.best_run_wave >= 50
    btn_rebirth.visible = bool(GameState.meta_unlocks.get("wave_50", false))
    if btn_rebirth.visible:
        btn_rebirth.text = "REBIRTH (+25%% perm.) — Mark %d" % (GameState.rebirths + 1)

func _on_jump(target_wave: int) -> void:
    HordeState.reset_run()
    HordePerks.reset_for_run()
    HordeState.wave = target_wave
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/horde.tscn")

func _on_ach_toggle() -> void:
    ach_scroll.visible = not ach_scroll.visible
    if ach_scroll.visible: _build_achievements()

func _on_bestiary_toggle() -> void:
    bestiary_scroll.visible = not bestiary_scroll.visible
    if bestiary_scroll.visible: _build_bestiary()

func _build_bestiary() -> void:
    if bestiary_rows == null: return
    for c in bestiary_rows.get_children(): c.queue_free()
    var sorted_keys: Array = []
    for k in HordeArena.ENEMY_TYPES.keys():
        sorted_keys.append(String(k))
    sorted_keys.sort()
    for k in sorted_keys:
        var def: Dictionary = HordeArena.ENEMY_TYPES[k]
        var seen: bool = GameState.bestiary.has(k)
        var n: int = int(GameState.lifetime_kills_by_type.get(k, 0))
        var row := HBoxContainer.new()
        row.theme_override_constants_separation = 8
        var name_lbl := Label.new()
        name_lbl.text = "%s %s" % [
            "✓" if seen else "?",
            String(def["label"]) if seen else "??????",
        ]
        name_lbl.size_flags_horizontal = 3
        name_lbl.add_theme_color_override("font_color",
            T.SUCCESS if seen else T.ON_SURFACE_DISABLED)
        row.add_child(name_lbl)
        var kills_lbl := Label.new()
        kills_lbl.text = ("%d kills" % n) if seen else "—"
        kills_lbl.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        row.add_child(kills_lbl)
        bestiary_rows.add_child(row)

func _build_achievements() -> void:
    if ach_rows == null: return
    for c in ach_rows.get_children(): c.queue_free()
    for r in Achievements.ROWS:
        var d: Dictionary = r
        var id: String = String(d["id"])
        var prog: Array = Achievements.progress(id)
        var done: bool = Achievements.is_done(id)
        var claimed: bool = Achievements.is_claimed(id)
        var row := HBoxContainer.new()
        row.theme_override_constants_separation = 8
        var name_lbl := Label.new()
        name_lbl.text = ("✓ " if done else "  ") + String(d["label"])
        name_lbl.size_flags_horizontal = 3
        name_lbl.add_theme_color_override("font_color",
            T.SUCCESS if claimed else (T.ON_SURFACE if done else T.ON_SURFACE_MUTED))
        row.add_child(name_lbl)
        var reward_lbl := Label.new()
        reward_lbl.text = "+%d🜂" % Achievements.reward(id)
        reward_lbl.add_theme_color_override("font_color",
            T.SECONDARY if not claimed else T.ON_SURFACE_MUTED)
        row.add_child(reward_lbl)
        var prog_lbl := Label.new()
        prog_lbl.text = "%d / %d" % [int(prog[0]), int(prog[1])]
        prog_lbl.add_theme_color_override("font_color",
            T.PRIMARY if done else T.ON_SURFACE)
        row.add_child(prog_lbl)
        ach_rows.add_child(row)

func _refresh_history() -> void:
    if history_label == null: return
    if GameState.run_history.is_empty():
        history_label.text = ""
        return
    var lines: Array[String] = ["recent runs"]
    var i: int = GameState.run_history.size() - 1
    while i >= 0 and lines.size() <= 5:
        var r: Dictionary = GameState.run_history[i]
        var combo_part: String = "  combo x%d" % int(r.get("combo", 0)) if int(r.get("combo", 0)) >= 5 else ""
        lines.append("W%d · %d kills · +%d🜂 (%s)%s" % [
            int(r.get("wave", 0)), int(r.get("kills", 0)),
            int(r.get("embers", 0)), String(r.get("class", "?")).capitalize(),
            combo_part,
        ])
        i -= 1
    history_label.text = "\n".join(lines)
    history_label.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)

func _refresh_top_runs() -> void:
    if top_runs_label == null: return
    if GameState.top_runs.is_empty():
        top_runs_label.text = ""
        return
    var lines: Array[String] = ["top runs"]
    var rank: int = 1
    for r in GameState.top_runs:
        var d: Dictionary = r
        lines.append("#%d  W%d · %d kills (%s)" % [
            rank, int(d.get("wave", 0)),
            int(d.get("kills", 0)),
            String(d.get("class", "?")).capitalize(),
        ])
        rank += 1
    top_runs_label.text = "\n".join(lines)
    top_runs_label.add_theme_color_override("font_color", T.PRIMARY)

func _on_rebirth() -> void:
    # Confirm-and-go: increments rebirths, wipes per-track upgrades, gold,
    # lifetime kills, best-run, and the wave_50 milestone (so the next
    # rebirth has to be earned again). Embers and the rebirth count
    # itself persist.
    GameState.rebirths += 1
    GameState.gold = 0
    GameState.lifetime_kills = 0
    GameState.lifetime_kills_by_type = {}
    GameState.best_run_wave = 0
    GameState.best_run_kills = 0
    GameState.bosses_felled = 0
    GameState.deepest_floor = 0
    GameState.unlocked_classes = ["warrior"] as Array[String]
    GameState.meta_unlocks["upgrades"] = {}
    GameState.meta_unlocks["milestones"] = {}
    GameState.meta_unlocks["wave_50"] = false
    HordeState.reset_run()
    HordePerks.reset_for_run()
    SaveSystem.save()
    _refresh_rows(); _refresh_gold(); _refresh_stats()

func _on_back() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/title.tscn")
