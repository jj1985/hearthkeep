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
@onready var btn_jump: Button = $V/JumpRow/Jump

var row_widgets: Array = []

func _ready() -> void:
    SaveSystem.load_save()
    bg.color = T.SURFACE_DIM
    UiStyle_.apply_secondary(btn_back)
    btn_back.pressed.connect(_on_back)
    btn_jump.pressed.connect(_on_jump)
    UiStyle_.apply_secondary(btn_jump)
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
    stats_label.text = "  ·  ".join(lines)
    btn_jump.visible = GameState.best_run_wave >= 25

func _on_jump() -> void:
    HordeState.reset_run()
    HordePerks.reset_for_run()
    HordeState.wave = 25
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/horde.tscn")

func _on_back() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/title.tscn")
