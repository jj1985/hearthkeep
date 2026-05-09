extends Control

# Game-over overlay. Spec: docs/ui_spec.md §12.3 — desaturate to mono
# over 800 ms, "YOU FELL" display_md fade-in, run summary, return-to-villa
# button.
#
# Spawned by run/main on _on_player_died. Pause-aware: PROCESS_MODE_ALWAYS.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

@onready var dim: ColorRect = $Dim
@onready var title_label: Label = $V/Title
@onready var stats_label: Label = $V/Stats
@onready var return_btn: Button = $V/Return

@export var floors_cleared: int = 0
@export var kills: int = 0
@export var gold_earned: int = 0
@export var legendaries: int = 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    dim.color = Color(0, 0, 0, 0.0)
    title_label.add_theme_font_size_override("font_size", T.FS_DISPLAY_MD)
    title_label.add_theme_color_override("font_color", T.ERROR)
    stats_label.add_theme_font_size_override("font_size", T.FS_BODY_LG)
    stats_label.add_theme_color_override("font_color", T.ON_SURFACE)
    UiStyle_.apply_primary(return_btn)
    UiAnim_.bind_press_feedback(return_btn)
    return_btn.pressed.connect(_on_return)
    title_label.modulate.a = 0.0
    stats_label.modulate.a = 0.0
    return_btn.modulate.a = 0.0
    _populate_stats()
    _animate_in()

func _populate_stats() -> void:
    var t: float = RunState.run_time
    var mins: int = int(t) / 60
    var secs: int = int(t) % 60
    var class_line: String = _class_line()
    var perks_line: String = "%d perk%s · %d evolution%s" % [
        RunState.perks_taken.size(), "" if RunState.perks_taken.size() == 1 else "s",
        RunState.weapon_evolutions.size(), "" if RunState.weapon_evolutions.size() == 1 else "s",
    ]
    stats_label.text = "%s\n%s\nLevel %d  ·  %d:%02d on the clock\nFloors cleared:  %d\nKills:  %d  ·  Gold:  %d  ·  Legendaries:  %d" % [
        class_line, perks_line,
        RunState.player_level, mins, secs,
        floors_cleared, kills, gold_earned, legendaries,
    ]

func _class_line() -> String:
    var parts: Array = []
    for cid in [RunState.class_primary, RunState.class_secondary, RunState.class_tertiary]:
        if cid == "":
            continue
        parts.append(String(Classes.get_class_def(cid).get("name", cid)))
    var line: String = " / ".join(parts)
    var hybs: Array = RunState.all_hybrid_prestiges()
    if hybs.is_empty():
        return line
    var names: Array = []
    for h in hybs:
        names.append(String(h.get("name", "")))
    return "%s  ·  %s" % [line, " + ".join(names)]

func _animate_in() -> void:
    # Phase 1: desaturate world (proxy via black scrim ramp)
    var tw := create_tween()
    tw.tween_property(dim, "color:a", 0.85, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    # Phase 2: title fade-in
    tw.tween_property(title_label, "modulate:a", 1.0, 0.4)
    # Phase 3: stats + return
    tw.tween_property(stats_label, "modulate:a", 1.0, 0.3)
    tw.tween_property(return_btn, "modulate:a", 1.0, 0.3)

func _on_return() -> void:
    get_tree().paused = false
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
