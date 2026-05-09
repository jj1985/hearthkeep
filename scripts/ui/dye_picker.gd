extends Control

# Dye picker. Tap a slot to focus, tap a color in the palette to apply.
# Uses GameState.dye_pots — applying a color consumes one pot of that
# color, unless the player is just previewing an unlocked color in
# which case set_dye is called without consumption.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

const SLOTS := ["head", "shoulders", "chest", "hands", "legs", "feet", "cloak"]

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var slot_row: HFlowContainer = $SafeArea/V/SlotRow
@onready var palette_grid: GridContainer = $SafeArea/V/PaletteScroll/Palette
@onready var sets_row: HBoxContainer = $SafeArea/V/SetsRow
@onready var save_set_btn: Button = $SafeArea/V/Footer/SaveSet
@onready var close_btn: Button = $SafeArea/V/Footer/Close

var current_slot: String = "chest"

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    headline.text = "DYE WORKBENCH"
    UiStyle_.apply_secondary(close_btn)
    UiStyle_.apply_primary(save_set_btn)
    UiAnim_.bind_press_feedback(close_btn)
    UiAnim_.bind_press_feedback(save_set_btn)
    close_btn.pressed.connect(_on_close)
    save_set_btn.pressed.connect(_on_save_set)
    palette_grid.columns = 5
    palette_grid.add_theme_constant_override("h_separation", 8)
    palette_grid.add_theme_constant_override("v_separation", 8)
    _populate_slots()
    _populate_palette()
    _populate_saved_sets()

func _populate_slots() -> void:
    for c in slot_row.get_children():
        c.queue_free()
    for s in SLOTS:
        var b := Button.new()
        b.text = s.to_upper()
        b.custom_minimum_size = Vector2(96, 48)
        b.set_meta("slot", s)
        UiStyle_.apply_secondary(b)
        UiAnim_.bind_press_feedback(b)
        b.pressed.connect(_on_slot_pressed.bind(s))
        slot_row.add_child(b)
    _refresh_slot_highlights()

func _populate_palette() -> void:
    for c in palette_grid.get_children():
        c.queue_free()
    for entry in DyeSystem.DEFAULT_PALETTE:
        palette_grid.add_child(_make_color_swatch(entry))

func _make_color_swatch(entry: Dictionary) -> Control:
    var color_id: String = String(entry["id"])
    var unlocked: bool = GameState.unlocked_dye_colors.has(color_id)
    var pots: int = int(GameState.dye_pots.get(color_id, 0))
    var swatch := PanelContainer.new()
    swatch.custom_minimum_size = Vector2(64, 64)
    var sb := StyleBoxFlat.new()
    sb.bg_color = entry["color"]
    sb.set_border_width_all(2)
    sb.border_color = T.PRIMARY if unlocked else T.OUTLINE
    sb.set_corner_radius_all(T.RADIUS_SM)
    if not unlocked:
        sb.bg_color = Color(entry["color"].r * 0.3, entry["color"].g * 0.3, entry["color"].b * 0.3, 1.0)
    swatch.add_theme_stylebox_override("panel", sb)
    var v := VBoxContainer.new()
    swatch.add_child(v)
    var name_label := Label.new()
    name_label.text = String(entry["name"])
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.add_theme_font_size_override("font_size", T.FS_LABEL_SM)
    name_label.add_theme_color_override("font_color", _label_color(entry["color"]))
    v.add_child(name_label)
    if unlocked:
        var pot_label := Label.new()
        pot_label.text = "%d pots" % pots
        pot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        pot_label.add_theme_font_size_override("font_size", T.FS_LABEL_SM)
        pot_label.add_theme_color_override("font_color", _label_color(entry["color"]))
        v.add_child(pot_label)
    swatch.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed:
            _on_swatch(color_id, unlocked, pots)
        elif event is InputEventScreenTouch and event.pressed:
            _on_swatch(color_id, unlocked, pots))
    return swatch

func _label_color(c: Color) -> Color:
    var lum: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
    return Color(0.05, 0.04, 0.06) if lum > 0.55 else Color(1, 1, 1)

func _populate_saved_sets() -> void:
    for c in sets_row.get_children():
        c.queue_free()
    for set_name in GameState.saved_dye_sets.keys():
        var b := Button.new()
        b.text = set_name.to_upper()
        b.custom_minimum_size = Vector2(120, 40)
        UiStyle_.apply_secondary(b)
        UiAnim_.bind_press_feedback(b)
        b.pressed.connect(func():
            DyeSystem.load_dye_set(set_name)
            EventBus.floating_text.emit("Loaded set: %s" % set_name, Vector2.ZERO, T.PRIMARY)
            _populate_palette())
        sets_row.add_child(b)

func _on_slot_pressed(slot: String) -> void:
    current_slot = slot
    _refresh_slot_highlights()

func _refresh_slot_highlights() -> void:
    for c in slot_row.get_children():
        var b: Button = c as Button
        if b == null: continue
        if String(b.get_meta("slot")) == current_slot:
            UiStyle_.apply_primary(b)
        else:
            UiStyle_.apply_secondary(b)

func _on_swatch(color_id: String, unlocked: bool, pots: int) -> void:
    if not unlocked:
        EventBus.floating_text.emit("Color not yet discovered.", Vector2.ZERO, T.WARNING)
        return
    var was_pot: bool = pots > 0
    var ok: bool = DyeSystem.apply_dye(current_slot, color_id)
    if not ok:
        return
    if was_pot:
        SfxBus.play("perk_pick", -3.0)
        EventBus.floating_text.emit("Applied %s to %s" % [color_id, current_slot], Vector2.ZERO, T.SUCCESS)
    else:
        EventBus.floating_text.emit("Preview only — no pots of %s left." % color_id, Vector2.ZERO, T.WARNING)
    _populate_palette()

func _on_save_set() -> void:
    var name: String = "set_%d" % (GameState.saved_dye_sets.size() + 1)
    DyeSystem.save_dye_set(name)
    EventBus.floating_text.emit("Saved as %s" % name, Vector2.ZERO, T.PRIMARY)
    _populate_saved_sets()

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
