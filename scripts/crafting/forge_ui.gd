extends Control

# Multi-step Forge wizard UI on top of the Forge autoload's data layer.
# Steps: 1 Form → 2 Primary Mat → 3 Secondary Mat → 4 Embellishment →
#        5 Engraving → 6 Quality preview → 7 Forge!
# (Dye is folded into the cosmetic pass and lives on the embellishment step
#  for Phase A; full multi-channel dye is Phase A.5.)

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

const STEPS := ["Form", "Primary Material", "Secondary Material", "Embellishment", "Engraving", "Forge"]

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var step_label: Label = $SafeArea/V/StepHeader/StepLabel
@onready var preview_name: Label = $SafeArea/V/Preview/Margin/V/Name
@onready var preview_stats: Label = $SafeArea/V/Preview/Margin/V/Stats
@onready var preview_tags: Label = $SafeArea/V/Preview/Margin/V/Tags
@onready var preview_panel: PanelContainer = $SafeArea/V/Preview
@onready var options_list: VBoxContainer = $SafeArea/V/Scroll/List
@onready var engraving_input: LineEdit = $SafeArea/V/EngravingInput
@onready var back_btn: Button = $SafeArea/V/Footer/Back
@onready var next_btn: Button = $SafeArea/V/Footer/Next
@onready var close_btn: Button = $SafeArea/V/Footer/Close

var step: int = 0
var selections: Dictionary = {}
var on_close: Callable

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
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
    engraving_input.text_changed.connect(func(s): selections["engraving"] = s)
    _enter_step(0)

func _enter_step(s: int) -> void:
    step = s
    step_label.text = "STEP %d / %d  ·  %s" % [step + 1, STEPS.size(), STEPS[step]]
    engraving_input.visible = (STEPS[step] == "Engraving")
    if engraving_input.visible:
        engraving_input.text = String(selections.get("engraving", ""))
    _populate_options_for_step(step)
    next_btn.text = "FORGE!" if step == STEPS.size() - 1 else "NEXT"
    back_btn.disabled = step == 0
    _refresh_preview()

func _populate_options_for_step(s: int) -> void:
    for c in options_list.get_children():
        c.queue_free()
    match STEPS[s]:
        "Form":
            for f in Forge.FORMS:
                _add_option_button(f["id"], f["name"], "%d-%d dmg · %.2f speed" % [
                    int(f["base_dmg"][0]), int(f["base_dmg"][1]), float(f["speed"])
                ], func(): _pick("form", f["id"]))
        "Primary Material":
            for m in Forge.PRIMARY_MATS:
                var blurb: String = "×%.2f dmg · %d durability" % [float(m["dmg_mult"]), int(m["durability"])]
                if m.has("flavor"): blurb += "  ·  " + String(m["flavor"])
                _add_option_button(m["id"], m["name"], blurb, func(): _pick("primary", m["id"]))
        "Secondary Material":
            for m in Forge.SECONDARY_MATS:
                _add_option_button(m["id"], m["name"], "×%.2f atk speed" % float(m["speed_mult"]),
                    func(): _pick("secondary", m["id"]))
        "Embellishment":
            for e in Forge.EMBELLISHMENTS:
                var aff_str: String = "no affix" if (e["affixes"] as Array).is_empty() else _format_affix(e["affixes"])
                _add_option_button(e["id"], e["name"], aff_str, func(): _pick("embellishment", e["id"]))
        "Engraving":
            var hint := Label.new()
            hint.text = "Inscribe a name on the blade.  Leave empty to skip."
            hint.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
            hint.add_theme_font_size_override("font_size", T.FS_BODY_MD)
            hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            options_list.add_child(hint)
        "Forge":
            var hint := Label.new()
            hint.text = "Strike the anvil.  The Forge will roll quality based on your skill."
            hint.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
            hint.add_theme_font_size_override("font_size", T.FS_BODY_MD)
            hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            options_list.add_child(hint)

