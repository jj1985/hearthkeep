extends Control

# 2D incremental horde arena.
#
# - Hero auto-attacks the closest enemy.
# - Enemies spawn from arena edges in waves.
# - Killing enemies grants gold + tracks lifetime kills (for milestones).
# - Wave clears advance to the next wave (faster, tougher spawns).
# - Multiclass milestones surface as overlay prompts: pick a second/third class.
# - All Control-node 2D — no physics, no 3D, no preloaded mesh — should
#   sidestep the crashes the prior 3D run flow was hitting on device.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const Achievements := preload("res://scripts/incremental/achievements.gd")
const Synergies := preload("res://scripts/incremental/synergies.gd")

const ENEMY_TYPES := {
    "skeleton":   {"label": "Skeleton",   "color": Color(0.85, 0.85, 0.78), "hp_base": 6,   "speed": 70.0,  "gold": 1,  "size": 28, "min_wave": 1},
    "goblin":     {"label": "Goblin",     "color": Color(0.45, 0.75, 0.35), "hp_base": 10,  "speed": 95.0,  "gold": 2,  "size": 28, "min_wave": 3},
    "skel_brute": {"label": "Bone Brute", "color": Color(0.75, 0.70, 0.55), "hp_base": 24,  "speed": 55.0,  "gold": 5,  "size": 32, "min_wave": 6},
    "ghoul":      {"label": "Ghoul",      "color": Color(0.55, 0.70, 0.50), "hp_base": 40,  "speed": 110.0, "gold": 9,  "size": 30, "min_wave": 9},
    "drake":      {"label": "Drake",      "color": Color(0.85, 0.35, 0.25), "hp_base": 60,  "speed": 75.0,  "gold": 14, "size": 36, "min_wave": 12},
    "wraith":     {"label": "Wraith",     "color": Color(0.55, 0.45, 0.85), "hp_base": 90,  "speed": 130.0, "gold": 24, "size": 30, "min_wave": 16},
    "sapper":     {"label": "Sapper",     "color": Color(0.95, 0.45, 0.20), "hp_base": 30,  "speed": 50.0,  "gold": 8,  "size": 30, "min_wave": 14, "explodes": true},
    "shaman":     {"label": "Shaman",     "color": Color(0.45, 0.85, 0.55), "hp_base": 50,  "speed": 60.0,  "gold": 16, "size": 30, "min_wave": 18, "heals": true},
    "archer":     {"label": "Archer",     "color": Color(0.70, 0.85, 0.40), "hp_base": 25,  "speed": 50.0,  "gold": 6,  "size": 28, "min_wave": 11, "ranged": true},
    "summoner":   {"label": "Summoner",   "color": Color(0.70, 0.50, 0.85), "hp_base": 70,  "speed": 45.0,  "gold": 18, "size": 32, "min_wave": 22, "summons": true},
    "ogre":       {"label": "Ogre",       "color": Color(0.55, 0.55, 0.30), "hp_base": 220, "speed": 40.0,  "gold": 55, "size": 44, "min_wave": 20},
    "boss_warchief":{"label":"Krrik III", "color": Color(0.95, 0.75, 0.25), "hp_base": 240, "speed": 50.0,  "gold": 60, "size": 56, "boss": true},
    "boss_dragon":{"label":"Vyxhasis",    "color": Color(0.85, 0.25, 0.55), "hp_base": 600, "speed": 45.0,  "gold": 200,"size": 72, "boss": true},
    "boss_aethyrnax":{"label":"Aethyrnax","color": Color(0.40, 0.85, 0.95), "hp_base": 1400,"speed": 55.0,  "gold": 500,"size": 84, "boss": true},
}

const HERO_RADIUS := 22.0
const HERO_DAMAGE_BASE := 4
const HERO_ATTACK_RATE := 2.5     # attacks/sec at base
const HERO_RANGE := 220.0

@onready var bg: ColorRect = $Bg
@onready var arena: Control = $Arena
@onready var floor_rect: ColorRect = $Arena/Floor
@onready var hero: Panel = $Arena/Hero
@onready var range_ring: Panel = $Arena/RangeRing
@onready var companion: Panel = $Arena/Companion
@onready var hero_label: Label = $Arena/Hero/Label
@onready var enemies_layer: Control = $Arena/Enemies
@onready var fx_layer: Control = $Arena/FX
@onready var hud_wave: Label = $HUD/Top/Wave
@onready var hud_kills: Label = $HUD/Top/Kills
@onready var hud_gold: Label = $HUD/Top/Gold
@onready var hud_loadout: Label = $HUD/Top/Loadout
@onready var dps_bar: ProgressBar = $HUD/Top/Wavebar
@onready var milestone_row_label: Label = $HUD/MilestoneRow/Label
@onready var milestone_row_bar: ProgressBar = $HUD/MilestoneRow/Bar
@onready var perk_row: HBoxContainer = $HUD/PerkRow
@onready var xp_bar: ProgressBar = $HUD/XPBar
@onready var combat_log: Label = $HUD/CombatLog
@onready var overlay_scrim: ColorRect = $Overlay/Scrim
@onready var overlay_flash: ColorRect = $Overlay/Flash
@onready var milestone_overlay: Panel = $Overlay/Milestone
@onready var milestone_title: Label = $Overlay/Milestone/V/Title
@onready var milestone_body: Label = $Overlay/Milestone/V/Body
@onready var milestone_choices: VBoxContainer = $Overlay/Milestone/V/Choices
@onready var milestone_skip: Button = $Overlay/Milestone/V/Skip
@onready var btn_quit: Button = $HUD/Bottom/Quit
@onready var btn_strike: Button = $HUD/Bottom/Strike
@onready var btn_skill: Button = $HUD/Bottom/Skill
@onready var btn_pause: Button = $HUD/Bottom/Pause
@onready var pause_overlay: Panel = $Overlay/Pause
@onready var btn_resume: Button = $Overlay/Pause/V/Resume
@onready var btn_pause_home: Button = $Overlay/Pause/V/Home
@onready var mute_check: CheckBox = $Overlay/Pause/V/MuteRow/MuteCheck
@onready var motion_check: CheckBox = $Overlay/Pause/V/MuteRow/MotionCheck
@onready var btn_restart: Button = $Overlay/Pause/V/Restart
@onready var pause_stats: Label = $Overlay/Pause/V/Stats
@onready var tutorial_panel: Panel = $Overlay/Tutorial
@onready var tutorial_label: Label = $Overlay/Tutorial/Label
@onready var hud_idle: Label = $HUD/Top/Idle
@onready var hud_embers: Label = $HUD/Top/Embers
@onready var hud_hp: ProgressBar = $HUD/Top/HP
@onready var hud_combo: Label = $HUD/Top/Combo
@onready var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var enemies: Array = []          # Array of { node, hp, max_hp, hp_bar, speed, gold, id }
var spawn_timer: float = 0.0
var attack_timer: float = 0.0
var idle_timer: float = 0.0
var skill_cd: float = 0.0
const SKILL_COOLDOWN := 6.0
var reroll_cost: int = 0

var companion_orbit_t: float = 0.0
var companion_atk_t: float = 0.0
const COMPANION_ATK_RATE := 1.0       # hits/sec
const COMPANION_ORBIT_R := 60.0
const COMPANION_RANGE := 180.0

func _has_companion() -> bool:
    return GameState.bosses_felled >= 1

var combo: int = 0
var combo_decay: float = 0.0
var combo_peak: int = 0
var run_embers_earned: int = 0

# Rolling DPS — list of [t, damage] entries within the last 3s.
var dps_log: Array = []
const DPS_WINDOW := 3.0

var arrows: Array = []   # [{node, vel, dmg}]
const ARROW_SPEED := 220.0

var log_lines: Array[String] = []
const LOG_CAP := 4

func _log(s: String) -> void:
    log_lines.append(s)
    while log_lines.size() > LOG_CAP: log_lines.pop_front()
    if combat_log != null:
        combat_log.text = "\n".join(log_lines)
        combat_log.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)

# Mid-run merchant buffs — apply through wave N, then expire.
var temp_dmg_until: int = -1
var temp_atk_until: int = -1

func _temp_dmg_active() -> bool: return HordeState.wave <= temp_dmg_until
func _temp_atk_active() -> bool: return HordeState.wave <= temp_atk_until
const COMBO_WINDOW := 1.5
const COMBO_MAX_BONUS := 1.0  # +100% at peak
const COMBO_HALF_AT := 30     # streak length where you hit half of max bonus

func _combo_mult() -> float:
    if combo <= 0: return 1.0
    var t: float = float(combo) / float(combo + COMBO_HALF_AT)  # 0..1 saturating
    return 1.0 + COMBO_MAX_BONUS * t
var wave_kills_target: int = 8
var wave_kills_progress: int = 0
var paused_for_milestone: bool = false
var paused_by_user: bool = false
var pending_slot: String = ""    # "secondary" | "tertiary" | ""

func _is_paused() -> bool:
    return paused_for_milestone or paused_by_user

# Idle gold/sec scales with deepest_floor + lifetime kills tier.
func _idle_gold_per_sec() -> float:
    var base: float = 0.4 + GameState.deepest_floor * 0.15
    base += float(GameState.lifetime_kills) / 1000.0
    if HordeState.secondary != "": base *= 1.4
    if HordeState.tertiary != "": base *= 1.5
    base *= Upgrades.idle_multiplier()
    return base

