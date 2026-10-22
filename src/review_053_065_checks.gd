class_name Review053065Checks
extends RefCounted
## Regressions found while reviewing PRs #25-37 together.

class DefeatBattle:
	extends CombatState
	var outcome := ""
	func _ready() -> void: pass # This check supplies its own tiny scene state.
	func _end_battle(result: String) -> void: outcome = result
	var first_id := ""
	func _start_combat_turn() -> void: first_id = str(tracker.get_active().get("id", ""))
	func _interrupt_work_for_combat() -> void: pass
	func _collect_roll_token_decision(_roller, _kind: String, _label: String, _seeded: Dictionary = {}) -> Dictionary: return {}

class PlacementBattle:
	extends Node
	var hex_grid: HexGrid
	var player_entities: Array = []
	var monster_entities: Array = []
	var tracker := InitiativeTracker.new()
	func _update_grid_entities() -> void: pass

static func run(check: Callable) -> void:
	Batch059Checks.load_fixtures()
	Batch056Checks.load_fixtures()
	Batch065Checks.load_fixtures()
	_queued_orders(check)
	_owner_turn_conditions(check)
	_party_defeat(check)
	_initial_initiative(check)
	_follower_identity(check)
	_projection_cleanup(check)
	_placement_size_and_plane(check)
	_material_choices(check)
	_material_commit(check)
	_reaction_targets(check)

static func _queued_orders(check: Callable) -> void:
	var clock := GameManager.campaign_elapsed_seconds
	for reason in ["incapacitated", "dead", "expired"]:
		var owner := Batch031Checks._character("r053_order_" + reason, 30)
		var actors := Batch056Checks.make(owner, Batch056Checks.HOUNDS, reason)
		var battle := Batch056Checks.battle(owner, actors)
		CombatAction.active_turn_serial += 1
		var ordered := CreatedCommandRules.issue(battle, owner, actors[0].character_id, "attack", "b056_goblin")
		if reason == "expired":
			var data: Dictionary = owner.spell_effects[actors[0].get_meta("created_source_id")].created_actors
			data.control_until = int(clock)
		elif reason == "dead":
			owner.current_hp = 0
			owner.is_alive = false
			owner.death_save_failures = 3
		else:
			owner.add_condition("stunned", 2)
		# Make the declared fallbacks visibly different from the queued attack.
		var original: Dictionary = DataLoader.spells[Batch056Checks.HOUNDS]
		var changed := original.duplicate(true)
		changed.effects[0].template.command["owner_incapacitated"] = "none"
		changed.effects[0].template.command["control_expired"] = "dodge"
		DataLoader.spells[Batch056Checks.HOUNDS] = changed
		battle.active_character = actors[0]
		battle.budget = {"action": 1, "bonus_action": 1}
		var hp := int(battle.monster_entities[0].current_hp)
		var line := CreatedCommandRules.take_turn(battle, battle.player_entities[1])
		check.call(ordered.success and int(battle.monster_entities[0].current_hp) == hp and (actors[0].has_condition("dodging") if reason == "expired" else line.is_empty()), "R053 queued order yields to %s policy (%s)" % [reason, line])
		DataLoader.spells[Batch056Checks.HOUNDS] = original
	GameManager.campaign_elapsed_seconds = clock

static func _owner_turn_conditions(check: Callable) -> void:
	var owner := Batch031Checks._character("r053_condition_owner", 30)
	var wolves := Batch055Checks.pack(owner)
	var battle := Batch056Checks.battle(owner, wolves)
	wolves[0].add_condition("stunned", 1)
	CreatedCommandRules.apply_defaults(battle, owner)
	check.call(not wolves[0].has_condition("stunned"), "R053 owner-turn creature conditions tick even when it cannot act")
	CombatAction.active_turn_serial += 1
	var paid := CreatedCommandRules.issue(battle, owner, wolves[1].character_id, "dodge")
	CreatedCommandRules.apply_defaults(battle, owner)
	check.call(paid.success and int(wolves[1].conditions.get("dodging", 0)) == 1, "R053 commanded owner-turn creature conditions tick once too")
	CreatedCommandRules.start_owner_turn(battle, owner)
	check.call(not wolves[1].has_condition("dodging"), "R053 owner-turn Dodge ends at the next owner turn")

static func _initial_initiative(check: Callable) -> void:
	var owner := Batch031Checks._character("r053_initial_owner", 30)
	owner.ability_scores.dexterity = 1
	var sprites := Batch056Checks.make(owner, Batch056Checks.SPRITE, "first")
	sprites[0].ability_scores.dexterity = 30
	var battle: CombatState = load("res://scenes/combat.tscn").instantiate()
	battle.set_script(DefeatBattle)
	battle.player_entities = [{"name": owner.character_name, "character": owner}, {"name": sprites[0].character_name, "character": sprites[0], "is_created_actor": true, "created_owner_id": owner.character_id}]
	GameManager.add_child(battle)
	seed(8734)
	battle._roll_initiative_and_start()
	check.call(battle.tracker.combatants[0].entity == sprites[0] and battle.first_id == sprites[0].character_id and battle.tracker.current_round == 1, "R053 an existing independent summon that rolls first starts in round one (%s)" % str(battle.tracker.combatants.map(func(c): return [c.name, c.roll])))
	randomize()
	battle.free()

