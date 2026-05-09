extends Control

# Snikkit's Gambling Den. Phase A — three games using only in-game
# currency (no real-money loot boxes ever). Per the design pillars:
# in-world gambling is THE betting hook, never paywalled.
#
# Games:
#   Mystery Item — pay N gold for a random item; rarity weights bias
#                  by stake size.
#   Double-or-Nothing — flip a coin (50/50) on your last winnings.
#   Wager-the-Run — bet a stake at run start for a multiplier on your
#                  run gold/loot drops (handled via RunState.wager_multiplier).

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var blurb: Label = $SafeArea/V/Blurb
@onready var balance: Label = $SafeArea/V/Balance
@onready var mystery_btn: Button = $SafeArea/V/Mystery/Btn
@onready var mystery_stake_label: Label = $SafeArea/V/Mystery/StakeLabel
@onready var mystery_stake_slider: HSlider = $SafeArea/V/Mystery/Slider
@onready var double_btn: Button = $SafeArea/V/Double/Btn
@onready var double_label: Label = $SafeArea/V/Double/Status
@onready var wager_btn: Button = $SafeArea/V/Wager/Btn
@onready var wager_label: Label = $SafeArea/V/Wager/Status
@onready var close_btn: Button = $SafeArea/V/Footer/Close

var pending_winnings: int = 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
    rng.randomize()
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    headline.text = "SNIKKIT'S DEN"
    blurb.text = "\"The dice know, soft-skin. The dice always know.\""
    blurb.add_theme_font_size_override("font_size", T.FS_BODY_LG)
    blurb.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    UiStyle_.apply_primary(mystery_btn)
    UiStyle_.apply_primary(double_btn)
    UiStyle_.apply_primary(wager_btn)
    UiStyle_.apply_secondary(close_btn)
    for b in [mystery_btn, double_btn, wager_btn, close_btn]:
        UiAnim_.bind_press_feedback(b)
    mystery_stake_slider.min_value = 50
    mystery_stake_slider.max_value = 5000
    mystery_stake_slider.step = 50
    mystery_stake_slider.value = 250
    mystery_stake_slider.value_changed.connect(func(_v): _refresh())
    mystery_btn.pressed.connect(_play_mystery)
    double_btn.pressed.connect(_play_double_or_nothing)
    wager_btn.pressed.connect(_apply_wager)
    close_btn.pressed.connect(_on_close)
    _refresh()

func _refresh() -> void:
    balance.text = "Gold:  %d" % GameState.gold
    balance.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    balance.add_theme_color_override("font_color", T.PRIMARY)
    mystery_stake_label.text = "Stake:  %d gold" % int(mystery_stake_slider.value)
    mystery_stake_label.add_theme_color_override("font_color", T.ON_SURFACE)
    if pending_winnings > 0:
        double_label.text = "Last winnings:  %d gold (risk it?)" % pending_winnings
        double_btn.disabled = false
    else:
        double_label.text = "No pending winnings."
        double_btn.disabled = true
    double_label.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
    var wager: float = float(RunState.wager_multiplier)
    wager_label.text = "Run wager:  ×%.2f (current)" % wager
    wager_label.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)

func _play_mystery() -> void:
    var stake: int = int(mystery_stake_slider.value)
    if GameState.gold < stake:
        EventBus.floating_text.emit("Not enough gold.", Vector2.ZERO, T.ERROR)
        return
    GameState.add_gold(-stake)
    SfxBus.play("chest_open", -3.0)
    # Bias rarity by stake size: rolls a notional scaling factor.
    var scaling: float = 1.0 + (float(stake) / 1000.0)
    var item: Dictionary = LootSystem.roll_item(-1, scaling)
    ChestManager.deposit(item)
    var rarity: int = clampi(int(item.get("rarity", 0)), 0, LootSystem.RARITY_NAMES.size() - 1)
    EventBus.floating_text.emit("WON: %s" % String(item.get("name", "?")),
        Vector2.ZERO, T.rarity(LootSystem.RARITY_NAMES[rarity].to_lower()))
    pending_winnings = int(VendorSystem.sell_value(item) * 0.4)
    _refresh()

func _play_double_or_nothing() -> void:
    if pending_winnings <= 0: return
    SfxBus.play("dodge", -2.0)
    if rng.randf() < 0.5:
        var doubled: int = pending_winnings * 2
        EventBus.floating_text.emit("DOUBLED!  +%d g" % doubled, Vector2.ZERO, T.SUCCESS)
        GameState.add_gold(doubled)
        pending_winnings = 0
    else:
        EventBus.floating_text.emit("LOST IT ALL", Vector2.ZERO, T.ERROR)
        pending_winnings = 0
    _refresh()

func _apply_wager() -> void:
    if RunState.active:
        EventBus.floating_text.emit("Cannot wager mid-run.", Vector2.ZERO, T.WARNING)
        return
    if GameState.gold < 100:
        EventBus.floating_text.emit("Need 100 gold to wager.", Vector2.ZERO, T.ERROR)
        return
    GameState.add_gold(-100)
    RunState.wager_multiplier = clampf(RunState.wager_multiplier + 0.10, 1.0, 3.0)
    EventBus.floating_text.emit("Wager set to ×%.2f for the next run." % RunState.wager_multiplier,
        Vector2.ZERO, T.PRIMARY)
    _refresh()

func _on_close() -> void:
    SaveSystem.save()
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
