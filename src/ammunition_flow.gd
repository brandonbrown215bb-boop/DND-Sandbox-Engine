class_name AmmunitionFlow
extends RefCounted

static func fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/ammunition/items.json", "item")
	Batch067Checks.load_fixtures()

static func equip(c: Character, definition: String) -> void:
	c.inventory.add_item(definition)
	c.inventory.equip(Inventory.Slot.WEAPON, definition)

static func count(c: Character, kind: String = "arrow") -> int:
	return AmmunitionRules.options(c, {"ammunition_kind":kind}).size()

static func button(h: Node, c: Character) -> void:
	await h.get_tree().process_frame # Let the harness finish entering the tree before creating a sheet layer.
	CharacterSheet.show_sheet(c)
	await h.get_tree().process_frame
	var controls := CharacterSheet._content.get_children().filter(func(child): return child is Button and child.text == "Recover ammunition (1 minute)" and not child.is_queued_for_deletion())
	var control: Button = controls[0] if not controls.is_empty() else null
	h._assert(control != null and not control.disabled, "S249 actual sheet offers legal one-minute recovery: " + AmmunitionRules.recovery_error(c))
	if control != null: control.pressed.emit()
	CharacterSheet.close_sheet()
	await h.get_tree().process_frame

static func save_pair(h: Node, name: String) -> Dictionary:
	h._assert(SaveManager.save_game(name), "S249 allowed full-party checkpoint: " + name)
	var dto := SaveManager._read_save(name)
	if dto.is_empty(): return {}
	var players := dto.duplicate(true)
	players.erase("party")
	h._assert(SaveManager._validate_save_data(players).is_empty(), "S249 allowed player-only checkpoint preflight: " + name)
	var file := FileAccess.open(SaveManager.SAVE_DIR + name + "_players.sav", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(players)); file.close()
	h._assert(file != null, "S249 player-only checkpoint written: " + name)
	return dto