func _ready() -> void:
    rng.randomize()
    combo_peak = 0
    run_embers_earned = 0
    SaveSystem.load_save()
    # Run state is now restored by load_save (perks + wave + class loadout).
    # The title screen's NEW RUN handler resets HordeState/HordePerks before
    # changing scene, so we don't blow away an in-progress run on every load.
    if HordeState.wave < 1: HordeState.wave = 1
    HordeState.hero_max_hp = HordeState.max_hp()
    if HordeState.hero_hp <= 0: HordeState.hero_hp = HordeState.hero_max_hp
    HordeState.milestone_reached.connect(_on_milestone)
    HordeState.slot_unlocked.connect(_on_slot_unlocked)
    HordeState.class_unlocked.connect(_on_class_unlocked)
    HordeState.hero_leveled.connect(_on_hero_leveled)
    btn_quit.pressed.connect(_on_quit)
    btn_strike.pressed.connect(_on_player_strike)
    btn_skill.pressed.connect(_on_skill_used)
    UiStyle_.apply_secondary(btn_skill)
    btn_skill.text = _skill_label()
    btn_pause.pressed.connect(_on_pause)
    btn_resume.pressed.connect(_on_resume)
    btn_pause_home.pressed.connect(_on_quit)
    btn_restart.pressed.connect(_on_restart)
    UiStyle_.apply_secondary(btn_restart)
    mute_check.button_pressed = Settings.sfx_volume <= 0.001
    mute_check.toggled.connect(_on_mute_toggled)
    motion_check.button_pressed = Settings.screen_shake_scale <= 0.001
    motion_check.toggled.connect(_on_motion_toggled)
    milestone_skip.pressed.connect(_close_milestone)
    bg.color = T.SURFACE_DIM
    UiStyle_.apply_secondary(btn_quit)
    UiStyle_.apply_primary(btn_strike)
    UiStyle_.apply_secondary(btn_pause)
    UiStyle_.apply_primary(btn_resume)
    UiStyle_.apply_secondary(btn_pause_home)
    UiStyle_.apply_secondary(milestone_skip)
    pause_overlay.visible = false
    _layout_hero()
    _refresh_hud()
    _refresh_perk_row()
    _hide_milestone()
    _maybe_show_tutorial()
    _setup_companion()
    MusicDirector.set_layer(MusicDirector.Layer.COMBAT)

func _setup_companion() -> void:
    if companion == null: return
    companion.visible = _has_companion()
    if not companion.visible: return
    var sb := StyleBoxFlat.new()
    var c: Color = _class_color(HordeState.secondary if HordeState.secondary != "" else HordeState.primary)
    sb.bg_color = Color(c.r * 0.7, c.g * 0.7, c.b * 0.7)
    sb.corner_radius_top_left = 10; sb.corner_radius_top_right = 10
    sb.corner_radius_bottom_left = 10; sb.corner_radius_bottom_right = 10
    sb.border_color = c
    sb.border_width_top = 2; sb.border_width_bottom = 2
    sb.border_width_left = 2; sb.border_width_right = 2
    companion.add_theme_stylebox_override("panel", sb)

const ZONES := [
    {"min":1,  "name":"Greenmarch", "floor": Color(0.07, 0.10, 0.07)},
    {"min":11, "name":"Ashen Vale", "floor": Color(0.11, 0.09, 0.07)},
    {"min":21, "name":"Frostwatch", "floor": Color(0.07, 0.09, 0.13)},
    {"min":31, "name":"Emberlands", "floor": Color(0.13, 0.06, 0.05)},
    {"min":41, "name":"The Void",   "floor": Color(0.05, 0.04, 0.10)},
]

static func _zone_for_wave(w: int) -> Dictionary:
    var current: Dictionary = ZONES[0]
    for z in ZONES:
        if w >= int(z["min"]): current = z
    return current

const CLASS_COLORS := {
    "warrior":     Color(0.85, 0.55, 0.30),
    "rogue":       Color(0.50, 0.85, 0.55),
    "wizard":      Color(0.45, 0.65, 0.95),
    "necromancer": Color(0.65, 0.45, 0.85),
    "bard":        Color(0.95, 0.65, 0.85),
}

func _class_color(cid: String) -> Color:
    return CLASS_COLORS.get(cid, T.PRIMARY)

func _layout_hero() -> void:
    var size := arena.size
    hero.position = size * 0.5 - hero.size * 0.5
    hero_label.text = _hero_initials()
    _style_hero()
    _start_hero_pulse()
    _style_range_ring()

func _style_range_ring() -> void:
    if range_ring == null: return
    var r: float = _hero_range()
    var diameter: float = r * 2.0
    range_ring.size = Vector2(diameter, diameter)
    var hero_center: Vector2 = hero.position + hero.size * 0.5
    range_ring.position = hero_center - Vector2(r, r)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(0, 0, 0, 0)
    sb.border_color = Color(0.85, 0.78, 0.45, 0.18)
    sb.border_width_top = 2; sb.border_width_bottom = 2
    sb.border_width_left = 2; sb.border_width_right = 2
    sb.corner_radius_top_left = int(r); sb.corner_radius_top_right = int(r)
    sb.corner_radius_bottom_left = int(r); sb.corner_radius_bottom_right = int(r)
    range_ring.add_theme_stylebox_override("panel", sb)

func _style_hero() -> void:
    var sb := StyleBoxFlat.new()
    var c: Color = _class_color(HordeState.primary)
    sb.bg_color = Color(c.r * 0.6, c.g * 0.6, c.b * 0.6)
    sb.corner_radius_top_left = 12; sb.corner_radius_top_right = 12
    sb.corner_radius_bottom_left = 12; sb.corner_radius_bottom_right = 12
    sb.border_color = c
    sb.border_width_top = 3; sb.border_width_bottom = 3
    sb.border_width_left = 3; sb.border_width_right = 3
    hero.add_theme_stylebox_override("panel", sb)

func _start_hero_pulse() -> void:
    if hero == null: return
    var tw := create_tween().set_loops()
    tw.tween_property(hero, "modulate", Color(1.15, 1.15, 1.15, 1), 0.7)
    tw.tween_property(hero, "modulate", Color(1.0, 1.0, 1.0, 1), 0.7)
    # Subtle vertical bob — anchored to the layout-time position.
    var rest_y: float = hero.position.y
    var bob := create_tween().set_loops()
    bob.tween_property(hero, "position:y", rest_y - 2.0, 0.75).set_trans(Tween.TRANS_SINE)
    bob.tween_property(hero, "position:y", rest_y, 0.75).set_trans(Tween.TRANS_SINE)

func _hero_initials() -> String:
    var parts := [HordeState.primary]
    if HordeState.secondary != "": parts.append(HordeState.secondary)
    if HordeState.tertiary != "": parts.append(HordeState.tertiary)
    var s := ""
    for p in parts:
        s += String(p).substr(0, 1).to_upper()
    return s

func _refresh_hud() -> void:
    var z: Dictionary = _zone_for_wave(HordeState.wave)
    hud_wave.text = "WAVE %d · %s" % [HordeState.wave, String(z["name"])]
    if floor_rect != null:
        var target: Color = z["floor"]
        if floor_rect.color != target:
            var tw := create_tween()
            tw.tween_property(floor_rect, "color", target, 0.6)
    hud_kills.text = "%d kills" % GameState.lifetime_kills
    hud_gold.text = "%d gold" % GameState.gold
    hud_loadout.text = _loadout_text()
    hud_idle.text = "+%.1f g/s" % _idle_gold_per_sec()
    hud_embers.text = "%d ember  ·  L%d" % [GameState.embers, GameState.hero_level]
    if xp_bar != null:
        xp_bar.max_value = max(1, GameState.xp_to_next_level())
        xp_bar.value = GameState.hero_xp
    hud_hp.max_value = max(1, HordeState.hero_max_hp)
    hud_hp.value = HordeState.hero_hp
    if combo > 1:
        hud_combo.text = "x%d combo · %.2f×" % [combo, _combo_mult()]
        hud_combo.add_theme_color_override("font_color",
            T.PRIMARY if combo >= 10 else T.ON_SURFACE)
    else:
        var sum: int = 0
        for e in dps_log: sum += int(e[1])
        var dps: float = float(sum) / DPS_WINDOW
        hud_combo.text = "%d dps" % int(round(dps)) if dps > 0.5 else ""
        hud_combo.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    dps_bar.max_value = max(1, wave_kills_target)
    dps_bar.value = wave_kills_progress
    _refresh_milestone_row()

func _refresh_milestone_row() -> void:
    var km: Dictionary = HordeState.next_kill_milestone()
    if km.is_empty():
        milestone_row_label.text = "All classes unlocked"
        milestone_row_bar.max_value = 1; milestone_row_bar.value = 1
        return
    var need: int = int(km["kills"])
    var have: int = GameState.lifetime_kills
    milestone_row_label.text = "Next: %s" % String(km["class"]).capitalize()
    milestone_row_bar.max_value = need
    milestone_row_bar.value = clamp(have, 0, need)

func _loadout_text() -> String:
    var parts := [HordeState.primary.capitalize()]
    if HordeState.secondary != "": parts.append(HordeState.secondary.capitalize())
    if HordeState.tertiary != "": parts.append(HordeState.tertiary.capitalize())
    var s: String = " / ".join(parts)
    var syn: Dictionary = Synergies.for_loadout(HordeState.primary, HordeState.secondary, HordeState.tertiary)
    if not syn.is_empty():
        s += "  ·  ✦ %s" % String(syn["label"])
    if GameState.rebirths > 0:
        s += "  ·  Mark %d" % GameState.rebirths
    return s

func _process(delta: float) -> void:
    if _is_paused():
        return
    spawn_timer -= delta
    attack_timer -= delta
    idle_timer -= delta
    if skill_cd > 0.0:
        skill_cd -= delta
        if skill_cd <= 0.0:
            btn_skill.text = _skill_label()
    if combo > 0:
        combo_decay -= delta
        if combo_decay <= 0.0:
            combo = 0
            _refresh_hud()
    # Trim the DPS log to the last 3s so the on-HUD number is "live".
    if dps_log.size() > 0:
        var cutoff: float = (Time.get_ticks_msec() / 1000.0) - DPS_WINDOW
        while dps_log.size() > 0 and float(dps_log[0][0]) < cutoff:
            dps_log.pop_front()
    if spawn_timer <= 0.0:
        _spawn_enemy()
        # Slower start for the first 5 waves, then standard ramp.
        var soft: float = 1.0 if HordeState.wave > 5 else lerp(2.2, 1.4, (HordeState.wave - 1) / 4.0)
        var t: float = soft - HordeState.wave * 0.04
        t /= max(0.4, 1.0 - HordePerks.spawn_slow)
        spawn_timer = max(0.25, t)
    if attack_timer <= 0.0:
        _hero_attack()
        attack_timer = 1.0 / _hero_atk_rate()
    if _has_companion():
        _companion_tick(delta)
    if idle_timer <= 0.0:
        var amount: int = int(round(_idle_gold_per_sec()))
        if amount > 0:
            GameState.add_gold(amount)
            _refresh_hud()
        idle_timer = 1.0
    _move_enemies(delta)
    _move_arrows(delta)
    _tick_poison(delta)

