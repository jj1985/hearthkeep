extends Control

# Character creator — paginated single-column list with sticky preview.
# Spec: docs/ui_spec.md §8. Compact-canonical layout; medium/expanded
# rearrangements are TODO behind OrientationMgr.bucket.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

const CLASS_ORDER := ["warrior", "rogue", "wizard", "necromancer", "bard", "paladin", "ranger"]

# Class-tinted placeholder portraits — replaced when real CC0 art lands.
const CLASS_TINT := {
    "warrior": Color("#7C5C3D"),
    "rogue": Color("#3D3A4A"),
    "wizard": Color("#3D5A7C"),
    "necromancer": Color("#3D2D3D"),
    "bard": Color("#7C5A3D"),
    "paladin": Color("#9A7C3D"),
    "ranger": Color("#3D5A3D"),
}

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var preview: PanelContainer = $SafeArea/V/Preview
@onready var preview_portrait: ColorRect = $SafeArea/V/Preview/Margin/H/PortraitFrame/Portrait
@onready var preview_name: Label = $SafeArea/V/Preview/Margin/H/Info/Name
@onready var preview_pitch: Label = $SafeArea/V/Preview/Margin/H/Info/Pitch
@onready var preview_tags: HBoxContainer = $SafeArea/V/Preview/Margin/H/Info/Tags
@onready var tab_primary_btn: Button = $SafeArea/V/Tabs/Primary
@onready var tab_secondary_btn: Button = $SafeArea/V/Tabs/Secondary
@onready var class_list: VBoxContainer = $SafeArea/V/Scroll/List
@onready var hybrid_callout: PanelContainer = $SafeArea/V/HybridCallout
@onready var hybrid_callout_label: Label = $SafeArea/V/HybridCallout/Label
@onready var begin_btn: Button = $SafeArea/V/Begin

var pending_primary: String = "warrior"
var pending_secondary: String = ""
var current_tab: String = "primary"     # "primary" or "secondary"
var row_buttons: Array[Button] = []

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    _apply_typography()
    _wire_chrome()
    _populate_list()
    _refresh()

func _apply_typography() -> void:
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    preview.add_theme_stylebox_override("panel", UiStyle_.panel_modal())
    preview_name.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    preview_name.add_theme_color_override("font_color", T.ON_SURFACE)
    preview_pitch.add_theme_font_size_override("font_size", T.FS_BODY_MD)
    preview_pitch.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    UiStyle_.apply_secondary(tab_primary_btn)
    UiStyle_.apply_secondary(tab_secondary_btn)
    UiStyle_.apply_primary(begin_btn)
    hybrid_callout.add_theme_stylebox_override("panel", UiStyle_.card_evolution())
    hybrid_callout_label.add_theme_font_size_override("font_size", T.FS_LABEL_LG)
    hybrid_callout_label.add_theme_color_override("font_color", T.PRIMARY)

func _wire_chrome() -> void:
    tab_primary_btn.pressed.connect(_select_tab.bind("primary"))
    tab_secondary_btn.pressed.connect(_select_tab.bind("secondary"))
    begin_btn.pressed.connect(_on_begin)
    for b in [tab_primary_btn, tab_secondary_btn, begin_btn]:
        UiAnim_.bind_press_feedback(b)

func _populate_list() -> void:
    for c in class_list.get_children():
        c.queue_free()
    row_buttons.clear()
    for id in CLASS_ORDER:
        var row := _make_class_row(id)
        class_list.add_child(row)
        row_buttons.append(row)

func _make_class_row(id: String) -> Button:
    var b := Button.new()
    var def: Dictionary = Classes.get_class_def(id)
    b.text = "  %s  ›" % def.get("name", id.capitalize())
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.set_meta("class_id", id)
    b.custom_minimum_size = Vector2(0, 88)
    UiStyle_.apply_secondary(b)
    b.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    b.pressed.connect(_on_row_pressed.bind(id))
    UiAnim_.bind_press_feedback(b)
    return b

func _on_row_pressed(id: String) -> void:
    if current_tab == "primary":
        if pending_secondary == id:
            pending_secondary = ""
        pending_primary = id
    else:
        if pending_primary == id:
            return    # can't pick the primary as your secondary
        if pending_secondary == id:
            pending_secondary = ""
        else:
            pending_secondary = id
    _refresh()

func _select_tab(tab: String) -> void:
    current_tab = tab
    _refresh()

func _refresh() -> void:
    var preview_id: String = pending_primary if current_tab == "primary" else (pending_secondary if pending_secondary != "" else pending_primary)
    var pdef: Dictionary = Classes.get_class_def(preview_id)
    preview_portrait.color = CLASS_TINT.get(preview_id, T.SURFACE_OVERLAY)
    preview_name.text = pdef.get("name", "?")
    preview_pitch.text = pdef.get("blurb", "")
    _populate_tags(pdef)
    _refresh_rows()
    _refresh_tabs()
    _refresh_begin()

func _populate_tags(def: Dictionary) -> void:
    for c in preview_tags.get_children():
        c.queue_free()
    var tags: Array = def.get("tags", [])
    for t in tags:
        var chip_btn := Label.new()
        chip_btn.text = String(t).to_upper()
        chip_btn.add_theme_font_size_override("font_size", T.FS_LABEL_SM)
        chip_btn.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        var box := PanelContainer.new()
        box.add_theme_stylebox_override("panel", UiStyle_.chip())
        box.add_child(chip_btn)
        preview_tags.add_child(box)

func _refresh_rows() -> void:
    var active_id: String = pending_primary if current_tab == "primary" else pending_secondary
    for b in row_buttons:
        var id: String = b.get_meta("class_id")
        var is_active: bool = (id == active_id)
        var is_locked_secondary: bool = current_tab == "secondary" and id == pending_primary
        b.disabled = is_locked_secondary
        if is_active:
            UiStyle_.apply_primary(b)
            b.add_theme_color_override("font_color", T.ON_PRIMARY)
        else:
            UiStyle_.apply_secondary(b)
            if is_locked_secondary:
                b.add_theme_color_override("font_color", T.ON_SURFACE_DISABLED)

func _refresh_tabs() -> void:
    if current_tab == "primary":
        UiStyle_.apply_primary(tab_primary_btn)
        UiStyle_.apply_secondary(tab_secondary_btn)
    else:
        UiStyle_.apply_secondary(tab_primary_btn)
        UiStyle_.apply_primary(tab_secondary_btn)

func _refresh_begin() -> void:
    var p_def: Dictionary = Classes.get_class_def(pending_primary)
    var p_name: String = p_def.get("name", "?").to_upper()
    if pending_secondary == "":
        begin_btn.text = "BEGIN AS %s" % p_name
        hybrid_callout.visible = false
        return
    var s_def: Dictionary = Classes.get_class_def(pending_secondary)
    var s_name: String = s_def.get("name", "?").to_upper()
    begin_btn.text = "BEGIN AS %s/%s" % [p_name, s_name]
    var hybrid: Dictionary = Classes.hybrid_for(pending_primary, pending_secondary)
    if hybrid.is_empty():
        hybrid_callout.visible = false
    else:
        hybrid_callout_label.text = "⚜  %s  —  Hybrid prestige unlocked" % String(hybrid.get("name", "")).to_upper()
        hybrid_callout.visible = true

func _on_begin() -> void:
    if not RunState.set_classes(pending_primary, pending_secondary):
        return
    get_tree().change_scene_to_file("res://scenes/run.tscn")
