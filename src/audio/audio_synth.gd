class_name AudioSynth
extends RefCounted

const SAMPLE_RATE: int = 22050


static func _make_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
    var count: int = samples.size()
    var bytes := PackedByteArray()
    bytes.resize(count * 2)

    for i in range(count):
        var s16: int = clampi(int(round(samples[i] * 32767.0)), -32768, 32767)
        if s16 < 0:
            s16 += 65536
        bytes[i * 2] = s16 & 0xFF
        bytes[i * 2 + 1] = (s16 >> 8) & 0xFF

    var wav := AudioStreamWAV.new()
    wav.format = AudioStreamWAV.FORMAT_16_BITS
    wav.mix_rate = SAMPLE_RATE
    wav.stereo = false
    wav.data = bytes
    if loop:
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        wav.loop_begin = 0
        wav.loop_end = count
    else:
        wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
    return wav


static func create_engine_loop() -> AudioStreamWAV:
    # Seamless single-cylinder motorcycle pulse loop (~88 Hz fundamental, 4 cycles)
    var base_freq: float = 88.0
    var count: int = int(round(float(SAMPLE_RATE) * 4.0 / base_freq))
    var samples := PackedFloat32Array()
    samples.resize(count)

    for i in range(count):
        var phase: float = TAU * 4.0 * float(i) / float(count)
        var s: float = (
            0.48 * sin(phase)
            + 0.28 * sin(phase * 2.0)
            + 0.14 * sin(phase * 3.0)
            + 0.08 * sin(phase * 4.0)
        )
        samples[i] = clampf(s * 0.55, -0.95, 0.95)

    return _make_wav(samples, true)


static func create_brake_loop() -> AudioStreamWAV:
    # Seamless filtered tire/pad friction loop (0.2s)
    var count: int = int(float(SAMPLE_RATE) * 0.2)
    var samples := PackedFloat32Array()
    samples.resize(count)
    var rng := RandomNumberGenerator.new()
    rng.seed = 4072

    for i in range(count):
        var t: float = float(i) / float(count)
        var screech: float = sin(TAU * 42.0 * t) * 0.25 + sin(TAU * 67.0 * t) * 0.15
        var grit: float = rng.randf_range(-0.35, 0.35)
        samples[i] = clampf((screech + grit) * 0.45, -0.9, 0.9)

    return _make_wav(samples, true)


static func create_menu_music_loop() -> AudioStreamWAV:
    # Subtle urban synth bass & pad loop (1.6s seamless)
    var duration: float = 1.6
    var count: int = int(float(SAMPLE_RATE) * duration)
    var samples := PackedFloat32Array()
    samples.resize(count)
    var notes: Array[float] = [110.0, 130.81, 146.83, 130.81]

    for i in range(count):
        var t: float = float(i) / float(SAMPLE_RATE)
        var step_idx: int = mini(notes.size() - 1, int(floor(t / 0.4)))
        var local_t: float = fmod(t, 0.4)
        var env: float = minf(1.0, local_t / 0.03) * exp(-local_t * 3.5)
        var freq: float = notes[step_idx]
        var bass: float = sin(TAU * freq * t) * 0.35 + sin(TAU * freq * 2.0 * t) * 0.12
        var pad: float = sin(TAU * 220.0 * t) * 0.08
        samples[i] = clampf(bass * env + pad, -0.8, 0.8)

    return _make_wav(samples, true)


static func create_reward_sfx() -> AudioStreamWAV:
    var count: int = int(float(SAMPLE_RATE) * 0.24)
    var samples := PackedFloat32Array()
    samples.resize(count)

    for i in range(count):
        var t: float = float(i) / float(SAMPLE_RATE)
        var freq: float = 660.0 if t < 0.11 else 880.0
        var env: float = exp(-t * 10.0)
        samples[i] = clampf((sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 1.5 * t)) * env * 0.5, -0.9, 0.9)

    return _make_wav(samples, false)


static func create_shift_sfx() -> AudioStreamWAV:
    var count: int = int(float(SAMPLE_RATE) * 0.08)
    var samples := PackedFloat32Array()
    samples.resize(count)

    for i in range(count):
        var t: float = float(i) / float(SAMPLE_RATE)
        var env: float = exp(-t * 38.0)
        samples[i] = clampf(sin(TAU * 240.0 * t) * env * 0.65, -0.9, 0.9)

    return _make_wav(samples, false)


static func create_transition_sfx() -> AudioStreamWAV:
    var count: int = int(float(SAMPLE_RATE) * 0.32)
    var samples := PackedFloat32Array()
    samples.resize(count)

    for i in range(count):
        var t: float = float(i) / float(SAMPLE_RATE)
        var p: float = t / 0.32
        var freq: float = lerpf(220.0, 520.0, p)
        var env: float = sin(PI * p) * 0.45
        samples[i] = clampf(sin(TAU * freq * t) * env, -0.9, 0.9)

    return _make_wav(samples, false)


static func create_collision_sfx() -> AudioStreamWAV:
    var count: int = int(float(SAMPLE_RATE) * 0.22)
    var samples := PackedFloat32Array()
    samples.resize(count)
    var rng := RandomNumberGenerator.new()
    rng.seed = 9001

    for i in range(count):
        var t: float = float(i) / float(SAMPLE_RATE)
        var env: float = exp(-t * 16.0)
        var thud: float = sin(TAU * lerpf(130.0, 45.0, t / 0.22) * t) * 0.6
        var crunch: float = rng.randf_range(-0.4, 0.4)
        samples[i] = clampf((thud + crunch) * env * 0.7, -0.95, 0.95)

    return _make_wav(samples, false)


static func create_ui_click_sfx() -> AudioStreamWAV:
    var count: int = int(float(SAMPLE_RATE) * 0.05)
    var samples := PackedFloat32Array()
    samples.resize(count)

    for i in range(count):
        var t: float = float(i) / float(SAMPLE_RATE)
        var env: float = exp(-t * 55.0)
        samples[i] = clampf(sin(TAU * 780.0 * t) * env * 0.5, -0.9, 0.9)

    return _make_wav(samples, false)
