class_name BackgroundMusic
extends Node
## Background music (autoload MusicPlayer; call BackgroundMusic.play from anywhere): one track at a time. Every change crossfades, and
## each track crossfades into its own start shortly before it ends, so neither a switch nor
## a restart ever cuts.
const TRACKS := {
	&"menu":"res://assets/audio/music/lobby_chill_plucks.ogg",
	&"tower":"res://assets/audio/music/ready_to_play.ogg",
	&"battle":"res://assets/audio/music/decisive_button_battle_protocol.ogg",
}
## Seconds of crossfade between two tracks, from silence at start, and into a track's own start.
const CHANGE_FADE: float = 1.2
const START_FADE: float = .5
const LOOP_FADE: float = 2.5
const VOLUME_DB: float = -6.0
var players: Array[AudioStreamPlayer] = []
var active: int = 0
var current: StringName = &""
var tweens: Array = [null, null]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var player := AudioStreamPlayer.new();player.volume_db = -80;add_child(player);players.append(player)

## Switches to `track` (menu / tower / battle). Asking for the playing track keeps it going.
static func play(track: StringName) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var node: BackgroundMusic = tree.root.get_node_or_null("MusicPlayer") if tree != null else null
	if node != null:node.switch_to(track)
func switch_to(track: StringName) -> void:
	if track == current or not TRACKS.has(track):return
	var first: bool = current == &""
	current = track
	_crossfade(load(TRACKS[track]), START_FADE if first else CHANGE_FADE)

func stop() -> void:
	current = &""
	for i in range(2):_fade(i, 0, CHANGE_FADE, true)

func _process(_delta: float) -> void:
	var player: AudioStreamPlayer = players[active] if not players.is_empty() else null
	if current == &"" or player == null or not player.playing or player.stream == null:return
	if player.stream.get_length() - player.get_playback_position() <= LOOP_FADE:_crossfade(player.stream, LOOP_FADE)

func _crossfade(stream: AudioStream, time: float) -> void:
	_fade(active, 0, time, true)
	active = 1 - active
	var player: AudioStreamPlayer = players[active]
	player.stream = stream;player.volume_db = -80;player.play()
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