func _tick_poison(delta: float) -> void:
    for e in enemies.duplicate():
        # Rime expiry — restore base speed when the slow timer elapses.
        if bool(e.get("slowed", false)):
            e["slow_t"] = float(e.get("slow_t", 0.0)) - delta
            if float(e["slow_t"]) <= 0.0:
                e["slowed"] = false
                e["speed"] = float(e.get("base_run_speed", e["speed"]))
                var n_s: Panel = e.get("node")
                if n_s != null and is_instance_valid(n_s):
                    n_s.self_modulate = Color(1, 1, 1)
        var stacks: int = int(e.get("poison", 0))
        if stacks <= 0: continue
        e["poison_t"] = float(e.get("poison_t", 0.0)) - delta
        if float(e["poison_t"]) <= 0.0:
            e["poison"] = 0
            continue
        e["poison_tick"] = float(e.get("poison_tick", 1.0)) - delta
        if float(e["poison_tick"]) <= 0.0:
            e["poison_tick"] = 1.0
            # Apply poison damage WITHOUT re-poisoning (avoids stack loop).
            var stacks_now: int = int(e["poison"])
            var saved: int = HordePerks.poison_stacks_per_hit
            HordePerks.poison_stacks_per_hit = 0
            _damage_enemy(e, stacks_now)
            HordePerks.poison_stacks_per_hit = saved

func _spawn_enemy() -> void:
    var size := arena.size
    var pool: Array = []
    for k in ENEMY_TYPES.keys():
        var def: Dictionary = ENEMY_TYPES[k]
        if bool(def.get("boss", false)): continue
        if HordeState.wave >= int(def.get("min_wave", 1)):
            pool.append(k)
    if pool.is_empty(): pool.append("skeleton")
    var id: String = pool[rng.randi_range(0, pool.size() - 1)]
    var def: Dictionary = ENEMY_TYPES[id]
    # ~3% chance for a Mythic — 10× HP, 10× gold, gold border, larger.
    var is_mythic: bool = HordeState.wave >= 5 and rng.randf() < (0.03 + HordePerks.mythic_rate_bonus)
    var sz: int = int(def.get("size", 28))
    if is_mythic: sz = int(sz * 1.4)
    var p := Panel.new()
    p.custom_minimum_size = Vector2(sz, sz)
    p.size = Vector2(sz, sz)
    var sb := StyleBoxFlat.new()
    sb.bg_color = def["color"]
    sb.corner_radius_top_left = 6
    sb.corner_radius_top_right = 6
    sb.corner_radius_bottom_left = 6
    sb.corner_radius_bottom_right = 6
    if is_mythic:
        sb.border_color = T.RARITY_MYTHIC
        sb.border_width_top = 3; sb.border_width_bottom = 3
        sb.border_width_left = 3; sb.border_width_right = 3
    p.add_theme_stylebox_override("panel", sb)
    var edge := rng.randi_range(0, 3)
    var pos := Vector2.ZERO
    match edge:
        0: pos = Vector2(rng.randf_range(0, size.x), -30)
        1: pos = Vector2(size.x + 30, rng.randf_range(0, size.y))
        2: pos = Vector2(rng.randf_range(0, size.x), size.y + 30)
        _: pos = Vector2(-30, rng.randf_range(0, size.y))
    p.position = pos
    enemies_layer.add_child(p)
    # HP bar floats above the enemy
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(28, 4)
    bar.size = Vector2(28, 4)
    bar.position = Vector2(0, -8)
    bar.max_value = 1.0
    bar.value = 1.0
    var bar_fg := StyleBoxFlat.new()
    bar_fg.bg_color = Color(0.85, 0.25, 0.25)
    bar.add_theme_stylebox_override("fill", bar_fg)
    p.add_child(bar)
    var hp_scale: float = 1.0 + (HordeState.wave - 1) * 0.18
    var max_hp: int = int(round(int(def["hp_base"]) * hp_scale * (10.0 if is_mythic else 1.0)))
    enemies.append({
        "node": p,
        "hp": max_hp,
        "max_hp": max_hp,
        "hp_bar": bar,
        "speed": float(def["speed"]) + HordeState.wave * 1.5,
        "gold": int(def["gold"]) * (10 if is_mythic else 1),
        "id": id,
        "mythic": is_mythic,
        "explodes": bool(def.get("explodes", false)),
        "heals": bool(def.get("heals", false)),
        "heal_cd": 3.0,
        "ranged": bool(def.get("ranged", false)),
        "shot_cd": 1.5,
        "summons": bool(def.get("summons", false)),
        "summon_cd": 3.0,
    })
    if is_mythic:
        _floating_text("MYTHIC %s" % String(def.get("label", "Foe")).to_upper(),
            Vector2(arena.size.x * 0.5 - 80, 100), T.RARITY_MYTHIC)

func _move_enemies(delta: float) -> void:
    var hero_center: Vector2 = hero.position + hero.size * 0.5
    var dead: Array = []
    for e in enemies:
        var node: Panel = e["node"]
        if node == null or not is_instance_valid(node):
            dead.append(e); continue
        var ep: Vector2 = node.position + node.size * 0.5
        # Stagger: skip movement entirely for the brief window after a hit.
        var stg: float = float(e.get("stagger", 0.0))
        if stg > 0.0:
            e["stagger"] = stg - delta
            continue
        if bool(e.get("boss", false)):
            _boss_tick(e, delta)
        # Summoners stay at distance and spawn minions on a cooldown.
        if bool(e.get("summons", false)):
            e["summon_cd"] = float(e.get("summon_cd", 5.0)) - delta
            var dist_s: float = ep.distance_to(hero_center)
            var dir_s: Vector2 = (hero_center - ep).normalized()
            if dist_s < 260.0:
                node.position -= dir_s * float(e["speed"]) * delta
            if float(e["summon_cd"]) <= 0.0:
                _spawn_minion(ep)
                e["summon_cd"] = 5.0
            continue
        # Archers kite at range and fire periodic projectiles at the hero.
        if bool(e.get("ranged", false)):
            e["shot_cd"] = float(e.get("shot_cd", 1.5)) - delta
            var dist: float = ep.distance_to(hero_center)
            var dir_h: Vector2 = (hero_center - ep).normalized()
            if dist < 240.0:
                node.position -= dir_h * float(e["speed"]) * delta
            else:
                node.position += dir_h * float(e["speed"]) * 0.6 * delta
            if float(e["shot_cd"]) <= 0.25 and not bool(e.get("telegraphed", false)):
                _spawn_shot_telegraph(ep, hero_center)
                e["telegraphed"] = true
            if float(e["shot_cd"]) <= 0.0:
                _spawn_arrow(ep, hero_center)
                e["shot_cd"] = 2.0
                e["telegraphed"] = false
            continue
        # Shamans hold distance and tick a heal cooldown.
        if bool(e.get("heals", false)):
            e["heal_cd"] = float(e.get("heal_cd", 3.0)) - delta
            if float(e["heal_cd"]) <= 0.0:
                _shaman_heal(e, ep)
                e["heal_cd"] = 4.0
            var dist: float = ep.distance_to(hero_center)
            var dir_h: Vector2 = (hero_center - ep).normalized()
            if dist < 220.0:
                node.position -= dir_h * float(e["speed"]) * delta  # back away
            else:
                node.position += dir_h * float(e["speed"]) * 0.4 * delta
            continue
        var dir: Vector2 = (hero_center - ep).normalized()
        node.position += dir * float(e["speed"]) * delta
        # Contact: enemy bites the hero for chip damage and dies (so the
        # arena never softlocks with a fully-buffed enemy stuck on top).
        if ep.distance_to(hero_center) < HERO_RADIUS + 14:
            if String(e.get("phase_kind", "")) == "fly": continue
            var bite: int = 2 + HordeState.wave / 4
            if bool(e.get("boss", false)): bite *= 6
            elif bool(e.get("mythic", false)): bite *= 3
            bite = max(1, int(round(bite * (1.0 - HordePerks.contact_reduction))))
            _hero_take_damage(bite)
            _damage_enemy(e, 9999)
            _shake(4)
    for d in dead: enemies.erase(d)

func _companion_tick(delta: float) -> void:
    companion_orbit_t += delta * 1.5
    var hero_center: Vector2 = hero.position + hero.size * 0.5
    var orbit: Vector2 = Vector2(cos(companion_orbit_t), sin(companion_orbit_t)) * COMPANION_ORBIT_R
    companion.position = hero_center + orbit - companion.size * 0.5
    companion_atk_t -= delta
    if companion_atk_t > 0.0: return
    var cp: Vector2 = companion.position + companion.size * 0.5
    var best: Dictionary = {}
    var best_d: float = COMPANION_RANGE
    for e in enemies:
        var n: Panel = e.get("node")
        if n == null or not is_instance_valid(n): continue
        var d: float = (n.position + n.size * 0.5).distance_to(cp)
        if d < best_d: best_d = d; best = e
    if best.is_empty(): return
    var dmg: int = max(1, int(_hero_damage() * 0.5))
    _damage_enemy(best, dmg)
    _spawn_strike(best["node"].position + best["node"].size * 0.5)
    companion_atk_t = 1.0 / COMPANION_ATK_RATE

func _hero_attack() -> void:
    var hero_center: Vector2 = hero.position + hero.size * 0.5
    var best: Dictionary = {}
    var best_d: float = _hero_range()
    for e in enemies:
        var node: Panel = e["node"]
        if node == null or not is_instance_valid(node):
            continue
        var d: float = (node.position + node.size * 0.5).distance_to(hero_center)
        if d < best_d:
            best_d = d; best = e
    if best.is_empty():
        return
    var dmg: int = _hero_damage()
    _damage_enemy(best, dmg)
    _spawn_strike(best["node"].position + best["node"].size * 0.5)
    SfxBus.play("crit" if dmg > HERO_DAMAGE_BASE * 3 else "hit", -10.0)

func _hero_damage() -> int:
    var d: int = HERO_DAMAGE_BASE
    if HordeState.secondary != "": d += 3
    if HordeState.tertiary != "": d += 4
    d += HordeState.wave / 2
    d += Upgrades.bonus_damage()
    d += int(round((GameState.hero_level - 1) * 0.5))
    d += int(GameState.level_perks.get("perm_dmg", 0))
    var f: float = float(d) * Upgrades.ember_damage_mult() * HordePerks.dmg_mult
    f *= 1.0 + GameState.rebirths * 0.25
    if GameState.dragonslayer: f *= 1.10
    var syn: Dictionary = Synergies.for_loadout(HordeState.primary, HordeState.secondary, HordeState.tertiary)
    if not syn.is_empty(): f *= 1.0 + float(syn.get("dmg_mult", 0.0))
    if _temp_dmg_active(): f *= 1.5
    var perm_crit: float = int(GameState.level_perks.get("perm_crit", 0)) * 0.02
    if rng.randf() < (Upgrades.crit_chance() + HordePerks.crit_bonus + perm_crit):
        f *= 2.0
    return int(round(f))

