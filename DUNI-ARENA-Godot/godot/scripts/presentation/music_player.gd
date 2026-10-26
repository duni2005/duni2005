class_name BackgroundMusic
extends Node
## Background music (autoload MusicPlayer; call the static helpers from anywhere): one track at
## a time. Every change crossfades, and each track crossfades into its own start shortly before
## it ends, so neither a switch nor a restart ever cuts. The tower theme picks up where it
## stopped. A loading screen fades the music out and holds requests until it is done.
const TRACKS := {
	&"menu":"res://assets/audio/music/lobby_chill_plucks.ogg",
	&"tower":"res://assets/audio/music/ready_to_play.ogg",
	&"battle":"res://assets/audio/music/decisive_button_battle_protocol.ogg",
	&"victory":"res://assets/audio/music/victory_chiptune.ogg",
	&"defeat":"res://assets/audio/music/deeper_shade_of_defeat.ogg",
}
## Tracks that resume from where they were stopped instead of starting over.
const RESUME := [&"tower"]
## Seconds of crossfade between two tracks, from silence at start, into a track's own start,
## of silence-first fade-out before the victory / defeat music, and out when a loading screen opens.
const CHANGE_FADE: float = 1.2
const START_FADE: float = .5
const LOOP_FADE: float = 2.5
const RESULT_FADE: float = 2.0
const LOADING_FADE: float = .9
const VOLUME_DB: float = -6.0
var players: Array[AudioStreamPlayer] = []
var active: int = 0
var current: StringName = &""
var tweens: Array = [null, null]
var positions: Dictionary = {}
var held: bool = false
var pending: StringName = &""
## A track waiting for the previous one to fade out completely (victory / defeat).
var delayed: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var player := AudioStreamPlayer.new();player.volume_db = -80;add_child(player);players.append(player)

static func _node() -> BackgroundMusic:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("MusicPlayer") if tree != null else null
## Switches to `track` (menu / tower / battle / victory / defeat). Asking for the playing track
## keeps it going. `fade` overrides the crossfade length.
static func play(track: StringName, fade: float = -1) -> void:
	var node := _node()
	if node != null:node.switch_to(track, fade)
## Fades the current music out completely, then starts `track` (victory / defeat after battle).
static func play_after_silence(track: StringName, out_time: float = RESULT_FADE) -> void:
	var node := _node()
	if node != null:node.switch_after(track, out_time)
## Fades the music out and holds further requests (loading screens).
static func hold() -> void:
	var node := _node()
	if node != null:node.fade_out(LOADING_FADE);node.held = true
## Ends a hold: the last track asked for during it starts now.
static func release() -> void:
	var node := _node()
	if node == null:return
	node.held = false
	var track: StringName = node.pending
	node.pending = &""
	if track != &"":node.switch_to(track)
## Forgets where a resuming track stopped, so it starts from the top next time.
static func reset(track: StringName) -> void:
	var node := _node()
	if node != null:node.positions.erase(track)

func switch_to(track: StringName, fade: float = -1) -> void:
	if held:pending = track;return
	if track == current or not TRACKS.has(track):return
	if delayed != null:delayed.kill();delayed = null
	_remember()
	var first: bool = current == &"" and not players.any(func(p):return p.playing)
	current = track
	_crossfade(load(TRACKS[track]), fade if fade > 0 else START_FADE if first else CHANGE_FADE, float(positions.get(track, 0.0)) if track in RESUME else 0.0)

func switch_after(track: StringName, out_time: float) -> void:
	if held:pending = track;return
	if track == current or not TRACKS.has(track):return
	if delayed != null:delayed.kill()
	_remember()
	current = track
	for i in range(2):_fade(i, 0, out_time, true)
	delayed = create_tween();delayed.tween_interval(out_time)
	delayed.tween_callback(func():delayed = null;_crossfade(load(TRACKS[track]), START_FADE))

func fade_out(time: float = CHANGE_FADE) -> void:
	if delayed != null:delayed.kill();delayed = null
	_remember()
	current = &""
	for i in range(2):_fade(i, 0, time, true)

func _remember() -> void:
	var player: AudioStreamPlayer = players[active] if not players.is_empty() else null
	if current in RESUME and player != null and player.playing:positions[current] = player.get_playback_position()

func _process(_delta: float) -> void:
	var player: AudioStreamPlayer = players[active] if not players.is_empty() else null
	if current == &"" or player == null or not player.playing or player.stream == null:return
	if player.stream.get_length() - player.get_playback_position() <= LOOP_FADE:_crossfade(player.stream, LOOP_FADE)

func _crossfade(stream: AudioStream, time: float, from: float = 0) -> void:
	_fade(active, 0, time, true)
	active = 1 - active
	var player: AudioStreamPlayer = players[active]
	if tweens[active] != null:tweens[active].kill()
	player.stream = stream;player.volume_db = -80;player.play(from)
	_fade(active, 1, time, false)

func _fade(index: int, to: float, time: float, stop_after: bool) -> void:
	if tweens[index] != null:tweens[index].kill()
	var player: AudioStreamPlayer = players[index]
	if not player.playing:return
	var from: float = db_to_linear(player.volume_db) / db_to_linear(VOLUME_DB)
	var tween := create_tween()
	tween.tween_method(func(v: float):player.volume_db = linear_to_db(maxf(v, .0001)) + VOLUME_DB, minf(from, 1), to, time)
	if stop_after:tween.tween_callback(player.stop)
	tweens[index] = tween