static func run(h: Node) -> void:
	h._enter_test("ammunition_flow")
	h._setup_world()
	fixtures()
	GameManager.campaign_elapsed_seconds = 172800 # Recovery timestamps must outlive small quantity bounds.
	h._assert(DataLoader.get_load_errors().is_empty(), "S249 neutral renamed ammunition definitions pass production loader: " + str(DataLoader.get_load_errors()))
	var c: Character = h._fresh_char("Ammo owner", "human", "fighter", {"STR":14,"DEX":16,"CON":14,"INT":10,"WIS":10,"CHA":10})
	while c.level < 5: c.level_up()
	c.inventory = Inventory.new()
	c.inventory.owner_character_ref = weakref(c)
	equip(c, "fixture:ammo_bow")
	PlayerManager.set_player_character(0, c)
	PartyManager.reset()
	PartyManager.register_player_character(0, c)
	PartyManager.register_player_character(1, PlayerManager.get_player(1).character)
	GameManager.current_state = GameManager.GameState.COMBAT
	GameManager.transition_context = {"terrain":"plains", "monster_ids":["goblin"]}
	var combat: CombatState = await h._spawn_scene("res://scenes/combat.tscn", 0.5)
	h._p_focus(combat, c)
	combat._reset_turn_action_economy()
	combat.player_entities[0].hex_position = Vector2i.ZERO
	var enemy: Dictionary = combat.monster_entities[0]
	enemy.hex_position = Vector2i(1, 0)
	enemy.current_hp = 500; enemy.max_hp = 500; enemy.armor_class = 1000
	combat._update_grid_entities()
	seed(249)
	var expected := randf()
	seed(249)
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(combat.turn_budget.action_available and c.ammunition_spent.is_empty() and randf() == expected, "S249 actual empty attack refuses before RNG and Action")
	for _i in 3: c.inventory.add_item("fixture:ammo_arrow")
	var originals: Array = AmmunitionRules.options(c, DataLoader.get_item("fixture:ammo_bow")).map(func(o): return str(o.copy.instance_id))
	c.inventory.add_item("fixture:ammo_quiver")
	var quiver: String = c.inventory.backpack_instances().filter(func(r): return r.definition_id == "fixture:ammo_quiver")[0].instance_id
	for id in originals.slice(1):
		h._assert(ContainerRules.put(c.inventory, quiver, id, "pieces").success, "S249 existing exact container holds one ammunition piece")
	# Purchase_quantity is metadata, not twenty pieces per exact copy.
	h._assert(count(c) == 3, "S249 three exact pieces are not three purchase lots")
	await combat._on_hud_action("cancel", {})
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hud_action("cancel", {})
	h._assert(count(c) == 3 and combat.turn_budget.action_available, "S249 cancelled targeting spends zero")
	var edge := Batch067Checks.feature(0)
	edge.scope.ids = ["fixture:ammo_bow"]
	c.features.append(edge)
	GameManager.test_mode = false
	var asked := await Batch067Controls._attack(h, combat, -1)
	h._assert(asked and count(c) == 3 and combat.turn_budget.action_available, "S249 cancelled activation choice spends zero ammo and Action")
	# Replace with an identical exact bow while the activation menu is held.
	c.inventory.add_item("fixture:ammo_bow")
	var other: String = c.inventory.backpack_instances().filter(func(r): return r.definition_id == "fixture:ammo_bow")[0].instance_id
	asked = await Batch067Controls._attack(h, combat, func():
		c.inventory.equip_instance(Inventory.Slot.WEAPON, other)
		return 0)
	h._assert(asked and count(c) == 3 and combat.turn_budget.action_available, "S249 stale identical weapon-copy choice spends zero")
	c.features.erase(edge)
	GameManager.test_mode = true
	seed(249)
	for _i in 2:
		combat.hud.btn_attack.pressed.emit()
		await combat._on_hex_clicked(enemy.hex_position)
	h._assert(count(c) == 1 and c.ammunition_spent.size() == 2 and not combat.turn_budget.action_available and combat.remaining_attack_swings == 0, "S249 actual Extra Attack fires two from three and leaves one")
	h._assert(enemy.current_hp == 500, "S249 both actual misses still spend exact ammunition")
	h._assert(not DataLoader.get_item("fixture:ammo_bow").has("_ammunition_shot"), "S249 shot receipts never mutate loaded definitions")
	combat._reset_turn_action_economy()
	enemy.conditions["resilient_sphere"] = 1
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(count(c) == 1 and combat.turn_budget.action_available, "S249 refused sphere target spends neither ammunition nor Action")
	enemy.conditions.erase("resilient_sphere")
	# A real readied shot uses its owner's Reaction on another actor's turn.
	combat._reset_turn_action_economy()
	await ReadyActionFlow.declare(h, combat, c, {"kind":"attack"})
	var trigger := {"type":"movement", "actor":enemy, "position":enemy.hex_position}
	var done := await ReadyActionFlow.answer(h, combat, func(): await combat.ready_actions.publish(combat, trigger), enemy.hex_position, true, true)
	h._assert(count(c) == 1 and c.reaction_available, "S249 cancelled readied target spends zero ammo and Reaction")
	# Ignored release retains Ready; another eligible completed event can release it.
	if not combat.ready_actions.held.has(c.character_id):
		combat._reset_turn_action_economy()
		await ReadyActionFlow.declare(h, combat, c, {"kind":"attack"})
	done = await ReadyActionFlow.answer(h, combat, func(): await combat.ready_actions.publish(combat, trigger), enemy.hex_position)
	h._assert(count(c) == 0 and c.ammunition_spent.size() == 3 and not c.reaction_available, "S249 actual readied shot spends one exact piece off-turn")
	await loading(h, combat, c, enemy)
	await shared_strike(h, combat, enemy)
	await continuation(h, enemy)
	c.inventory.equip_instance(Inventory.Slot.WEAPON, other)
	for _i in 2:
		c.inventory.add_item("fixture:ammo_arrow")
		CombatAction.resolve_weapon_attack(c, enemy, DataLoader.get_item("fixture:ammo_bow"))
	# Five spent pieces yield two, proving the odd floor rather than rounding up.
	await combat._end_battle("victory")
	h._assert(c.ammunition_spent.is_empty() and c.ammunition_recovery.size() == 1 and c.ammunition_recovery[0].spent_count == 5 and c.ammunition_recovery[0].pieces.size() == 2, "S249 actual encounter ending captures one floor-half batch")
	h._teardown_scene(combat)
	await h.get_tree().process_frame
	GameManager.current_state = GameManager.GameState.OVERWORLD
	GameManager.active_dungeon_state.clear()
	GameManager.game_in_progress = true
	var at_site := AmmunitionRules.site()
	GameManager.active_dungeon_state = {"dungeon_id":"fixture:dungeon", "party_position":Vector2i(1,0)}
	var generated_a := AmmunitionRules.site()
	GameManager.active_dungeon_state.party_position = Vector2i(2,0)
	h._assert(generated_a != AmmunitionRules.site(), "S249 generated dungeon rooms retain distinct recovery sites")
	GameManager.active_dungeon_state.clear()
	h._assert(AmmunitionRules.site() == at_site, "S249 returning to the represented site restores recovery eligibility")
	var dto := save_pair(h, "ammunition_pending")
	malformed(h, dto, c)
	var time := int(GameManager.campaign_elapsed_seconds)
	await button(h, c)
	h._assert(count(c) == 2 and c.ammunition_recovery.is_empty() and int(GameManager.campaign_elapsed_seconds) == time + 60, "S249 actual sheet recovery returns half and costs exactly one minute")
	h._assert(c.inventory.backpack_instances().any(func(r): return r.instance_id == originals[0]), "S249 recovery preserves original piece identity")
	var repeated := AmmunitionRules.recover(c)
	h._assert(not repeated.success and count(c) == 2 and int(GameManager.campaign_elapsed_seconds) == time + 60, "S249 repeated recovery cannot pay or grant twice")
	save_pair(h, "ammunition_done")
	h._exit_test()