func _hero_atk_rate() -> float:
    var r := HERO_ATTACK_RATE + Upgrades.bonus_atk_speed() + HordePerks.atk_speed_bonus
    r += float(GameState.level_perks.get("perm_atk", 0)) * 0.1
    var syn: Dictionary = Synergies.for_loadout(HordeState.primary, HordeState.secondary, HordeState.tertiary)
    if not syn.is_empty(): r += float(syn.get("atk_speed_bonus", 0.0))
    if _temp_atk_active(): r += 1.0
    return r

func _hero_range() -> float:
    return HERO_RANGE + Upgrades.bonus_range() + HordePerks.range_bonus + float(GameState.level_perks.get("perm_range", 0)) * 10.0

func _damage_enemy(e: Dictionary, amount: int) -> void:
    # Airborne dragon ignores hits entirely.
    if String(e.get("phase_kind", "")) == "fly":
        var n0: Panel = e.get("node")
        if n0 != null and is_instance_valid(n0):
            _floating_text("MISS", n0.position + n0.size * 0.5, T.ON_SURFACE_MUTED)
        return
    var now: float = Time.get_ticks_msec() / 1000.0
    dps_log.append([now, amount])
    e["hp"] -= amount
    # Venom: each hit adds poison stacks; ticks below in _process.
    if HordePerks.poison_stacks_per_hit > 0:
        e["poison"] = min(5, int(e.get("poison", 0)) + HordePerks.poison_stacks_per_hit)
        e["poison_t"] = 3.0
        e["poison_tick"] = 1.0
    # Rime: hits apply 50% speed slow for 2s. Refreshes duration.
    if HordePerks.slow_on_hit:
        if not bool(e.get("slowed", false)):
            e["slowed"] = true
            e["base_run_speed"] = float(e["speed"])
            e["speed"] = float(e["speed"]) * 0.5
            var node_blue: Panel = e.get("node")
            if node_blue != null and is_instance_valid(node_blue):
                node_blue.self_modulate = Color(0.7, 0.85, 1.05)
        e["slow_t"] = 2.0
    # Hit-stop stagger: skip movement for 0.08s and shove back 4px from
    # the hero. Bosses get a softer 0.04s/2px so they don't lock up.
    var nh: Panel = e.get("node")
    if nh != null and is_instance_valid(nh):
        var hero_center: Vector2 = hero.position + hero.size * 0.5
        var ep: Vector2 = nh.position + nh.size * 0.5
        var back: Vector2 = (ep - hero_center).normalized()
        var is_boss: bool = bool(e.get("boss", false))
        var dist: float = 2.0 if is_boss else 4.0
        nh.position += back * dist
        e["stagger"] = 0.04 if is_boss else 0.08
    var bar: ProgressBar = e.get("hp_bar")
    if bar != null and is_instance_valid(bar):
        bar.value = float(max(0, e["hp"])) / float(max(1, int(e["max_hp"])))
    var n: Panel = e["node"]
    var death_pos: Vector2 = Vector2.ZERO
    if n != null and is_instance_valid(n):
        death_pos = n.position + n.size * 0.5
        _floating_text("-%d" % amount, death_pos,
            T.WARNING if amount < 10 else T.SECONDARY)
    if e["hp"] <= 0:
        if n != null and is_instance_valid(n):
            n.queue_free()
        enemies.erase(e)
        if bool(e.get("explodes", false)) and death_pos != Vector2.ZERO:
            _detonate_at(death_pos, 60.0, _hero_damage())
        var was_boss: bool = bool(e.get("boss", false))
        combo += 1
        combo_decay = COMBO_WINDOW
        if combo > combo_peak: combo_peak = combo
        var syn: Dictionary = Synergies.for_loadout(HordeState.primary, HordeState.secondary, HordeState.tertiary)
        var syn_gold: float = 1.0 + float(syn.get("gold_mult", 0.0)) if not syn.is_empty() else 1.0
        var perm_gold_mult: float = 1.0 + int(GameState.level_perks.get("perm_gold", 0)) * 0.05
        var gold_amt: int = int(round(int(e.get("gold", 1))
            * Upgrades.ember_gold_mult() * HordePerks.gold_mult * _combo_mult()
            * (1.0 + GameState.rebirths * 0.25)
            * _challenge_reward_mult() * syn_gold * perm_gold_mult))
        HordeState.record_kill(String(e.get("id", "skeleton")), gold_amt)
        _pop(hud_kills); _pop(hud_gold)
        if bool(e.get("mythic", false)):
            _drop_powerup(death_pos)
        if was_boss:
            var ember_reward: int = int(round((1 + HordeState.wave / 10) * _challenge_reward_mult()))
            GameState.add_embers(ember_reward)
            run_embers_earned += ember_reward
            GameState.bosses_felled += 1
            _log("BOSS DOWN: %s (+%d ember)" % [
                String(ENEMY_TYPES[String(e.get("id", ""))].get("label", "Boss")),
                ember_reward,
            ])
            _open_boss_loot_picker()
            var boss_kid: String = String(e.get("id", ""))
            if boss_kid in ["boss_dragon", "boss_aethyrnax", "boss_warchief"]:
                if not GameState.defeated_dragons.has(boss_kid):
                    GameState.defeated_dragons.append(boss_kid)
                if GameState.defeated_dragons.size() >= 3 and not GameState.dragonslayer:
                    GameState.dragonslayer = true
                    _achievement_banner("DRAGONSLAYER — permanent +10%% damage")
                    GameState.add_embers(15)
            _floating_text("+%d Embers" % ember_reward,
                Vector2(arena.size.x * 0.5 - 50, arena.size.y * 0.4), T.SECONDARY)
            _boss_burst(death_pos)
            _pop(hud_embers)
            _flash_screen(Color(1, 1, 1, 1), 0.65, 0.35)
            _slow_mo(0.3, 0.3)
            SfxBus.play("dragon_roar", 0.0)
            SfxBus.play("levelup", -3.0)
            SaveSystem.save()
        else:
            wave_kills_progress += 1
        _refresh_hud()
        if wave_kills_progress >= wave_kills_target:
            _next_wave()

func _challenge_disables(curse: String) -> bool:
    return GameState.challenge_active and GameState.daily_curse == curse

func _challenge_reward_mult() -> float:
    return 2.0 if GameState.challenge_active else 1.0

func _on_player_strike() -> void:
    if _is_paused():
        return
    if _challenge_disables("steady_pace") or _challenge_disables("no_strike"):
        return
    # Tap deals a fat hit on the closest enemy and visibly shakes the arena.
    var hero_center: Vector2 = hero.position + hero.size * 0.5
    var best: Dictionary = {}
    var best_d: float = _hero_range() * 1.3
    for e in enemies:
        var node: Panel = e["node"]
        if node == null or not is_instance_valid(node):
            continue
        var d: float = (node.position + node.size * 0.5).distance_to(hero_center)
        if d < best_d:
            best_d = d; best = e
    if best.is_empty(): return
    _damage_enemy(best, _hero_damage() * 4)
    _spawn_strike(best["node"].position + best["node"].size * 0.5)
    _shake(8)
    SfxBus.play("hit_heavy", -4.0)

func _next_wave() -> void:
    HordeState.advance_wave()
    _log("Wave %d cleared" % HordeState.wave)
    wave_kills_progress = 0
    wave_kills_target = int(8 + HordeState.wave * 1.5)
    # Heal 25% on wave clear so the run isn't a death spiral.
    HordeState.hero_hp = min(HordeState.hero_max_hp,
        HordeState.hero_hp + HordeState.hero_max_hp / 4)
    # Wave-clear bonus: 5 + wave² gold so survival pays off even when
    # you're not gathering kill drops fast.
    var bonus: int = 5 + HordeState.wave * HordeState.wave
    bonus = int(round(bonus * Upgrades.ember_gold_mult() * HordePerks.wave_bonus_mult))
    GameState.add_gold(bonus)
    SaveSystem.save()
    _refresh_hud()
    _floating_text("WAVE %d  +%d g" % [HordeState.wave, bonus],
        hero.position + hero.size * 0.5, T.PRIMARY)
    _pop(hud_gold)
    _flash_screen(T.PRIMARY, 0.18, 0.22)
    SfxBus.play("levelup", -8.0)
    if HordeState.wave % 10 == 0:
        _telegraph_boss()
        MusicDirector.set_layer(MusicDirector.Layer.BOSS)
    elif HordeState.wave % 10 == 1 and HordeState.wave > 1:
        # The wave just after a boss returns to combat layer.
        MusicDirector.set_layer(MusicDirector.Layer.COMBAT)
    if HordeState.wave % 5 == 0:
        _open_perk_picker()
    elif HordeState.wave % 7 == 0:
        if not _challenge_disables("spendthrift"):
            _open_merchant()
    if HordeState.wave == 50 and not bool(GameState.meta_unlocks.get("wave_50", false)):
        GameState.meta_unlocks["wave_50"] = true
        GameState.add_embers(25)
        _floating_text("ENDLESS — +25 Embers",
            Vector2(arena.size.x * 0.5 - 100, 60), T.RARITY_MYTHIC)
        _flash_screen(T.RARITY_MYTHIC, 0.8, 0.5)
        SaveSystem.save()
    if HordeState.wave == 30 and GameState.challenge_active and not GameState.challenge_claimed_today:
        GameState.challenge_claimed_today = true
        GameState.curses_cleared += 1
        GameState.add_embers(5)
        run_embers_earned += 5
        _floating_text("CURSE BROKEN — +5 Embers",
            Vector2(arena.size.x * 0.5 - 130, 60), T.SECONDARY)
        _flash_screen(T.SECONDARY, 0.6, 0.4)
        SaveSystem.save()

