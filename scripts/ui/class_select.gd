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
@onready var preview_portrait: Control = $SafeArea/V/Preview/Margin/H/PortraitFrame/Portrait
@onready var preview_name: Label = $SafeArea/V/Preview/Margin/H/Info/Name
@onready var preview_pitch: Label = $SafeArea/V/Preview/Margin/H/Info/Pitch
@onready var preview_tags: HBoxContainer = $SafeArea/V/Preview/Margin/H/Info/Tags
@onready var tab_primary_btn: Button = $SafeArea/V/Tabs/Primary
@onready var tab_secondary_btn: Button = $SafeArea/V/Tabs/Secondary
@onready var tab_tertiary_btn: Button = $SafeArea/V/Tabs/Tertiary
@onready var class_list: VBoxContainer = $SafeArea/V/Scroll/List
@onready var hybrid_callout: PanelContainer = $SafeArea/V/HybridCallout
@onready var hybrid_callout_label: Label = $SafeArea/V/HybridCallout/Label
@onready var begin_btn: Button = $SafeArea/V/Begin

var pending_primary: String = "warrior"
var pending_secondary: String = ""
var pending_tertiary: String = ""
var current_tab: String = "primary"     # "primary", "secondary", or "tertiary"
var row_buttons: Array[Button] = []

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    _apply_typography()
    _wire_chrome()
    # Tertiary tab is gated on the meta-unlock granted by defeating
    # all three dragons (TrophyManager sets the flag).
    tab_tertiary_btn.visible = bool(GameState.meta_unlocks.get("triple_class", false))
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
    UiStyle_.apply_secondary(tab_tertiary_btn)
    UiStyle_.apply_primary(begin_btn)
    hybrid_callout.add_theme_stylebox_override("panel", UiStyle_.card_evolution())
    hybrid_callout_label.add_theme_font_size_override("font_size", T.FS_LABEL_LG)
    hybrid_callout_label.add_theme_color_override("font_color", T.PRIMARY)

func _wire_chrome() -> void:
    tab_primary_btn.pressed.connect(_select_tab.bind("primary"))
    tab_secondary_btn.pressed.connect(_select_tab.bind("secondary"))
    tab_tertiary_btn.pressed.connect(_select_tab.bind("tertiary"))
    begin_btn.pressed.connect(_on_begin)
    for b in [tab_primary_btn, tab_secondary_btn, tab_tertiary_btn, begin_btn]:
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
    var unlocked: bool = GameState.unlocked_classes.has(id)
    var label: String = "  %s  ›" % def.get("name", id.capitalize())
    if not unlocked:
        label = "  🔒  %s   (locked)" % def.get("name", id.capitalize())
    b.text = label
    b.alignment = HORIZONTAL_ALIGNMENT_LEFT
    b.set_meta("class_id", id)
    b.set_meta("unlocked", unlocked)
    b.custom_minimum_size = Vector2(0, 88)
    UiStyle_.apply_secondary(b)
    b.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    if unlocked:
        b.pressed.connect(_on_row_pressed.bind(id))
        UiAnim_.bind_press_feedback(b)
    else:
        b.disabled = true
        b.add_theme_color_override("font_disabled_color", T.ON_SURFACE_DISABLED)
    return b

func _on_row_pressed(id: String) -> void:
    if current_tab == "primary":
        if pending_secondary == id:
            pending_secondary = ""
        if pending_tertiary == id:
            pending_tertiary = ""
        pending_primary = id
    elif current_tab == "secondary":
        if pending_primary == id:
            return    # can't pick the primary as your secondary
        if pending_tertiary == id:
            pending_tertiary = ""
        if pending_secondary == id:
            pending_secondary = ""
        else:
            pending_secondary = id
    else: # tertiary
        if pending_primary == id or pending_secondary == id:
            return    # tertiary can't dupe primary/secondary
        if pending_tertiary == id:
            pending_tertiary = ""
        else:
            pending_tertiary = id
    _refresh()

func _select_tab(tab: String) -> void:
    current_tab = tab
    _refresh()

