class_name Batch033Controls
extends RefCounted

static func cast(h: Node, combat: Node, caster: Character, target, suffix: String, answers: Array = []) -> void:
	h._p_focus(combat, caster)
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index].get("id") == "fixture:b033_" + suffix:
			combat.hud._on_spell_selected(index)
			break
	await Batch027Controls.answer(h, combat, "", "Level 1")
	var pos: Vector2i = target.get("hex_position", Vector2i.ZERO) if target is Dictionary else Batch031Controls._position(combat, target)
	combat._on_hex_clicked(pos)
	for answer in answers:
		h._assert(await Batch027Controls.answer(h, combat, "Zero HP replacement", str(answer)), "033 actual player selects %s" % str(answer))
	for _frame in 300:
		await h.get_tree().process_frame
		if not combat._cast_in_progress and combat.pending_action_type.is_empty(): break
	h._assert(not combat._cast_in_progress, "033 cast finishes through its production continuation")

static func receipt(combat: Node) -> Dictionary:
	var records: Array = combat.last_spell_damage_receipts
	var r: Dictionary = records[0] if not records.is_empty() else {}
	print("B033 RECEIPTS ", JSON.stringify(records))
	return r

static func run(h: Node) -> void:
	h._enter_test("batch_033_zero_hp_flow")
	h._setup_world()
	Batch033Checks.load_fixtures()
	seed(33033)
	var a: Character = PlayerManager.get_player(0).get("character")
	var b: Character = PlayerManager.get_player(1).get("character")
	var prior_known := b.known_spells.duplicate()
	var prior_book := b.wizard_spellbook.duplicate()
	var prior_choices := b.feature_choices.duplicate(true)
	var prior_features := b.features.duplicate(true)
	Batch033Checks.setup(a)
	var spells: Array[String] = []
	for id in DataLoader.spells:
		if str(id).begins_with("fixture:b033_"): spells.append(str(id))
	b.known_spells.assign(spells)
	b.wizard_spellbook.assign(spells)
	b.feature_choices[b.get_spellcasting_feature_id()] = spells.duplicate()
	b.features.append({"id": "fixture:b033_permission", "effects": [{"type": "always_prepared_spells", "spells": spells.duplicate(), "ability": "INT", "maximum_spell_level": 1}]})
	b.spell_slots["1"] = 40
	for actor in [a, b]:
		actor.max_hp = 100
		actor.current_hp = 50
		actor.temp_hp = 0
	a.add_modifier("roll", "save:CON", 100, 999)
	GameManager.transition_context = {"terrain": "plains", "monster_ids": ["goblin"]}
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.test_mode = false
	var combat: Node = await h._spawn_scene("res://scenes/combat.tscn", 0.8)
	for _frame in 600:
		if combat.active_combatant.get("is_player", false): break
		await h.get_tree().process_frame
	for entry in combat.player_entities:
		entry["hex_position"] = Vector2i.ZERO if entry.character == a else Vector2i(0, 1)
		entry["has_turn"] = true
	var enemy: Dictionary = combat.monster_entities[0]
	enemy["hex_position"] = Vector2i(1, 0)
	Batch033Checks.revive(a)
	a.concentrating_on = {"spell_id": "shield_of_faith", "targets": [a]}
	var slots: int = b.spell_slots["1"]
	await cast(h, combat, b, a, "ordered", ["Last Stand", "Decline"])
	var r := receipt(combat)
	h._assert(a.current_hp == 3 and a.is_alive and not a.concentrating_on.is_empty() and a.zero_hp_history["b033:stand"].attempts == 1 and ResourcePoolRules.availability(a, "b033:pool").current == 9 and int(b.spell_slots["1"]) == slots - 1 and not combat.turn_budget.action_available, "033 ordered damage saves at DC10 to six then deals three once with one slot/action/payment")
	h._assert(r.zero_hp_receipt.saves[0].dc == 10 and r.zero_hp_receipt.replacement_hp == 6, "033 actual ordered receipt captures formula HP and save result")
	Batch033Checks.revive(a)
	await cast(h, combat, b, a, "fire", ["Last Stand"])
	r = receipt(combat)
	h._assert(a.current_hp == 6 and r.zero_hp_receipt.saves[0].dc == 15 and a.zero_hp_history["b033:stand"].attempts == 2, "033 actual subsequent flat damage escalates owned save DC15")
	for excluded in ["radiant", "massive", "temporary"]:
		Batch033Checks.revive(a)
		var history := a.zero_hp_history.duplicate(true)
		if excluded == "temporary": a.temp_hp = 20
		await cast(h, combat, b, a, "fire" if excluded == "temporary" else excluded, ["Last Stand"])
		h._assert(a.zero_hp_history == history and ResourcePoolRules.availability(a, "b033:pool").current == 8, "033 actual %s exclusion cannot activate or pay" % excluded)
		a.temp_hp = 0
	Batch033Checks.revive(a)
	a.add_modifier("roll", "save:CON", -200, 999)
	await cast(h, combat, b, a, "fire", ["Last Stand"])
	r = receipt(combat)
	h._assert(a.current_hp == 0 and not a.is_alive and a.concentrating_on.is_empty() and r.zero_hp_receipt.saves[0].dc == 20 and not r.zero_hp_receipt.saved and ResourcePoolRules.availability(a, "b033:pool").current == 7, "033 actual failed save settles original zero outcome and attempted payment/history once")
	Batch033Checks.revive(a)
	a.add_modifier("roll", "save:CON", 200, 999)
	# Incoming weapon goes through its actual source chooser and hit control.
	enemy["attacks"] = [{"name": "Fixture hit", "damage": "7", "damage_type": "fire", "ability": "STR", "attack_bonus_override": 100}]
	Batch031Controls._seed_hit()
	combat._execute_monster_attack(enemy, a.character_name, 0)
	h._assert(await Batch027Controls.answer(h, combat, "Zero HP replacement", "Last Stand"), "033 incoming weapon player accepts owned replacement")
	await h.get_tree().process_frame
	h._assert(a.current_hp == 6 and a.zero_hp_history["b033:stand"].attempts == 4 and ResourcePoolRules.availability(a, "b033:pool").current == 6, "033 actual incoming weapon save uses DC25 and pays its exact source once")
	Batch033Checks.revive(a)
	var critical_history := a.zero_hp_history.duplicate(true)
	# Seed a natural 20 before the real incoming attack control rolls.
	for candidate in 1000:
		seed(candidate)
		if randi_range(1, 20) == 20:
			seed(candidate)
			break
	combat._execute_monster_attack(enemy, a.character_name, 0)
	await Batch027Controls.answer(h, combat, "Zero HP replacement", "Last Stand")
	await h.get_tree().process_frame
	h._assert(bool(combat.last_monster_weapon_attack_result.get("crit", false)) and a.current_hp == 0 and a.zero_hp_history == critical_history and ResourcePoolRules.availability(a, "b033:pool").current == 6, "033 real critical incoming weapon bypasses selected source without attempt/payment")
	# Created creature data uses the same rule on the live Dictionary host.
	var creature := DataLoader.get_monster("fixture:b033_cinder")
	enemy["special_abilities"] = creature.special_abilities.duplicate(true)
	enemy["current_hp"] = 3
	enemy["max_hp"] = 100
	enemy["is_alive"] = true
	enemy["saving_throw_bonuses"] = {"CON": 100}
	await cast(h, combat, b, enemy, "fire")
	r = receipt(combat)
	h._assert(enemy.current_hp == 4 and r.zero_hp_receipt.saves[0].dc == 12, "033 actual creature spell host shares typed event executor and incoming-damage DC")
	await stale(h, combat, a, b)
	await poison_riders(h, combat, a, enemy)
	# Both histories, real reset stamps, and spent numeric pool survive a checkpoint.
	Batch033Checks.revive(a, 40)
	a.features.append(Batch033Checks.rule(1))
	a.add_condition("shielded", 999)
	a.add_modifier("roll", "save:WIS", 100, 999)
	CombatAction.resolve_damage(a, 50, "cold", Batch033Checks.choice(a, 1))
	h._teardown_scene(combat)
	b.known_spells.assign(prior_known)
	b.wizard_spellbook.assign(prior_book)
	b.feature_choices = prior_choices
	b.features = prior_features
	b.spell_slots["1"] = 1
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.game_in_progress = true
	GameManager.active_dungeon_state.clear()
	await no_reset_checkpoint(h, a)
	RestRules.complete_short_rest([a], {"allow_in_test": true, "skip_campaign_time": true})
	h._assert(a.zero_hp_history["b033:stand"].attempts == 0 and a.zero_hp_history["b033:anchor"].attempts == 1, "033 actual rest owner resets selected history and retains independent sibling")
	await checkpoint(h, a)
	GameManager.test_mode = true
	h._exit_test()