func _boss_tick(e: Dictionary, delta: float) -> void:
    var node: Panel = e["node"]
    if node == null or not is_instance_valid(node): return
    if float(e.get("phase_active", 0.0)) > 0.0:
        e["phase_active"] = float(e["phase_active"]) - delta
        if float(e["phase_active"]) <= 0.0:
            # Phase ended — restore visuals + speed + reset cooldown.
            e["speed"] = float(e["base_speed"])
            node.modulate = Color(1, 1, 1, 1)
            e["phase_kind"] = ""
            e["phase_cd"] = 4.0
        return
    e["phase_cd"] = float(e.get("phase_cd", 4.0)) - delta
    if float(e["phase_cd"]) > 0.0: return
    # Trigger phase based on boss kind.
    var id: String = String(e.get("id", ""))
    if id == "boss_warchief":
        e["phase_kind"] = "charge"
        e["phase_active"] = 1.0
        e["speed"] = float(e["base_speed"]) * 4.0
        node.modulate = Color(1.4, 0.8, 0.6)  # heated
        SfxBus.play("hit_heavy", -6.0)
        _floating_text("CHARGE!", node.position + node.size * 0.5, T.SECONDARY)
    elif id == "boss_dragon":
        e["phase_kind"] = "fly"
        e["phase_active"] = 1.2
        e["speed"] = float(e["base_speed"]) * 0.5
        node.modulate = Color(1, 1, 1, 0.4)   # transparent = airborne
        SfxBus.play("dragon_phase_air", -4.0)
        _floating_text("AIRBORNE", node.position + node.size * 0.5, T.RARITY_RARE)
    elif id == "boss_aethyrnax":
        # Aethyrnax alternates between CHARGE and FLY each cycle.
        var swap: int = int(e.get("phase_count", 0))
        e["phase_count"] = swap + 1
        if swap % 2 == 0:
            e["phase_kind"] = "charge"
            e["phase_active"] = 0.8
            e["speed"] = float(e["base_speed"]) * 5.0
            node.modulate = Color(0.6, 1.4, 1.4)
            SfxBus.play("hit_heavy", -2.0)
            _floating_text("CHARGE!", node.position + node.size * 0.5, T.SECONDARY)
        else:
            e["phase_kind"] = "fly"
            e["phase_active"] = 1.4
            e["speed"] = float(e["base_speed"]) * 0.6
            node.modulate = Color(1, 1, 1, 0.35)
            SfxBus.play("dragon_phase_air", -2.0)
            _floating_text("SOARING", node.position + node.size * 0.5, T.RARITY_RARE)

func _shaman_heal(shaman: Dictionary, sp: Vector2) -> void:
    # Heal nearest non-shaman ally for 20% of its missing HP.
    var best: Dictionary = {}
    var best_d: float = 1e9
    for e in enemies:
        if e == shaman or bool(e.get("heals", false)): continue
        var n: Panel = e.get("node")
        if n == null or not is_instance_valid(n): continue
        if int(e["hp"]) >= int(e["max_hp"]): continue
        var d: float = (n.position + n.size * 0.5).distance_to(sp)
        if d < best_d: best_d = d; best = e
    if best.is_empty(): return
    var amount: int = int(round((int(best["max_hp"]) - int(best["hp"])) * 0.2))
    if amount <= 0: return
    best["hp"] = min(int(best["max_hp"]), int(best["hp"]) + amount)
    var bar: ProgressBar = best.get("hp_bar")
    if bar != null and is_instance_valid(bar):
        bar.value = float(best["hp"]) / float(max(1, int(best["max_hp"])))
    var bn: Panel = best["node"]
    if bn != null and is_instance_valid(bn):
        _floating_text("+%d" % amount, bn.position + bn.size * 0.5, T.RARITY_UNCOMMON)
    # Tether visual: a thin green line via short ColorRect.
    var line := ColorRect.new()
    line.color = Color(0.45, 0.85, 0.55, 0.7)
    var dest: Vector2 = bn.position + bn.size * 0.5 if bn != null else sp
    var mid: Vector2 = (sp + dest) * 0.5
    line.size = Vector2(sp.distance_to(dest), 2)
    line.position = mid - line.size * 0.5
    line.rotation = (dest - sp).angle()
    fx_layer.add_child(line)
    var tw := create_tween()
    tw.tween_property(line, "modulate:a", 0.0, 0.4)
    tw.tween_callback(line.queue_free)

const POWERUPS := [
    {"id":"heal",   "label":"+25%% HP",    "color": Color(0.55, 0.85, 0.55)},
    {"id":"gold",   "label":"+50g",        "color": Color(0.85, 0.78, 0.45)},
    {"id":"haste",  "label":"+1 atk/s 8s", "color": Color(0.95, 0.55, 0.25)},
]

func _drop_powerup(pos: Vector2) -> void:
    var pick: Dictionary = POWERUPS[rng.randi_range(0, POWERUPS.size() - 1)]
    var p := Panel.new()
    p.custom_minimum_size = Vector2(18, 18)
    p.size = Vector2(18, 18)
    p.position = pos - p.size * 0.5
    var sb := StyleBoxFlat.new()
    sb.bg_color = pick["color"]
    sb.corner_radius_top_left = 9; sb.corner_radius_top_right = 9
    sb.corner_radius_bottom_left = 9; sb.corner_radius_bottom_right = 9
    p.add_theme_stylebox_override("panel", sb)
    fx_layer.add_child(p)
    # Float to hero over 1s; on arrival apply effect.
    var hero_center: Vector2 = hero.position + hero.size * 0.5
    var tw := create_tween()
    tw.tween_property(p, "position", hero_center - p.size * 0.5, 1.0).set_trans(Tween.TRANS_QUAD)
    tw.tween_callback(_apply_powerup.bind(pick))
    tw.tween_callback(p.queue_free)

func _apply_powerup(p: Dictionary) -> void:
    var id: String = String(p["id"])
    var label: String = String(p["label"]).replace("%%", "%")
    match id:
        "heal":
            var amt: int = HordeState.hero_max_hp / 4
            HordeState.hero_hp = min(HordeState.hero_max_hp, HordeState.hero_hp + amt)
        "gold":
            GameState.add_gold(50)
        "haste":
            HordePerks.atk_speed_bonus += 1.0
            var t := get_tree().create_timer(8.0, true, false, true)
            t.timeout.connect(func(): HordePerks.atk_speed_bonus = max(0.0, HordePerks.atk_speed_bonus - 1.0))
    _floating_text(label, hero.position + hero.size * 0.5, T.RARITY_MYTHIC)
    SfxBus.play("pickup", -4.0)
    _refresh_hud()

func _spawn_minion(pos: Vector2) -> void:
    var def: Dictionary = ENEMY_TYPES["skeleton"]
    var sz: int = int(def["size"])
    var p := Panel.new()
    p.custom_minimum_size = Vector2(sz, sz)
    p.size = Vector2(sz, sz)
    p.position = pos
    var sb := StyleBoxFlat.new()
    sb.bg_color = def["color"]
    sb.corner_radius_top_left = 6; sb.corner_radius_top_right = 6
    sb.corner_radius_bottom_left = 6; sb.corner_radius_bottom_right = 6
    p.add_theme_stylebox_override("panel", sb)
    enemies_layer.add_child(p)
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(sz, 4)
    bar.size = Vector2(sz, 4); bar.position = Vector2(0, -8)
    bar.max_value = 1.0; bar.value = 1.0
    p.add_child(bar)
    var hp_scale: float = 1.0 + (HordeState.wave - 1) * 0.18
    var max_hp: int = int(round(int(def["hp_base"]) * hp_scale))
    enemies.append({
        "node": p, "hp": max_hp, "max_hp": max_hp, "hp_bar": bar,
        "speed": float(def["speed"]) + HordeState.wave * 1.5,
        "gold": 0,  # minions don't pay out
        "id": "skeleton",
        "mythic": false, "explodes": false, "heals": false, "heal_cd": 0.0,
        "ranged": false, "shot_cd": 0.0, "summons": false, "summon_cd": 0.0,
    })

func _spawn_shot_telegraph(from: Vector2, to: Vector2) -> void:
    var line := ColorRect.new()
    line.color = Color(0.85, 0.30, 0.30, 0.45)
    var mid: Vector2 = (from + to) * 0.5
    line.size = Vector2(from.distance_to(to), 2)
    line.position = mid - line.size * 0.5
    line.rotation = (to - from).angle()
    fx_layer.add_child(line)
    var tw := create_tween()
    tw.tween_property(line, "modulate:a", 0.0, 0.25)
    tw.tween_callback(line.queue_free)

func _spawn_arrow(from: Vector2, to: Vector2) -> void:
    var dir: Vector2 = (to - from).normalized()
    var a := ColorRect.new()
    a.color = Color(0.95, 0.85, 0.55, 0.9)
    a.size = Vector2(10, 3)
    a.position = from - a.size * 0.5
    a.rotation = dir.angle()
    fx_layer.add_child(a)
    arrows.append({"node": a, "vel": dir * ARROW_SPEED,
        "dmg": 3 + HordeState.wave / 3, "life": 3.0})
    SfxBus.play("hit", -14.0)

func _move_arrows(delta: float) -> void:
    var dead: Array = []
    var hero_center: Vector2 = hero.position + hero.size * 0.5
    var arena_size := arena.size
    for a in arrows:
        var n: ColorRect = a.get("node")
        if n == null or not is_instance_valid(n):
            dead.append(a); continue
        n.position += (a["vel"] as Vector2) * delta
        a["life"] = float(a.get("life", 3.0)) - delta
        var cp: Vector2 = n.position + n.size * 0.5
        if cp.distance_to(hero_center) < HERO_RADIUS + 4:
            if rng.randf() < HordePerks.dodge_chance:
                _floating_text("DODGE", hero_center, T.PRIMARY)
            else:
                _hero_take_damage(int(a["dmg"]))
            n.queue_free()
            dead.append(a)
            continue
        if float(a["life"]) <= 0.0 or cp.x < -20 or cp.y < -20 or cp.x > arena_size.x + 20 or cp.y > arena_size.y + 20:
            n.queue_free()
            dead.append(a)
    for d in dead: arrows.erase(d)

