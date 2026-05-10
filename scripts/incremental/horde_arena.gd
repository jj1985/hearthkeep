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

const ENEMY_TYPES := {
    "skeleton":   {"label": "Skeleton",   "color": Color(0.85, 0.85, 0.78), "hp_base": 6,  "speed": 70.0,  "gold": 1},
    "goblin":     {"label": "Goblin",     "color": Color(0.45, 0.75, 0.35), "hp_base": 10, "speed": 95.0,  "gold": 2},
    "skel_brute": {"label": "Bone Brute", "color": Color(0.75, 0.7, 0.55),  "hp_base": 24, "speed": 55.0,  "gold": 5},
    "drake":      {"label": "Drake",      "color": Color(0.85, 0.35, 0.25), "hp_base": 60, "speed": 75.0,  "gold": 14},
}

const HERO_RADIUS := 22.0
const HERO_DAMAGE_BASE := 4
const HERO_ATTACK_RATE := 2.5     # attacks/sec at base
const HERO_RANGE := 220.0

@onready var bg: ColorRect = $Bg
@onready var arena: Control = $Arena
@onready var hero: Panel = $Arena/Hero
@onready var hero_label: Label = $Arena/Hero/Label
@onready var enemies_layer: Control = $Arena/Enemies
@onready var fx_layer: Control = $Arena/FX
@onready var hud_wave: Label = $HUD/Top/Wave
@onready var hud_kills: Label = $HUD/Top/Kills
@onready var hud_gold: Label = $HUD/Top/Gold
@onready var hud_loadout: Label = $HUD/Top/Loadout
@onready var dps_bar: ProgressBar = $HUD/Top/Wavebar
@onready var overlay_scrim: ColorRect = $Overlay/Scrim
@onready var milestone_overlay: Panel = $Overlay/Milestone
@onready var milestone_title: Label = $Overlay/Milestone/V/Title
@onready var milestone_body: Label = $Overlay/Milestone/V/Body
@onready var milestone_choices: VBoxContainer = $Overlay/Milestone/V/Choices
@onready var milestone_skip: Button = $Overlay/Milestone/V/Skip
@onready var btn_quit: Button = $HUD/Bottom/Quit
@onready var btn_strike: Button = $HUD/Bottom/Strike
@onready var hud_idle: Label = $HUD/Top/Idle
@onready var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var enemies: Array = []          # Array of { node, hp, max_hp, hp_bar, speed, gold, id }
var spawn_timer: float = 0.0
var attack_timer: float = 0.0
var idle_timer: float = 0.0
var wave_kills_target: int = 8
var wave_kills_progress: int = 0
var paused_for_milestone: bool = false
var pending_slot: String = ""    # "secondary" | "tertiary" | ""

# Idle gold/sec scales with deepest_floor + lifetime kills tier.
func _idle_gold_per_sec() -> float:
    var base: float = 0.4 + GameState.deepest_floor * 0.15
    base += float(GameState.lifetime_kills) / 1000.0
    if HordeState.secondary != "": base *= 1.4
    if HordeState.tertiary != "": base *= 1.5
    return base

func _ready() -> void:
    rng.randomize()
    HordeState.reset_run()
    HordeState.milestone_reached.connect(_on_milestone)
    HordeState.slot_unlocked.connect(_on_slot_unlocked)
    HordeState.class_unlocked.connect(_on_class_unlocked)
    btn_quit.pressed.connect(_on_quit)
    btn_strike.pressed.connect(_on_player_strike)
    milestone_skip.pressed.connect(_close_milestone)
    bg.color = T.SURFACE_DIM
    UiStyle_.apply_secondary(btn_quit)
    UiStyle_.apply_primary(btn_strike)
    UiStyle_.apply_secondary(milestone_skip)
    _layout_hero()
    _refresh_hud()
    _hide_milestone()

func _layout_hero() -> void:
    var size := arena.size
    hero.position = size * 0.5 - hero.size * 0.5
    hero_label.text = _hero_initials()

