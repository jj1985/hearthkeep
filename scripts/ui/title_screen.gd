extends Control

# Title screen — three-state machine: splash → title (tap-to-begin) → menu.
# Spec: docs/ui_spec.md §11.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")

enum State { SPLASH, TITLE, MENU }

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var splash: Control = $SafeArea/Splash
@onready var splash_logo: Label = $SafeArea/Splash/V/Logo
@onready var splash_subtitle: Label = $SafeArea/Splash/V/Subtitle
@onready var title_pane: Control = $SafeArea/Title
@onready var title_logo: Label = $SafeArea/Title/V/Logo
@onready var title_subtitle: Label = $SafeArea/Title/V/Subtitle
@onready var tap_label: Label = $SafeArea/Title/V/TapHint
@onready var menu: Control = $SafeArea/Menu
@onready var btn_continue: Button = $SafeArea/Menu/V/Continue
@onready var btn_new_run: Button = $SafeArea/Menu/V/NewRun
@onready var btn_villa: Button = $SafeArea/Menu/V/Villa
@onready var btn_codex: Button = $SafeArea/Menu/V/Codex
@onready var btn_settings: Button = $SafeArea/Menu/V/Settings

var state: int = State.SPLASH
var pulse_t: float = 0.0
var splash_t: float = 0.0
const SPLASH_DURATION := 1.2

func _ready() -> void:
    SaveSystem.load_save()
    Settings.load_settings()
    MusicDirector.set_layer(MusicDirector.Layer.EXPLORATION)
    bg.color = T.SURFACE_DIM
    _wire_buttons()
    _apply_typography()
    _enter_splash()

func _wire_buttons() -> void:
    UiStyle_.apply_primary(btn_new_run)
    UiStyle_.apply_secondary(btn_continue)
    UiStyle_.apply_secondary(btn_villa)
    UiStyle_.apply_secondary(btn_codex)
    UiStyle_.apply_secondary(btn_settings)
    btn_new_run.pressed.connect(_on_new_run)
    btn_continue.pressed.connect(_on_continue)
    btn_villa.pressed.connect(_on_villa)
    btn_codex.pressed.connect(_on_codex)
    btn_settings.pressed.connect(_on_settings)
    btn_continue.visible = _has_save()

func _apply_typography() -> void:
    splash_logo.add_theme_font_size_override("font_size", T.FS_DISPLAY_LG)
    splash_logo.add_theme_color_override("font_color", T.PRIMARY)
    splash_subtitle.add_theme_font_size_override("font_size", T.FS_HEADLINE_SM)
    splash_subtitle.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    title_logo.add_theme_font_size_override("font_size", T.FS_DISPLAY_MD)
    title_logo.add_theme_color_override("font_color", T.PRIMARY)
    title_subtitle.add_theme_font_size_override("font_size", T.FS_HEADLINE_SM)
    title_subtitle.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    tap_label.add_theme_font_size_override("font_size", T.FS_LABEL_LG)
    tap_label.add_theme_color_override("font_color", T.ON_SURFACE)

func _has_save() -> bool:
    if not Engine.has_singleton("GameState"):
        return false
    return GameState.run_count > 0 or GameState.deepest_floor > 0 or GameState.gold > 0

func _process(delta: float) -> void:
    pulse_t += delta
    match state:
        State.SPLASH:
            splash_t += delta
            var fade_in: float = clamp(splash_t / 0.4, 0.0, 1.0)
            var fade_out: float = clamp((SPLASH_DURATION - splash_t) / 0.2, 0.0, 1.0)
            splash.modulate.a = min(fade_in, fade_out)
            if splash_t >= SPLASH_DURATION:
                _enter_title()
        State.TITLE:
            tap_label.modulate.a = 0.6 + 0.4 * (0.5 + 0.5 * sin(pulse_t * 2.2))
        State.MENU:
            pass

func _input(event: InputEvent) -> void:
    if state == State.SPLASH:
        if event is InputEventMouseButton and event.pressed:
            _enter_title()
        elif event is InputEventScreenTouch and event.pressed:
            _enter_title()
        elif event is InputEventKey and event.pressed:
            _enter_title()
    elif state == State.TITLE:
        if event is InputEventMouseButton and event.pressed:
            _enter_menu()
        elif event is InputEventScreenTouch and event.pressed:
            _enter_menu()
        elif event is InputEventKey and event.pressed:
            _enter_menu()

func _enter_splash() -> void:
    state = State.SPLASH
    splash_t = 0.0
    splash.visible = true
    splash.modulate.a = 0.0
    title_pane.visible = false
    menu.visible = false

func _enter_title() -> void:
    state = State.TITLE
    splash.visible = false
    title_pane.visible = true
    title_pane.modulate.a = 0.0
    menu.visible = false
    var tw := create_tween()
    tw.tween_property(title_pane, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _enter_menu() -> void:
    state = State.MENU
    menu.visible = true
    menu.modulate.a = 0.0
    menu.position.y = 80
    var tw := create_tween().set_parallel(true)
    tw.tween_property(menu, "modulate:a", 1.0, 0.28)
    tw.tween_property(menu, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    var tw2 := create_tween()
    tw2.tween_property(title_pane, "scale", Vector2(0.78, 0.78), 0.28)

func _on_new_run() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/class_select.tscn")

func _on_continue() -> void:
    get_tree().change_scene_to_file("res://scenes/run.tscn")

func _on_villa() -> void:
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")

func _on_codex() -> void:
    EventBus.floating_text.emit("Codex coming soon", Vector2.ZERO, T.ON_SURFACE_MUTED)

func _on_settings() -> void:
    EventBus.floating_text.emit("Settings coming soon", Vector2.ZERO, T.ON_SURFACE_MUTED)