func _detonate_at(pos: Vector2, radius: float, damage: int) -> void:
    # Visual ring
    var c := ColorRect.new()
    c.color = Color(1.0, 0.55, 0.20, 0.55)
    c.size = Vector2(radius * 2, radius * 2)
    c.position = pos - c.size * 0.5
    fx_layer.add_child(c)
    var tw := create_tween()
    tw.parallel().tween_property(c, "modulate:a", 0.0, 0.35)
    tw.parallel().tween_property(c, "scale", Vector2(1.4, 1.4), 0.35)
    tw.tween_callback(c.queue_free)
    # Damage everything in radius (chain detonating Sappers)
    for e in enemies.duplicate():
        var n: Panel = e.get("node")
        if n == null or not is_instance_valid(n): continue
        var ep: Vector2 = n.position + n.size * 0.5
        if ep.distance_to(pos) <= radius:
            _damage_enemy(e, damage)
    # Hero takes splash if too close
    var hero_center: Vector2 = hero.position + hero.size * 0.5
    if hero_center.distance_to(pos) <= radius:
        _hero_take_damage(int(damage * 0.5))
    _shake(8)
    SfxBus.play("hit_heavy", -4.0)

func _telegraph_boss() -> void:
    var boss_id: String = "boss_warchief"
    if HordeState.wave >= 30: boss_id = "boss_dragon"
    if HordeState.wave >= 50: boss_id = "boss_aethyrnax"
    var def: Dictionary = ENEMY_TYPES[boss_id]
    var name: String = String(def["label"])
    # Three quick floating warnings + a screen flash, then spawn.
    for i in 3:
        var t := get_tree().create_timer(float(i) * 0.9, true, false, true)
        t.timeout.connect(func():
            if not is_instance_valid(self): return
            _floating_text("INCOMING: %s — %ds" % [name, 3 - i],
                Vector2(arena.size.x * 0.5 - 140, 60), T.SECONDARY)
            _flash_screen(T.ERROR, 0.25, 0.18)
            SfxBus.play("low_hp", -10.0))
    var spawn_t := get_tree().create_timer(2.7, true, false, true)
    spawn_t.timeout.connect(func():
        if is_instance_valid(self): _spawn_boss())

func _spawn_boss() -> void:
    var boss_id: String = "boss_warchief"
    if HordeState.wave >= 30: boss_id = "boss_dragon"
    if HordeState.wave >= 50: boss_id = "boss_aethyrnax"
    var def: Dictionary = ENEMY_TYPES[boss_id]
    var sz: int = int(def["size"])
    var p := Panel.new()
    p.custom_minimum_size = Vector2(sz, sz)
    p.size = Vector2(sz, sz)
    var sb := StyleBoxFlat.new()
    sb.bg_color = def["color"]
    sb.corner_radius_top_left = 10
    sb.corner_radius_top_right = 10
    sb.corner_radius_bottom_left = 10
    sb.corner_radius_bottom_right = 10
    sb.border_color = T.PRIMARY
    sb.border_width_top = 3
    sb.border_width_bottom = 3
    sb.border_width_left = 3
    sb.border_width_right = 3
    p.add_theme_stylebox_override("panel", sb)
    p.position = Vector2(arena.size.x * 0.5 - sz * 0.5, -sz - 4)
    enemies_layer.add_child(p)
    var bar := ProgressBar.new()
    bar.show_percentage = false
    bar.custom_minimum_size = Vector2(sz, 5)
    bar.size = Vector2(sz, 5)
    bar.position = Vector2(0, -10)
    bar.max_value = 1.0; bar.value = 1.0
    p.add_child(bar)
    var hp_scale: float = 1.0 + (HordeState.wave - 1) * 0.18
    var max_hp: int = int(round(int(def["hp_base"]) * hp_scale))
    enemies.append({
        "node": p, "hp": max_hp, "max_hp": max_hp, "hp_bar": bar,
        "speed": float(def["speed"]),
        "base_speed": float(def["speed"]),
        "gold": int(def["gold"]),
        "id": boss_id, "boss": true,
        "phase_cd": 4.0,
        "phase_active": 0.0,
        "phase_kind": "",   # "charge" | "fly"
    })
    _floating_text("%s appears!" % String(def["label"]), Vector2(arena.size.x * 0.5 - 80, 80), T.SECONDARY)

func _spawn_strike(pos: Vector2) -> void:
    var c := ColorRect.new()
    var base: Color = _class_color(HordeState.primary)
    c.color = Color(base.r * 1.1, base.g * 1.1, base.b * 1.1, 0.9)
    c.size = Vector2(14, 14)
    c.position = pos - c.size * 0.5
    fx_layer.add_child(c)
    var tw := create_tween()
    tw.parallel().tween_property(c, "scale", Vector2(1.6, 1.6), 0.18)
    tw.parallel().tween_property(c, "modulate:a", 0.0, 0.18)
    tw.tween_callback(c.queue_free)

func _floating_text(s: String, pos: Vector2, color: Color) -> void:
    var lbl := Label.new()
    lbl.text = s
    lbl.add_theme_color_override("font_color", color)
    lbl.add_theme_font_size_override("font_size", T.FS_HEADLINE_SM)
    lbl.position = pos
    fx_layer.add_child(lbl)
    var tw := create_tween()
    tw.parallel().tween_property(lbl, "position:y", pos.y - 36, 0.6)
    tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
    tw.tween_callback(lbl.queue_free)

func _shake(amount: float) -> void:
    if Settings.screen_shake_scale <= 0.001: return
    var orig := arena.position
    var scaled: float = amount * Settings.screen_shake_scale
    var tw := create_tween()
    tw.tween_property(arena, "position", orig + Vector2(scaled, 0), 0.04)
    tw.tween_property(arena, "position", orig, 0.06)

func _pop(node: Control) -> void:
    if node == null: return
    var orig := node.scale
    var tw := create_tween()
    tw.tween_property(node, "scale", orig * 1.18, 0.06)
    tw.tween_property(node, "scale", orig, 0.10)

func _flash_screen(c: Color, peak_alpha: float, duration: float) -> void:
    if overlay_flash == null: return
    overlay_flash.color = Color(c.r, c.g, c.b, 0.0)
    var tw := create_tween()
    tw.tween_property(overlay_flash, "color:a", peak_alpha, duration * 0.25)
    tw.tween_property(overlay_flash, "color:a", 0.0, duration * 0.75)

func _slow_mo(scale: float, hold: float) -> void:
    if Settings.screen_shake_scale <= 0.001: return
    Engine.time_scale = scale
    # Real-time timer (ignore_time_scale=true) so the slow-mo actually ends.
    var t := get_tree().create_timer(hold, true, false, true)
    t.timeout.connect(func(): Engine.time_scale = 1.0)

func _boss_burst(pos: Vector2) -> void:
    # Eight-petal radial flash for the boss kill.
    for i in 8:
        var c := ColorRect.new()
        c.color = T.PRIMARY
        c.size = Vector2(10, 10)
        c.position = pos - c.size * 0.5
        fx_layer.add_child(c)
        var angle: float = TAU * float(i) / 8.0
        var dest: Vector2 = pos + Vector2(cos(angle), sin(angle)) * 96.0 - c.size * 0.5
        var tw := create_tween()
        tw.parallel().tween_property(c, "position", dest, 0.45)
        tw.parallel().tween_property(c, "modulate:a", 0.0, 0.45)
        tw.tween_callback(c.queue_free)
    _shake(16)

# --- Milestone overlay --------------------------------------------------

func _on_milestone(_id: String, label: String) -> void:
    _show_milestone_toast(label)

const LEVEL_PERK_CHOICES := [
    {"id":"perm_hp",    "label":"Iron Body",   "desc":"+5 max HP."},
    {"id":"perm_dmg",   "label":"Sharpened",   "desc":"+1 damage."},
    {"id":"perm_atk",   "label":"Quickened",   "desc":"+0.1 atk/sec."},
    {"id":"perm_gold",  "label":"Coinhand",    "desc":"+5%% gold drops."},
    {"id":"perm_range", "label":"Longarm",     "desc":"+10 range."},
    {"id":"perm_crit",  "label":"Keen Eye",    "desc":"+2%% crit chance."},
]

func _on_hero_leveled(new_level: int) -> void:
    _floating_text("LEVEL %d" % new_level, hero.position + hero.size * 0.5, T.PRIMARY)
    _flash_screen(T.PRIMARY, 0.18, 0.18)
    SfxBus.play("levelup", -4.0)
    # Heal a chunk to celebrate.
    HordeState.hero_max_hp = HordeState.max_hp()
    HordeState.hero_hp = min(HordeState.hero_max_hp, HordeState.hero_hp + 10)
    _refresh_hud()
    _log("Level %d" % new_level)
    if new_level % 5 == 0:
        _open_level_perk_picker(new_level)

func _open_level_perk_picker(level: int) -> void:
    var pool: Array = LEVEL_PERK_CHOICES.duplicate()
    pool.shuffle()
    var picks: Array = pool.slice(0, 3)
    milestone_title.text = "Level %d — pick a permanent boost" % level
    milestone_body.text = "Carry it across runs and rebirths."
    for c in milestone_choices.get_children():
        c.queue_free()
    for p in picks:
        var d: Dictionary = p
        var b := Button.new()
        b.text = "%s — %s" % [String(d["label"]),
            String(d["desc"]).replace("%%", "%")]
        b.custom_minimum_size = Vector2(0, 64)
        UiStyle_.apply_primary(b)
        b.pressed.connect(_on_level_perk_chosen.bind(d))
        milestone_choices.add_child(b)
    paused_for_milestone = true
    milestone_overlay.visible = true
    overlay_scrim.visible = true

func _on_level_perk_chosen(perk: Dictionary) -> void:
    var id: String = String(perk["id"])
    GameState.level_perks[id] = int(GameState.level_perks.get(id, 0)) + 1
    SaveSystem.save()
    _floating_text("✦ %s" % String(perk["label"]),
        Vector2(arena.size.x * 0.5 - 80, 100), T.PRIMARY)
    HordeState.hero_max_hp = HordeState.max_hp()
    _refresh_hud()
    _close_milestone()

func _on_class_unlocked(class_id: String) -> void:
    _show_milestone_toast("%s class unlocked" % class_id.capitalize())
    # If a slot milestone fired earlier without options, re-open the picker.
    if pending_slot != "":
        _open_slot_picker(pending_slot)

func _on_slot_unlocked(slot: String) -> void:
    pending_slot = slot
    _open_slot_picker(slot)

func _show_milestone_toast(label: String) -> void:
    _achievement_banner(label)

