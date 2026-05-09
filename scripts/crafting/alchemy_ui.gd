extends Control

# Alchemy wizard. Mirrors Forge UI: steps Vessel → Reagent → Catalyst →
# Label → Brew. Same pattern, different data tables.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

const STEPS := ["Vessel", "Reagent", "Catalyst", "Label", "Brew"]

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var step_label: Label = $SafeArea/V/StepHeader/StepLabel
@onready var preview_name: Label = $SafeArea/V/Preview/Margin/V/Name
@onready var preview_stats: Label = $SafeArea/V/Preview/Margin/V/Stats
@onready var preview_tags: Label = $SafeArea/V/Preview/Margin/V/Tags
@onready var preview_panel: PanelContainer = $SafeArea/V/Preview
@onready var options_list: VBoxContainer = $SafeArea/V/Scroll/List
@onready var label_input: LineEdit = $SafeArea/V/LabelInput
@onready var back_btn: Button = $SafeArea/V/Footer/Back
@onready var next_btn: Button = $SafeArea/V/Footer/Next
@onready var close_btn: Button = $SafeArea/V/Footer/Close

var step: int = 0
var selections: Dictionary = {}

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    headline.text = "ALCHEMY LAB"
    step_label.add_theme_font_size_override("font_size", T.FS_HEADLINE_SM)
    step_label.add_theme_color_override("font_color", T.ON_SURFACE)
    preview_panel.add_theme_stylebox_override("panel", UiStyle_.panel_modal())
    preview_name.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    preview_name.add_theme_color_override("font_color", T.PRIMARY)
    preview_stats.add_theme_font_size_override("font_size", T.FS_BODY_MD)
    preview_stats.add_theme_color_override("font_color", T.ON_SURFACE)
    preview_tags.add_theme_font_size_override("font_size", T.FS_LABEL_MD)
    preview_tags.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    UiStyle_.apply_secondary(back_btn)
    UiStyle_.apply_primary(next_btn)
    UiStyle_.apply_secondary(close_btn)
    UiAnim_.bind_press_feedback(back_btn)
    UiAnim_.bind_press_feedback(next_btn)
    UiAnim_.bind_press_feedback(close_btn)
    back_btn.pressed.connect(_back)
    next_btn.pressed.connect(_next)
    close_btn.pressed.connect(_on_close)
    label_input.text_changed.connect(func(s): selections["label"] = s)
    _enter_step(0)

func _enter_step(s: int) -> void:
    step = s
    step_label.text = "STEP %d / %d  ·  %s" % [step + 1, STEPS.size(), STEPS[step]]
    label_input.visible = (STEPS[step] == "Label")
    if label_input.visible:
        label_input.text = String(selections.get("label", ""))
    _populate_options_for_step(step)
    next_btn.text = "BREW!" if step == STEPS.size() - 1 else "NEXT"
    back_btn.disabled = step == 0
    _refresh_preview()

func _populate_options_for_step(s: int) -> void:
    for c in options_list.get_children():
        c.queue_free()
    match STEPS[s]:
        "Vessel":
            for v in Alchemy.VESSELS:
                _add_button(v["id"], v["name"], "kind: %s" % String(v["kind"]),
                    func(): _pick("vessel", v["id"]))
        "Reagent":
            for r in Alchemy.REAGENTS:
                var blurb: String = "potency ×%.1f · %s" % [float(r["potency"]), String(r["school"])]
                if r.has("flavor"): blurb += "  ·  " + String(r["flavor"])
                _add_button(r["id"], r["name"], blurb, func(): _pick("reagent", r["id"]))
        "Catalyst":
            for c in Alchemy.CATALYSTS:
                var blurb: String = "potency ×%.2f · duration ×%.2f" % [float(c.get("potency_mult", 1.0)), float(c.get("duration_mult", 1.0))]
                _add_button(c["id"], c["name"], blurb, func(): _pick("catalyst", c["id"]))
        "Label":
            var hint := Label.new()
            hint.text = "Inscribe the brew with a name.  Leave blank to skip."
            hint.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
            hint.add_theme_font_size_override("font_size", T.FS_BODY_MD)
            hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            options_list.add_child(hint)
        "Brew":
            var hint := Label.new()
            hint.text = "Pour. Stir. The Lab will roll quality based on your skill."
            hint.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
            hint.add_theme_font_size_override("font_size", T.FS_BODY_MD)
            hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            options_list.add_child(hint)

