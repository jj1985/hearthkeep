extends Control

# Trophy Hall display picker. Spec §10.4. Opened by villa proximity to
# a pedestal; lets the player place / unplace a trophy, toggle which
# placed trophies are active (set bonus), and see set progress.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var slot_label: Label = $SafeArea/V/SlotLabel
@onready var collected_grid: GridContainer = $SafeArea/V/Scroll/Collected
@onready var sets_label: Label = $SafeArea/V/Sets
@onready var active_label: Label = $SafeArea/V/Active
@onready var close_btn: Button = $SafeArea/V/Footer/Close

var slot_id: String = ""

func _ready() -> void:
    if slot_id == "" and TrophyManager.target_slot_id != "":
        slot_id = TrophyManager.target_slot_id
    if slot_id == "":
        slot_id = "pedestal_1"
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    headline.text = "DISPLAY A TROPHY"
    slot_label.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    slot_label.add_theme_font_size_override("font_size", T.FS_BODY_LG)
    sets_label.add_theme_color_override("font_color", T.ON_SURFACE)
    sets_label.add_theme_font_size_override("font_size", T.FS_BODY_MD)
    active_label.add_theme_color_override("font_color", T.PRIMARY)
    active_label.add_theme_font_size_override("font_size", T.FS_TITLE_MD)
    UiStyle_.apply_secondary(close_btn)
    UiAnim_.bind_press_feedback(close_btn)
    close_btn.pressed.connect(_on_close)
    collected_grid.columns = _grid_cols()
    if Engine.has_singleton("OrientationMgr"):
        OrientationMgr.bucket_changed.connect(func(_b): collected_grid.columns = _grid_cols())
    _refresh()

func _grid_cols() -> int:
    if not Engine.has_singleton("OrientationMgr"):
        return 3
    match OrientationMgr.bucket:
        OrientationMgr.Bucket.MEDIUM: return 4
        OrientationMgr.Bucket.EXPANDED: return 6
    return 3

func setup_for_slot(p_slot_id: String) -> void:
    slot_id = p_slot_id
    if is_inside_tree():
        _refresh()

func _refresh() -> void:
    var current: String = String(TrophyManager.placed.get(slot_id, ""))
    if current != "":
        var def: Dictionary = _trophy_def(current)
        slot_label.text = "Slot:  %s  (currently  %s)" % [slot_id, def.get("name", current)]
    else:
        slot_label.text = "Slot:  %s  (empty)" % slot_id
    for c in collected_grid.get_children():
        c.queue_free()
    var any: bool = false
    for tid in TrophyManager.collected.keys():
        if int(TrophyManager.collected[tid]) > 0:
            any = true
            collected_grid.add_child(_trophy_card(tid))
    if not any:
        var empty := Label.new()
        empty.text = "The first dragon will not slay itself."
        empty.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        empty.add_theme_font_size_override("font_size", T.FS_BODY_LG)
        collected_grid.add_child(empty)
    var progress: Array = TrophyManager.set_progress()
    var lines: Array = []
    for s in progress:
        var pct: int = int(round(float(s["have"]) * 100.0 / max(1.0, float(s["need"]))))
        lines.append("%s — %d/%d (%d%%)" % [String(s["name"]), int(s["have"]), int(s["need"]), pct])
    sets_label.text = "\n".join(lines) if not lines.is_empty() else ""
    active_label.text = "Active buffs:  %d / %d" % [TrophyManager.active_buff_ids.size(), TrophyManager.active_cap]

func _trophy_def(tid: String) -> Dictionary:
    for t in TrophyManager.TrophyDB.TROPHIES:
        if t["id"] == tid: return t
    return {"id": tid, "name": tid, "buff": ""}

func _trophy_card(tid: String) -> Control:
    var def: Dictionary = _trophy_def(tid)
    var placed_here: bool = TrophyManager.placed.get(slot_id, "") == tid
    var active: bool = TrophyManager.active_buff_ids.has(tid)

    var panel := PanelContainer.new()
    var sb: StyleBoxFlat = UiStyle_.card_resting()
    if placed_here:
        sb.border_color = T.PRIMARY
        sb.set_border_width_all(2)
    panel.add_theme_stylebox_override("panel", sb)
    panel.custom_minimum_size = Vector2(0, 130)

    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    panel.add_child(v)
    var name_label := Label.new()
    name_label.text = String(def.get("name", tid))
    name_label.add_theme_font_size_override("font_size", T.FS_TITLE_MD)
    name_label.add_theme_color_override("font_color", T.PRIMARY if (placed_here or active) else T.ON_SURFACE)
    v.add_child(name_label)
    if def.has("buff"):
        var buff_label := Label.new()
        buff_label.text = String(def["buff"])
        buff_label.add_theme_font_size_override("font_size", T.FS_BODY_SM)
        buff_label.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        buff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        v.add_child(buff_label)
    var btn_row := HBoxContainer.new()
    btn_row.add_theme_constant_override("separation", 6)
    v.add_child(btn_row)
    var place_btn := Button.new()
    place_btn.text = "REMOVE" if placed_here else "DISPLAY"
    place_btn.custom_minimum_size = Vector2(0, 40)
    UiStyle_.apply_primary(place_btn) if placed_here else UiStyle_.apply_secondary(place_btn)
    UiAnim_.bind_press_feedback(place_btn)
    place_btn.pressed.connect(_toggle_place.bind(tid))
    btn_row.add_child(place_btn)
    var active_btn := Button.new()
    active_btn.text = "ACTIVE ✓" if active else "ACTIVATE"
    active_btn.custom_minimum_size = Vector2(0, 40)
    if active:
        UiStyle_.apply_primary(active_btn)
    else:
        UiStyle_.apply_secondary(active_btn)
    UiAnim_.bind_press_feedback(active_btn)
    active_btn.pressed.connect(_toggle_active.bind(tid))
    btn_row.add_child(active_btn)
    return panel

func _toggle_place(tid: String) -> void:
    if TrophyManager.placed.get(slot_id, "") == tid:
        TrophyManager.unplace(slot_id)
    else:
        TrophyManager.place(slot_id, tid)
    SfxBus.play("perk_pick", -2.0)
    _refresh()

func _toggle_active(tid: String) -> void:
    var was_active: bool = TrophyManager.active_buff_ids.has(tid)
    if not TrophyManager.set_active(tid, not was_active):
        EventBus.floating_text.emit("Active buff cap reached.", Vector2.ZERO, T.WARNING)
        return
    SfxBus.play("levelup", -3.0)
    _refresh()

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