func _achievement_banner(label: String) -> void:
    # Big primary-gold banner that flies in from the top, holds 1.4s,
    # then fades out. Reuses fx_layer so it tracks the arena.
    var bg := Panel.new()
    bg.custom_minimum_size = Vector2(360, 56)
    bg.size = Vector2(360, 56)
    bg.position = Vector2(arena.size.x * 0.5 - 180, -60)
    var sb := StyleBoxFlat.new()
    sb.bg_color = Color(T.PRIMARY.r, T.PRIMARY.g, T.PRIMARY.b, 0.92)
    sb.corner_radius_top_left = 12; sb.corner_radius_top_right = 12
    sb.corner_radius_bottom_left = 12; sb.corner_radius_bottom_right = 12
    bg.add_theme_stylebox_override("panel", sb)
    fx_layer.add_child(bg)
    var lbl := Label.new()
    lbl.text = "✦ %s ✦" % label
    lbl.anchor_right = 1.0; lbl.anchor_bottom = 1.0
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lbl.add_theme_color_override("font_color", T.ON_PRIMARY)
    lbl.add_theme_font_size_override("font_size", T.FS_HEADLINE_SM)
    bg.add_child(lbl)
    var tw := create_tween()
    tw.tween_property(bg, "position:y", 24, 0.3)
    tw.tween_interval(1.4)
    tw.tween_property(bg, "modulate:a", 0.0, 0.4)
    tw.tween_callback(bg.queue_free)
    SfxBus.play("levelup", -3.0)

func _open_slot_picker(slot: String) -> void:
    var options: Array[String] = HordeState.available_classes_for_extra_slot()
    if options.is_empty():
        # No second class unlocked yet — defer the picker until one is.
        # The milestone is already marked done, so we re-fire when the next
        # class_unlocked signal arrives.
        pending_slot = slot
        _floating_text("Slot ready — unlock a class to fill it",
            Vector2(arena.size.x * 0.5 - 140, 80), T.WARNING)
        return
    pending_slot = ""
    milestone_title.text = "Choose your %s class" % slot
    milestone_body.text = "Your power has grown. Pick another path to fuse with %s." % HordeState.primary.capitalize()
    for c in milestone_choices.get_children():
        c.queue_free()
    for cid in options:
        var b := Button.new()
        b.text = cid.capitalize()
        b.custom_minimum_size = Vector2(0, 56)
        UiStyle_.apply_primary(b)
        b.pressed.connect(_pick_extra_class.bind(slot, cid))
        milestone_choices.add_child(b)
    paused_for_milestone = true
    milestone_overlay.visible = true
    overlay_scrim.visible = true

func _pick_extra_class(slot: String, cid: String) -> void:
    if slot == "secondary":
        HordeState.secondary = cid
    elif slot == "tertiary":
        HordeState.tertiary = cid
    pending_slot = ""
    _close_milestone()
    hero_label.text = _hero_initials()
    _style_hero()
    btn_skill.text = _skill_label()
    _refresh_hud()

const MERCHANT_OFFERS := [
    {"id":"heal",     "label":"Healing Tonic",    "desc":"Restore HP to full.",            "cost":40},
    {"id":"oil",      "label":"Whetstone Oil",    "desc":"+50%% damage for 3 waves.",      "cost":60},
    {"id":"drum",     "label":"Battle Drum",      "desc":"+1.0 atk/sec for 3 waves.",      "cost":80},
    {"id":"trade",    "label":"Ember Bargain",    "desc":"Trade 30 gold for 1 Ember.",     "cost":30},
]

func _open_merchant() -> void:
    milestone_title.text = "Wandering Merchant"
    milestone_body.text = "A trader sets up shop between fights."
    for c in milestone_choices.get_children():
        c.queue_free()
    for o in MERCHANT_OFFERS:
        var d: Dictionary = o
        var b := Button.new()
        var label: String = String(d["label"])
        var desc: String = String(d["desc"]).replace("%%", "%")
        var cost: int = int(d["cost"])
        b.text = "%s (%dg)  —  %s" % [label, cost, desc]
        b.custom_minimum_size = Vector2(0, 56)
        b.disabled = GameState.gold < cost or (String(d["id"]) == "trade" and GameState.gold < 30)
        UiStyle_.apply_secondary(b)
        b.pressed.connect(_on_merchant_buy.bind(d))
        milestone_choices.add_child(b)
    paused_for_milestone = true
    milestone_overlay.visible = true
    overlay_scrim.visible = true
    SfxBus.play("chest_open", -6.0)

func _on_merchant_buy(offer: Dictionary) -> void:
    var cost: int = int(offer["cost"])
    if GameState.gold < cost: return
    GameState.gold -= cost
    EventBus.currency_changed.emit("gold", -cost, GameState.gold)
    match String(offer["id"]):
        "heal":
            HordeState.hero_hp = HordeState.hero_max_hp
        "oil":
            temp_dmg_until = HordeState.wave + 3
        "drum":
            temp_atk_until = HordeState.wave + 3
        "trade":
            GameState.add_embers(1)
    SaveSystem.save()
    _refresh_hud()
    _close_milestone()
    _floating_text("Bought: %s" % String(offer["label"]),
        Vector2(arena.size.x * 0.5 - 100, 80), T.SECONDARY)

const BOSS_LOOT := [
    {"id":"berserk",   "label":"Berserk",    "desc":"+40%% damage this run.", "kind":"dmg_mult", "value":0.40},
    {"id":"sanctuary", "label":"Sanctuary",  "desc":"+50%% max HP this run.", "kind":"sanctuary","value":0.50},
    {"id":"hoard",     "label":"Hoard",      "desc":"+50%% gold drops this run.", "kind":"gold_mult","value":0.50},
    {"id":"storm",     "label":"Storm",      "desc":"+0.5 atk/sec this run.", "kind":"atk_speed","value":0.5},
]

func _open_boss_loot_picker() -> void:
    var pool: Array = BOSS_LOOT.duplicate()
    pool.shuffle()
    var picks: Array = pool.slice(0, 2)
    milestone_title.text = "Boss loot — choose a boon"
    milestone_body.text = "A reward for felling the boss. Active this run only."
    for c in milestone_choices.get_children():
        c.queue_free()
    for p in picks:
        var d: Dictionary = p
        var b := Button.new()
        b.text = "%s — %s" % [String(d["label"]),
            String(d["desc"]).replace("%%", "%")]
        b.custom_minimum_size = Vector2(0, 64)
        UiStyle_.apply_primary(b)
        b.pressed.connect(_on_boss_loot_chosen.bind(d))
        milestone_choices.add_child(b)
    paused_for_milestone = true
    milestone_overlay.visible = true
    overlay_scrim.visible = true
    SfxBus.play("chest_open", -4.0)

func _on_boss_loot_chosen(perk: Dictionary) -> void:
    var kind: String = String(perk["kind"])
    var v: float = float(perk["value"])
    match kind:
        "dmg_mult": HordePerks.dmg_mult *= 1.0 + v
        "gold_mult": HordePerks.gold_mult *= 1.0 + v
        "atk_speed": HordePerks.atk_speed_bonus += v
        "sanctuary":
            HordeState.hero_max_hp = int(HordeState.hero_max_hp * (1.0 + v))
            HordeState.hero_hp = HordeState.hero_max_hp
    _floating_text("✦ %s" % String(perk["label"]),
        Vector2(arena.size.x * 0.5 - 80, 100), T.PRIMARY)
    _refresh_hud()
    _close_milestone()

func _open_perk_picker() -> void:
    reroll_cost = 50
    _populate_perk_picker()
    paused_for_milestone = true
    milestone_overlay.visible = true
    overlay_scrim.visible = true
    SfxBus.play("perk_pick", -6.0)

func _populate_perk_picker() -> void:
    var picks: Array = HordePerks.roll(rng, 3)
    if picks.is_empty(): return
    milestone_title.text = "Perk pick — wave %d" % HordeState.wave
    milestone_body.text = "Choose a power to carry into the next push."
    for c in milestone_choices.get_children():
        c.queue_free()
    for p in picks:
        var d: Dictionary = p
        var b := Button.new()
        var label: String = String(d["label"])
        var desc: String = String(d["desc"]).replace("%%", "%")
        b.text = "%s  —  %s" % [label, desc]
        b.custom_minimum_size = Vector2(0, 64)
        UiStyle_.apply_primary(b)
        b.pressed.connect(_on_perk_chosen.bind(d))
        milestone_choices.add_child(b)
    var rb := Button.new()
    rb.text = "Reroll (%d g)" % reroll_cost
    rb.custom_minimum_size = Vector2(0, 48)
    rb.disabled = GameState.gold < reroll_cost
    UiStyle_.apply_secondary(rb)
    rb.pressed.connect(_on_perk_reroll)
    milestone_choices.add_child(rb)

func _on_perk_reroll() -> void:
    if GameState.gold < reroll_cost: return
    GameState.gold -= reroll_cost
    EventBus.currency_changed.emit("gold", -reroll_cost, GameState.gold)
    reroll_cost = int(round(reroll_cost * 1.6))
    _populate_perk_picker()
    _refresh_hud()

func _on_perk_chosen(perk: Dictionary) -> void:
    HordePerks.apply(perk)
    _floating_text("+ %s" % String(perk["label"]),
        Vector2(arena.size.x * 0.5 - 80, 100), T.PRIMARY)
    _refresh_perk_row()
    _style_range_ring()
    _log("Perk: %s" % String(perk["label"]))
    _close_milestone()

func _refresh_perk_row() -> void:
    if perk_row == null: return
    for c in perk_row.get_children(): c.queue_free()
    for id in HordePerks.taken_ids:
        var def: Dictionary = {}
        for p in HordePerks.ALL_PERKS:
            if String((p as Dictionary)["id"]) == id:
                def = p; break
        if def.is_empty(): continue
        var chip := Panel.new()
        chip.custom_minimum_size = Vector2(0, 28)
        var sb := StyleBoxFlat.new()
        sb.bg_color = T.SURFACE_BRIGHT
        sb.corner_radius_top_left = 14; sb.corner_radius_top_right = 14
        sb.corner_radius_bottom_left = 14; sb.corner_radius_bottom_right = 14
        sb.border_color = T.PRIMARY
        sb.border_width_left = 1; sb.border_width_right = 1
        sb.border_width_top = 1; sb.border_width_bottom = 1
        chip.add_theme_stylebox_override("panel", sb)
        var label := Label.new()
        label.text = "  %s  " % String(def["label"])
        label.add_theme_color_override("font_color", T.ON_SURFACE)
        label.add_theme_font_size_override("font_size", T.FS_BODY_SM)
        chip.add_child(label)
        label.position = Vector2(0, 4)
        perk_row.add_child(chip)

