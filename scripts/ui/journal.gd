extends Control

# Combined Journal — Quest log + Lore codex behind a 2-tab segmented control.
# Reached from the Villa "War Room" / "Library" buildings or via inventory hotkey.

const T := preload("res://scripts/ui/ui_tokens.gd")
const UiStyle_ := preload("res://scripts/ui/ui_style.gd")
const UiAnim_ := preload("res://scripts/ui/ui_anim.gd")

const CATEGORY_ORDER := ["region", "dragons", "creatures", "pantheon", "history", "items", "npc", "cosmology", "magic", "mystery"]

@onready var bg: ColorRect = $Bg
@onready var safe_area: MarginContainer = $SafeArea
@onready var headline: Label = $SafeArea/V/Headline
@onready var tab_quests: Button = $SafeArea/V/Tabs/Quests
@onready var tab_codex: Button = $SafeArea/V/Tabs/Codex
@onready var quests_pane: ScrollContainer = $SafeArea/V/QuestsPane
@onready var quests_list: VBoxContainer = $SafeArea/V/QuestsPane/List
@onready var codex_pane: HBoxContainer = $SafeArea/V/CodexPane
@onready var codex_categories: VBoxContainer = $SafeArea/V/CodexPane/Categories/Inner
@onready var codex_entries: VBoxContainer = $SafeArea/V/CodexPane/Detail/Entries
@onready var close_btn: Button = $SafeArea/V/Footer/Close

var current_tab: String = "quests"
var current_category: String = "region"

func _ready() -> void:
    bg.color = T.SURFACE_DIM
    headline.add_theme_font_size_override("font_size", T.FS_HEADLINE_LG)
    headline.add_theme_color_override("font_color", T.PRIMARY)
    UiStyle_.apply_secondary(close_btn)
    UiStyle_.apply_secondary(tab_quests)
    UiStyle_.apply_secondary(tab_codex)
    UiAnim_.bind_press_feedback(close_btn)
    UiAnim_.bind_press_feedback(tab_quests)
    UiAnim_.bind_press_feedback(tab_codex)
    tab_quests.pressed.connect(_select_tab.bind("quests"))
    tab_codex.pressed.connect(_select_tab.bind("codex"))
    close_btn.pressed.connect(_on_close)
    _select_tab(current_tab)
    _populate_codex_categories()

func _select_tab(tab: String) -> void:
    current_tab = tab
    if tab == "quests":
        UiStyle_.apply_primary(tab_quests)
        UiStyle_.apply_secondary(tab_codex)
        quests_pane.visible = true
        codex_pane.visible = false
        _populate_quests()
    else:
        UiStyle_.apply_secondary(tab_quests)
        UiStyle_.apply_primary(tab_codex)
        quests_pane.visible = false
        codex_pane.visible = true

# ---- Quest log ----

func _populate_quests() -> void:
    for c in quests_list.get_children():
        c.queue_free()
    var actives: Array = QuestSystem.get_active_list()
    var completed: Array = QuestSystem.completed
    if actives.is_empty() and completed.is_empty():
        var empty := Label.new()
        empty.text = "No quests yet. The world watches."
        empty.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        empty.add_theme_font_size_override("font_size", T.FS_BODY_LG)
        quests_list.add_child(empty)
        return
    if not actives.is_empty():
        var hdr := _section_header("ACTIVE", T.PRIMARY)
        quests_list.add_child(hdr)
        for q in actives:
            quests_list.add_child(_quest_card(q, true))
    if not completed.is_empty():
        var hdr2 := _section_header("COMPLETED", T.ON_SURFACE_MUTED)
        quests_list.add_child(hdr2)
        for qid in completed:
            var q: Dictionary = QuestSystem.registry.get(qid, {"id": qid, "title": qid, "objectives": []})
            quests_list.add_child(_quest_card(q, false))