static func _party_defeat(check: Callable) -> void:
	var battle := DefeatBattle.new()
	battle.hud = CombatHUD.new()
	var owner := Batch031Checks._character("r053_dead_party", 30)
	owner.current_hp = 0
	owner.is_alive = false
	owner.death_save_failures = 3
	var summon := Batch031Checks._character("r053_last_summon", 30)
	battle.player_entities = [{"character": owner}, {"character": summon, "is_created_actor": true}]
	battle.monster_entities = [{"is_alive": true}]
	check.call(battle._check_battle_end_conditions() and battle.outcome == "defeat", "R053 a surviving created creature does not prevent party defeat")
	battle.hud.free()
	battle.free()

static func _follower_identity(check: Callable) -> void:
	var owner := Batch031Checks._character("r053_durable_owner", 30)
	var hounds := Batch056Checks.make(owner, Batch056Checks.HOUNDS, "identity")
	var battle := Batch056Checks.battle(owner, [])
	battle.tracker.combatants[0].id = "player_7"
	for actor in hounds: CreatedCommandRules.join_initiative(battle, owner, actor)
	battle.tracker.add_combatant("player_8", "Tied", false, {}, 15, 14)
	battle.tracker.sort_initiative_preserving_active()
	var ids: Array = battle.tracker.combatants.map(func(e): return str(e.id))
	check.call(ids.slice(0, 3) == ["player_7", hounds[0].character_id, hounds[1].character_id], "R053 after-owner actors follow the owner's combat ID when it differs from the durable character ID")

static func _projection_cleanup(check: Callable) -> void:
	var owner := Batch042Checks.linker("r053_projection_owner")
	var copy := Batch042Checks.add(owner, Batch042Checks.FIGURINE)
	ItemProjectionRules.project(owner, copy)
	var projected := ItemProjectionRules.actor(owner, copy)
	var battle := Batch056Checks.battle(owner, [])
	battle.player_entities.append({"character": projected, "combat_id": projected.character_id, "is_created_actor": true, "created_owner_id": owner.character_id})
	var gone := CreatedCommandRules.reconcile(battle)
	check.call(gone.is_empty() and battle.player_entities.any(func(e): return e.get("character") == projected), "R053 summon reconciliation preserves an unrelated projected exact item")

static func _placement_size_and_plane(check: Callable) -> void:
	var prior := GameManager.transition_context.duplicate(true)
	GameManager.transition_context = {"local_room": {"ceiling_feet": 4}}
	var owner := Batch031Checks._character("r053_owl_owner", 30)
	var spell := DataLoader.get_spell(Batch054Checks.MENAGERIE)
	var owl: Dictionary = spell.effects[0].options[0]
	var made := CreatedActorRules.create(owner, Batch054Checks.cast(owner, 1), owl, 1, spell)
	var battle := PlacementBattle.new()
	battle.hex_grid = Batch053Checks.grid()
	battle.player_entities = [{"character": owner, "hex_position": Vector2i.ZERO}]
	var joined := CreatedActorRules.attach(battle, owner, Vector2i.ZERO, [Vector2i(1, 0)])
	check.call(made.created and joined.size() == 1 and battle.player_entities[1].hex_position == Vector2i(1, 0), "R053 the chosen Tiny template uses its own clearance on arrival")
	owner.feature_uses["plane"] = "ethereal"
	var candidates := PlacementRules.candidates(battle, Vector2i.ZERO, "tiny", 1)
	check.call(candidates.is_empty(), "R053 a caster on another plane cannot place into the represented room")
	battle.hex_grid.free()
	battle.free()
	GameManager.transition_context = prior

static func _material_choices(check: Callable) -> void:
	var spell := DataLoader.get_spell(Batch059Checks.REMAINS)
	var effect := CreatedActorRules._effect(spell)
	var owner := Batch031Checks._character("r053_material_owner", 30)
	var original: Dictionary = DataLoader.spells[Batch059Checks.REMAINS]
	var changed := original.duplicate(true)
	changed.effects[0].count_choice = false
	DataLoader.spells[Batch059Checks.REMAINS] = changed
	var cast := {"source_id": "spell:%s:r053_capped" % owner.character_id, "caster_id": owner.character_id, "spell_id": Batch059Checks.REMAINS, "concentration": false, "conditions": []}
	var made := CreatedActorRules.create(owner, cast, effect.template, 4, changed, 1, {"b059_skeleton": 1})
	var dto: Dictionary = JSON.parse_string(JSON.stringify(owner.to_dict()))
	var record: Dictionary = dto.spell_effects.get(cast.source_id, {})
	check.call(made.get("created", false) and not record.is_empty() and CreatedActorRules.saved_record_error(dto, record).is_empty(), "R053 a material-capped fixed-count cast creates and reloads its actual smaller count")
	DataLoader.spells[Batch059Checks.REMAINS] = original

