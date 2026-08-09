## Project-context script parse gate.
##
## Loading scripts from a running project scene keeps autoloads and project
## class_name declarations available. This replaces the old file-by-file
## --check-only preflight, which could report false failures for valid scripts
## that depend on project context.
extends Node

var _failures: Array[String] = []

func _ready() -> void:
	print("==================================================")
	print(" Project-context script parse gate")
	print("==================================================")
	_scan_directory("res://src")
	_scan_directory("res://scenes")
	if _failures.is_empty():
		print("PARSE GATE PASSED: %d scripts loaded" % _script_count)
		get_tree().quit(0)
		return
	print("PARSE GATE FAILED: %d scripts could not load" % _failures.size())
	for failure in _failures:
		print("[FAIL] %s" % failure)
	get_tree().quit(1)

var _script_count := 0

func _scan_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		_failures.append("cannot open %s" % path)
		return
	var files := directory.get_files()
	files.sort()
	for file_name in files:
		if not file_name.ends_with(".gd"):
			continue
		var script_path := path.path_join(file_name)
		_script_count += 1
		var loaded = load(script_path)
		# Godot can return a non-null GDScript resource while reporting a parse
		# error. Check whether the script can instantiate so a broken script
		# cannot masquerade as a passing project-context parse.
		if loaded == null or (loaded is Script and not loaded.can_instantiate()):
			_failures.append(script_path)
	var directories := directory.get_directories()
	directories.sort()
	for directory_name in directories:
		_scan_directory(path.path_join(directory_name))
