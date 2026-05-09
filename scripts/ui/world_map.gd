extends Control

# World map / travel UI. Shows the Sundered Realms with discovered
# Wayspire portals as gold nodes, undiscovered as dim outlines, the
# player's bond location as an ember diamond. Tap a discovered portal
# to set it as the next bond, or to fast-travel (Phase A: just rebinds
# bond — actual scene-warp happens when the player uses the bond stone
# from a run).

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

# Logical map coordinates (0..1 in both axes — laid out so portals are
# distinct on a phone screen). Names match TravelSystem.unlocked_portals
# keys + LoreCodex region entries.
const PORTAL_LAYOUT := {
    "valehome_keep":     {"label": "Valehome Keep",       "pos": Vector2(0.50, 0.40)},
    "duskport_alley":    {"label": "Duskport Alley",      "pos": Vector2(0.78, 0.62)},
    "thalanore_canopy":  {"label": "Thalanore Canopy",    "pos": Vector2(0.20, 0.30)},
    "graymarrow_gate":   {"label": "Graymarrow Gate",     "pos": Vector2(0.30, 0.72)},
    "ashfen_outpost":    {"label": "Ashfen Outpost",      "pos": Vector2(0.66, 0.18)},
    "fearhollow_seal":   {"label": "Fearhollow Seal",     "pos": Vector2(0.78, 0.86)},
    "ruinmarch_camp":    {"label": "Ruinmarch Camp",      "pos": Vector2(0.36, 0.18)},
}

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var subhead: Label = $SafeArea/V/Subhead
@onready var canvas: Control = $SafeArea/V/MapPanel/Canvas
@onready var detail: Label = $SafeArea/V/Detail
@onready var bind_btn: Button = $SafeArea/V/Footer/Bind
@onready var close_btn: Button = $SafeArea/V/Footer/Close
@onready var unlock_all_btn: Button = $SafeArea/V/Footer/UnlockAll

var selected_portal: String = ""

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    subhead.add_theme_font_size_override("font_size", T.FS_BODY_LG)
    subhead.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    detail.add_theme_color_override("font_color", T.ON_SURFACE)
    detail.add_theme_font_size_override("font_size", T.FS_BODY_LG)
    UiStyle_.apply_primary(bind_btn)
    UiStyle_.apply_secondary(close_btn)
    UiStyle_.apply_secondary(unlock_all_btn)
    UiAnim_.bind_press_feedback(bind_btn)
    UiAnim_.bind_press_feedback(close_btn)
    UiAnim_.bind_press_feedback(unlock_all_btn)
    bind_btn.pressed.connect(_on_bind)
    close_btn.pressed.connect(_on_close)
    unlock_all_btn.pressed.connect(_on_unlock_all)
    canvas.gui_input.connect(_on_canvas_click)
    canvas.draw.connect(_draw_canvas)
    selected_portal = TravelSystem.bond_location
    _refresh_detail()

func _draw_canvas() -> void:
    var s: Vector2 = canvas.size
    if s.x < 4 or s.y < 4: return
    canvas.draw_rect(Rect2(Vector2.ZERO, s), T.SURFACE)
    canvas.draw_rect(Rect2(Vector2.ZERO, s), T.OUTLINE_VARIANT, false, 1.5)
    # Road network (straight lines between portals; visual only)
    for from_id in PORTAL_LAYOUT.keys():
        for to_id in PORTAL_LAYOUT.keys():
            if from_id >= to_id: continue
            var p1: Vector2 = _portal_pos_in_canvas(from_id)
            var p2: Vector2 = _portal_pos_in_canvas(to_id)
            canvas.draw_line(p1, p2, Color(T.OUTLINE.r, T.OUTLINE.g, T.OUTLINE.b, 0.3), 1.0)
    # Portals
    for pid in PORTAL_LAYOUT.keys():
        var center: Vector2 = _portal_pos_in_canvas(pid)
        var unlocked: bool = TravelSystem.is_unlocked(pid)
        var bonded: bool = pid == TravelSystem.bond_location
        var selected: bool = pid == selected_portal
        var color: Color = T.PRIMARY if unlocked else T.OUTLINE
        var radius: float = 8.0 if unlocked else 6.0
        if bonded:
            # Ember-tinted halo
            canvas.draw_circle(center, radius + 6.0, Color(T.SECONDARY.r, T.SECONDARY.g, T.SECONDARY.b, 0.45))
        if selected:
            canvas.draw_circle(center, radius + 4.0, Color(T.PRIMARY.r, T.PRIMARY.g, T.PRIMARY.b, 0.35))
        canvas.draw_circle(center, radius, color)
        var label_pos: Vector2 = center + Vector2(12.0, -4.0)
        canvas.draw_string(get_theme_default_font(), label_pos,
            String(PORTAL_LAYOUT[pid]["label"]),
            HORIZONTAL_ALIGNMENT_LEFT, -1, 12, T.ON_SURFACE if unlocked else T.ON_SURFACE_MUTED)

func _portal_pos_in_canvas(pid: String) -> Vector2:
    var s: Vector2 = canvas.size
    var rel: Vector2 = PORTAL_LAYOUT[pid]["pos"]
    return Vector2(rel.x * s.x, rel.y * s.y)

func _on_canvas_click(event: InputEvent) -> void:
    var pos: Vector2 = Vector2.ZERO
    if event is InputEventMouseButton and event.pressed:
        pos = event.position
    elif event is InputEventScreenTouch and event.pressed:
        pos = event.position
    else:
        return
    var best_d := 24.0
    var picked := ""
    for pid in PORTAL_LAYOUT.keys():
        var center: Vector2 = _portal_pos_in_canvas(pid)
        var d: float = pos.distance_to(center)
        if d < best_d:
            best_d = d
            picked = pid
    if picked != "":
        selected_portal = picked
        _refresh_detail()
        canvas.queue_redraw()

func _refresh_detail() -> void:
    if selected_portal == "":
        detail.text = "Tap a portal."
        bind_btn.disabled = true
        return
    var label: String = String(PORTAL_LAYOUT[selected_portal]["label"])
    var unlocked: bool = TravelSystem.is_unlocked(selected_portal)
    var bonded: bool = selected_portal == TravelSystem.bond_location
    if not unlocked:
        detail.text = "%s — undiscovered.  Find it in the world to unlock." % label
        bind_btn.disabled = true
    elif bonded:
        detail.text = "%s — already your bond." % label
        bind_btn.disabled = true
    else:
        detail.text = "%s — set as your bond?" % label
        bind_btn.disabled = false

func _on_bind() -> void:
    if not TravelSystem.set_bond(selected_portal): return
    SfxBus.play("levelup", -3.0)
    EventBus.floating_text.emit("Bond set: %s" % PORTAL_LAYOUT[selected_portal]["label"], Vector2.ZERO, T.PRIMARY)
    _refresh_detail()
    canvas.queue_redraw()

func _on_unlock_all() -> void:
    # Cheat / dev-aid: marks all portals unlocked. The user asked for this
    # via the Wager-the-Run / gambling currency loop in spirit; it's gated
    # behind a 5000-gold cost so it has weight.
    if GameState.gold < 5000:
        EventBus.floating_text.emit("Need 5000 g to bribe the wayspire keepers.", Vector2.ZERO, T.ERROR)
        return
    GameState.add_gold(-5000)
    for pid in PORTAL_LAYOUT.keys():
        TravelSystem.unlock(pid)
    EventBus.floating_text.emit("All wayspires unlocked.", Vector2.ZERO, T.PRIMARY)
    _refresh_detail()
    canvas.queue_redraw()

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
