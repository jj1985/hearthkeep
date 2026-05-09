extends Control

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

const STEPS := ["Piece", "Fabric", "Trim", "Weave"]

@onready var bg: ColorRect = $Bg
@onready var headline: Label = $SafeArea/V/Headline
@onready var step_label: Label = $SafeArea/V/StepHeader/StepLabel
@onready var preview_name: Label = $SafeArea/V/Preview/Margin/V/Name
@onready var preview_stats: Label = $SafeArea/V/Preview/Margin/V/Stats
@onready var preview_panel: PanelContainer = $SafeArea/V/Preview
@onready var options_list: VBoxContainer = $SafeArea/V/Scroll/List
@onready var back_btn: Button = $SafeArea/V/Footer/Back
@onready var next_btn: Button = $SafeArea/V/Footer/Next
@onready var close_btn: Button = $SafeArea/V/Footer/Close

var step: int = 0
var selections: Dictionary = {}

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    headline.text = "TAILORING LOOM"
    step_label.add_theme_color_override("font_color", T.ON_SURFACE)
    preview_panel.add_theme_stylebox_override("panel", UiStyle_.panel_modal())
    preview_name.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    preview_name.add_theme_color_override("font_color", T.PRIMARY)
    preview_stats.add_theme_font_size_override("font_size", T.FS_BODY_MD)
    preview_stats.add_theme_color_override("font_color", T.ON_SURFACE)
    UiStyle_.apply_secondary(back_btn)
    UiStyle_.apply_primary(next_btn)
    UiStyle_.apply_secondary(close_btn)
    UiAnim_.bind_press_feedback(back_btn)
    UiAnim_.bind_press_feedback(next_btn)
    UiAnim_.bind_press_feedback(close_btn)
    back_btn.pressed.connect(_back)
    next_btn.pressed.connect(_next)
    close_btn.pressed.connect(_on_close)
    _enter_step(0)

func _enter_step(s: int) -> void:
    step = s
    step_label.text = "STEP %d / %d  ·  %s" % [step + 1, STEPS.size(), STEPS[step]]
    _populate_options()
    next_btn.text = "WEAVE!" if step == STEPS.size() - 1 else "NEXT"
    back_btn.disabled = step == 0
    _refresh_preview()

func _populate_options() -> void:
    for c in options_list.get_children():
        c.queue_free()
    match STEPS[step]:
        "Piece":
            for p in Loom.PIECES:
                _add(p["id"], String(p["name"]), "slot: %s" % String(p["slot"]),
                    func(): _pick("piece", p["id"]))
        "Fabric":
            for f in Loom.FABRICS:
                _add(f["id"], String(f["name"]), "armor: %d" % int(f["armor"]),
                    func(): _pick("fabric", f["id"]))
        "Trim":
            for tr in Loom.TRIM:
                var blurb: String = "no extra"
                if String(tr.get("stat_bonus", "")) != "":
                    blurb = "+%g %s" % [float(tr.get("bonus", 0)), String(tr["stat_bonus"])]
                _add(tr["id"], String(tr["name"]), blurb, func(): _pick("trim", tr["id"]))
        "Weave":
            var hint := Label.new()
            hint.text = "Take the cloth from the loom."
            hint.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
            options_list.add_child(hint)

func _add(id: String, name: String, blurb: String, cb: Callable) -> void:
    var b := Button.new()
    b.text = "%s\n%s" % [name, blurb]
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.custom_minimum_size = Vector2(0, 64)
    UiStyle_.apply_secondary(b)
    UiAnim_.bind_press_feedback(b)
    b.pressed.connect(cb)
    var key := ""
    match STEPS[step]:
        "Piece":  key = "piece"
        "Fabric": key = "fabric"
        "Trim":   key = "trim"
    if key != "" and selections.get(key, "") == id:
        UiStyle_.apply_primary(b)
    options_list.add_child(b)

func _pick(key: String, id: String) -> void:
    selections[key] = id
    _populate_options()
    _refresh_preview()

func _refresh_preview() -> void:
    var p: Dictionary = _find(Loom.PIECES, selections.get("piece", ""))
    var f: Dictionary = _find(Loom.FABRICS, selections.get("fabric", ""))
    var tr: Dictionary = _find(Loom.TRIM, selections.get("trim", "none"))
    if p.is_empty() or f.is_empty():
        preview_name.text = "—"
        preview_stats.text = "Choose a piece and fabric."
        return
    preview_name.text = "%s %s" % [String(f["name"]), String(p["name"])]
    var s: String = "armor: %d" % int(f["armor"])
    if String(tr.get("stat_bonus", "")) != "":
        s += "  ·  %s +%g" % [String(tr["stat_bonus"]), float(tr.get("bonus", 0))]
    preview_stats.text = s

func _find(arr: Array, id: String) -> Dictionary:
    for x in arr:
        if x["id"] == id: return x
    return {}

func _back() -> void:
    if step > 0:
        _enter_step(step - 1)

func _next() -> void:
    if step == STEPS.size() - 1:
        selections["skill_level"] = clampi(GameState.building_tier("forge") + 1, 1, 5)
        var item: Dictionary = Loom.craft(selections)
        if item.is_empty():
            EventBus.floating_text.emit("The loom rattles — incomplete.", Vector2.ZERO, T.ERROR)
            return
        ChestManager.deposit(item)
        EventBus.floating_text.emit("WOVEN: %s" % String(item.get("name", "?")), Vector2.ZERO, T.SUCCESS)
        SfxBus.play("perk_pick", -3.0)
        selections = {}
        _enter_step(0)
        return
    if STEPS[step] == "Piece" and not selections.has("piece"):
        EventBus.floating_text.emit("Pick a piece.", Vector2.ZERO, T.WARNING)
        return
    if STEPS[step] == "Fabric" and not selections.has("fabric"):
        EventBus.floating_text.emit("Pick a fabric.", Vector2.ZERO, T.WARNING)
        return
    _enter_step(step + 1)

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
