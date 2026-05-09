extends Control

# First-run tutorial. Spawned by run/main on the player's very first run
# (Settings.tutorial_seen == false). Pauses the game; the player can dismiss
# with any tap or the on-screen DISMISS button.
#
# 4 anchored callouts:
#   - Bottom-left:  virtual stick → "Move"
#   - Bottom-right: skill cluster → "Skills"
#   - Bottom-mid:   potions       → "Potions"
#   - Top-right:    pause + minimap → "Menu / Map"

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

@onready var dim: ColorRect = $Dim
@onready var headline: Label = $Headline
@onready var stick_label: Label = $StickLabel
@onready var skills_label: Label = $SkillsLabel
@onready var potions_label: Label = $PotionsLabel
@onready var menu_label: Label = $MenuLabel
@onready var dismiss_btn: Button = $Dismiss

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    dim.color = T.SCRIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    for l in [stick_label, skills_label, potions_label, menu_label]:
        l.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
        l.add_theme_color_override("font_color", T.ON_SURFACE)
    UiStyle_.apply_primary(dismiss_btn)
    UiAnim_.bind_press_feedback(dismiss_btn)
    dismiss_btn.pressed.connect(_dismiss)
    UiAnim_.pulse(stick_label, 1.6, 0.5, 1.0)
    UiAnim_.pulse(skills_label, 1.6, 0.5, 1.0)
    UiAnim_.pulse(potions_label, 1.6, 0.5, 1.0)
    UiAnim_.pulse(menu_label, 1.6, 0.5, 1.0)

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        _dismiss()
    elif event is InputEventScreenTouch and event.pressed:
        _dismiss()
    elif event is InputEventKey and event.pressed:
        _dismiss()

func _dismiss() -> void:
    Settings.tutorial_seen = true
    Settings.save()
    get_tree().paused = false
    queue_free()
