extends Control

# Pause menu modal. Pause-aware: PROCESS_MODE_ALWAYS so the menu ticks
# while the rest of the tree is paused. Spec: docs/ui_spec.md §12.3.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

@onready var dim: ColorRect = $Dim
@onready var card: PanelContainer = $Card
@onready var title_label: Label = $Card/Margin/V/Title
@onready var resume_btn: Button = $Card/Margin/V/Resume
@onready var villa_btn: Button = $Card/Margin/V/Villa
@onready var title_btn: Button = $Card/Margin/V/Title2
@onready var quit_btn: Button = $Card/Margin/V/Quit

signal resumed

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    dim.color = T.SCRIM
    title_label.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    title_label.add_theme_color_override("font_color", T.PRIMARY)
    card.add_theme_stylebox_override("panel", UiStyle_.panel_modal())
    UiStyle_.apply_primary(resume_btn)
    UiStyle_.apply_secondary(villa_btn)
    UiStyle_.apply_secondary(title_btn)
    UiStyle_.apply_secondary(quit_btn)
    for b in [resume_btn, villa_btn, title_btn, quit_btn]:
        UiAnim_.bind_press_feedback(b)
    resume_btn.pressed.connect(_resume)
    villa_btn.pressed.connect(_to_villa)
    title_btn.pressed.connect(_to_title)
    quit_btn.pressed.connect(_quit)
    UiAnim_.slide_up_in(card, 80.0, UiAnim_.DUR_LG)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        _resume()

func _resume() -> void:
    resumed.emit()
    queue_free()

func _to_villa() -> void:
    get_tree().paused = false
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")

func _to_title() -> void:
    get_tree().paused = false
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/title.tscn")

func _quit() -> void:
    SaveSystem.save()
    get_tree().quit()
