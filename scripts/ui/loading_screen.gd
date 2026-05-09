extends Control

# Loading screen with rotating lore + class tips. Spec §11.2.
# Mix per spec: 60% gameplay tips, 25% class lore stingers, 15% world lore.
# Cycles tips every 4 s with 240 ms fade in/out. Bottom-right rune
# spinner ticks for ambience.

const T := preload("res://scripts/ui/ui_tokens.gd")

const TIP_GAMEPLAY := [
    "Hold a skill button to charge for +30% damage.",
    "Below 25% HP, your potions heal 50% more.",
    "Crit floaters scale with rarity — landed any artifacts?",
    "Goblin Sappers light a fuse before exploding. You can interrupt them.",
    "Vyxhasis takes wing at 70% HP. Brace.",
    "Warchiefs call reinforcements at half HP. Burst them down or break for cover.",
    "Stack the same perk twice for compounding effects.",
    "Weapon evolutions need a perk + the right weapon equipped.",
    "Set your Bond Stone at a wayspire — channel home from anywhere out of combat.",
    "Trophy buffs only count when active. The hall caps how many you can run with.",
    "Every 5th floor: a dragon. Every 5 dragons: a memory.",
    "The Forge's quality roll favors high skill. Upgrade the building.",
]

const TIP_CLASS := [
    "WARRIOR — every shield-block returns 4% damage as gold. The bookkeeping never stops.",
    "ROGUE — daggers from shadow are not louder than swords from light, but they argue more.",
    "WIZARD — minds the mana bar.  All the rest is decoration.",
    "NECROMANCER — borrows what others would not lend.",
    "BARD — songs that bolster, shouts that shatter.",
    "PALADIN — holy steel cuts what holy words won't argue.",
    "RANGER — a shaft of yew, a hound, and time. Most things fall to that.",
]

const TIP_WORLD := [
    "The Sundering shattered Aerathis into seven realms; you walk what remains.",
    "There is no temple to Sennari. Only altars where coin has changed hands.",
    "Drakes are dragons that have not yet eaten enough kingdoms.",
    "Goblins were not always so many. The Sundering opened the underdeep.",
    "The crown's lighthouse keeps the shipping lanes open. From its keep, every adventurer departs.",
]

@onready var bg: ColorRect = $Bg
@onready var brazier_label: Label = $Brazier
@onready var tip_label: Label = $Tip
@onready var rune_label: Label = $Rune

var elapsed: float = 0.0
var rotate_t: float = 0.0
var current_tip: String = ""
var seen_recent: Array[String] = []
@export var auto_advance_after: float = 0.0    # 0 = never auto-advance; >0 = seconds before scene_change
@export var next_scene: String = ""

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    brazier_label.add_theme_color_override("font_color", T.SECONDARY)
    brazier_label.add_theme_font_size_override("font_size", T.FS_DISPLAY_LG)
    tip_label.add_theme_color_override("font_color", T.ON_SURFACE)
    tip_label.add_theme_font_size_override("font_size", T.FS_BODY_LG)
    tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tip_label.modulate.a = 0.0
    rune_label.add_theme_color_override("font_color", T.PRIMARY)
    rune_label.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    _new_tip()

func _process(delta: float) -> void:
    elapsed += delta
    rotate_t += delta
    # Brazier flicker
    var brazier_pulse: float = 0.85 + 0.15 * sin(elapsed * 7.0)
    brazier_label.modulate.a = brazier_pulse
    # Rune spinner
    var ring := ["⟁", "⟆", "✶", "❖", "✷", "⟜"]
    rune_label.text = ring[int(elapsed * 4.0) % ring.size()]
    # Tip rotation
    if rotate_t > 4.0:
        rotate_t = 0.0
        var tw := create_tween()
        tw.tween_property(tip_label, "modulate:a", 0.0, 0.24)
        tw.tween_callback(_new_tip)
        tw.tween_property(tip_label, "modulate:a", 1.0, 0.24)
    # Auto-advance
    if auto_advance_after > 0.0 and elapsed > auto_advance_after and next_scene != "":
        auto_advance_after = 0.0    # one-shot
        get_tree().change_scene_to_file(next_scene)

func _new_tip() -> void:
    var roll: float = randf()
    var pool: Array
    if roll < 0.60:   pool = TIP_GAMEPLAY
    elif roll < 0.85: pool = TIP_CLASS
    else:             pool = TIP_WORLD
    var pick: String = current_tip
    var safety: int = 8
    while pick == current_tip and safety > 0:
        pick = String(pool[randi() % pool.size()])
        safety -= 1
    if seen_recent.size() >= 5:
        seen_recent.pop_front()
    seen_recent.append(pick)
    current_tip = pick
    tip_label.text = pick
