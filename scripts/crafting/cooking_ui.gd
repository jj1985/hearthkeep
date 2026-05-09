extends Control

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

const STEPS := ["Dish", "Staple", "Spice", "Cook"]

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
    headline.text = "COOKING HEARTH"
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
    next_btn.text = "COOK!" if step == STEPS.size() - 1 else "NEXT"
    back_btn.disabled = step == 0
    _refresh_preview()

func _populate_options() -> void:
    for c in options_list.get_children():
        c.queue_free()
    match STEPS[step]:
        "Dish":
            for d in Cooking.DISHES:
                _add(d["id"], String(d["name"]),
                    "buff: %s · %ds" % [String(d["buff_id"]), int(d["duration"])],
                    func(): _pick("dish", d["id"]))
        "Staple":
            for s in Cooking.STAPLES:
                _add(s["id"], String(s["name"]), "potency ×%.1f" % float(s.get("potency_mult", 1.0)),
                    func(): _pick("staple", s["id"]))
        "Spice":
            for sp in Cooking.SPICES:
                _add(sp["id"], String(sp["name"]), "potency ×%.1f" % float(sp.get("potency_mult", 1.0)),
                    func(): _pick("spice", sp["id"]))
        "Cook":
            var hint := Label.new()
            hint.text = "The hearth roars. Pull the dish."
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
        "Dish":   key = "dish"
        "Staple": key = "staple"
        "Spice":  key = "spice"
    if key != "" and selections.get(key, "") == id:
        UiStyle_.apply_primary(b)
    options_list.add_child(b)

func _pick(key: String, id: String) -> void:
    selections[key] = id
    _populate_options()
    _refresh_preview()

func _refresh_preview() -> void:
    var d: Dictionary = _find(Cooking.DISHES, selections.get("dish", ""))
    var s: Dictionary = _find(Cooking.STAPLES, selections.get("staple", ""))
    var sp: Dictionary = _find(Cooking.SPICES, selections.get("spice", "salt"))
    if d.is_empty() or s.is_empty():
        preview_name.text = "—"
        preview_stats.text = "Choose a dish and staple."
        return
    preview_name.text = "%s with %s" % [String(d["name"]), String(sp["name"])]
    var potency: float = float(s.get("potency_mult", 1.0)) * float(sp.get("potency_mult", 1.0))
    preview_stats.text = "buff: %s  ·  potency ×%.2f  ·  %ds" % [String(d["buff_id"]), potency, int(d["duration"])]

func _find(arr: Array, id: String) -> Dictionary:
    for x in arr:
        if x["id"] == id: return x
    return {}

func _back() -> void:
    if step > 0:
        _enter_step(step - 1)

func _next() -> void:
    if step == STEPS.size() - 1:
        selections["skill_level"] = clampi(GameState.building_tier("tavern") + 1, 1, 5)
        var item: Dictionary = Cooking.craft(selections)
        if item.is_empty():
            EventBus.floating_text.emit("The hearth gutters — incomplete.", Vector2.ZERO, T.ERROR)
            return
        ChestManager.deposit(item)
        EventBus.floating_text.emit("COOKED: %s" % String(item.get("name", "?")), Vector2.ZERO, T.SUCCESS)
        SfxBus.play("perk_pick", -3.0)
        selections = {}
        _enter_step(0)
        return
    if STEPS[step] == "Dish" and not selections.has("dish"):
        EventBus.floating_text.emit("Pick a dish.", Vector2.ZERO, T.WARNING)
        return
    if STEPS[step] == "Staple" and not selections.has("staple"):
        EventBus.floating_text.emit("Pick a staple.", Vector2.ZERO, T.WARNING)
        return
    _enter_step(step + 1)

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