func _add_button(id: String, name: String, blurb: String, cb: Callable) -> void:
    var b := Button.new()
    b.text = "%s\n%s" % [name, blurb]
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.custom_minimum_size = Vector2(0, 64)
    UiStyle_.apply_secondary(b)
    UiAnim_.bind_press_feedback(b)
    b.set_meta("option_id", id)
    b.pressed.connect(cb)
    options_list.add_child(b)
    _highlight_if_selected(b)

func _highlight_if_selected(b: Button) -> void:
    var oid: String = String(b.get_meta("option_id", ""))
    var key: String = ""
    match STEPS[step]:
        "Vessel":   key = "vessel"
        "Reagent":  key = "reagent"
        "Catalyst": key = "catalyst"
    if key != "" and selections.get(key, "") == oid:
        UiStyle_.apply_primary(b)

func _pick(key: String, id: String) -> void:
    selections[key] = id
    _populate_options_for_step(step)
    _refresh_preview()

func _refresh_preview() -> void:
    var v: Dictionary = Alchemy.get_vessel(selections.get("vessel", ""))
    var r: Dictionary = Alchemy.get_reagent(selections.get("reagent", ""))
    var c: Dictionary = Alchemy.get_catalyst(selections.get("catalyst", "none"))
    var name_parts: Array = []
    if not r.is_empty(): name_parts.append(String(r["name"]))
    if not v.is_empty(): name_parts.append(String(v["name"]))
    var name_text: String = "—" if name_parts.is_empty() else " ".join(name_parts)
    var label: String = String(selections.get("label", ""))
    if label != "":
        name_text = "%s — \"%s\"" % [name_text, label]
    preview_name.text = name_text
    if v.is_empty() or r.is_empty():
        preview_stats.text = "Choose a vessel and a reagent to see the preview."
        preview_tags.text = ""
        return
    var potency: float = float(r["potency"]) * float(c.get("potency_mult", 1.0))
    var duration: float = 12.0 * float(c.get("duration_mult", 1.0))
    preview_stats.text = "potency ×%.2f  ·  %ds duration  ·  %s school" % [potency, int(duration), String(r["school"])]
    var tags: Array = []
    for src in [v, c]:
        for t in src.get("tags", []):
            if not tags.has(t): tags.append(t)
    if not tags.is_empty():
        preview_tags.text = String(", ".join(tags)).to_upper()
    else:
        preview_tags.text = ""

func _back() -> void:
    if step > 0:
        _enter_step(step - 1)

func _next() -> void:
    if step == STEPS.size() - 1:
        _commit_brew()
        return
    if STEPS[step] == "Vessel" and not selections.has("vessel"):
        EventBus.floating_text.emit("Pick a vessel first.", Vector2.ZERO, T.WARNING)
        return
    if STEPS[step] == "Reagent" and not selections.has("reagent"):
        EventBus.floating_text.emit("Pick a reagent.", Vector2.ZERO, T.WARNING)
        return
    _enter_step(step + 1)

func _commit_brew() -> void:
    selections["skill_level"] = clampi(GameState.building_tier("forge") + 1, 1, 5)
    var item: Dictionary = Alchemy.craft(selections)
    if item.is_empty():
        EventBus.floating_text.emit("The cauldron sputters — incomplete brew.", Vector2.ZERO, T.ERROR)
        return
    ChestManager.deposit(item)
    EventBus.floating_text.emit("BREWED: %s" % String(item.get("name", "?")),
        Vector2.ZERO, T.SUCCESS)
    SfxBus.play("perk_pick", -2.0)
    selections = {}
    _enter_step(0)

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