func _section_header(text: String, color: Color) -> Label:
    var lbl := Label.new()
    lbl.text = text
    lbl.add_theme_font_size_override("font_size", T.FS_HEADLINE_SM)
    lbl.add_theme_color_override("font_color", color)
    return lbl

func _quest_card(q: Dictionary, is_active: bool) -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiStyle_.card_resting())
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    panel.add_child(v)
    var title := Label.new()
    title.text = String(q.get("title", q.get("id", "?")))
    title.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    title.add_theme_color_override("font_color", T.PRIMARY if is_active else T.ON_SURFACE_MUTED)
    v.add_child(title)
    if q.has("desc"):
        var desc := Label.new()
        desc.text = String(q["desc"])
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc.add_theme_font_size_override("font_size", T.FS_BODY_MD)
        desc.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        v.add_child(desc)
    var objectives: Array = q.get("objectives", [])
    var progress: Dictionary = QuestSystem.active.get(q.get("id", ""), {})
    for obj in objectives:
        var line := Label.new()
        var oid: String = obj.get("id", "")
        var done: int = int(progress.get(oid, 0))
        var need: int = int(obj.get("count", 1))
        var mark := "✓" if done >= need else "—"
        line.text = "  %s  %s  (%d/%d)" % [mark, obj.get("text", oid), done, need]
        line.add_theme_font_size_override("font_size", T.FS_BODY_MD)
        line.add_theme_color_override("font_color", T.SUCCESS if done >= need else T.ON_SURFACE)
        v.add_child(line)
    return panel

# ---- Lore codex ----

func _populate_codex_categories() -> void:
    for c in codex_categories.get_children():
        c.queue_free()
    var seen: Array[String] = []
    for entry in LoreCodex.ENTRIES:
        var cat: String = entry.get("cat", "misc")
        if not seen.has(cat):
            seen.append(cat)
    seen.sort()
    for cat in seen:
        var b := Button.new()
        b.text = cat.to_upper()
        b.set_meta("cat", cat)
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.custom_minimum_size = Vector2(0, 48)
        UiStyle_.apply_secondary(b)
        UiAnim_.bind_press_feedback(b)
        b.pressed.connect(_on_category_picked.bind(cat))
        codex_categories.add_child(b)
    if not seen.is_empty():
        _on_category_picked(seen[0])

func _on_category_picked(cat: String) -> void:
    current_category = cat
    for c in codex_categories.get_children():
        var btn: Button = c as Button
        if btn == null:
            continue
        var is_active: bool = String(btn.get_meta("cat")) == cat
        if is_active:
            UiStyle_.apply_primary(btn)
        else:
            UiStyle_.apply_secondary(btn)
    _populate_codex_entries(cat)

func _populate_codex_entries(cat: String) -> void:
    for c in codex_entries.get_children():
        c.queue_free()
    var entries: Array = LoreCodex.by_category(cat)
    if entries.is_empty():
        var empty := Label.new()
        empty.text = "Nothing recorded yet."
        empty.add_theme_color_override("font_color", T.ON_SURFACE_MUTED)
        codex_entries.add_child(empty)
        return
    for entry in entries:
        codex_entries.add_child(_lore_card(entry))

func _lore_card(entry: Dictionary) -> Control:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", UiStyle_.card_resting())
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 8)
    panel.add_child(v)
    var title := Label.new()
    title.text = String(entry.get("title", "?"))
    title.add_theme_font_size_override("font_size", T.FS_TITLE_LG)
    title.add_theme_color_override("font_color", T.PRIMARY)
    v.add_child(title)
    var body := Label.new()
    body.text = String(entry.get("text", ""))
    body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    body.add_theme_font_size_override("font_size", T.FS_BODY_MD)
    body.add_theme_color_override("font_color", T.ON_SURFACE)
    v.add_child(body)
    return panel

func _on_close() -> void:
    get_tree().change_scene_to_file("res://scenes/villa/villa.tscn")