func _hero_initials() -> String:
    var parts := [HordeState.primary]
    if HordeState.secondary != "": parts.append(HordeState.secondary)
    if HordeState.tertiary != "": parts.append(HordeState.tertiary)
    var s := ""
    for p in parts:
        s += String(p).substr(0, 1).to_upper()
    return s

func _refresh_hud() -> void:
    hud_wave.text = "WAVE %d" % HordeState.wave
    hud_kills.text = "%d kills" % GameState.lifetime_kills
    hud_gold.text = "%d gold" % GameState.gold
    hud_loadout.text = _loadout_text()
    hud_idle.text = "+%.1f g/s" % _idle_gold_per_sec()
    dps_bar.max_value = max(1, wave_kills_target)
    dps_bar.value = wave_kills_progress

func _loadout_text() -> String:
    var parts := [HordeState.primary.capitalize()]
    if HordeState.secondary != "": parts.append(HordeState.secondary.capitalize())
    if HordeState.tertiary != "": parts.append(HordeState.tertiary.capitalize())
    return " / ".join(parts)

func _process(delta: float) -> void:
    if paused_for_milestone:
        return
    spawn_timer -= delta
    attack_timer -= delta
    idle_timer -= delta
    if spawn_timer <= 0.0:
        _spawn_enemy()
        spawn_timer = max(0.25, 1.4 - HordeState.wave * 0.04)
    if attack_timer <= 0.0:
        _hero_attack()
        attack_timer = 1.0 / HERO_ATTACK_RATE
    if idle_timer <= 0.0:
        var amount: int = int(round(_idle_gold_per_sec()))
        if amount > 0:
            GameState.add_gold(amount)
            _refresh_hud()
        idle_timer = 1.0
    _move_enemies(delta)

func _spawn_enemy() -> void:
    var size := arena.size
    var pool: Array = ["skeleton"]
    if HordeState.wave >= 3: pool.append("goblin")
    if HordeState.wave >= 6: pool.append("skel_brute")
    if HordeState.wave >= 12: pool.append("drake")
    var id: String = pool[rng.randi_range(0, pool.size() - 1)]
    var def: Dictionary = ENEMY_TYPES[id]
    var p := Panel.new()
    p.custom_minimum_size = Vector2(28, 28)
    p.size = Vector2(28, 28)
    var sb := StyleBoxFlat.new()
    sb.bg_color = def["color"]
    sb.corner_radius_top_left = 6
    sb.corner_radius_top_right = 6
    sb.corner_radius_bottom_left = 6
    sb.corner_radius_bottom_right = 6
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
    var max_hp: int = int(round(int(def["hp_base"]) * hp_scale))
    enemies.append({
        "node": p,
        "hp": max_hp,
        "max_hp": max_hp,
        "hp_bar": bar,
        "speed": float(def["speed"]) + HordeState.wave * 1.5,
        "gold": int(def["gold"]),
        "id": id,
    })

func _move_enemies(delta: float) -> void:
    var hero_center: Vector2 = hero.position + hero.size * 0.5
    var dead: Array = []
    for e in enemies:
        var node: Panel = e["node"]
        if node == null or not is_instance_valid(node):
            dead.append(e); continue
        var ep: Vector2 = node.position + node.size * 0.5
        var dir: Vector2 = (hero_center - ep).normalized()
        node.position += dir * float(e["speed"]) * delta
        # Contact damage = chip the player's gold (no death — stable)
        if ep.distance_to(hero_center) < HERO_RADIUS + 14:
            # Touch nibble: enemy explodes harmlessly so the run never softlocks
            _damage_enemy(e, 9999)
            _shake(4)
    for d in dead: enemies.erase(d)

