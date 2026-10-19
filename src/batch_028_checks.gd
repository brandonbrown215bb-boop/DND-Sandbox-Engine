class_name Batch028Checks
extends RefCounted

static func load_fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/batch_028/spells/one.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_028/spells/two.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_028/spells/renamed.json", "spell")
	DataLoader._load_json_file("res://data/fixtures/batch_028/classes/sequence.json", "class")
	DataLoader._load_json_file("res://data/fixtures/batch_028/items/draught.json", "item")


static func run(check: Callable) -> void:
	# Gameplay budgets/continuations are checked through real controls, not private helpers.
	var spell := {"id":"fixture:028_validation", "name":"Validation", "execution":"shared", "level":0, "casting_time":"action", "range":1, "target":"single", "effects":[{"type":"heal", "value":1}], "attack_unit_substitution":{"units":2}}
	check.call(SharedSpell.content_error(spell).is_empty(), "028 accepts declared two-unit Action spell syntax")
	for quantity in [0, 3, 1.5, "1"]:
		var invalid: Dictionary = spell.duplicate(true)
		invalid.attack_unit_substitution.units = quantity
		check.call(not SharedSpell.content_error(invalid).is_empty(), "028 rejects malformed unit count " + str(quantity))
	spell.casting_time = "bonus_action"
	check.call(not SharedSpell.content_error(spell).is_empty(), "028 refuses Bonus Action spells as strike substitutions")
	load_fixtures()
	var parent: Dictionary = DataLoader.classes["fixture:028_class"].features_by_level["1"][0].duplicate(true)
	check.call(CombatChildActions.content_error(parent).is_empty(), "028 loaded parent declaration validates")
	parent.child_actions.children[0].kind = "nested_parent"
	check.call(not CombatChildActions.content_error(parent).is_empty(), "028 unsupported child kinds refuse before parent payment")
	DataLoader.load_all_data()
