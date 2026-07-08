class_name DungeonHUD
extends OverworldHUD

## Rook's Touch: the dungeon gets its own HUD identity instead of borrowing
## the overworld HUD and hiding a button. Same node layout as OverworldHUD
## (so dungeon_state / harness refs stay valid), but tuned for crawl context:
## no turn-based End Turn, a dungeon-context banner instead.

@onready var _context_banner: Label = $MarginContainer/HBoxContainer/MainArea/Header/MarginContainer/VBoxContainer/ObjectiveLabel

func _ready() -> void:
	super()
	# Dungeons aren't turn-based; the party moves as one. Hide the overworld
	# End Turn control rather than reusing it.
	if btn_end_turn != null:
		btn_end_turn.visible = false
	if _context_banner != null:
		_context_banner.text = "Dungeon: explore room by room. Click a lit room to move."
