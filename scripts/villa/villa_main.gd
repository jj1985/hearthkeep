extends Node3D

# Walkable Villa scene — stub.
# Rooms: Treasury (9 chests), Trophy Hall (display pedestals), Forge stub,
# Tavern stub, Gambling Den stub.
#
# Player walks the same controller as the run scene; interaction prompts
# show when near a chest / pedestal / stub door.

const PlayerScene := preload("res://scenes/player/player.tscn")

@onready var camera: Camera3D = $World/Cam
@onready var player_layer: Node3D = $World/PlayerLayer
@onready var sun: DirectionalLight3D = $World/Sun
@onready var prompt_label: Label = $HUD/Root/Prompt
@onready var chest_overlay: CanvasLayer = $ChestOverlay
@onready var chest_root: Control = $ChestOverlay/Root
@onready var return_btn: Button = $HUD/Root/ReturnButton

var player: CharacterBody3D
var nearest_chest_id: String = ""
var nearest_pedestal: Node3D = null

func _ready() -> void:
    SaveSystem.load_save()
    Settings.load_settings()
    EventBus.day_night_phase_changed.connect(_on_phase_changed)
    return_btn.pressed.connect(_return_to_title)
    _spawn_player()
    MusicDirector.set_layer(MusicDirector.Layer.EXPLORATION)
    _on_phase_changed(WorldSim.phase)
    EventBus.floating_text.emit("Welcome home.", Vector2(0, 0), Color(1, 0.85, 0.6))

func _process(delta: float) -> void:
    if player != null and is_instance_valid(player):
        var lookahead: Vector3 = (player.move_dir as Vector3).normalized() * 1.6
        var target: Vector3 = player.global_position + Vector3(lookahead.x, 0, lookahead.z)
        camera.position = camera.position.lerp(target + Vector3(8.0, 12.0, 8.0), 0.07)
        camera.look_at(target + Vector3.UP, Vector3.UP)
    _update_proximity_prompt()
    if Input.is_action_just_pressed("interact"):
        _try_interact()

func _spawn_player() -> void:
    player = PlayerScene.instantiate()
    player.class_primary = "warrior"
    player.position = Vector3(0, 0, 4)   # spawn at the entry hall
    player_layer.add_child(player)

func _update_proximity_prompt() -> void:
    nearest_chest_id = ""
    nearest_pedestal = null
    if player == null or not is_instance_valid(player):
        prompt_label.visible = false
        return
    var best_d := 2.6
    for c in get_tree().get_nodes_in_group("chest"):
        var d: float = player.global_position.distance_to((c as Node3D).global_position)
        if d < best_d:
            best_d = d
            nearest_chest_id = (c as Node3D).get_meta("chest_id", "")
    var best_p := 2.6
    for p in get_tree().get_nodes_in_group("pedestal"):
        var d: float = player.global_position.distance_to((p as Node3D).global_position)
        if d < best_p:
            best_p = d
            nearest_pedestal = p as Node3D
    if nearest_chest_id != "":
        prompt_label.text = "[E] Open  " + _chest_name(nearest_chest_id)
        prompt_label.visible = true
    elif nearest_pedestal != null:
        var t: String = nearest_pedestal.get_meta("trophy_id", "")
        prompt_label.text = "[E] Trophy slot  ·  " + (t if t != "" else "(empty)")
        prompt_label.visible = true
    else:
        prompt_label.visible = false

func _chest_name(id: String) -> String:
    for d in ChestManager.CHEST_DEFS:
        if (d as Dictionary)["id"] == id:
            return str((d as Dictionary)["name"])
    return id

func _try_interact() -> void:
    if nearest_chest_id != "":
        _open_chest(nearest_chest_id)
    elif nearest_pedestal != null:
        EventBus.floating_text.emit("Trophy slot — placement UI roadmap", Vector2(player.global_position.x, player.global_position.z), Color(1, 0.8, 1))

func _open_chest(chest_id: String) -> void:
    chest_overlay.visible = true
    get_tree().paused = true
    chest_root.show_chest(chest_id, _close_chest)

func _close_chest() -> void:
    chest_overlay.visible = false
    get_tree().paused = false

func _on_phase_changed(_phase: int) -> void:
    var c := WorldSim.phase_color()
    sun.light_color = c
    sun.light_energy = 0.5 if WorldSim.phase == WorldSim.Phase.NIGHT else 1.1

func _return_to_title() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/title.tscn")
