## Audio Manager
## Autoloaded singleton for playing sound effects and music.
## Placeholder implementation — will be expanded when audio assets are added.
extends Node

## Audio bus names.
const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"

## SFX players pool (for overlapping sounds).
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 8

## Music player.
var _music_player: AudioStreamPlayer


func _ready() -> void:
	# Create SFX player pool
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = BUS_MASTER  # Will use SFX bus when audio buses are set up
		add_child(player)
		_sfx_players.append(player)

	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MASTER  # Will use Music bus
	add_child(_music_player)


## Play a sound effect by resource path.
func play_sfx(sfx_path: String, volume_db: float = 0.0) -> void:
	var stream := _load_audio(sfx_path)
	if stream == null:
		return

	# Find an available player
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return

	# All players busy — use the first one (interrupt oldest sound)
	_sfx_players[0].stream = stream
	_sfx_players[0].volume_db = volume_db
	_sfx_players[0].play()


## Play background music (loops).
func play_music(music_path: String, volume_db: float = -10.0) -> void:
	var stream := _load_audio(music_path)
	if stream == null:
		return

	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()


## Stop the current music.
func stop_music() -> void:
	_music_player.stop()


## Load an audio resource from path.
func _load_audio(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("[AudioManager] Audio file not found: %s" % path)
		return null
	return load(path) as AudioStream
