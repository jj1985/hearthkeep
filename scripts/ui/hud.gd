extends Control

# Combat HUD. Hand-anchored Control children per spec §7 + §13.3
# (no container; HUD is the one screen where explicit anchors are right).
#
# Anatomy (compact portrait):
#   top-left  — HP/MP/XP cluster
#   top-right — minimap stub + pause button
#   bottom-left  — virtual stick (144 dp)
#   bottom-mid   — potion shortcuts (HP/MP 56 dp each)
#   bottom-right — diamond skill cluster (primary 88, secondaries 72) + dodge

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

@onready var hp_bar: ProgressBar = $TopLeft/Bars/HPBar
@onready var mp_bar: ProgressBar = $TopLeft/Bars/MPBar
@onready var xp_bar: ProgressBar = $TopLeft/Bars/XPBar
@onready var lvl_label: Label = $TopLeft/Bars/Header/LevelLabel
@onready var floor_label: Label = $TopLeft/Bars/Header/FloorLabel
@onready var gold_label: Label = $TopRight/GoldLabel
@onready var pause_btn: Button = $TopRight/PauseButton
@onready var minimap_stub: PanelContainer = $TopRight/Minimap
@onready var perk_strip: HBoxContainer = $BuffRow/Strip
@onready var virtual_stick: Control = $VirtualStick

@onready var skill_primary: Button = $SkillCluster/Primary
@onready var skill_2: Button = $SkillCluster/S2
@onready var skill_3: Button = $SkillCluster/S3
@onready var skill_4: Button = $SkillCluster/S4
@onready var skill_5: Button = $SkillCluster/S5

@onready var potion_hp_btn: Button = $Potions/PotionHP
@onready var potion_mp_btn: Button = $Potions/PotionMP
@onready var dodge_btn: Button = $Dodge

var player: Node = null
var perk_chips: Array = []
var _low_hp_t: float = 0.0
var _was_low_hp: bool = false

func _ready() -> void:
    EventBus.perk_chosen.connect(_on_perk_chosen)
    EventBus.weapon_evolved.connect(_on_weapon_evolved)
    EventBus.currency_changed.connect(_on_currency_changed)
    _style_bars()
    _style_buttons()
    if not OS.has_feature("mobile") and not OS.has_feature("web"):
        virtual_stick.visible = false
        # Desktop keeps keyboard input; touch chrome stays present so the same
        # build can run on a connected phone screen, but is unobtrusive.
    _wire_skill_button(skill_primary, "attack")
    _wire_skill_button(skill_2, "skill_1")
    _wire_skill_button(skill_3, "skill_2")
    _wire_skill_button(skill_4, "skill_3")
    _wire_skill_button(skill_5, "skill_4")
    _wire_skill_button(potion_hp_btn, "potion_hp")
    _wire_skill_button(potion_mp_btn, "potion_mp")
    _wire_skill_button(dodge_btn, "dodge")
    pause_btn.pressed.connect(_on_pause)
    for b in [skill_primary, skill_2, skill_3, skill_4, skill_5, potion_hp_btn, potion_mp_btn, dodge_btn, pause_btn]:
        UiAnim_.bind_press_feedback(b, 0.92)

func _style_bars() -> void:
    _style_progress(hp_bar, T.ERROR, T.SURFACE_DIM)
    _style_progress(mp_bar, T.TERTIARY, T.SURFACE_DIM)
    _style_progress(xp_bar, T.PRIMARY, T.SURFACE_DIM)
    lvl_label.add_theme_color_override("font_color", T.PRIMARY)
    lvl_label.add_theme_font_size_override("font_size", T.FS_LABEL_LG)
    floor_label.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    floor_label.add_theme_font_size_override("font_size", T.FS_LABEL_MD)
    gold_label.add_theme_color_override("font_color", T.PRIMARY)
    gold_label.add_theme_font_size_override("font_size", T.FS_LABEL_LG)
    minimap_stub.add_theme_stylebox_override("panel", UiStyle_.card_resting())

func _style_progress(bar: ProgressBar, fill: Color, bg: Color) -> void:
    var sb_bg := StyleBoxFlat.new()
    sb_bg.bg_color = bg
    sb_bg.set_corner_radius_all(T.RADIUS_XS)
    sb_bg.border_color = T.OUTLINE
    sb_bg.set_border_width_all(1)
    var sb_fg := StyleBoxFlat.new()
    sb_fg.bg_color = fill
    sb_fg.set_corner_radius_all(T.RADIUS_XS)
    bar.add_theme_stylebox_override("background", sb_bg)
    bar.add_theme_stylebox_override("fill", sb_fg)

func _style_buttons() -> void:
    UiStyle_.apply_secondary(pause_btn)
    pause_btn.add_theme_font_size_override("font_size", T.FS_LABEL_LG)
    _style_skill_button(skill_primary, T.PRIMARY, true)
    _style_skill_button(skill_2, T.SECONDARY, false)
    _style_skill_button(skill_3, T.TERTIARY, false)
    _style_skill_button(skill_4, T.SUCCESS, false)
    _style_skill_button(skill_5, T.WARNING, false)
    _style_skill_button(potion_hp_btn, T.ERROR, false)
    _style_skill_button(potion_mp_btn, T.TERTIARY, false)
    _style_skill_button(dodge_btn, T.OUTLINE_VARIANT, false)
    dodge_btn.text = "↻"
    potion_hp_btn.text = "♥"
    potion_mp_btn.text = "✦"