func _hero_attack() -> void:
    var hero_center: Vector2 = hero.position + hero.size * 0.5
    var best: Dictionary = {}
    var best_d: float = HERO_RANGE
    for e in enemies:
        var node: Panel = e["node"]
        if node == null or not is_instance_valid(node):
            continue
        var d: float = (node.position + node.size * 0.5).distance_to(hero_center)
        if d < best_d:
            best_d = d; best = e
    if best.is_empty():
        return
    _damage_enemy(best, _hero_damage())
    _spawn_strike(best["node"].position + best["node"].size * 0.5)

func _hero_damage() -> int:
    var d: int = HERO_DAMAGE_BASE
    if HordeState.secondary != "": d += 3
    if HordeState.tertiary != "": d += 4
    d += HordeState.wave / 2
    return d

func _damage_enemy(e: Dictionary, amount: int) -> void:
    e["hp"] -= amount
    var bar: ProgressBar = e.get("hp_bar")
    if bar != null and is_instance_valid(bar):
        bar.value = float(max(0, e["hp"])) / float(max(1, int(e["max_hp"])))
    if e["hp"] <= 0:
        var n: Panel = e["node"]
        if n != null and is_instance_valid(n):
            n.queue_free()
        enemies.erase(e)
        HordeState.record_kill(String(e.get("id", "skeleton")), int(e.get("gold", 1)))
        wave_kills_progress += 1
        _refresh_hud()
        if wave_kills_progress >= wave_kills_target:
            _next_wave()

func _on_player_strike() -> void:
    if paused_for_milestone:
        return
    # Tap deals a fat hit on the closest enemy and visibly shakes the arena.
    var hero_center: Vector2 = hero.position + hero.size * 0.5
    var best: Dictionary = {}
    var best_d: float = HERO_RANGE * 1.3
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

func _next_wave() -> void:
    HordeState.advance_wave()
    wave_kills_progress = 0
    wave_kills_target = int(8 + HordeState.wave * 1.5)
    SaveSystem.save()
    _refresh_hud()
    _floating_text("WAVE %d" % HordeState.wave, hero.position + hero.size * 0.5, T.PRIMARY)

func _spawn_strike(pos: Vector2) -> void:
    var c := ColorRect.new()
    c.color = Color(1.0, 0.95, 0.6, 0.9)
    c.size = Vector2(14, 14)
    c.position = pos - c.size * 0.5
    fx_layer.add_child(c)
    var tw := create_tween()
    tw.tween_property(c, "modulate:a", 0.0, 0.18)
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
    var orig := arena.position
    var tw := create_tween()
    tw.tween_property(arena, "position", orig + Vector2(amount, 0), 0.04)
    tw.tween_property(arena, "position", orig, 0.06)

# --- Milestone overlay --------------------------------------------------

func _on_milestone(_id: String, label: String) -> void:
    _show_milestone_toast(label)

func _on_class_unlocked(class_id: String) -> void:
    _show_milestone_toast("%s class unlocked" % class_id.capitalize())

func _on_slot_unlocked(slot: String) -> void:
    pending_slot = slot
    _open_slot_picker(slot)

func _show_milestone_toast(label: String) -> void:
    _floating_text(label, Vector2(arena.size.x * 0.5 - 80, 80), T.PRIMARY)

func _open_slot_picker(slot: String) -> void:
    var label: String = "Choose your %s class" % slot
    milestone_title.text = label
    milestone_body.text = "Your power has grown. Pick another path to fuse with %s." % HordeState.primary.capitalize()
    for c in milestone_choices.get_children():
        c.queue_free()
    var options: Array[String] = HordeState.available_classes_for_extra_slot()
    if options.is_empty():
        # Nothing else unlocked yet — milestone fired but no class to pick.
        milestone_body.text += "\n\nUnlock another class first by stacking kills."
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
    _refresh_hud()

func _close_milestone() -> void:
    paused_for_milestone = false
    milestone_overlay.visible = false
    overlay_scrim.visible = false

func _hide_milestone() -> void:
    milestone_overlay.visible = false
    overlay_scrim.visible = false

func _on_quit() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/title.tscn")
