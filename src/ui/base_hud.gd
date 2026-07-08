## BaseHUD — shared foundation for all gameplay HUDs.
## Owns the system-button signals (Rest / Save / Menu / Settings / Sheet) and
## the log plumbing so Combat / Overworld / Dungeon share one implementation
## and one contract. The dungeon deliberately does NOT get end_turn_pressed —
## it is not turn-based, so it must not inherit a turn-based End Turn affordance.
##
## Pattern H from UI_OVERHAUL_RESEARCH.md. Replaces the old
## "DungeonHUD extends OverworldHUD and hides btn_end_turn" smell with a real
## shared base class.
class_name BaseHUD
extends CanvasLayer

## System-row signals shared by every mode.
signal rest_pressed
signal save_pressed
signal menu_pressed
signal settings_pressed
signal sheet_pressed

## Set by each subclass in _ready to its own log RichTextLabel.
var log_text: RichTextLabel

## Clear the log panel.
func clear_logs() -> void:
	if log_text != null:
		log_text.text = ""

## Append a line to the log and auto-scroll.
func add_log(msg: String) -> void:
	if log_text == null:
		return
	log_text.text += msg + "\n"
	var scroll = log_text.get_v_scroll_bar()
	if scroll:
		scroll.value = scroll.max_value
