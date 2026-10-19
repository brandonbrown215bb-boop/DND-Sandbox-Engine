class_name BatchJChecks
extends RefCounted

static func run(check: Callable) -> void:
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/fixtures/batch_j_limits.json"))
	var validator: Node = DataLoader.get_script().new()
	check.call(validator._validate_content(record, "class", "batch-j"), "Batch J neutral scoped riders validate through DataLoader")
	for mutation in ["bad_scope", "bad_own", "bad_first", "bad_waiver", "bad_replacement", "combined_payment", "missing_pool"]:
		var invalid := record.duplicate(true)
		var feature: Dictionary = invalid.features_by_level["1"][0]
		var effect: Dictionary = feature.passive_effects[0]
		match mutation:
			"bad_scope": effect.use_limit = "everywhere"
			"bad_own": effect.own_turn_only = "true"
			"bad_first": effect.first_round_only = 1
			"bad_waiver": effect.payment_waiver = {"parent": "any", "requires_active_source": true}
			"bad_replacement": effect.payment_replacement = {"pool_id": "fixture:replacement", "quantity": 0}
			"combined_payment":
				effect.payment_replacement = {"pool_id": "fixture:replacement", "quantity": 1}
				effect.payment_waiver = {"parent": "weapon_attack", "requires_active_source": true}
			"missing_pool": feature.erase("resource_pool")
		check.call(not validator._validate_content(invalid, "class", "batch-j-invalid"), "Batch J loader refuses " + mutation)
	validator.free()
	var replacement_definition: Dictionary = record.duplicate(true)
	var replacement_rider: Dictionary = replacement_definition.features_by_level["1"][0].passive_effects[0]
	replacement_rider["payment_replacement"] = {"pool_id": "fixture:j_replacement_dice", "quantity": 1}
	var replacement_validator: Node = DataLoader.get_script().new()
	check.call(replacement_validator._validate_content(replacement_definition, "class", "batch-j-replacement"), "Batch J rider accepts one declared captured-die payment replacement")
	replacement_validator.free()
	var replacement_owner := Character.new()
	replacement_owner.initialize("Replacement payer", "human", "fighter", AbilityScores.new())
	replacement_owner.character_id = "fixture:replacement_owner"
	var replacement_feature: Dictionary = record.features_by_level["1"][0].duplicate(true)
	replacement_feature.source_instance_id = "fixture:replacement_rider_source"
	replacement_feature.passive_effects[0].own_turn_only = false
	replacement_feature.passive_effects[0].payment_replacement = {"pool_id": "fixture:j_replacement_dice", "quantity": 1}
	replacement_owner.features = [replacement_feature]
	ResourcePoolRules.acquire(replacement_owner, replacement_feature, "fixture:replacement_rider_source")
	var captured_payment_feature := {"id": "fixture:replacement_dice_feature", "name": "Replacement dice", "resource_pool": {"id": "fixture:j_replacement_dice", "capacity_formula": 2, "initial_quantity": 2, "die_size": 6, "capture_policy": "on_acquire", "upgrade_policy": "new_dice_only", "spend_choice": {"minimum": 1, "maximum": 1}}}
	ResourcePoolRules.acquire(replacement_owner, captured_payment_feature, "fixture:replacement_dice_source")
	CombatAction.advance_combat_turn(replacement_owner, 1)
	var replacement_target := {"id": "fixture:replacement_target", "is_alive": true, "current_hp": 1000, "max_hp": 1000, "conditions": {}}
	var replacement_riders := CombatAction.resolve_weapon_damage_riders(replacement_owner, replacement_target, {}, {"id": "fixture:replacement_sword", "type": "weapon", "range": 1})
	var replacement_paid: Dictionary = replacement_riders[0].get("replacement_payment", {}) if not replacement_riders.is_empty() else {}
	check.call(replacement_riders.size() == 1 and int(ResourcePoolRules.availability(replacement_owner, "fixture:replacement_rider_source").current) == 10 and int(ResourcePoolRules.availability(replacement_owner, "fixture:replacement_dice_source").current) == 1 and replacement_paid.get("captured_dice", []).size() == 1 and str(replacement_riders[0].get("payment_source_instance_id", "")) == "fixture:replacement_dice_source", "Weapon rider pays from the exact captured-dice source once and preserves its original pool")
	var actor := Character.new()
	actor.character_id = "j:owner"
	actor.class_id = "fighter"
	actor.level = 1
	actor.ability_scores = AbilityScores.new()
	var other := Character.new()
	other.character_id = "j:other"
	var feature: Dictionary = record.features_by_level["1"][0].duplicate(true)
	feature.source_instance_id = "j:source"
	actor.features = [feature]
	ResourcePoolRules.acquire(actor, feature, "j:source")
	var weapon := {"id": "j:sword", "type": "weapon", "range": 1}
	var target := {"id": "j:target", "is_alive": true, "current_hp": 1000, "max_hp": 1000, "conditions": {}}
	CombatAction.reset_bounded_owner_turn_rider_locks()
	CombatAction.advance_combat_turn(other, 1)
	var rolls: Array = []
	var listener := func(details: Dictionary): rolls.append(details)
	Dice.dice_rolled.connect(listener)
	check.call(CombatAction.resolve_weapon_damage_riders(actor, target, {}, weapon).is_empty() and rolls.is_empty() and int(ResourcePoolRules.availability(actor, "j:source").current) == 10, "Off-turn own-turn refusal preserves RNG, HP, pool and lock")
	CombatAction.advance_combat_turn(actor, 1)
	check.call(CombatAction.resolve_weapon_damage_riders(actor, target, {}, weapon).size() == 1, "Own-turn first qualifying hit commits round lock")
	var hp := int(target.current_hp)
	var count := rolls.size()
	CombatAction.advance_combat_turn(other, 1)
	CombatAction.advance_combat_turn(actor, 1)
	check.call(CombatAction.resolve_weapon_damage_riders(actor, target, {}, weapon).is_empty() and int(target.current_hp) == hp and rolls.size() == count, "Additional own turn in same round cannot reset round allowance or reroll")
	CombatAction.advance_combat_turn(actor, 2)
	check.call(CombatAction.resolve_weapon_damage_riders(actor, target, {}, weapon).size() == 1 and int(ResourcePoolRules.availability(actor, "j:source").current) == 8, "Next actual round unlocks without refill")
	feature.passive_effects[0].first_round_only = true
	CombatAction.advance_combat_turn(actor, 3)
	check.call(CombatAction.resolve_weapon_damage_riders(actor, target, {}, weapon).is_empty(), "First-round eligibility cannot be borrowed in later round")
	var active: Dictionary = record.features_by_level["1"][3].duplicate(true)
	active.source_instance_id = "j:active"
	actor.features = [active]
	ResourcePoolRules.acquire(actor, active, "j:active")
	check.call(CombatAction.resolve_weapon_damage_riders(actor, target, {}, weapon).is_empty(), "Per-active-instance requires an actually active exact source")
	var activation := ClassFeature.execute(actor, active, null, null, "j:active")
	var first := CombatAction.resolve_weapon_damage_riders(actor, target, {}, weapon)
	var repeat := CombatAction.resolve_weapon_damage_riders(actor, target, {}, weapon)
	check.call(bool(activation.get("success", false)) and first.size() == 1 and repeat.is_empty() and int(ResourcePoolRules.availability(actor, "j:active").current) == 8, "Per-active-instance pays activation and one rider once")
	CombatAction.reset_bounded_owner_turn_rider_locks()
	check.call(CombatAction.resolve_weapon_damage_riders(actor, target, {}, weapon).is_empty(), "New encounter does not erase durable active-grant lock")
	var saved := actor.to_dict()
	check.call(Character.saved_campaign_modifier_error(saved, int(GameManager.campaign_elapsed_seconds)).is_empty(), "Used active-grant option serializes with exact source and deadline")
	for bad in ["string", "duplicate", "invalid"]:
		var malformed := saved.duplicate(true)
		malformed.modifiers[0].used_rider_options = "j_active" if bad == "string" else (["j_active", "j_active"] if bad == "duplicate" else ["not valid"])
		check.call(not Character.saved_campaign_modifier_error(malformed, int(GameManager.campaign_elapsed_seconds)).is_empty(), "Malformed durable active-grant lock refuses " + bad)
	var old_grant := str(first[0].grant_instance_id) if not first.is_empty() else ""
	actor.remove_campaign_modifiers_from_source("j:active")
	ClassFeature.execute(actor, active, null, null, "j:active")
	var fresh := CombatAction.resolve_weapon_damage_riders(actor, target, {}, weapon)
	check.call(fresh.size() == 1 and str(fresh[0].grant_instance_id) != old_grant, "New activation gets a different grant identity and independent allowance")
	Dice.dice_rolled.disconnect(listener)
	CombatAction.reset_bounded_owner_turn_rider_locks()
	CombatAction.active_turn_actor_id = 0
