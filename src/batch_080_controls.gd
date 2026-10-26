class_name Batch080Controls
extends RefCounted
## Batch 080 (#44 follow-up): per-item last-charge outcomes on party characters.
## Staff of Power copy A spends its last charge without the failure face (0
## charges, keeps everything); copy B fails (keeps only its +2 weapon bonus).
## Another character's Staff of Striking fails and becomes nonmagical. Real
## attacks read the exact equipped copy; real SaveManager save/load and the
## batch_080_last_charge_text_reload fresh process keep each outcome.

const SLOT := "batch_080_last_charge_text"
const IDS := "user://batch_080_ids.txt"

static func _wield(c: Character, copy: String) -> void:
	c.inventory.equip_instance(Inventory.Slot.WEAPON, copy)

static func _state(h: Node, a: Character, b: Character, ids: Array, label: String) -> void:
	_wield(b, ids[1])
	var kept := Batch080Checks.bonus(b, Batch080Checks.POWER)
	var kept_hit := Batch080Checks.hit_bonus(b, Batch080Checks.POWER)
	var ac_a := SourceBenefitRules.total(b, "AC")
	_wield(b, ids[2])
	var failed := Batch080Checks.bonus(b, Batch080Checks.POWER)
	var failed_hit := Batch080Checks.hit_bonus(b, Batch080Checks.POWER)
	var ac_b := SourceBenefitRules.total(b, "AC")
	var striking := Batch080Checks.bonus(a, Batch080Checks.STRIKING)
	var striking_hit := Batch080Checks.hit_bonus(a, Batch080Checks.STRIKING)
	h._assert(int(b.inventory.get_instance(ids[1]).state.charges) == 0 and kept.attack == 2 and kept_hit == 2 and ac_a == 2, "080 %s: Power copy A at 0 charges with no failure keeps +2 and AC +2 (hit %d, AC %d)" % [label, kept_hit, ac_a])
	h._assert(failed.attack == 2 and failed.magical and failed_hit == 2 and ac_b == 0, "080 %s: Power copy B after its failure keeps +2 weapon bonus only (hit %d, AC %d)" % [label, failed_hit, ac_b])
	h._assert(not striking.magical and striking.attack == 0 and striking_hit == 0 and str(a.inventory.get_instance(ids[3]).definition_id) == Batch080Checks.STRIKING, "080 %s: Staff of Striking is a nonmagical quarterstaff copy (hit bonus %d)" % [label, striking_hit])

static func run(h: Node) -> void:
	h._enter_test("batch_080_last_charge_text_flow")
	h._setup_world()
	Batch080Checks.load_fixtures()
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var pa := Batch041Checks.add_copy(b, Batch080Checks.POWER)
	var pb := Batch041Checks.add_copy(b, Batch080Checks.POWER)
	var st := Batch041Checks.add_copy(a, Batch080Checks.STRIKING)
	for pair in [[b, pa], [b, pb], [a, st]]:
		(pair[0] as Character).inventory.attune_instance(pair[1], (pair[0] as Character).character_id)
	_wield(b, pa)
	_wield(a, st)
	h._assert(Batch080Checks.hit_bonus(b, Batch080Checks.POWER) == 2 and Batch080Checks.hit_bonus(a, Batch080Checks.STRIKING) == 3, "080 actual attuned staffs add +2 / +3 on real attacks")
	var ra := Batch080Checks.drain(b, pa, 7)
	_wield(b, pb)
	var rb := Batch080Checks.drain(b, pb, 1)
	var rs := Batch080Checks.drain(a, st, 1)
	h._assert(not ra.get("triggered", true) and rb.get("kept_properties", []) == ["weapon_bonus"] and rs.get("nonmagical", false), "080 actual receipts follow each item's text (A=%s B=%s S=%s)" % [str(ra), str(rb), str(rs)])
	var ids := [b.character_id, pa, pb, st, a.character_id]
	_state(h, a, b, ids, "live")
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(SLOT)
	h._assert(saved, "080 actual real save (block='%s')" % block)
	if saved:
		var loaded := SaveManager.load_game(SLOT)
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		var na: Character = PartyManager.characters.get(a.character_id, null)
		h._assert(loaded and nb != null and na != null and nb != b, "080 actual real load")
		if loaded and nb != null and na != null: _state(h, na, nb, ids, "loaded")
		var f := FileAccess.open(IDS, FileAccess.WRITE)
		f.store_string("|".join(ids))
		f.close()
	h._exit_test()

static func reload(h: Node) -> void:
	h._enter_test("batch_080_last_charge_text_reload")
	Batch080Checks.load_fixtures()
	var p := FileAccess.get_file_as_string(IDS).strip_edges().split("|")
	var loaded := SaveManager.load_game(SLOT)
	var nb: Character = PartyManager.characters.get(p[0], null) if p.size() == 5 else null
	var na: Character = PartyManager.characters.get(p[4], null) if p.size() == 5 else null
	h._assert(loaded and nb != null and na != null, "080 fresh process loads the save")
	if nb != null and na != null:
		_state(h, na, nb, Array(p), "fresh process")
		nb.inventory.recover_daily_charges()
		na.inventory.recover_daily_charges()
		h._assert(int(nb.inventory.get_instance(p[1]).state.charges) > 0 and int(nb.inventory.get_instance(p[2]).state.charges) == 0 and int(na.inventory.get_instance(p[3]).state.charges) == 0, "080 fresh process dawn: unfailed copy A recharges; failed copies do not")
	SaveManager.delete_save(SLOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(IDS))
	h._exit_test()
