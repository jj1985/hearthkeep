extends Control

# Workbench wizard. Steps: Mount → Stone → Inscription → Craft. Mirrors
# the Forge / Alchemy wizard UI patterns; different data tables.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

const STEPS := ["Mount", "Stone", "Inscription", "Craft"]

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var step_label: Label = $SafeArea/V/StepHeader/StepLabel
@onready var preview_name: Label = $SafeArea/V/Preview/Margin/V/Name
@onready var preview_stats: Label = $SafeArea/V/Preview/Margin/V/Stats
@onready var preview_tags: Label = $SafeArea/V/Preview/Margin/V/Tags
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
    headline.text = "WORKBENCH"
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
    _enter_step(0)

func _enter_step(s: int) -> void:
    step = s
    step_label.text = "STEP %d / %d  ·  %s" % [step + 1, STEPS.size(), STEPS[step]]
    _populate_options()
    next_btn.text = "CRAFT!" if step == STEPS.size() - 1 else "NEXT"
    back_btn.disabled = step == 0
    _refresh_preview()

func _populate_options() -> void:
    for c in options_list.get_children():
        c.queue_free()
    match STEPS[step]:
        "Mount":
            for m in Workbench.MOUNTS:
                _add_button(m["id"], String(m["name"]),
                    "slot: %s  ·  ×%.2f stat" % [String(m["slot"]), float(m["stat_mult"])],
                    func(): _pick("mount", m["id"]))
        "Stone":
            for s in Workbench.STONES:
                _add_button(s["id"], String(s["name"]),
                    "%s  +%g–%g" % [String(s["stat"]), float(s["min"]), float(s["max"])],
                    func(): _pick("stone", s["id"]))
        "Inscription":
            for ins in Workbench.INSCRIPTIONS:
                var blurb: String = "no extra stat"
                if String(ins.get("bonus_stat", "")) != "":
                    blurb = "+%d %s" % [int(ins.get("bonus", 0)), String(ins["bonus_stat"])]
                _add_button(ins["id"], String(ins["name"]), blurb, func(): _pick("inscription", ins["id"]))
        "Craft":
            var hint := Label.new()
            hint.text = "Lay the work. The Workbench will roll quality based on your skill."
            hint.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
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
    var key: String = ""
    match STEPS[step]:
        "Mount": key = "mount"
        "Stone": key = "stone"
        "Inscription": key = "inscription"
    if key != "" and selections.get(key, "") == id:
        UiStyle_.apply_primary(b)

func _pick(key: String, id: String) -> void:
    selections[key] = id
    _populate_options()
    _refresh_preview()

func _refresh_preview() -> void:
    var m: Dictionary = Workbench.get_mount(selections.get("mount", ""))
    var st: Dictionary = Workbench.get_stone(selections.get("stone", ""))
    var ins: Dictionary = Workbench.get_inscription(selections.get("inscription", "none"))
    var name_parts: Array = []
    if not st.is_empty(): name_parts.append(String(st["name"]))
    if not m.is_empty():  name_parts.append(String(m["name"]))
    preview_name.text = "—" if name_parts.is_empty() else " ".join(name_parts)
    if m.is_empty() or st.is_empty():
        preview_stats.text = "Choose a mount and a stone to see the preview."
        preview_tags.text = ""
        return
    var stat_avg: float = (float(st["min"]) + float(st["max"])) * 0.5 * float(m["stat_mult"])
    var s: String = "%s ≈ %.2f" % [String(st["stat"]), stat_avg]
    if String(ins.get("bonus_stat", "")) != "":
        s += "  ·  %s +%d" % [String(ins["bonus_stat"]), int(ins.get("bonus", 0))]
    preview_stats.text = s
    var tags: Array = []
    for src in [m, st]:
        for t in src.get("tags", []):
            if not tags.has(t): tags.append(t)
    preview_tags.text = String(", ".join(tags)).to_upper() if not tags.is_empty() else ""

func _back() -> void:
    if step > 0:
        _enter_step(step - 1)

func _next() -> void:
    if step == STEPS.size() - 1:
        _commit()
        return
    if STEPS[step] == "Mount" and not selections.has("mount"):
        EventBus.floating_text.emit("Pick a mount first.", Vector2.ZERO, T.WARNING)
        return
    if STEPS[step] == "Stone" and not selections.has("stone"):
        EventBus.floating_text.emit("Pick a stone.", Vector2.ZERO, T.WARNING)
        return
    _enter_step(step + 1)

func _commit() -> void:
    selections["skill_level"] = clampi(GameState.building_tier("forge") + 1, 1, 5)
    var item: Dictionary = Workbench.craft(selections)
    if item.is_empty():
        EventBus.floating_text.emit("The bench is silent — incomplete.", Vector2.ZERO, T.ERROR)
        return
    ChestManager.deposit(item)
    EventBus.floating_text.emit("CRAFTED: %s" % String(item.get("name", "?")), Vector2.ZERO, T.SUCCESS)
    SfxBus.play("perk_pick", -3.0)
    selections = {}
    _enter_step(0)

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
