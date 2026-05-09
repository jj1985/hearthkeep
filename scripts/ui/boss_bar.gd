extends Control

# Boss HP banner. Spawned by arena_runner above the HUD; reads the
# current dragon's hp/max_hp/phase each frame and renders:
#   - Boss name (display_md gold)
#   - Wide HP bar with phase color
#   - Phase indicator chips (Ground/Air/Enraged) lighting up as the boss
#     advances. Hits a heartbeat pulse when within 5% of next phase
#     threshold.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")

@export var boss_path: NodePath

@onready var name_label: Label = $V/Name
@onready var bar: ProgressBar = $V/Bar
@onready var phase_row: HBoxContainer = $V/Phases
@onready var phase_ground: PanelContainer = $V/Phases/Ground
@onready var phase_air: PanelContainer = $V/Phases/Air
@onready var phase_enraged: PanelContainer = $V/Phases/Enraged

var boss: Node = null
var pulse_t: float = 0.0

func _ready() -> void:
    name_label.add_theme_font_size_override("font_size", T.FS_HEADLINE_SM)
    name_label.add_theme_color_override("font_color", T.PRIMARY)
    _style_bar()
    _style_phase_chips()
    _resolve_boss()

func _resolve_boss() -> void:
    if boss_path != NodePath(""):
        boss = get_node_or_null(boss_path)
    if boss == null:
        var arr := get_tree().get_nodes_in_group("boss")
        if not arr.is_empty():
            boss = arr[0]
    if boss != null:
        var d = boss.get("dragon_id")
        name_label.text = String(d if d != null else "boss").to_upper()

func _style_bar() -> void:
    var sb_bg := StyleBoxFlat.new()
    sb_bg.bg_color = T.SURFACE_DIM
    sb_bg.border_color = T.OUTLINE_VARIANT
    sb_bg.set_border_width_all(1)
    sb_bg.set_corner_radius_all(T.RADIUS_XS)
    bar.add_theme_stylebox_override("background", sb_bg)
    var sb_fg := StyleBoxFlat.new()
    sb_fg.bg_color = T.ERROR
    sb_fg.set_corner_radius_all(T.RADIUS_XS)
    bar.add_theme_stylebox_override("fill", sb_fg)

func _style_phase_chips() -> void:
    for chip in [phase_ground, phase_air, phase_enraged]:
        chip.add_theme_stylebox_override("panel", UiStyle_.chip())

func _process(delta: float) -> void:
    pulse_t += delta
    if boss == null or not is_instance_valid(boss):
        _resolve_boss()
        if boss == null or not is_instance_valid(boss):
            visible = false
            return
    visible = not boss.is_dead()
    var hp: float = float(boss.get("hp"))
    var max_hp: float = float(boss.get("max_hp"))
    if max_hp <= 0.0:
        return
    var pct: float = hp / max_hp
    bar.value = pct * 100.0
    var phase: int = int(boss.get("phase"))
    _refresh_phase_chips(phase)
    _refresh_bar_color(phase)
    # Heartbeat pulse when within 5% of next threshold (0.70 or 0.33)
    var near_threshold: bool = (pct > 0.70 and pct < 0.75) or (pct > 0.33 and pct < 0.38)
    if near_threshold:
        bar.modulate.a = 0.7 + 0.3 * sin(pulse_t * 8.0)
    else:
        bar.modulate.a = 1.0

func _refresh_phase_chips(phase: int) -> void:
    var labels: Array[Label] = []
    for chip in [phase_ground, phase_air, phase_enraged]:
        if chip.get_child_count() == 0:
            var l := Label.new()
            l.add_theme_font_size_override("font_size", T.FS_LABEL_SM)
            chip.add_child(l)
        labels.append(chip.get_child(0))
    labels[0].text = "GROUND"
    labels[1].text = "AIR"
    labels[2].text = "ENRAGED"
    var phases := [phase_ground, phase_air, phase_enraged]
    var phase_colors := [T.ON_SURFACE_MUTED, T.TERTIARY, T.SECONDARY]
    for i in range(3):
        var active: bool = phase >= i
        var current: bool = phase == i
        var c: Color = phase_colors[i] if (active or current) else T.ON_SURFACE_DISABLED
        labels[i].add_theme_color_override("font_color", c)
        var sb := UiStyle_.chip()
        if current:
            sb.border_color = c
            sb.set_border_width_all(2)
        phases[i].add_theme_stylebox_override("panel", sb)

func _refresh_bar_color(phase: int) -> void:
    var sb := bar.get_theme_stylebox("fill") as StyleBoxFlat
    if sb == null: return
    var color: Color = T.ERROR
    if phase == 1: color = Color(T.ERROR.r, T.ERROR.g * 0.5, T.SECONDARY.b * 0.6)    # ember-red
    elif phase == 2: color = T.SECONDARY
    sb.bg_color = color
