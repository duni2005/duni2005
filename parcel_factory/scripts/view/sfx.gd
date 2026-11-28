extends Node
## 효과음 자리. assets/sfx/<이름>.wav (또는 .ogg)가 있으면 그 소리를, 없으면 fallback(코드로 만든 소리)을,
## 그것도 없으면 무음이에요. 이름: button(버튼) · place(설치 '착') · break(철거) · tick(칸 이동 '틱')
## main.sfx 하나를 모두 같이 써요. 게임 상태는 바꾸지 않아요.

const DIR := "res://assets/sfx/"
const VOICES := 6               # 동시에 날 수 있는 소리 수

var _players: Array = []
var _cache := {}                # 이름 -> AudioStream 또는 null
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sfx_name: String, fallback: AudioStream = null, volume_db := -6.0) -> void:
	var s: AudioStream = _load(sfx_name)
	if s == null:
		s = fallback
	if s == null:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = s
	p.volume_db = volume_db
	p.play()


func _load(sfx_name: String) -> AudioStream:
	if _cache.has(sfx_name):
		return _cache[sfx_name]
	var s: AudioStream = null
	for ext in [".wav", ".ogg"]:
		if ResourceLoader.exists(DIR + sfx_name + ext):
			s = load(DIR + sfx_name + ext)
			break
	_cache[sfx_name] = s
	return s


static func tone(sec: float, freq: float, noise: float, decay: float, seed_ := 7) -> AudioStreamWAV:
	## 짧은 효과음 만들기: 낮은 퉁 소리(freq) + 잡음(noise)이 decay 빠르기로 사라져요 (16비트)
	var rate := 22050
	var n := int(rate * sec)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	for i in n:
		var t := float(i) / rate
		var v := (rng.randf_range(-1.0, 1.0) * noise + sin(TAU * freq * t) * 0.8) * exp(-t * decay)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w