## R1: authorization follows primary rider damage by reference, whether still
## unused after a small base hit or consumed by a zero-HP base hit.
static func poison_riders(h: Node, combat: Node, a: Character, enemy: Dictionary) -> void:
	var initial_attempts: int = a.zero_hp_history["b033:stand"].attempts
	var initial_fuel: int = ResourcePoolRules.availability(a, "b033:pool").current
	a.add_modifier("roll", "save:DEX", -100, 999)
	for base in [1, 7]:
		Batch033Checks.revive(a)
		a.remove_condition("poisoned")
		enemy["attacks"] = [{"name": "Primary poison probe", "damage": str(base), "damage_type": "fire", "ability": "STR", "attack_bonus_override": 100, "extra_effects": [{"type": "poison_save", "save": "DEX", "dc": 100, "damage": "7", "duration": 1}]}]
		Batch031Controls._seed_hit()
		combat._execute_monster_attack(enemy, a.character_name, 0)
		h._assert(await Batch027Controls.answer(h, combat, "Zero HP replacement", "Last Stand"), "033 R1 primary poison attack accepts the real source choice")
		await h.get_tree().process_frame
		var attack: Dictionary = combat.last_monster_weapon_attack_result
		var components: Array = attack.get("damage_components", [])
		print("B033 R1 WEAPON ", JSON.stringify(attack))
		var completed: bool = components.size() == 2 and attack.get("hit", false) and not attack.get("crit", false)
		h._assert(completed, "033 R1 base and poison damage each settle once on a noncritical actual hit")
		if not completed: return
		var base_receipt: Dictionary = components[0].receipt
		var poison_receipt: Dictionary = components[1].receipt
		var expected_uses := 1 if base == 1 else 2
		h._assert(a.zero_hp_history["b033:stand"].attempts == initial_attempts + expected_uses and ResourcePoolRules.availability(a, "b033:pool").current == initial_fuel - expected_uses and base_receipt.raw == base and poison_receipt.raw == 7, "033 R1 exact source history/payment advance once per accepted attack")
		if base == 1:
			h._assert(a.current_hp == 6 and base_receipt.zero_hp_receipt.is_empty() and poison_receipt.zero_hp_receipt.source_instance_id == "b033:stand" and poison_receipt.zero_hp_receipt.saves[0].dc == 10 + initial_attempts * 5 and poison_receipt.zero_hp_receipt.paid == 1, "033 R1 unused base authorization reaches lethal primary poison damage and replaces HP")
		else:
			h._assert(a.current_hp == 0 and base_receipt.zero_hp_receipt.replaced and poison_receipt.zero_hp_receipt.is_empty(), "033 R1 base-consumed authorization cannot grant a second replacement on poison damage")
	a.add_modifier("roll", "save:DEX", 100, 999)
	a.remove_condition("poisoned")

