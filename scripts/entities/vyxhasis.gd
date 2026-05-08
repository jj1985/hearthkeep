extends "res://scripts/entities/dragon_boss.gd"

# Vyxhasis — the Cinderwastes fire dragon. Phase A scaffolding:
# physical hitbox + 3 phases that change emission color + ground/air abilities.
# Telegraphed attack VFX is Phase B.

const T := preload("res://scripts/ui/ui_tokens.gd")

@onready var body: MeshInstance3D = $Body
@onready var mat: StandardMaterial3D
@onready var hit_area: Area3D = $HitArea

var ability_t: float = 0.0

func _ready() -> void:
    super._ready()
    dragon_id = "vyxhasis"
    max_hp = 1200.0
    hp = max_hp
    contact_damage = 24.0
    register_ability("breath", 4.5)
    register_ability("dive", 9.0)
    register_ability("rupture", 6.0)
    if body != null:
        mat = body.get_active_material(0).duplicate() if body.get_active_material(0) != null else StandardMaterial3D.new()
        body.set_surface_override_material(0, mat)
        _apply_phase_visual()
    phase_entered.connect(_on_phase_entered)
    died.connect(_on_died)

func _process(delta: float) -> void:
    tick(delta)
    ability_t += delta
    var player_arr := get_tree().get_nodes_in_group("player")
    if player_arr.is_empty():
        return
    var p = player_arr[0]
    look_at(Vector3(p.global_position.x, global_position.y, p.global_position.z), Vector3.UP)
    if phase == Phase.GROUND:
        if is_ability_ready("breath") and global_position.distance_to(p.global_position) < 14.0:
            consume_ability("breath")
            _do_breath(p)
    elif phase == Phase.AIR:
        if is_ability_ready("dive"):
            consume_ability("dive")
            _do_dive(p)
    elif phase == Phase.ENRAGED:
        if is_ability_ready("rupture"):
            consume_ability("rupture")
            _do_rupture(p)
        if is_ability_ready("breath"):
            consume_ability("breath")
            _do_breath(p)

func _on_phase_entered(p: int) -> void:
    _apply_phase_visual()
    var msg: String = ""
    match p:
        Phase.AIR:    msg = "Vyxhasis takes wing!"
        Phase.ENRAGED: msg = "VYXHASIS RAGES!"
    if msg != "":
        EventBus.floating_text.emit(msg, Vector2(global_position.x, global_position.z), T.SECONDARY)
        SfxBus.play("dragon_roar", -2.0)
        EventBus.screen_shake.emit(0.6, 0.4)

func _apply_phase_visual() -> void:
    if mat == null:
        return
    match phase:
        Phase.GROUND:
            mat.albedo_color = Color("#5C2A1A")
            mat.emission = Color("#6E2010")
            mat.emission_energy_multiplier = 0.5
        Phase.AIR:
            mat.albedo_color = Color("#7C2E1E")
            mat.emission = Color("#A02E1E")
            mat.emission_energy_multiplier = 1.4
        Phase.ENRAGED:
            mat.albedo_color = Color("#A03318")
            mat.emission = Color("#E04018")
            mat.emission_energy_multiplier = 3.5

func _do_breath(p: Node) -> void:
    var dist: float = global_position.distance_to(p.global_position)
    if dist < 16.0 and p.has_method("get") and p.get("stats") != null:
        p.stats.take_damage(contact_damage * 0.7)
        EventBus.floating_text.emit("FIRE BREATH", p.global_position, T.SECONDARY)
        EventBus.screen_shake.emit(0.4, 0.2)

func _do_dive(p: Node) -> void:
    EventBus.floating_text.emit("DIVE!", global_position, T.WARNING)
    var tw := create_tween()
    var target: Vector3 = p.global_position + Vector3.UP * 1.0
    tw.tween_property(self, "global_position", target, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tw.tween_callback(func():
        if p.has_method("get") and p.get("stats") != null and global_position.distance_to(p.global_position) < 4.0:
            p.stats.take_damage(contact_damage * 1.2)
            EventBus.screen_shake.emit(0.8, 0.3)
            EventBus.hit_stop.emit(0.08))

func _do_rupture(p: Node) -> void:
    EventBus.floating_text.emit("GROUND RUPTURE", global_position, T.ERROR)
    EventBus.screen_shake.emit(0.6, 0.35)
    if p.has_method("get") and p.get("stats") != null and global_position.distance_to(p.global_position) < 12.0:
        p.stats.take_damage(contact_damage * 0.9)

func _on_body_hit(by: Node) -> void:
    # Player attacks call this from their attack swing area.
    if by != null and by.has_method("current_damage"):
        take_damage(by.current_damage())

func _on_died() -> void:
    EventBus.floating_text.emit("VYXHASIS  DEFEATED", global_position, T.PRIMARY)
    SfxBus.play("dragon_roar", 2.0)
    EventBus.screen_shake.emit(1.2, 0.8)
    EventBus.hit_stop.emit(0.5)
    if not GameState.defeated_dragons.has("vyxhasis"):
        GameState.defeated_dragons.append("vyxhasis")
    GameState.add_gold(500)
    if Engine.has_singleton("VendorSystem"):
        VendorSystem.add_currency("dragon_shards", 10)
    _rain_loot()
    var tw := create_tween()
    tw.tween_interval(2.5)
    tw.tween_callback(func():
        SaveSystem.save()
        get_tree().change_scene_to_file("res://scenes/villa/villa.tscn"))

func _rain_loot() -> void:
    # Spawn 8 legendary loot drops in a circle around the dragon corpse.
    for i in range(8):
        var ang: float = float(i) * TAU / 8.0
        var pos: Vector2 = Vector2(global_position.x + cos(ang) * 4.0, global_position.z + sin(ang) * 4.0)
        var item: Dictionary = LootSystem.roll_item(4)    # 4 = Legendary in RARITY_NAMES
        EventBus.loot_dropped.emit(item, pos)
