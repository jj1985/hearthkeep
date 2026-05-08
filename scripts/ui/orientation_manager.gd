extends Node

# Authoritative source of truth for layout bucket + safe area.
# Spec: docs/ui_spec.md §1.3 (Material 3 width window-size classes) and §2 (safe areas).
#
# Buckets (Material 3 WSC, by width in dp):
#   Compact   < 600 dp   — phone portrait
#   Medium    600–839 dp — small tablet portrait, phone landscape on big devices
#   Expanded  ≥ 840 dp   — 10"+ tablet, large phone landscape
#
# The legacy 5-bucket Orient enum is kept as `Orient` for backward compatibility
# with code that still imports it; new code reads `bucket` directly.

enum Bucket { COMPACT, MEDIUM, EXPANDED }
enum Orient { LANDSCAPE_PHONE, PORTRAIT_PHONE, LANDSCAPE_TABLET, PORTRAIT_TABLET, DESKTOP }

const BASE_VIEWPORT := Vector2i(720, 1280)

signal bucket_changed(bucket: Bucket)
signal safe_area_changed(rect: Rect2i)
signal orientation_changed(orient: int)    # legacy 5-bucket signal

var bucket: Bucket = Bucket.COMPACT
var safe_area: Rect2i = Rect2i()
var dp_scale: float = 1.0          # 1 dp = dp_scale * (window px) — NOTE: scale of dp per px
var current: int = Orient.DESKTOP  # legacy field

var _last_window_size: Vector2i = Vector2i.ZERO
var _last_dpi: int = 0

func _ready() -> void:
    var root := get_tree().root
    if root != null:
        root.size_changed.connect(_recompute)
    _recompute()

func _recompute() -> void:
    var win: Vector2i = DisplayServer.window_get_size()
    if win == Vector2i.ZERO:
        # Fallback for headless / pre-display contexts (tests, init order).
        var vp := get_viewport()
        if vp != null:
            win = vp.get_visible_rect().size
    if win == Vector2i.ZERO:
        return
    var screen_idx: int = DisplayServer.window_get_current_screen()
    var dpi: int = max(160, DisplayServer.screen_get_dpi(screen_idx))
    dp_scale = 160.0 / float(dpi)
    var width_dp: int = int(round(win.x * dp_scale))

    var new_bucket: Bucket = Bucket.COMPACT
    if width_dp >= 840:
        new_bucket = Bucket.EXPANDED
    elif width_dp >= 600:
        new_bucket = Bucket.MEDIUM

    if new_bucket != bucket or win != _last_window_size:
        bucket = new_bucket
        _last_window_size = win
        _last_dpi = dpi
        bucket_changed.emit(bucket)
        _emit_legacy_orientation(win)

    var sa: Rect2i = DisplayServer.get_display_safe_area()
    if sa.size == Vector2i.ZERO:
        sa = Rect2i(Vector2i.ZERO, win)
    if sa != safe_area:
        safe_area = sa
        safe_area_changed.emit(safe_area)

func _emit_legacy_orientation(win: Vector2i) -> void:
    # Map the new buckets back to the legacy 5-bucket enum so existing
    # subscribers keep working until they migrate to bucket_changed.
    var on_mobile: bool = OS.has_feature("mobile") or OS.has_feature("web")
    var aspect: float = float(win.x) / max(1.0, float(win.y))
    var is_tablet: bool = bucket != Bucket.COMPACT
    var legacy: int
    if not on_mobile:
        legacy = Orient.DESKTOP
    elif aspect >= 1.0:
        legacy = Orient.LANDSCAPE_TABLET if is_tablet else Orient.LANDSCAPE_PHONE
    else:
        legacy = Orient.PORTRAIT_TABLET if is_tablet else Orient.PORTRAIT_PHONE
    if legacy != current:
        current = legacy
        orientation_changed.emit(current)

func bucket_name(b: int = -1) -> String:
    var bb: int = b if b >= 0 else int(bucket)
    match bb:
        int(Bucket.COMPACT): return "compact"
        int(Bucket.MEDIUM): return "medium"
        int(Bucket.EXPANDED): return "expanded"
    return "?"

func is_portrait() -> bool:
    var w: Vector2i = _last_window_size if _last_window_size != Vector2i.ZERO else DisplayServer.window_get_size()
    return w.y >= w.x

func is_tablet() -> bool:
    return bucket != Bucket.COMPACT

# Bucket-keyed scalar tokens (spec §1.4). Read-only at runtime; the values
# below match the spec table verbatim. Layouts call these helpers rather
# than indexing the Bucket enum themselves.
func font_scale() -> float:
    match bucket:
        Bucket.MEDIUM: return 1.10
        Bucket.EXPANDED: return 1.15
    return 1.00

func padding_scale() -> float:
    match bucket:
        Bucket.MEDIUM: return 1.25
        Bucket.EXPANDED: return 1.50
    return 1.00

func min_touch_target_dp() -> int:
    return 56 if bucket == Bucket.EXPANDED else 48

func primary_btn_min_h_dp() -> int:
    match bucket:
        Bucket.MEDIUM: return 64
        Bucket.EXPANDED: return 72
    return 56

func combat_skill_btn_dp() -> int:
    match bucket:
        Bucket.MEDIUM: return 88
        Bucket.EXPANDED: return 96
    return 72

func perk_cards_per_row() -> int:
    return 4 if bucket == Bucket.EXPANDED else 2

func class_grid_cols() -> int:
    match bucket:
        Bucket.MEDIUM: return 2
        Bucket.EXPANDED: return 3
    return 1
