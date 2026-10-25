class_name Batch079Controls
extends RefCounted
## Batch 079 (#43 follow-up): max-HP stacking policy through the real spell
## resolver on party characters, a real SaveManager save/load, a legacy source
## record in the same save, and batch_079_max_hp_stacking_reload in a fresh process.

const SLOT := "batch_079_max_hp_stacking"
const IDS := "user://batch_079_ids.txt"

static func run(h: Node) -> void:
	h._enter_test("batch_079_max_hp_stacking_flow")
	h._setup_world()
	Batch079Checks.load_fixtures()
	var alice: Character = PlayerManager.get_player(0).get("character")
	var bob: Character = PlayerManager.get_player(1).get("character")
	var caster := bob
	bob.spell_slots["1"] = 4
	alice.max_hp_sources.clear()
	var base := alice.max_hp
	alice.current_hp = maxi(1, base - 10)
	var hurt := alice.current_hp
	var r1 := Batch071Checks.cast(caster, alice, Batch079Checks.LOW)
	h._assert(r1.get("success", false) and alice.max_hp == base + 3 and alice.current_hp == hurt + 3, "079 live weak casting +3 (%d/%d)" % [alice.current_hp, alice.max_hp])
	var r2 := Batch071Checks.cast(caster, alice, Batch079Checks.HIGH)
	h._assert(r2.get("success", false) and alice.max_hp == base + 7 and alice.current_hp == hurt + 7, "079 live stronger casting replaces it; current rises only by the net +4 (%d/%d)" % [alice.current_hp, alice.max_hp])
	var r3 := Batch071Checks.cast(caster, alice, Batch079Checks.HIGH)
	var active: Dictionary = alice.max_hp_sources.get(str(r3.get("_source", "")), {})
	h._assert(alice.max_hp == base + 7 and int(active.get("applied", 0)) == 7, "079 live equal-strength recast: newest is the active source (%s, max %d)" % [str(r3.get("message", r3.get("success", ""))), alice.max_hp])
	Batch071Checks.cast(caster, alice, Batch079Checks.OTHER)
	h._assert(alice.max_hp == base + 9, "079 live same display name, different source id still applies (+2)")
	# Legacy record (pre-079: no combine, no order) on bob.
	bob.max_hp_sources.clear()
	var bdto := bob.to_dict()
	var bbase := int(bdto.max_hp)
	bdto.max_hp = bbase - 4
	bdto.current_hp = mini(int(bdto.current_hp), bbase - 4)
	bdto["max_hp_sources"] = {"legacy:a": {"rule_id": "legacy", "kind": "reduction", "requested": 2, "applied": -2, "accumulate": false, "floor": 1, "cure_on": [], "periodic": {}, "raise_current": false}, "legacy:b": {"rule_id": "legacy", "kind": "reduction", "requested": 2, "applied": -2, "accumulate": false, "floor": 1, "cure_on": [], "periodic": {}, "raise_current": false}}
	bob.from_dict(bdto)
	h._assert(bob.max_hp == bbase - 4 and bob.max_hp_sources.size() == 2, "079 legacy record installs on bob")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "079 real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		var na: Character = PartyManager.characters.get(alice.character_id, null)
		var nb: Character = PartyManager.characters.get(bob.character_id, null)
		h._assert(loaded and na != null and na.max_hp == base + 9 and na.current_hp == hurt + 9 and nb != null and nb.max_hp == bbase - 4, "079 real load keeps stacking and the legacy record")
		var f := FileAccess.open(IDS, FileAccess.WRITE)
		f.store_string("%s|%d|%d|%s|%d" % [alice.character_id, base, hurt, bob.character_id, bbase])
		f.close()
	h._exit_test()

static func reload(h: Node) -> void:
	h._enter_test("batch_079_max_hp_stacking_reload")
	Batch079Checks.load_fixtures()
	var p := FileAccess.get_file_as_string(IDS).strip_edges().split("|")
	var loaded := SaveManager.load_game(SLOT)
	var na: Character = PartyManager.characters.get(p[0], null) if p.size() == 5 else null
	var nb: Character = PartyManager.characters.get(p[3], null) if p.size() == 5 else null
	h._assert(loaded and na != null and na.max_hp == int(p[1]) + 9 and na.current_hp == int(p[2]) + 9, "079 fresh process: stacking rebuilt once (+9)")
	h._assert(nb != null and nb.max_hp == int(p[4]) - 4 and MaxHpSourceRules.saved_error(nb.to_dict()).is_empty(), "079 fresh process: legacy save loads and validates")
	if na != null:
		for source in SpellEffects.records(na).keys():
			if SpellEffects.records(na)[source].has("max_hp_source"): SpellEffects.remove(na, source, "expired")
		h._assert(na.max_hp == int(p[1]) and na.max_hp_sources.is_empty(), "079 fresh process: ending every casting restores the base maximum")
	if nb != null:
		MaxHpSourceRules.remove(nb, "legacy:a")
		h._assert(nb.max_hp == int(p[4]) - 2, "079 fresh process: legacy sources still sum and revert independently")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	h._exit_test()
