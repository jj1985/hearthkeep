extends Control

# Title screen — three-state machine: splash → title (tap-to-begin) → menu.
# Spec: docs/ui_spec.md §11.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

enum State { SPLASH, TITLE, MENU }

@onready var bg: ColorRect = $Bg
@onready var ember_rain: CPUParticles2D = $EmberRain
@onready var dragon_shadow: ColorRect = $DragonShadow
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
@onready var milestone_hint: Label = $SafeArea/Menu/V/MilestoneHint
@onready var challenge_check: CheckBox = $SafeArea/Menu/V/ChallengeRow/ChallengeCheck

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
    _award_offline_progress()
    _award_daily_login()
    _enter_splash()

func _award_daily_login() -> void:
    var res: Dictionary = SaveSystem.process_daily_login()
    var bonus: int = int(res.get("ember", 0))
    if bonus <= 0: return
    var streak: int = int(res.get("streak", 1))
    title_subtitle.text += "  ·  Day %d streak: +%d ember" % [streak, bonus]

func _award_offline_progress() -> void:
    var seconds: int = SaveSystem.seconds_since_last_save()
    if seconds < 30: return
    var rate: float = HordeState.idle_gold_per_sec()
    var amount: int = int(round(rate * seconds))
    if amount <= 0: return
    GameState.add_gold(amount)
    SaveSystem.save()
    var hours: float = seconds / 3600.0
    title_subtitle.text = "While away (%.1f h): +%d gold" % [hours, amount]

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
    _refresh_meta_subtitle()
    _refresh_milestone_hint()
    _refresh_challenge_row()
    challenge_check.toggled.connect(_on_challenge_toggled)

func _refresh_challenge_row() -> void:
    if GameState.daily_curse == "":
        challenge_check.visible = false
        return
    var def: Dictionary = HordeState.curse_def(GameState.daily_curse)
    if def.is_empty():
        challenge_check.visible = false
        return
    challenge_check.visible = true
    challenge_check.button_pressed = GameState.challenge_active
    challenge_check.text = "Daily: %s — %s  ·  ×2 rewards" % [
        String(def["label"]), String(def["desc"]),
    ]

func _on_challenge_toggled(on: bool) -> void:
    GameState.challenge_active = on
    SaveSystem.save()
    for b in [btn_new_run, btn_continue, btn_villa, btn_codex, btn_settings]:
        UiAnim_.bind_press_feedback(b)

func _refresh_milestone_hint() -> void:
    var lines: Array[String] = []
    if GameState.dragonslayer:
        lines.append("⚔ Dragonslayer")
    if GameState.rebirths > 0:
        lines.append("Mark %d" % GameState.rebirths)
    if GameState.deepest_floor > 0:
        lines.append("Best wave: %d" % GameState.deepest_floor)
    if GameState.bosses_felled > 0:
        lines.append("Bosses felled: %d" % GameState.bosses_felled)
    if GameState.curses_cleared > 0:
        lines.append("Curses cleared: %d" % GameState.curses_cleared)
    if not GameState.daily_quest.is_empty():
        var dq: Dictionary = GameState.daily_quest
        if not bool(dq.get("claimed", false)):
            lines.append("Daily: kill %d / %d %s" % [
                int(dq.get("progress", 0)),
                int(dq.get("target_count", 0)),
                String(dq.get("target_id", "")).capitalize(),
            ])
        else:
            lines.append("Daily ✓ (%d g, %d 🜂)" % [
                int(dq.get("reward_gold", 0)),
                int(dq.get("reward_ember", 0)),
            ])
    var km: Dictionary = HordeState.next_kill_milestone()
    if not km.is_empty():
        var need: int = int(km["kills"])
        var have: int = GameState.lifetime_kills
        var cls: String = String(km["class"])
        lines.append("Next: %s (%d / %d kills)" % [cls.capitalize(), min(have, need), need])
    var wm: Dictionary = HordeState.next_wave_milestone()
    if not wm.is_empty():
        var need_w: int = int(wm["wave"])
        lines.append("Next slot: wave %d" % need_w)
    if lines.is_empty():
        milestone_hint.text = "All paths unlocked. Push deeper for Embers."
        milestone_hint.add_theme_color_override("font_color", T.PRIMARY)
    else:
        milestone_hint.text = "  ·  ".join(lines)
        milestone_hint.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)

func _refresh_meta_subtitle() -> void:
    # Replace the static "of the Sundered Realms" subtitle with a
    # progress-aware line once meaningful meta progression has occurred.
    # Pre-progress: keep the lore tagline.
    var dragons: int = GameState.defeated_dragons.size()
    var triple: bool = bool(GameState.meta_unlocks.get("triple_class", false))
    if dragons == 0 and not triple:
        return
    var parts: Array = []
    if dragons > 0:
        parts.append("%d / 3 dragons felled" % dragons)
    if triple:
        parts.append("Triple-class is yours")
    title_subtitle.text = " · ".join(parts)

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
    _start_dragon_shadow_loop()

func _start_dragon_shadow_loop() -> void:
    if dragon_shadow == null:
        return
    var screen_w: float = get_viewport_rect().size.x
    var sweep := func():
        if state != State.TITLE and state != State.MENU:
            return
        dragon_shadow.visible = true
        dragon_shadow.position.x = -200
        var tw := create_tween()
        tw.tween_property(dragon_shadow, "position:x", screen_w + 100, 2.4).set_trans(Tween.TRANS_LINEAR)
        tw.tween_callback(func():
            dragon_shadow.visible = false)
    sweep.call()
    var loop_t := Timer.new()
    loop_t.wait_time = 12.0
    loop_t.autostart = true
    add_child(loop_t)
    loop_t.timeout.connect(sweep)

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
    HordeState.reset_run()
    HordePerks.reset_for_run()
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/horde.tscn")

func _on_continue() -> void:
    # CONTINUE jumps straight back into the horde arena.
    get_tree().change_scene_to_file("res://scenes/horde.tscn")

func _on_villa() -> void:
    # Repurposed: VILLA → upgrade workshop where gold buys persistent
    # stat boosts. The full 3D villa scene is shelved during the
    # incremental pivot.
    get_tree().change_scene_to_file("res://scenes/upgrades.tscn")

func _on_codex() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/journal.tscn")

func _on_settings() -> void:
    get_tree().change_scene_to_file("res://scenes/ui/settings_screen.tscn")
