extends Node

# SFX bus — procedurally-generated tones with ADSR envelope until real CC0
# audio packs land. API stays `SfxBus.play(name, volume_db)` so callers
# never need to change.

var _generated: Dictionary = {}
const SAMPLE_RATE := 22050

func _ready() -> void:
    # Combat
    _generated["hit"]              = _tone(440.0, 0.06, "perc")
    _generated["hit_heavy"]        = _chord([220.0, 330.0, 440.0], 0.10, "perc")
    _generated["crit"]             = _chord([880.0, 1320.0], 0.16, "shimmer")
    _generated["dodge"]            = _sweep(880.0, 220.0, 0.18, "swoosh")
    _generated["parry"]            = _chord([1760.0, 880.0], 0.10, "shimmer")
    _generated["footstep"]         = _tone(110.0, 0.04, "perc")
    # Pickups + UI
    _generated["pickup"]           = _tone(660.0, 0.05, "tone")
    _generated["potion"]           = _chord([550.0, 825.0], 0.12, "tone")
    _generated["levelup"]          = _chord([523.0, 659.0, 784.0], 0.40, "shimmer")    # C-major triad
    _generated["perk_pick"]        = _chord([440.0, 660.0, 880.0], 0.30, "shimmer")
    _generated["chest_open"]       = _sweep(220.0, 660.0, 0.45, "shimmer")
    _generated["forge_strike"]     = _tone(165.0, 0.18, "perc")
    # State / warnings
    _generated["low_hp"]           = _pulse(220.0, 0.35)        # heartbeat-style
    _generated["quest_complete"]   = _chord([523.0, 659.0, 784.0, 1046.0], 0.55, "shimmer")
    _generated["error"]            = _tone(196.0, 0.20, "tone")
    # Dragon / boss
    _generated["dragon_roar"]      = _chord([100.0, 132.0, 165.0], 0.65, "growl")
    _generated["dragon_phase_air"] = _sweep(180.0, 660.0, 0.80, "shimmer")
    _generated["dragon_phase_enraged"] = _chord([88.0, 110.0, 132.0], 0.95, "growl")

func play(name: String, volume_db: float = -6.0) -> void:
    if not _generated.has(name):
        return
    var p := AudioStreamPlayer.new()
    p.stream = _generated[name]
    p.volume_db = volume_db
    add_child(p)
    p.play()
    p.finished.connect(p.queue_free)

# ---- Internal generators --------------------------------------------------

func _tone(freq: float, dur: float, shape: String = "tone") -> AudioStreamWAV:
    return _build_wav(_render_tone(freq, dur, shape))

func _chord(freqs: Array, dur: float, shape: String = "tone") -> AudioStreamWAV:
    var sample_count := int(SAMPLE_RATE * dur)
    var sums := PackedFloat32Array()
    sums.resize(sample_count)
    for i in range(sample_count): sums[i] = 0.0
    for f in freqs:
        var add := _render_tone(float(f), dur, shape)
        for i in range(sample_count):
            sums[i] += add[i]
    # Normalize chord
    var maxv: float = 0.001
    for i in range(sample_count):
        var av: float = abs(sums[i])
        if av > maxv: maxv = av
    var out := PackedFloat32Array()
    out.resize(sample_count)
    for i in range(sample_count):
        out[i] = (sums[i] / maxv) * 0.85
    return _build_wav(out)

func _sweep(f_start: float, f_end: float, dur: float, shape: String = "tone") -> AudioStreamWAV:
    var sample_count := int(SAMPLE_RATE * dur)
    var out := PackedFloat32Array()
    out.resize(sample_count)
    var phase: float = 0.0
    for i in range(sample_count):
        var t: float = float(i) / SAMPLE_RATE
        var k: float = float(i) / float(max(1, sample_count - 1))
        var f: float = lerp(f_start, f_end, k)
        phase += f / SAMPLE_RATE
        var s: float = _shape(phase, shape) * _envelope(t, dur, shape)
        out[i] = s
    return _build_wav(out)

func _pulse(freq: float, dur: float) -> AudioStreamWAV:
    var sample_count := int(SAMPLE_RATE * dur)
    var out := PackedFloat32Array()
    out.resize(sample_count)
    for i in range(sample_count):
        var t: float = float(i) / SAMPLE_RATE
        # Two heartbeat thumps
        var thumps: float = max(_pulse_envelope(t, 0.0, 0.06), _pulse_envelope(t, 0.18, 0.06))
        var s: float = sin(t * freq * TAU) * thumps
        out[i] = s
    return _build_wav(out)

# ---- Wave-shape primitives ------------------------------------------------

func _render_tone(freq: float, dur: float, shape: String) -> PackedFloat32Array:
    var sample_count := int(SAMPLE_RATE * dur)
    var out := PackedFloat32Array()
    out.resize(sample_count)
    for i in range(sample_count):
        var t: float = float(i) / SAMPLE_RATE
        var s: float = _shape(t * freq, shape) * _envelope(t, dur, shape)
        out[i] = s
    return out

func _shape(phase_or_t: float, shape: String) -> float:
    match shape:
        "perc":    return sin(phase_or_t * TAU) + 0.3 * sin(phase_or_t * TAU * 2.0)
        "shimmer": return sin(phase_or_t * TAU) + 0.4 * sin(phase_or_t * TAU * 1.5) + 0.2 * sin(phase_or_t * TAU * 3.0)
        "growl":   return sin(phase_or_t * TAU) + 0.5 * sin(phase_or_t * TAU * 0.5)
        "swoosh":  return sin(phase_or_t * TAU) * 0.6 + (randf() - 0.5) * 0.4
        _:         return sin(phase_or_t * TAU)

func _envelope(t: float, dur: float, shape: String) -> float:
    var attack: float = 0.005
    var release: float = 0.4 * dur
    if shape == "perc":
        attack = 0.002
        release = 0.85 * dur
    elif shape == "shimmer":
        attack = 0.02
        release = 0.5 * dur
    elif shape == "growl":
        attack = 0.05
        release = 0.5 * dur
    if t < attack:
        return t / max(0.001, attack)
    if t > dur - release:
        return clamp((dur - t) / max(0.001, release), 0.0, 1.0)
    return 1.0

func _pulse_envelope(t: float, t0: float, dur: float) -> float:
    if t < t0 or t > t0 + dur:
        return 0.0
    var local: float = (t - t0) / dur
    return sin(local * PI)    # 0 → 1 → 0 over the pulse window

func _build_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
    var data := PackedByteArray()
    data.resize(samples.size() * 2)
    for i in range(samples.size()):
        var v: int = int(clamp(samples[i] * 0.7 * 32767.0, -32768.0, 32767.0))
        data[i * 2] = v & 0xff
        data[i * 2 + 1] = (v >> 8) & 0xff
    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = SAMPLE_RATE
    wav.stereo = false
    wav.data = data
    return wav
