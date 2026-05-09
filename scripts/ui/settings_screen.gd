extends Control

# Settings screen — Phase A. Reads/writes the Settings autoload directly.
# Reachable from title menu and pause menu.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var music_slider: HSlider = $SafeArea/V/MusicRow/Slider
@onready var music_label: Label = $SafeArea/V/MusicRow/Label
@onready var sfx_slider: HSlider = $SafeArea/V/SfxRow/Slider
@onready var sfx_label: Label = $SafeArea/V/SfxRow/Label
@onready var ambient_slider: HSlider = $SafeArea/V/AmbientRow/Slider
@onready var ambient_label: Label = $SafeArea/V/AmbientRow/Label
@onready var shake_slider: HSlider = $SafeArea/V/ShakeRow/Slider
@onready var shake_label: Label = $SafeArea/V/ShakeRow/Label
@onready var orientation_btn: OptionButton = $SafeArea/V/OrientationRow/OptionButton
@onready var control_btn: OptionButton = $SafeArea/V/ControlRow/OptionButton
@onready var auto_pickup_check: CheckBox = $SafeArea/V/AutoPickupRow/Check
@onready var subtitle_check: CheckBox = $SafeArea/V/SubtitleRow/Check
@onready var haptics_check: CheckBox = $SafeArea/V/HapticsRow/Check
@onready var save_btn: Button = $SafeArea/V/Footer/Save
@onready var close_btn: Button = $SafeArea/V/Footer/Close

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    UiStyle_.apply_primary(save_btn)
    UiStyle_.apply_secondary(close_btn)
    UiAnim_.bind_press_feedback(save_btn)
    UiAnim_.bind_press_feedback(close_btn)
    save_btn.pressed.connect(_on_save)
    close_btn.pressed.connect(_on_close)

    for slider in [music_slider, sfx_slider, ambient_slider, shake_slider]:
        slider.min_value = 0.0
        slider.max_value = 1.0
        slider.step = 0.05
    music_slider.value = Settings.music_volume
    sfx_slider.value = Settings.sfx_volume
    ambient_slider.value = Settings.ambient_volume
    shake_slider.value = Settings.screen_shake_scale
    music_slider.value_changed.connect(func(v):
        _refresh_label(music_label, "Music", v)
        Settings.music_volume = v
        Settings.apply_audio_buses())
    sfx_slider.value_changed.connect(func(v):
        _refresh_label(sfx_label, "SFX", v)
        Settings.sfx_volume = v
        Settings.apply_audio_buses())
    ambient_slider.value_changed.connect(func(v):
        _refresh_label(ambient_label, "Ambient", v)
        Settings.ambient_volume = v
        Settings.apply_audio_buses())
    shake_slider.value_changed.connect(func(v):
        _refresh_label(shake_label, "Screen shake", v)
        Settings.screen_shake_scale = v)
    _refresh_label(music_label, "Music", Settings.music_volume)
    _refresh_label(sfx_label, "SFX", Settings.sfx_volume)
    _refresh_label(ambient_label, "Ambient", Settings.ambient_volume)
    _refresh_label(shake_label, "Screen shake", Settings.screen_shake_scale)

    orientation_btn.add_item("Auto-rotate", 0)
    orientation_btn.add_item("Lock landscape", 1)
    orientation_btn.add_item("Lock portrait", 2)
    var ori_idx: int = ["auto", "landscape", "portrait"].find(Settings.orientation_lock)
    orientation_btn.select(max(0, ori_idx))
    orientation_btn.item_selected.connect(func(idx):
        Settings.orientation_lock = ["auto", "landscape", "portrait"][idx])

    control_btn.add_item("Twin-stick (virtual stick + skills)", 0)
    control_btn.add_item("Tap-to-move + auto-attack", 1)
    control_btn.select(Settings.control_scheme)
    control_btn.item_selected.connect(func(idx): Settings.control_scheme = idx)

    auto_pickup_check.button_pressed = Settings.auto_pickup_junk
    auto_pickup_check.toggled.connect(func(v): Settings.auto_pickup_junk = v)
    subtitle_check.button_pressed = Settings.subtitle_barks
    subtitle_check.toggled.connect(func(v): Settings.subtitle_barks = v)
    haptics_check.button_pressed = Settings.haptics
    haptics_check.toggled.connect(func(v): Settings.haptics = v)

func _refresh_label(label: Label, name: String, val: float) -> void:
    label.text = "%s   %d %%" % [name, int(round(val * 100.0))]
    label.add_theme_color_override("font_color", T.ON_SURFACE)
    label.add_theme_font_size_override("font_size", T.FS_BODY_LG)

func _on_save() -> void:
    Settings.save()
    EventBus.floating_text.emit("Settings saved.", Vector2.ZERO, T.SUCCESS)

func _on_close() -> void:
    Settings.save()
    get_tree().change_scene_to_file("res://scenes/title.tscn")
