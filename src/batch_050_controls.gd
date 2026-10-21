class_name Batch050Controls
extends RefCounted
## Batch 050 scenario: Brandon's four playtest steps through real party
## characters, real save/load and real campaign time.

static func _party_member(id: String) -> Character:
	var c := Batch050Checks.actor(id)
	PartyManager.characters[c.character_id] = c
	return c

static func _reload(h: Node, slot: String, label: String) -> bool:
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	var loaded: bool = saved and SaveManager.load_game(slot)
	h._assert(loaded, "050 actual %s: real save and load (block='%s')" % [label, block])
	return loaded

static func run(h: Node) -> void:
	h._enter_test("batch_050_playtest_fixes_flow")
	h._setup_world()
	Batch050Checks.load_fixtures()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var slot := "batch_050_playtest"
	var a: Character = PlayerManager.get_player(0).get("character")
	var b := _party_member("b050_scn_finder")
	a.inventory.unequip(Inventory.Slot.SHIELD)
	# 1) Drop an equipped magic weapon; another character picks it up and equips it.
	var id := Batch050Checks.wield(a)
	var w := Batch050Checks.ward(id)
	RuleUpgradeRules.choose_alternative(a, w, "edge", "deep@" + id)
	FeatureModeRules.activate(a, w, "protect")
	FeatureModeRules.end(a, w, "dismissed")
	var record := a.inventory.drop_equipped_instance(Inventory.Slot.WEAPON)
	var picked := b.inventory.receive_instance(record)
	if _reload(h, slot, "after the drop and pick-up"):
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		nb.inventory.equip_instance(Inventory.Slot.WEAPON, id)
		h._assert(picked and int(nb.feature_uses.get(w, -1)) == 1 and nb.rule_alternatives.get(w + "|edge", "") == "deep@" + id, "050 actual bug 1: the picked-up blade keeps its 1 remaining use and its Deep option (playtest saw a recharge)")
		b = nb
	a = PlayerManager.get_player(0).get("character")
	# 2) Activate protection, suppress the item, incapacitate, restore.
	var pid := Batch050Checks.wield(a)
	var pw := Batch050Checks.ward(pid)
	var on := FeatureModeRules.activate(a, pw, "protect")
	var ac_on := SourceBenefitRules.total(a, "AC")
	Batch050Checks.mute(a, "b050_scn_mute")
	a.add_condition("incapacitated", 6)
	a.remove_condition("incapacitated")
	a.spell_effects.erase("b050_scn_mute")
	if _reload(h, slot, "after suppression, incapacitation and restore"):
		a = PlayerManager.get_player(0).get("character")
		h._assert(on.success and ac_on == 1 and not bool(a.feature_modes[pw].active) and SourceBenefitRules.total(a, "AC") == 0, "050 actual bug 2: protection that ended on incapacitation stays ended after suppression lifts and reload")
	# 3) Two identical blades equipped: both tracked.
	b = PartyManager.characters.get("b050_scn_finder", b)
	var main := Batch050Checks.wield(b)
	b.inventory.unequip(Inventory.Slot.WEAPON)
	b.inventory.equip_instance(Inventory.Slot.WEAPON, main)
	var off := Batch050Checks.wield(b, Inventory.Slot.OFFHAND)
	FeatureModeRules.activate(b, Batch050Checks.ward(off), "protect")
	if _reload(h, slot, "with two identical blades"):
		var nb: Character = PartyManager.characters.get(b.character_id, null)
		h._assert(nb.has_feature(Batch050Checks.ward(main)) and nb.has_feature(Batch050Checks.ward(off)) and int(nb.feature_uses[Batch050Checks.ward(main)]) == 2 and int(nb.feature_uses[Batch050Checks.ward(off)]) == 1, "050 actual bug 3: both identical copies exist after reload with their own uses (2 and 1)")
		# Dawn (SRD 5.2.1 p.206) through real campaign time.
		GameManager.advance_campaign_time(86400 - (int(GameManager.campaign_elapsed_seconds) % 86400))
		h._assert(int(nb.feature_uses[Batch050Checks.ward(off)]) == 2, "050 actual the next dawn recharges the spent blade")
	# 4) Typo in a feat reference fails loading with a useful error.
	var before := DataLoader._load_errors.size()
	DataLoader._load_json_file("res://data/fixtures/batch_050/races/typo.json", "race")
	var errors: Array = DataLoader._load_errors.slice(before)
	DataLoader._load_errors.resize(before)
	h._assert(errors.size() == 1 and "fixture:b049_faet" in str(errors) and "typo.json" in str(errors), "050 actual bug 4: loading the typo species reports its file and the missing feat id: %s" % str(errors))
	# Save while suppression is still active, rather than removing it first.
	a = PlayerManager.get_player(0).get("character")
	var saved_id := Batch050Checks.wield(a)
	var saved_ward := Batch050Checks.ward(saved_id)
	RuleUpgradeRules.choose_alternative(a, saved_ward, "edge", "deep@" + saved_id)
	OwnedFeatureSources.recover_dawn(a)
	var cast := Batch044Checks.cast(a, Batch050Checks.QUELL)
	var dagger := Batch041Checks.add_copy(a, "dagger")
	var equipped := a.inventory.equip_instance(Inventory.Slot.OFFHAND, dagger)
	h._assert(cast.get("magic_suppression", {}).get("applied", false) and equipped and not MagicPropertyRules.active(a, saved_id, "features") and int(a.feature_uses[saved_ward]) == 3, "050 actual refresh during suppression keeps the upgraded 3-use capacity")
	if _reload(h, slot, "while item powers remain suppressed"):
		a = PlayerManager.get_player(0).get("character")
		h._assert(not MagicPropertyRules.active(a, saved_id, "features") and int(a.feature_uses[saved_ward]) == 3, "050 actual suppressed item reload keeps suppression and all 3 uses")
		SpellEffects.end_concentration(a, [a])
		h._assert(MagicPropertyRules.active(a, saved_id, "features") and int(a.feature_uses[saved_ward]) == 3 and a.rule_alternatives.get(saved_ward + "|edge", "") == "deep@" + saved_id, "050 actual lifting suppression after reload restores the remembered option without losing a use")
	SaveManager.delete_save(slot)
	PartyManager.characters.erase("b050_scn_finder")
	h._exit_test()
