extends Control

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

const STEPS := ["Form", "Sigil", "Ink", "Inscribe"]

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
    headline.text = "ARCANE ATELIER"
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
    next_btn.text = "INSCRIBE!" if step == STEPS.size() - 1 else "NEXT"
    back_btn.disabled = step == 0
    _refresh_preview()

func _populate_options() -> void:
    for c in options_list.get_children():
        c.queue_free()
    match STEPS[step]:
        "Form":
            for f in Atelier.FORMS:
                _add(f["id"], String(f["name"]), "kind: %s" % String(f["kind"]),
                    func(): _pick("form", f["id"]))
        "Sigil":
            for sg in Atelier.SIGILS:
                _add(sg["id"], String(sg["name"]), "buff: %s" % String(sg["buff_id"]),
                    func(): _pick("sigil", sg["id"]))
        "Ink":
            for ink in Atelier.INKS:
                _add(ink["id"], String(ink["name"]),
                    "potency ×%.1f" % float(ink.get("potency_mult", 1.0)),
                    func(): _pick("ink", ink["id"]))
        "Inscribe":
            var hint := Label.new()
            hint.text = "The Atelier hums. Tap INSCRIBE to commit the work."
            hint.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
            hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
        "Form":  key = "form"
        "Sigil": key = "sigil"
        "Ink":   key = "ink"
    if key != "" and selections.get(key, "") == id:
        UiStyle_.apply_primary(b)
    options_list.add_child(b)

func _pick(key: String, id: String) -> void:
    selections[key] = id
    _populate_options()
    _refresh_preview()

func _refresh_preview() -> void:
    var f: Dictionary = _find_in(Atelier.FORMS, selections.get("form", ""))
    var sg: Dictionary = _find_in(Atelier.SIGILS, selections.get("sigil", ""))
    var ink: Dictionary = _find_in(Atelier.INKS, selections.get("ink", "ash_ink"))
    if f.is_empty() or sg.is_empty():
        preview_name.text = "—"
        preview_stats.text = "Choose a form and sigil."
        return
    preview_name.text = "%s of %s" % [String(f["name"]), String(sg["name"]).replace("Sigil of ", "")]
    preview_stats.text = "potency ×%.2f  ·  buff: %s" % [float(ink.get("potency_mult", 1.0)), String(sg["buff_id"])]

func _find_in(arr: Array, id: String) -> Dictionary:
    for x in arr:
        if x["id"] == id: return x
    return {}

func _back() -> void:
    if step > 0:
        _enter_step(step - 1)

func _next() -> void:
    if step == STEPS.size() - 1:
        selections["skill_level"] = clampi(GameState.building_tier("wizard_tower") + 1, 1, 5)
        var item: Dictionary = Atelier.craft(selections)
        if item.is_empty():
            EventBus.floating_text.emit("The ink is dry — incomplete.", Vector2.ZERO, T.ERROR)
            return
        ChestManager.deposit(item)
        EventBus.floating_text.emit("INSCRIBED: %s" % String(item.get("name", "?")), Vector2.ZERO, T.SUCCESS)
        SfxBus.play("perk_pick", -3.0)
        selections = {}
        _enter_step(0)
        return
    if STEPS[step] == "Form" and not selections.has("form"):
        EventBus.floating_text.emit("Pick a form.", Vector2.ZERO, T.WARNING)
        return
    if STEPS[step] == "Sigil" and not selections.has("sigil"):
        EventBus.floating_text.emit("Pick a sigil.", Vector2.ZERO, T.WARNING)
        return
    _enter_step(step + 1)

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