func _close_milestone() -> void:
    paused_for_milestone = false
    milestone_overlay.visible = false
    overlay_scrim.visible = false

func _hide_milestone() -> void:
    milestone_overlay.visible = false
    overlay_scrim.visible = false

func _maybe_show_tutorial() -> void:
    if Settings.tutorial_seen: return
    if tutorial_panel == null: return
    tutorial_label.text = "STRIKE — tap for a heavy hit\nSKILL — class active (6s cd)\nClear waves to unlock paths and pick perks every 5"
    tutorial_panel.visible = true
    var t := get_tree().create_timer(7.0, true, false, true)
    t.timeout.connect(func():
        if tutorial_panel != null and is_instance_valid(tutorial_panel):
            tutorial_panel.visible = false)
    Settings.tutorial_seen = true
    Settings.save()

func _on_quit() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/title.tscn")

func _hero_take_damage(amount: int) -> void:
    if dead_screen_open: return
    HordeState.hero_hp = max(0, HordeState.hero_hp - amount)
    _refresh_hud()
    SfxBus.play("low_hp" if HordeState.hero_hp < HordeState.hero_max_hp / 4 else "hit", -10.0)
    var alpha: float = clamp(0.15 + amount * 0.04, 0.18, 0.55)
    var dur: float = 0.18 + clamp(amount * 0.008, 0.0, 0.18)
    _flash_screen(T.ERROR, alpha, dur)
    if amount >= 10: _shake(6)
    if HordeState.hero_hp <= 0:
        _on_hero_died()

var dead_screen_open: bool = false

func _on_hero_died() -> void:
    # Spend a Second Wind revive if any are left.
    if HordeState.revives_used < Upgrades.max_revives():
        HordeState.revives_used += 1
        HordeState.hero_hp = HordeState.hero_max_hp / 2
        for e in enemies:
            var n: Panel = e.get("node")
            if n != null and is_instance_valid(n): n.queue_free()
        enemies.clear()
        _flash_screen(T.PRIMARY, 0.7, 0.5)
        _slow_mo(0.4, 0.4)
        SfxBus.play("levelup", -2.0)
        _floating_text("SECOND WIND", hero.position + hero.size * 0.5, T.PRIMARY)
        _refresh_hud()
        return
    dead_screen_open = true
    paused_for_milestone = true
    overlay_scrim.visible = true
    if HordeState.wave > GameState.best_run_wave:
        GameState.best_run_wave = HordeState.wave
    if HordeState.kills_this_run > GameState.best_run_kills:
        GameState.best_run_kills = HordeState.kills_this_run
    var class_best: int = int(GameState.best_wave_by_class.get(HordeState.primary, 0))
    if HordeState.wave > class_best:
        GameState.best_wave_by_class[HordeState.primary] = HordeState.wave
    var ach_reward: int = Achievements.scan_and_claim()
    if ach_reward > 0:
        run_embers_earned += ach_reward
    GameState.push_run_history({
        "wave": HordeState.wave,
        "kills": HordeState.kills_this_run,
        "combo": combo_peak,
        "embers": run_embers_earned,
        "class": HordeState.primary,
        "when": int(Time.get_unix_time_from_system()),
    })
    var lost: int = GameState.gold / 2
    GameState.gold = max(0, GameState.gold - lost)
    SaveSystem.save()
    milestone_title.text = "FALLEN ON WAVE %d" % HordeState.wave
    var perk_count: int = HordePerks.taken_ids.size()
    var lines: Array[String] = []
    lines.append("Kills:   %d" % HordeState.kills_this_run)
    lines.append("Gold:    -%d (spilled)" % lost)
    if combo_peak >= 5:
        lines.append("Peak combo: x%d  (%.2f×)" % [combo_peak,
            1.0 + (float(combo_peak) / float(combo_peak + COMBO_HALF_AT))])
    if run_embers_earned > 0:
        lines.append("Embers:  +%d" % run_embers_earned)
    lines.append("Perks taken: %d" % perk_count)
    if HordeState.wave > GameState.best_run_wave:
        lines.append("⚑ NEW BEST WAVE")
    milestone_body.text = "\n".join(lines)
    for c in milestone_choices.get_children(): c.queue_free()
    var b := Button.new()
    b.text = "VIEW UPGRADES"
    b.custom_minimum_size = Vector2(0, 56)
    UiStyle_.apply_primary(b)
    b.pressed.connect(_on_death_view_upgrades)
    milestone_choices.add_child(b)
    var h := Button.new()
    h.text = "RETURN HOME"
    h.custom_minimum_size = Vector2(0, 56)
    UiStyle_.apply_secondary(h)
    h.pressed.connect(_on_return_after_death)
    milestone_choices.add_child(h)
    milestone_overlay.visible = true
    milestone_skip.visible = false
    SfxBus.play("dragon_phase_enraged", 0.0)

func _on_return_after_death() -> void:
    HordeState.reset_run()
    HordePerks.reset_for_run()
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/title.tscn")

func _on_death_view_upgrades() -> void:
    HordeState.reset_run()
    HordePerks.reset_for_run()
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/upgrades.tscn")

func _on_restart() -> void:
    HordeState.reset_run()
    HordePerks.reset_for_run()
    SaveSystem.save()
    get_tree().reload_current_scene()

const SKILL_BY_CLASS := {
    "warrior":     {"label": "CLEAVE",  "kind": "aoe"},
    "rogue":       {"label": "BLINK",   "kind": "heal_invuln"},
    "wizard":      {"label": "FIREBALL","kind": "single_huge"},
    "necromancer": {"label": "REAP",    "kind": "drain_aoe"},
    "bard":        {"label": "ANTHEM",  "kind": "atk_buff"},
}

func _skill_def() -> Dictionary:
    return SKILL_BY_CLASS.get(HordeState.primary, SKILL_BY_CLASS["warrior"])

func _skill_label() -> String:
    if skill_cd > 0.0: return "%s (%.1fs)" % [String(_skill_def()["label"]), skill_cd]
    return String(_skill_def()["label"])

func _on_skill_used() -> void:
    if skill_cd > 0.0 or _is_paused(): return
    if _challenge_disables("bare_hands"): return
    var kind: String = String(_skill_def()["kind"])
    var dmg := _hero_damage()
    match kind:
        "aoe":
            for e in enemies.duplicate():
                _damage_enemy(e, dmg * 2)
            _flash_screen(T.WARNING, 0.4, 0.25)
            _shake(10)
        "heal_invuln":
            HordeState.hero_hp = HordeState.hero_max_hp
            _flash_screen(T.RARITY_UNCOMMON, 0.4, 0.25)
            _refresh_hud()
        "single_huge":
            # Find biggest-HP enemy and atomize.
            var best: Dictionary = {}
            var best_hp: int = 0
            for e in enemies:
                if int(e["hp"]) > best_hp: best_hp = int(e["hp"]); best = e
            if not best.is_empty():
                _damage_enemy(best, dmg * 12)
                _spawn_strike(best["node"].position + best["node"].size * 0.5)
                _flash_screen(T.RARITY_RARE, 0.5, 0.25)
        "drain_aoe":
            for e in enemies.duplicate():
                _damage_enemy(e, dmg)
            HordeState.hero_hp = min(HordeState.hero_max_hp,
                HordeState.hero_hp + dmg)
            _flash_screen(T.RARITY_EPIC, 0.4, 0.25)
            _refresh_hud()
        "atk_buff":
            HordePerks.atk_speed_bonus += 0.5
            var t := get_tree().create_timer(8.0, true, false, true)
            t.timeout.connect(func(): HordePerks.atk_speed_bonus = max(0.0, HordePerks.atk_speed_bonus - 0.5))
            _flash_screen(T.SECONDARY, 0.3, 0.25)
    skill_cd = SKILL_COOLDOWN
    btn_skill.text = _skill_label()
    SfxBus.play("perk_pick", -4.0)

func _on_pause() -> void:
    paused_by_user = true
    pause_overlay.visible = true
    overlay_scrim.visible = true
    _refresh_pause_stats()
    SaveSystem.save()

func _refresh_pause_stats() -> void:
    if pause_stats == null: return
    var crit_pct: float = (Upgrades.crit_chance() + HordePerks.crit_bonus) * 100.0
    var lines: Array[String] = [
        "Damage: %d   ·   Atk/sec: %.1f" % [_hero_damage(), _hero_atk_rate()],
        "Range: %d   ·   Crit: %.0f%%" % [int(_hero_range()), crit_pct],
        "Gold mult: %.2f×   ·   Wave bonus: %.2f×" % [
            Upgrades.ember_gold_mult() * HordePerks.gold_mult * (1.0 + GameState.rebirths * 0.25),
            HordePerks.wave_bonus_mult,
        ],
    ]
    pause_stats.text = "\n".join(lines)

func _on_motion_toggled(reduced: bool) -> void:
    if reduced:
        if Settings.screen_shake_scale > 0.001:
            Settings.set_meta("prev_shake", Settings.screen_shake_scale)
        Settings.screen_shake_scale = 0.0
    else:
        var prev := float(Settings.get_meta("prev_shake", 1.0))
        Settings.screen_shake_scale = prev if prev > 0.05 else 1.0
    Settings.save()

func _on_mute_toggled(muted: bool) -> void:
    # Mute SFX *and* music together — single switch matches UX expectation
    # (one "mute everything" checkbox).
    if muted:
        if Settings.sfx_volume > 0.001:
            Settings.set_meta("prev_sfx_vol", Settings.sfx_volume)
        if Settings.music_volume > 0.001:
            Settings.set_meta("prev_music_vol", Settings.music_volume)
        Settings.sfx_volume = 0.0
        Settings.music_volume = 0.0
    else:
        var prev_sfx := float(Settings.get_meta("prev_sfx_vol", 0.8))
        var prev_music := float(Settings.get_meta("prev_music_vol", 0.7))
        Settings.sfx_volume = prev_sfx if prev_sfx > 0.05 else 0.8
        Settings.music_volume = prev_music if prev_music > 0.05 else 0.7
    Settings.apply_audio_buses()
    Settings.save()

func _on_resume() -> void:
    paused_by_user = false
    pause_overlay.visible = false
    if not paused_for_milestone:
        overlay_scrim.visible = false