static func shared_strike(h: Node, combat: CombatState, enemy: Dictionary) -> void:
	var caster: Character = PlayerManager.get_player(1).character
	h._assert(CrownSc01Support01Flow._prepare_cantrips(caster, ["true_strike"]), "S249 actual caster learns shared weapon-attack spell")
	caster.inventory = Inventory.new()
	caster.inventory.owner_character_ref = weakref(caster)
	equip(caster, "fixture:ammo_bow")
	var slots := caster.spell_slots.duplicate(true)
	ConversionBatch002Flow._select(h, combat, caster, "true_strike", 0)
	await combat._on_hex_clicked(enemy.hex_position)
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(combat.turn_budget.action_available and caster.spell_slots == slots and caster.ammunition_spent.is_empty(), "S249 actual empty shared weapon cast refuses before Magic action/slot payment")
	caster.inventory.add_item("fixture:ammo_arrow")
	ConversionBatch002Flow._select(h, combat, caster, "true_strike", 0)
	await combat._on_hex_clicked(enemy.hex_position)
	await ConversionBatch002Flow._wait_resolution(h, combat)
	h._assert(not combat.turn_budget.action_available and count(caster) == 0 and caster.ammunition_spent.size() == 1, "S249 actual shared True Strike spends one ammunition piece and its Magic action")

static func continuation(h: Node, enemy: Dictionary) -> void:
	DataLoader._load_json_file("res://data/fixtures/failed_save_bonus/classes/weapon_attack_bonuses.json", "class")
	var c: Character = h._fresh_char("Held shot", "human", "fixture:weapon_attack_bonus_neutral_class", {"STR":10,"DEX":16,"CON":12,"INT":10,"WIS":10,"CHA":10})
	c.character_id = "fixture:held_ammunition_owner"
	var source: Dictionary = c.features.filter(func(f): return f.get("id") == "fixture:steady_strike")[0]
	h._assert(ResourcePoolRules.acquire(c, source, "fixture:steady_strike").success, "S249 captured-attack fixture acquires its owned bonus pool")
	c.inventory = Inventory.new()
	equip(c, "fixture:ammo_bow")
	c.inventory.add_item("fixture:ammo_arrow")
	seed(h._batch_g_single_seed(5))
	var pending := CombatAction.resolve_weapon_attack(c, enemy, DataLoader.get_item("fixture:ammo_bow"), false, false, {"allow_weapon_attack_bonus":true})
	h._assert(pending.has("weapon_attack_bonus_request") and count(c) == 0 and c.ammunition_spent.size() == 1, "S249 captured post-roll chooser has already spent exactly one piece")
	var settled := SpellDamageRolls.settle_weapon_attack_bonus(c, enemy, pending, "")
	var replay := SpellDamageRolls.settle_weapon_attack_bonus(c, enemy, pending, "")
	h._assert(not settled.has("weapon_attack_bonus_request") and replay.get("refused", false) and count(c) == 0 and c.ammunition_spent.size() == 1, "S249 real captured continuation and stale replay cannot debit twice")
	AmmunitionRules.finish(c)
	h._assert(c.ammunition_recovery.is_empty(), "S249 one spent piece recovers floor-half zero")

