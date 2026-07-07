## Settings Manager (Autoload)
## Persistent player settings + the save/load-anywhere API used by the settings
## overlay. Settings are written to user://settings.cfg (JSON) so they survive
## between sessions. Save/Load game calls delegate to SaveManager.
##
## Pause: open_settings() pauses the tree (get_tree().paused = true) so the
## overlay freezes gameplay underneath; close_settings() resumes it. The overlay
## itself lives on a high CanvasLayer and is excluded from pausing.
extends Node

signal settings_opened
signal settings_closed

const SETTINGS_PATH := "user://settings.cfg"

# Persisted settings (typical video-game options).
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var screen_shake: bool = true
var high_contrast: bool = false
var show_damage_numbers: bool = true
var tooltip_delay: float = 0.5

var _overlay: CanvasLayer = null


func _ready() -> void:
	load_settings()


## ---- Persisted settings ----

func save_settings() -> void:
	var data := {
		"master_volume": master_volume,
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
		"screen_shake": screen_shake,
		"high_contrast": high_contrast,
		"show_damage_numbers": show_damage_numbers,
		"tooltip_delay": tooltip_delay,
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("[Settings] Could not write settings file")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_apply_to_audio()
	print("[Settings] Saved settings.")


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("[Settings] Corrupt settings file, using defaults")
		return
	var data: Dictionary = json.data
	master_volume = float(data.get("master_volume", 1.0))
	sfx_volume = float(data.get("sfx_volume", 1.0))
	music_volume = float(data.get("music_volume", 1.0))
	screen_shake = bool(data.get("screen_shake", true))
	high_contrast = bool(data.get("high_contrast", false))
	show_damage_numbers = bool(data.get("show_damage_numbers", true))
	tooltip_delay = float(data.get("tooltip_delay", 0.5))
	_apply_to_audio()


func _apply_to_audio() -> void:
	if AudioManager == null:
		return
	# AudioManager buses default to Master; nudge volumes when audio assets exist.
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(master_volume, 0.001)))
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(maxf(sfx_volume, 0.001)))
	var mus_idx := AudioServer.get_bus_index("Music")
	if mus_idx >= 0:
		AudioServer.set_bus_volume_db(mus_idx, linear_to_db(maxf(music_volume, 0.001)))


## ---- Save / Load anywhere ----

## Save the current game to a named slot (defaults to manual quicksave).
## Returns true on success. Requires an in-progress game.
func save_game(slot: String = "quicksave") -> bool:
	if not GameManager.game_in_progress:
		push_warning("[Settings] No game in progress; cannot save.")
		return false
	return SaveManager.save_game(slot)


## Load a game from a named slot. Returns true on success.
func load_game(slot: String) -> bool:
	return SaveManager.load_game(slot)


func get_saves() -> Array[String]:
	return SaveManager.get_available_saves()


## ---- Settings overlay / pause ----

## Open the settings overlay. Pauses the tree so gameplay freezes behind it.
## safe_caller is the node requesting open (used to log context); optional.
func open_settings(_caller: Node = null) -> void:
	if _overlay != null:
		return
	var overlay_scene := load("res://scenes/ui/settings_overlay.tscn")
	if overlay_scene == null:
		push_error("[Settings] settings_overlay.tscn not found")
		return
	_overlay = overlay_scene.instantiate()
	get_tree().root.add_child(_overlay)
	get_tree().paused = true
	settings_opened.emit()


## Close the overlay and resume the tree.
func close_settings() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	if get_tree().paused:
		get_tree().paused = false
	settings_closed.emit()


## True while the settings overlay is open.
func is_open() -> bool:
	return _overlay != null
