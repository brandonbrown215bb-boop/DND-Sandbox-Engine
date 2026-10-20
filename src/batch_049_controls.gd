class_name Batch049Controls
extends RefCounted
## Batch 049 scenario: species, species-feat and exact attuned item-copy modes
## through real equip/attune, real save/load and real campaign time.

static func run(h: Node) -> void:
	h._enter_test("batch_049_owned_feature_sources_flow")
	h._setup_world()
	Batch049Checks.load_fixtures()
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	var a: Character = PlayerManager.get_player(0).get("character")
	# The player's species is the fixture kin (production sync, as at creation).
	a.race_id = Batch049Checks.KIN
	OwnedFeatureSources.sync(a)
	var surge := Batch049Checks.SURGE
	h._assert(a.has_feature(Batch049Checks.ASPECT) and a.has_feature(surge) and int(a.feature_uses.get(surge, 0)) == 2, "049 actual the player's species and its granted feat own their rules (feat upgraded to 2 uses)")
	var id := Batch049Checks.wear(a, false)
	var focus := Batch049Checks.focus(id)
	var before := a.feature_uses.duplicate()
	var refused := FeatureModeRules.activate(a, focus, "ward")
	h._assert(not refused.success and a.feature_uses == before and not a.has_feature(focus), "049 actual the worn but unattuned circlet owns nothing; the refused activation spends no use")
	var att := a.inventory.attune_instance(id, a.character_id)
	GameManager.advance_campaign_time(int(att.get("seconds", 0)))
	var keen := RuleUpgradeRules.choose_alternative(a, focus, "tuning", "keen@" + id)
	var ac0 := SourceBenefitRules.total(a, "AC")
	var stone := FeatureModeRules.choose(a, Batch049Checks.ASPECT, "stone")
	var brace := FeatureModeRules.activate(a, surge, "brace")
	var ward := FeatureModeRules.activate(a, focus, "ward")
	h._assert(att.get("success", false) and keen and stone.success and brace.success and ward.success and SourceBenefitRules.total(a, "AC") == ac0 + 4 and int(a.feature_uses[focus]) == 1 and int(a.feature_uses[surge]) == 1, "049 actual species mode, feat activation and the exact attuned copy each grant once (+4 AC)")
	GameManager.advance_campaign_time(30)
	var focus_left := int(a.feature_modes[focus].remaining_seconds)
	var surge_left := int(a.feature_modes[surge].remaining_seconds)
	h._assert(focus_left == 570 and surge_left == 30, "049 actual campaign time runs both deadlines (%d/%d)" % [focus_left, surge_left])
	var slot := "batch_049_owned_sources"
	var block := SaveManager.get_save_block_reason()
	var saved: bool = block.is_empty() and SaveManager.save_game(slot)
	h._assert(saved, "049 actual real save with species, feat and item-copy modes (block='%s')" % block)
	if saved:
		var modes := a.feature_modes.duplicate(true)
		var alternatives := a.rule_alternatives.duplicate(true)
		var loaded := SaveManager.load_game(slot)
		var na: Character = PartyManager.characters.get(a.character_id, null)
		var ok: bool = loaded and na != null and na != a
		h._assert(ok and na.feature_modes == modes and na.rule_alternatives == alternatives and int(na.feature_uses[focus]) == 1 and int(na.feature_uses[surge]) == 1, "049 actual real load keeps choices, uses and deadlines")
		if ok:
			var ids: Array = na.features.map(func(f): return str(f.get("id", "")))
			h._assert(ids.count(focus) == 1 and ids.count(surge) == 1 and ids.count(Batch049Checks.ASPECT) == 1 and SourceBenefitRules.total(na, "AC") == ac0 + 4 and na.get_feature(focus).source_instance_id == id, "049 actual reloaded benefits come from the same exact copy, once")
			GameManager.advance_campaign_time(30)
			h._assert(not na.feature_modes[surge].active and int(na.feature_modes[focus].remaining_seconds) == 540 and SourceBenefitRules.total(na, "AC") == ac0 + 2, "049 actual the feat deadline expires on schedule after reload while the item keeps running")
			na.inventory.unequip(Inventory.Slot.HEAD)
			na.inventory.equip_instance(Inventory.Slot.HEAD, id)
			h._assert(not na.feature_modes.has(focus) and int(na.feature_uses[focus]) == 1 and SourceBenefitRules.total(na, "AC") == ac0 + 1, "049 actual taking the circlet off ends its mode; putting it back cannot refill its use")
		SaveManager.delete_save(slot)
	h._exit_test()
