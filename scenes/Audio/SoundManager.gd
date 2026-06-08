extends Node
## SoundManager (Autoload singleton - Fase 7)
##
## Gestione centralizzata dell'audio industriale del simulatore. Tutti i suoni
## sono GENERATI PROCEDURALMENTE in PCM 16-bit (AudioStreamWAV) al primo avvio:
## nessun file audio nel progetto, nessuna dipendenza esterna.
##
## Layer:
##   - belt_hum     : ronzio motore del nastro, loop continuo a basso volume.
##                    Si abbassa (non si spegne) quando il nastro e' fermo.
##   - click        : click meccanico tastiera a membrana (APPROVA/RESPINGI).
##   - alert_beep   : tono acuto 880Hz per THREAT MISSED (riprodotto 3 volte).
##   - confirm_beep : tono grave 440Hz per CLEARED / THREAT IDENTIFIED.
##   - spawn_thud   : impatto morbido all'arrivo di un nuovo bagaglio.

const SAMPLE_RATE: int = 22050

# Volume (dB) del ronzio a nastro in moto e fermo: da fermo resta udibile.
const HUM_DB_RUNNING: float = -16.0
const HUM_DB_IDLE: float = -28.0

var _hum_player: AudioStreamPlayer
var _click: AudioStreamWAV
var _alert: AudioStreamWAV
var _confirm: AudioStreamWAV
var _spawn: AudioStreamWAV

# Pool di player per suoni one-shot sovrapponibili.
var _oneshot_pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0


func _ready() -> void:
	# Ronzio del nastro: stream in loop su un player dedicato.
	_hum_player = AudioStreamPlayer.new()
	_hum_player.stream = _make_belt_hum()
	_hum_player.volume_db = HUM_DB_RUNNING
	add_child(_hum_player)
	_hum_player.play()

	# One-shot precomputati.
	_click = _make_click()
	_alert = _make_tone(880.0, 0.3, 0.5)
	_confirm = _make_tone(440.0, 0.2, 0.5)
	_spawn = _make_thud()

	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_oneshot_pool.append(p)


# --- API pubblica ------------------------------------------------------------

## Alza/abbassa il ronzio in base allo stato del nastro (senza mai spegnerlo).
func set_belt_running(running: bool) -> void:
	if _hum_player != null:
		_hum_player.volume_db = HUM_DB_RUNNING if running else HUM_DB_IDLE


func play_click() -> void:
	_play(_click, -6.0)


func play_confirm() -> void:
	_play(_confirm, -8.0)


func play_spawn() -> void:
	_play(_spawn, -12.0)


## Tre beep acuti in sequenza (~0.36s) sincronizzati col lampeggio THREAT MISSED.
func play_threat_missed() -> void:
	_play(_alert, -5.0)
	for i in range(1, 3):
		var t := get_tree().create_timer(0.36 * i)
		t.timeout.connect(func(): _play(_alert, -5.0))


# --- Helper di riproduzione --------------------------------------------------

func _play(stream: AudioStreamWAV, db: float) -> void:
	if stream == null:
		return
	var p := _oneshot_pool[_pool_index]
	_pool_index = (_pool_index + 1) % _oneshot_pool.size()
	p.stream = stream
	p.volume_db = db
	p.play()


# --- Generazione procedurale dei suoni --------------------------------------

## Costruisce un AudioStreamWAV 16-bit mono da un array di campioni in [-1, 1].
func _wav_from_samples(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Ronzio del nastro: 60Hz + 120Hz con leggera modulazione d'ampiezza a 4Hz.
## Finestra di 1.0s con frequenze intere -> loop perfettamente continuo.
func _make_belt_hum() -> AudioStreamWAV:
	var count := SAMPLE_RATE # 1 secondo esatto
	var s := PackedFloat32Array()
	s.resize(count)
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var am := 1.0 + 0.15 * sin(TAU * 4.0 * t)
		var v := 0.55 * sin(TAU * 60.0 * t) + 0.30 * sin(TAU * 120.0 * t)
		v += 0.04 * (randf() * 2.0 - 1.0) # un filo di rumore meccanico
		s[i] = v * am * 0.6
	return _wav_from_samples(s, true)


## Tono con inviluppo attack/decay morbido (per beep di allerta/conferma).
func _make_tone(freq: float, duration: float, amp: float) -> AudioStreamWAV:
	var count := int(duration * SAMPLE_RATE)
	var s := PackedFloat32Array()
	s.resize(count)
	var attack := int(0.01 * SAMPLE_RATE)
	var release := int(0.06 * SAMPLE_RATE)
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var env := 1.0
		if i < attack:
			env = float(i) / attack
		elif i > count - release:
			env = float(count - i) / release
		s[i] = sin(TAU * freq * t) * amp * env
	return _wav_from_samples(s)


## Click meccanico: brevissimo burst di rumore con decadimento rapido.
func _make_click() -> AudioStreamWAV:
	var count := int(0.06 * SAMPLE_RATE)
	var s := PackedFloat32Array()
	s.resize(count)
	for i in count:
		var env := pow(1.0 - float(i) / count, 4.0)
		s[i] = (randf() * 2.0 - 1.0) * 0.6 * env
	return _wav_from_samples(s)


## Impatto morbido (spawn bagaglio): seno grave 90Hz con decadimento + tonfo.
func _make_thud() -> AudioStreamWAV:
	var count := int(0.18 * SAMPLE_RATE)
	var s := PackedFloat32Array()
	s.resize(count)
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var env := pow(1.0 - float(i) / count, 2.5)
		var v := sin(TAU * 90.0 * t) * 0.8 + (randf() * 2.0 - 1.0) * 0.15
		s[i] = v * env
	return _wav_from_samples(s)