func _style_skill_button(b: Button, accent: Color, is_primary: bool) -> void:
    var sb := StyleBoxFlat.new()
    sb.bg_color = T.SURFACE_BRIGHT
    sb.border_color = accent
    sb.set_border_width_all(3 if is_primary else 2)
    sb.set_corner_radius_all(T.RADIUS_ROUND)
    sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.35)
    sb.shadow_size = 8 if is_primary else 4
    var sb_pressed := sb.duplicate()
    sb_pressed.bg_color = accent
    b.add_theme_stylebox_override("normal", sb)
    b.add_theme_stylebox_override("hover", sb)
    b.add_theme_stylebox_override("pressed", sb_pressed)
    b.add_theme_color_override("font_color", T.ON_SURFACE)
    b.add_theme_color_override("font_pressed_color", T.ON_PRIMARY)
    b.add_theme_font_size_override("font_size",
        T.FS_TITLE_LG if is_primary else T.FS_TITLE_MD)

func _wire_skill_button(b: Button, action: String) -> void:
    b.button_down.connect(func(): Input.action_press(action))
    b.button_up.connect(func(): Input.action_release(action))

func _on_pause() -> void:
    get_tree().paused = not get_tree().paused

func _process(delta: float) -> void:
    if player == null:
        var p_arr := get_tree().get_nodes_in_group("player")
        if p_arr.is_empty():
            return
        player = p_arr[0]
    if player.has_method("get") and (player as Node).get("stats") != null:
        var s = player.stats
        var pct: float = s.hp / max(1.0, s.max_hp)
        hp_bar.value = pct * 100.0
        mp_bar.value = s.mp / max(1.0, s.max_mp) * 100.0
        # Low-HP warning: pulse + heartbeat ping when below 25%
        var is_low: bool = pct < 0.25 and pct > 0.0
        if is_low:
            _low_hp_t -= delta
            if _low_hp_t <= 0.0:
                _low_hp_t = 1.2
                SfxBus.play("low_hp", -10.0)
            hp_bar.modulate.a = 0.5 + 0.5 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012))
        elif _was_low_hp:
            hp_bar.modulate.a = 1.0
        _was_low_hp = is_low
    xp_bar.value = (RunState.xp / max(0.001, RunState.xp_to_next)) * 100.0
    lvl_label.text = "Lv %d" % RunState.player_level
    floor_label.text = "F%d" % (RunState.floor_index + 1)
    gold_label.text = "%d g" % GameState.gold

func _on_perk_chosen(id: String) -> void:
    var pill := _make_buff_pill(id, false)
    perk_strip.add_child(pill)
    perk_chips.append(pill)
    if perk_chips.size() > 8:
        var oldest = perk_chips.pop_front()
        if is_instance_valid(oldest):
            oldest.queue_free()

func _on_weapon_evolved(_from, evo_id: String) -> void:
    var pill := _make_buff_pill(evo_id, true)
    perk_strip.add_child(pill)

# 32×32 dp colored circle pill with a 1-letter glyph derived from the
# perk/evolution id. Real CC0 icons swap the ColorRect for a TextureRect
# in a future polish pass — the layout and pool stay identical.
func _make_buff_pill(id: String, is_evolution: bool) -> Control:
    var size: int = 32
    var pill := PanelContainer.new()
    pill.custom_minimum_size = Vector2(size, size)
    var sb := StyleBoxFlat.new()
    sb.bg_color = _accent_for_id(id, is_evolution)
    sb.set_corner_radius_all(size / 2)
    sb.border_color = T.PRIMARY if is_evolution else T.OUTLINE
    sb.set_border_width_all(2 if is_evolution else 1)
    if is_evolution:
        sb.shadow_color = Color(T.PRIMARY.r, T.PRIMARY.g, T.PRIMARY.b, 0.5)
        sb.shadow_size = 4
    pill.add_theme_stylebox_override("panel", sb)
    var glyph := Label.new()
    glyph.text = _glyph_for_id(id, is_evolution)
    glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    glyph.add_theme_font_size_override("font_size", 14)
    glyph.add_theme_color_override("font_color", T.ON_SURFACE)
    pill.add_child(glyph)
    pill.tooltip_text = id.replace("_", " ")
    return pill

func _glyph_for_id(id: String, is_evolution: bool) -> String:
    if is_evolution:
        return "★"
    var clean: String = id.replace("u_", "").replace("c_", "")
    if clean.is_empty():
        return "•"
    return clean.substr(0, 1).to_upper()

func _accent_for_id(id: String, is_evolution: bool) -> Color:
    if is_evolution:
        return T.SECONDARY
    var l: String = id.to_lower()
    if l.contains("fire") or l.contains("flame") or l.contains("infernal") or l.contains("ember"):
        return T.SECONDARY
    if l.contains("frost") or l.contains("ice") or l.contains("cold"):
        return T.TERTIARY
    if l.contains("poison") or l.contains("plague") or l.contains("venom"):
        return T.SUCCESS
    if l.contains("crit") or l.contains("luck"):
        return T.PRIMARY
    if l.contains("heal") or l.contains("regen") or l.contains("life"):
        return T.SUCCESS
    if l.contains("storm") or l.contains("lightning") or l.contains("shock"):
        return T.WARNING
    return T.SURFACE_OVERLAY

func _on_currency_changed(_kind, _delta, _total) -> void:
    pass
