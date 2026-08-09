## Bounded project boot gate.
## Instantiates the production main scene, watches it for a short settle period,
## and exits with an explicit marker so a runner cannot confuse a timeout with
## a successful boot.
extends Node

@export var settle_seconds := 3.0

func _ready() -> void:
	# Keep the boot supervisor alive while the production bootstrapper runs. The
	# normal game still transitions to the main menu when test_mode is false.
	GameManager.test_mode = true
	var main_scene := load("res://scenes/main.tscn")
	if main_scene == null:
		print("BOOT GATE FAILED: main scene could not load")
		get_tree().quit(1)
		return
	var main_instance: Node = main_scene.instantiate()
	add_child(main_instance)
	await get_tree().create_timer(settle_seconds).timeout
	print("BOOT GATE PASSED: main scene settled for %.1f seconds" % settle_seconds)
	get_tree().quit(0)