## R2: reproduce positive-but-inconsistent counts through both real save DTOs
## before any reset; this checkpoint must not silently lower the next DC.
static func no_reset_checkpoint(h: Node, a: Character) -> void:
	var slot := "batch_033_no_reset"
	var history := a.zero_hp_history.duplicate(true)
	var pools := a.numeric_resource_pools.duplicate(true)
	var saved := SaveManager.save_game(slot)
	h._assert(saved and history["b033:stand"].resets == 0 and history["b033:stand"].attempts == history["b033:stand"].total_attempts, "033 R2 real pre-reset checkpoint retains attempted history and next DC")
	if not saved: return
	for route in ["party", "players"]:
		for defect in ["current_count", "before_count", "after_count", "conditional_count"]:
			var bad: Dictionary = SaveManager._read_save(slot).duplicate(true)
			var dto: Dictionary = bad.party.characters[a.character_id] if route == "party" else bad.players[0].character
			var source := "b033:anchor" if defect == "conditional_count" else "b033:stand"
			var entry: Dictionary = dto.zero_hp_history[source]
			match defect:
				"current_count", "conditional_count": entry.attempts = 0
				"before_count": entry.last_receipt.attempts_before += 1
				"after_count": entry.last_receipt.attempts_after -= 1
			var file := FileAccess.open(SaveManager.SAVE_DIR + "batch_033_bad_count.sav", FileAccess.WRITE)
			file.store_string(JSON.stringify(bad))
			file.close()
			h._assert(not SaveManager.load_game("batch_033_bad_count") and PartyManager.characters.get(a.character_id) == a and a.zero_hp_history == history and a.numeric_resource_pools == pools, "033 R2 inconsistent %s on %s refuses before replacing live party" % [defect, route])

