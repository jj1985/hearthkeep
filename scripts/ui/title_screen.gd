extends Node2D

@onready var start_btn: Button = $UI/StartButton
@onready var villa_btn: Button = $UI/VillaButton
@onready var credits_btn: Button = $UI/CreditsButton
@onready var logo: Label = $UI/Logo

var blink_t: float = 0.0

func _ready() -> void:
    SaveSystem.load_save()
    Settings.load_settings()
    MusicDirector.set_layer(MusicDirector.Layer.EXPLORATION)
    start_btn.pressed.connect(_on_start)
    villa_btn.pressed.connect(_on_villa)
    credits_btn.pressed.connect(_on_credits)

func _process(delta: float) -> void:
    blink_t += delta
    logo.modulate.a = 0.85 + 0.15 * sin(blink_t * 1.6)

func _on_start() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/class_select.tscn")

func _on_villa() -> void:
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")

func _on_credits() -> void:
    get_tree().change_scene_to_file("res://scenes/credits.tscn")