static func _material_commit(check: Callable) -> void:
	var owner := Batch031Checks._character("r053_material_commit", 30)
	var body := Batch059Checks._body("bones", Vector2i(1, 0))
	var cast := Batch059Checks._cast(owner, [body])
	cast.spell = DataLoader.get_spell(Batch059Checks.REMAINS).duplicate(true)
	cast.spell["_factory"] = {"template_id": "b059_skeleton", "count": 1, "mix": {"b059_skeleton": 1}}
	var chosen := SpellCastChoices.revalidate_creation(cast)
	body.is_alive = true
	var stale := SpellCastChoices.revalidate_creation(cast)
	check.call(chosen and not stale and owner.spell_effects.is_empty() and not bool(body.get("material_used", false)), "R053 remains lost while placement is open refuse before payment or creation")
	body.is_alive = false
	cast.spell = DataLoader.get_spell(Batch059Checks.REMAINS).duplicate(true)
	cast.spell["_factory"] = {"template_id": "b059_skeleton", "count": 1, "mix": {"b059_skeleton": 1}}
	cast.spell["_placement"] = []
	SpellCastChoices.revalidate_creation(cast)
	check.call(MaterialTargetRules.consume_created(cast) == 0 and not bool(body.get("material_used", false)), "R053 a paid no-space result consumes no remains")
	cast.spell.erase("_placement")
	SpellCastChoices.revalidate_creation(cast)
	var source := {"source_id": "spell:%s:r053_material" % owner.character_id, "caster_id": owner.character_id, "spell_id": Batch059Checks.REMAINS, "concentration": false, "conditions": []}
	cast.spell["_effect_cast"] = source
	var effect := CreatedActorRules._effect(cast.spell)
	var made := CreatedActorRules.create(owner, source, effect.template, 3, cast.spell, 1, {"b059_skeleton": 1})
	check.call(made.created and MaterialTargetRules.consume_created(cast) == 1 and MaterialTargetRules.consume_created(cast) == 0 and bool(body.get("material_used", false)), "R053 a successful creation consumes its exact reserved body once")
	# Two kinds sharing the bones tag cannot both reserve the same pile.
	var two := Batch059Checks._cast(owner, [Batch059Checks._body("bones", Vector2i(1, 0)), Batch059Checks._body("intact", Vector2i(2, 0))])
	two.spell = DataLoader.get_spell(Batch059Checks.REMAINS).duplicate(true)
	two.spell.effects[0].material_targets.kinds = {"b059_skeleton": "bones", "b059_zombie": "bones"}
	two.spell["_factory"] = {"count": 2, "mix": {"b059_skeleton": 1, "b059_zombie": 1}}
	check.call(not SpellCastChoices.revalidate_creation(two), "R053 two material kinds cannot spend the same bones twice")

static func _reaction_targets(check: Callable) -> void:
	var caster := Batch065Checks.warlock("r053_reactor")
	var foe := Batch065Checks.goblin()
	var original: Dictionary = DataLoader.spells[Batch065Checks.REBUKE]
	var changed := original.duplicate(true)
	changed.target_creature_types = ["dragon"]
	DataLoader.spells[Batch065Checks.REBUKE] = changed
	var event := ReactionTriggers.make_event("on_damaged_by_creature", caster, foe, 30, true)
	var offers := ReactionTriggers.offers(caster, event)
	var before := Batch065Checks.slots(caster)
	# Invalid source targets must never be offered or charged a slot/Reaction.
	var result := {}
	if not offers.is_empty(): result = ReactionTriggers.confirm(caster, offers[0], event, true, SpellPermissionRules.payment_choices(caster, Batch065Checks.REBUKE)[0])
	check.call(offers.is_empty() and Batch065Checks.slots(caster) == before, "R053 reaction target restrictions are checked before payment (%s)" % str(result.get("success", false)))
	DataLoader.spells[Batch065Checks.REBUKE] = original
	var open := ReactionTriggers.make_event("on_damaged_by_creature", caster, foe, 30, true)
	var fresh: Dictionary = ReactionTriggers.offers(caster, open)[0]
	var payment: Dictionary = SpellPermissionRules.payment_choices(caster, Batch065Checks.REBUKE)[0]
	caster.add_condition("raging", 2)
	var raging := ReactionTriggers.confirm(caster, fresh, open, true, payment)
	check.call(ReactionTriggers.offers(caster, open).is_empty() and not raging.success and Batch065Checks.slots(caster) == before, "R053 a caster who cannot cast refuses a pending reaction without payment")
	caster.remove_condition("raging")
	changed = original.duplicate(true)
	changed.range = 1
	changed.reaction_trigger.erase("range_feet")
	DataLoader.spells[Batch065Checks.REBUKE] = changed
	check.call(ReactionTriggers.offers(caster, open).is_empty(), "R053 an unbounded trigger cannot bypass the spell's own range")
	DataLoader.spells[Batch065Checks.REBUKE] = original