func _refresh() -> void:
    var preview_id: String = pending_primary
    if current_tab == "secondary":
        preview_id = pending_secondary if pending_secondary != "" else pending_primary
    elif current_tab == "tertiary":
        preview_id = pending_tertiary if pending_tertiary != "" else pending_primary
    var pdef: Dictionary = Classes.get_class_def(preview_id)
    if preview_portrait.has_method("set"):
        preview_portrait.set("class_id", preview_id)
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
    var active_id: String = pending_primary
    if current_tab == "secondary":
        active_id = pending_secondary
    elif current_tab == "tertiary":
        active_id = pending_tertiary
    for b in row_buttons:
        var id: String = b.get_meta("class_id")
        var is_active: bool = (id == active_id)
        var is_locked: bool = false
        if current_tab == "secondary" and id == pending_primary:
            is_locked = true
        elif current_tab == "tertiary" and (id == pending_primary or id == pending_secondary):
            is_locked = true
        b.disabled = is_locked
        if is_active:
            UiStyle_.apply_primary(b)
            b.add_theme_color_override("font_color", T.ON_PRIMARY)
        else:
            UiStyle_.apply_secondary(b)
            if is_locked:
                b.add_theme_color_override("font_color", T.ON_SURFACE_DISABLED)

func _refresh_tabs() -> void:
    UiStyle_.apply_secondary(tab_primary_btn)
    UiStyle_.apply_secondary(tab_secondary_btn)
    UiStyle_.apply_secondary(tab_tertiary_btn)
    if current_tab == "primary":
        UiStyle_.apply_primary(tab_primary_btn)
    elif current_tab == "secondary":
        UiStyle_.apply_primary(tab_secondary_btn)
    else:
        UiStyle_.apply_primary(tab_tertiary_btn)

func _refresh_begin() -> void:
    var p_def: Dictionary = Classes.get_class_def(pending_primary)
    var p_name: String = p_def.get("name", "?").to_upper()
    if pending_secondary == "":
        begin_btn.text = "BEGIN AS %s" % p_name
        hybrid_callout.visible = false
        return
    var s_def: Dictionary = Classes.get_class_def(pending_secondary)
    var s_name: String = s_def.get("name", "?").to_upper()
    if pending_tertiary != "":
        var t_def: Dictionary = Classes.get_class_def(pending_tertiary)
        var t_name: String = t_def.get("name", "?").to_upper()
        begin_btn.text = "BEGIN AS %s/%s/%s" % [p_name, s_name, t_name]
        # Enumerate every pairwise hybrid prestige present in the trio.
        var pairs: Array = [
            [pending_primary, pending_secondary],
            [pending_primary, pending_tertiary],
            [pending_secondary, pending_tertiary],
        ]
        var matched: Array = []
        var seen: Dictionary = {}
        for pair in pairs:
            var h: Dictionary = Classes.hybrid_for(pair[0], pair[1])
            if h.is_empty():
                continue
            var hid: String = String(h.get("id", ""))
            if seen.has(hid):
                continue
            seen[hid] = true
            matched.append(String(h.get("name", "")).to_upper())
        if matched.is_empty():
            hybrid_callout_label.text = "⚜  TRIPLE-CLASS — 50/30/20 STAT BLEND"
        else:
            hybrid_callout_label.text = "⚜  TRIPLE-CLASS  ·  " + " + ".join(matched)
        hybrid_callout.visible = true
        return
    begin_btn.text = "BEGIN AS %s/%s" % [p_name, s_name]
    var hybrid: Dictionary = Classes.hybrid_for(pending_primary, pending_secondary)
    if hybrid.is_empty():
        hybrid_callout.visible = false
    else:
        hybrid_callout_label.text = "⚜  %s  —  Hybrid prestige unlocked" % String(hybrid.get("name", "")).to_upper()
        hybrid_callout.visible = true

func _on_begin() -> void:
    if not RunState.set_classes(pending_primary, pending_secondary, pending_tertiary):
        return
    # Route through loading screen for cinematic transition.
    var loading_ps: PackedScene = load("res://scenes/ui/loading_screen.tscn")
    if loading_ps == null:
        get_tree().change_scene_to_file("res://scenes/run.tscn")
        return
    var loading := loading_ps.instantiate()
    loading.next_scene = "res://scenes/run.tscn"
    loading.auto_advance_after = 2.4
    get_tree().root.add_child(loading)
    queue_free()