static func stale(h: Node, combat: Node, a: Character, b: Character) -> void:
	Batch033Checks.revive(a)
	var history := a.zero_hp_history.duplicate(true)
	var payment: int = ResourcePoolRules.availability(a, "b033:pool").current
	h._p_focus(combat, b)
	combat.hud._show_spell_selection()
	for index in combat.hud.spells_registered.size():
		if combat.hud.spells_registered[index].get("id") == "fixture:b033_ordered": combat.hud._on_spell_selected(index); break
	await Batch027Controls.answer(h, combat, "", "Level 1")
	combat._on_hex_clicked(Batch031Controls._position(combat, a))
	var menu := await Batch027Controls.popup(h, combat, "Zero HP replacement")
	h._assert(menu != null and a.current_hp == 3 and a.zero_hp_history == history and not SaveManager.get_save_block_reason().is_empty(), "033 pending choice keeps original HP/history/payment and blocks saves")
	var request := {}
	for record in SpellDamageRolls._pending_requests.values():
		if record.has("zero_hp_options") and not record.settled: request = {"damage_request": {"request_id": record.request_id}}
	a.features = a.features.filter(func(f): return f.get("source_instance_id") != "b033:stand")
	a.features.append(Batch033Checks.rule())
	await Batch027Controls.answer(h, combat, "Zero HP replacement", "Last Stand")
	for _frame in 300:
		await h.get_tree().process_frame
		if not combat._cast_in_progress: break
	h._assert(a.current_hp == 0 and a.zero_hp_history == history and ResourcePoolRules.availability(a, "b033:pool").current == payment and not combat._cast_in_progress, "033 removed selected source resumes ordered work without save/payment/history or strand")
	var rejected := SpellDamageRolls.settle_pending_request(b, a, request, {"zero_hp_source": "b033:stand"})
	h._assert(not rejected.get("valid", false) and a.zero_hp_history == history, "033 stale duplicate callback cannot reroll or pay after continuation")

static func checkpoint(h: Node, a: Character) -> void:
	var slot := "batch_033_history"
	var history := a.zero_hp_history.duplicate(true)
	var pools := a.numeric_resource_pools.duplicate(true)
	var saved := SaveManager.get_save_block_reason().is_empty() and SaveManager.save_game(slot)
	h._assert(saved and history.size() == 2, "033 allowed checkpoint stores source identities, attempts, reset stamp and exact paid pool")
	if not saved: return
	var manifest := {"target_id": a.character_id, "history": history, "pools": pools, "hp": a.current_hp, "pid": OS.get_process_id()}
	var file := FileAccess.open("user://batch_033_manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()
	for route in ["party", "players"]:
		for defect in ["attempts", "owner", "source", "reset", "policy", "pending", "missing_entry", "missing_history", "receipt", "post_reset_count", "reset_order"]:
			var bad: Dictionary = SaveManager._read_save(slot).duplicate(true)
			var dto: Dictionary = bad.party.characters[a.character_id] if route == "party" else bad.players[0].character
			var entry: Dictionary = dto.zero_hp_history["b033:stand"]
			match defect:
				"attempts": entry.attempts = -1
				"owner": entry.owner_id = "other"
				"source": entry.source_instance_id = "sibling"
				"reset": entry.last_reset = "query"
				"policy": entry.rule.history.increment = "query"
				"pending": entry["pending_request"] = {"request_id": "old"}
				"missing_entry": dto.zero_hp_history.erase("b033:stand")
				"missing_history": dto.erase("zero_hp_history")
				"receipt": entry.last_receipt.saves[0].dc = "bad"
				"post_reset_count": entry.attempts = 1
				"reset_order": entry.last_receipt.reset_count = entry.resets
			var bad_file := FileAccess.open(SaveManager.SAVE_DIR + "batch_033_bad.sav", FileAccess.WRITE)
			bad_file.store_string(JSON.stringify(bad))
			bad_file.close()
			h._assert(not SaveManager.load_game("batch_033_bad") and PartyManager.characters.get(a.character_id) == a and a.zero_hp_history == history and a.numeric_resource_pools == pools, "033 malformed %s on %s refuses before replacing party" % [defect, route])
	OS.set_environment("B033_RELAUNCH_PHASE", "recover")
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://scenes/batch_033_fresh_relaunch.tscn"], output, true)
	OS.set_environment("B033_RELAUNCH_PHASE", "")
	var child_text := "\n".join(PackedStringArray(output))
	h._assert(exit_code == 0 and child_text.contains("BATCH 033 FRESH RELAUNCH PASSED"), "033 fresh process recovers histories/payments/HP without RNG or reacquisition; exit=%d output=%s" % [exit_code, child_text])