func _format_affix(affixes: Array) -> String:
    var parts: Array = []
    for a in affixes:
        parts.append("%s +%.0f-%.0f" % [String(a["id"]), float(a["min"]), float(a["max"])])
    return ", ".join(parts)

func _add_option_button(id: String, name: String, blurb: String, cb: Callable) -> void:
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
        "Form":               key = "form"
        "Primary Material":   key = "primary"
        "Secondary Material": key = "secondary"
        "Embellishment":      key = "embellishment"
    if key != "" and selections.get(key, "") == oid:
        UiStyle_.apply_primary(b)

func _pick(key: String, id: String) -> void:
    selections[key] = id
    _populate_options_for_step(step)
    _refresh_preview()

func _refresh_preview() -> void:
    var f: Dictionary = Forge.get_form(selections.get("form", ""))
    var p: Dictionary = Forge.get_primary_material(selections.get("primary", ""))
    var s: Dictionary = Forge.get_secondary_material(selections.get("secondary", ""))
    var e: Dictionary = Forge.get_embellishment(selections.get("embellishment", "none"))
    var name_parts: Array = []
    if not p.is_empty(): name_parts.append(String(p["name"]))
    if not f.is_empty(): name_parts.append(String(f["name"]))
    var name_text: String = "—" if name_parts.is_empty() else " ".join(name_parts)
    var engraving: String = String(selections.get("engraving", ""))
    if engraving != "":
        name_text = "%s — \"%s\"" % [name_text, engraving]
    preview_name.text = name_text
    if f.is_empty() or p.is_empty():
        preview_stats.text = "Choose a form and a material to see the preview."
        preview_tags.text = ""
        return
    var dmin: int = int(float(f["base_dmg"][0]) * float(p["dmg_mult"]))
    var dmax: int = int(float(f["base_dmg"][1]) * float(p["dmg_mult"]))
    var speed: float = float(f["speed"]) * float(s.get("speed_mult", 1.0))
    var stats_str: String = "%d-%d damage  ·  %.2f speed" % [dmin, dmax, speed]
    if not (e.get("affixes", []) as Array).is_empty():
        stats_str += "  ·  " + _format_affix(e["affixes"])
    preview_stats.text = stats_str
    var tags: Array = []
    for src in [f, p, s]:
        for t in src.get("tags", []):
            if not tags.has(t): tags.append(t)
    preview_tags.text = String(", ".join(tags)).to_upper() if not tags.is_empty() else ""

func _back() -> void:
    if step > 0:
        _enter_step(step - 1)

func _next() -> void:
    if step == STEPS.size() - 1:
        _commit_craft()
        return
    if STEPS[step] == "Form" and not selections.has("form"):
        EventBus.floating_text.emit("Pick a form first.", Vector2.ZERO, T.WARNING)
        return
    if STEPS[step] == "Primary Material" and not selections.has("primary"):
        EventBus.floating_text.emit("Pick a primary material.", Vector2.ZERO, T.WARNING)
        return
    _enter_step(step + 1)

func _commit_craft() -> void:
    selections["skill_level"] = clampi(GameState.building_tier("forge") + 1, 1, 5)
    var item: Dictionary = Forge.craft(selections)
    if item.is_empty():
        EventBus.floating_text.emit("The forge is silent — incomplete recipe.", Vector2.ZERO, T.ERROR)
        return
    ChestManager.deposit(item)
    EventBus.floating_text.emit("FORGED: %s" % String(item.get("name", "?")),
        Vector2.ZERO, T.rarity(LootSystem.RARITY_NAMES[clampi(int(item.get("rarity", 0)), 0, LootSystem.RARITY_NAMES.size() - 1)].to_lower()))
    SfxBus.play("levelup")
    selections = {}
    _enter_step(0)

func _on_close() -> void:
    if on_close.is_valid():
        on_close.call()
        return
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