static func loading(h: Node, combat: CombatState, c: Character, enemy: Dictionary) -> void:
	# Isolate this fight's extra checks from the bow recovery batch.
	var spent := c.ammunition_spent.duplicate(true)
	c.ammunition_spent.clear()
	equip(c, "fixture:ammo_crossbow")
	for _i in 2: c.inventory.add_item("fixture:ammo_bolt")
	combat._reset_turn_action_economy()
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(count(c, "bolt") == 1 and combat.remaining_attack_swings == 0 and not combat.turn_budget.action_available, "S249 actual Loading weapon fires once despite Extra Attack")
	equip(c, "fixture:ammo_bow")
	c.inventory.add_item("fixture:ammo_arrow")
	combat._reset_turn_action_economy()
	var rolls := []
	var observe := func(result: Dictionary):
		if int(result.get("sides", 0)) == 20: rolls.append(result)
	Dice.dice_rolled.connect(observe)
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	Dice.dice_rolled.disconnect(observe)
	h._assert(count(c) == 0 and rolls.size() == 1 and combat.remaining_attack_swings == 1, "S249 exhausted automatic Extra Attack stops before another RNG roll or attack unit")
	equip(c, "fixture:ammo_sling")
	c.inventory.add_item("fixture:ammo_stone")
	c.inventory.add_item("shield")
	c.inventory.equip(Inventory.Slot.SHIELD, "shield")
	combat._reset_turn_action_economy()
	combat.hud.btn_attack.pressed.emit()
	await combat._on_hex_clicked(enemy.hex_position)
	h._assert(count(c, "stone") == 1 and combat.turn_budget.action_available, "S249 actual one-handed ammunition weapon refuses loading with Shield")
	c.inventory.unequip(Inventory.Slot.SHIELD)
	# Restore bow fight's exact spent list; other fixture pieces are deliberately lost.
	c.ammunition_spent = spent

static func malformed(h: Node, dto: Dictionary, c: Character) -> void:
	if dto.is_empty(): return
	for players_only in [false, true]:
		for defect in ["fraction", "count", "future", "duplicate", "serial"]:
			var bad := dto.duplicate(true)
			if players_only: bad.erase("party")
			var actor: Dictionary = bad.players[0].character if players_only else bad.party.characters[c.character_id]
			var batch: Dictionary = actor.ammunition_recovery[0]
			match defect:
				"fraction": batch.spent_count = 5.5
				"count": batch.pieces.pop_back()
				"future": batch.ended_at = 999999
				"duplicate": batch.pieces[1] = batch.pieces[0].duplicate(true)
				"serial": batch.pieces[0].instance_id = str(actor.inventory.copies.inventory_id) + ":" + str(actor.inventory.copies.next_id)
			var file := FileAccess.open(SaveManager.SAVE_DIR + "ammunition_malformed.sav", FileAccess.WRITE)
			if file != null: file.store_string(JSON.stringify(bad)); file.close()
			h._assert(file != null and not SaveManager._validate_save_data(bad).is_empty() and not SaveManager.load_game("ammunition_malformed") and PlayerManager.get_player(0).character == c, "S249 malformed %s refuses actual %s checkpoint load before replacing session" % [defect, "players" if players_only else "party"])
	var disagreement := dto.duplicate(true)
	disagreement.players[0].character.ammunition_recovery.clear()
	h._assert(not SaveManager._validate_save_data(disagreement).is_empty(), "S249 player/party recovery disagreement refuses")

static func run_reload(h: Node) -> void:
	h._enter_test("ammunition_reload")
	fixtures()
	for slot in ["ammunition_pending", "ammunition_pending_players", "ammunition_done", "ammunition_done_players"]:
		h._assert(SaveManager.load_game(slot), "S249 fresh-process allowed checkpoint load: " + slot)
		var c: Character = PlayerManager.get_player(0).get("character")
		if c == null: continue
		var time := int(GameManager.campaign_elapsed_seconds)
		if "pending" in slot:
			h._assert(count(c) == 0 and c.ammunition_recovery.size() == 1 and c.ammunition_recovery[0].pieces.size() == 2, "S249 fresh process preserves spent and recoverable exact counts")
			await button(h, c)
			h._assert(count(c) == 2 and c.ammunition_recovery.is_empty() and int(GameManager.campaign_elapsed_seconds) == time + 60, "S249 recovered pending checkpoint completes once after one minute")
		else:
			h._assert(count(c) == 2 and c.ammunition_recovery.is_empty(), "S249 fresh-process completed recovery retains pieces without replay")
		var repeated := AmmunitionRules.recover(c)
		h._assert(not repeated.success and count(c) == 2 and int(GameManager.campaign_elapsed_seconds) == time + (60 if "pending" in slot else 0), "S249 fresh-process repeat cannot duplicate ammunition or clock")
	h._exit_test()
