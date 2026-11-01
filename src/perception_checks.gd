class_name PerceptionChecks
extends RefCounted

static func fixtures() -> void:
	DataLoader._load_json_file("res://data/fixtures/perception/class.json", "class")
	DataLoader._load_json_file("res://data/fixtures/perception/spells.json", "spell")

static func actor(id: String) -> Character:
	var c := Character.new()
	c.initialize(id, "human", "wizard", AbilityScores.new())
	c.character_id = id
	return c

static func sense(c: Character, id: String) -> void:
	for feature in DataLoader.get_character_class("fixture:perception").get("features_by_level", {}).get("1", []):
		if feature.id == "fixture:" + id: c.features.append(feature.duplicate(true))

static func grid() -> HexGrid:
	var g := HexGrid.new()
	for x in range(-4, 9):
		for y in range(-4, 9):
			var tile := HexTile.new()
			tile.coord = Vector2i(x, y)
			g.add_tile(tile)
	return g

static func target() -> Dictionary:
	return {"id":"perception_target", "name":"Perception target", "current_hp":200, "max_hp":200, "armor_class":-100, "is_alive":true, "conditions":{}, "condition_sources":{}, "hex_position":Vector2i(2, 0)}

static func spatial(g: HexGrid, here := Vector2i.ZERO, there := Vector2i(2, 0)) -> Dictionary:
	return {"spell_visibility":{"grid":g, "caster_position":here, "target_position":there}}

static func run(check: Callable) -> void:
	fixtures()
	check.call(DataLoader.get_load_errors().is_empty(), "S190 fixtures load through production validation")
	var g := grid()
	var ordinary := actor("ordinary")
	var dark := actor("dark")
	var blind := actor("blind")
	var truth := actor("truth")
	var tremor := actor("tremor")
	var own := actor("own")
	var exact := actor("exact")
	sense(dark, "short_dark"); sense(blind, "short_blind"); sense(truth, "short_true")
	sense(tremor, "short_tremor"); sense(own, "own_dark"); sense(exact, "one_dark")
	var victim := target()
	var here := Vector2i.ZERO
	var there := Vector2i(2, 0)
	CombatPerception.configure_ambient_light(g, "dark")
	check.call(not CombatPerception.can_see_target(ordinary, victim, here, there, g) and CombatPerception.can_see_target(dark, victim, here, there, g), "S190 same target in ordinary darkness differs by actual observer")
	check.call(not CombatPerception.can_see_target(dark, victim, Vector2i(-1, 0), there, g), "S190 Darkvision stops beyond authored range")
	g.add_entity({"hex_position":here, "bright_light_radius_hexes":2, "dim_light_radius_hexes":3})
	check.call(CombatPerception.can_see_target(ordinary, victim, here, there, g), "S190 existing portable light illuminates target")
	g.get_tile(Vector2i(1, 0)).custom_properties["blocks_sight"] = true
	check.call(CombatPerception.illumination_level_at(g, there) == "dark" and not CombatPerception.can_see_target(blind, victim, here, there, g), "S190 existing wall blocks light and Blindsight")
	g.get_tile(Vector2i(1, 0)).custom_properties["blocks_sight"] = false
	g.clear_entities()
	CombatPerception.configure_ambient_light(g, "bright")
	g.obscurement_sources["perception:area_a"] = {"kind":"magical_darkness", "caster_id":"own", "coords":[Vector2i(1, 0)]}
	check.call(not CombatPerception.can_see_target(dark, victim, here, there, g) and CombatPerception.can_see_target(truth, victim, here, there, g) and CombatPerception.can_see_target(blind, victim, here, there, g), "S190 intervening magical darkness defeats Darkvision but permits in-range Truesight and Blindsight")
	check.call(CombatPerception.can_see_target(own, victim, here, there, g) and CombatPerception.can_see_target(exact, victim, here, there, g) and not CombatPerception.can_see_target(ordinary, victim, here, there, g), "S190 owner-only and exact-source exceptions don't reveal target to other observers")
	g.obscurement_sources["perception:area_b"] = {"kind":"magical_darkness", "caster_id":"other", "coords":[there]}
	check.call(not CombatPerception.can_see_target(own, victim, here, there, g) and not CombatPerception.can_see_target(exact, victim, here, there, g), "S190 exception to one darkness source cannot pierce overlapping unrelated source")
	g.obscurement_sources.erase("perception:area_b")
	own.features.clear()
	check.call(not CombatPerception.can_see_target(own, victim, here, there, g), "S190 removing exception's feature source immediately restores obstruction")
	g.obscurement_sources.erase("perception:area_a")
	g.obscurement_sources["fog"] = {"kind":"fog", "coords":[Vector2i(1, 0)]}
	check.call(not CombatPerception.can_see_target(truth, victim, here, there, g) and CombatPerception.can_see_target(blind, victim, here, there, g), "S190 Truesight cannot pierce fog; Blindsight can")
	g.obscurement_sources.clear()
	for c in [ordinary, dark, truth, blind]: c.add_condition("blinded", 10)
	check.call(not CombatPerception.can_see_target(truth, victim, here, there, g) and not CombatPerception.can_see_target(dark, victim, here, there, g) and CombatPerception.can_see_target(blind, victim, here, there, g), "S190 only in-range Blindsight supplies sight while Blinded")
	check.call(not CombatPerception.can_see_target(blind, victim, Vector2i(-1, 0), there, g), "S190 blinded observer loses sight outside Blindsight range")
	for c in [ordinary, dark, truth, blind]: c.remove_condition("blinded")
	CombatAction.apply_condition(victim, "invisible", 10, "cloak")
	check.call(CombatPerception.can_locate_target(ordinary, victim, here, there, g) and not CombatPerception.can_see_target(ordinary, victim, here, there, g), "S191 known Invisible location is targetable without becoming visible")
	CombatAction.apply_condition(victim, "hidden", 10, "hide_a")
	check.call(not CombatPerception.can_locate_target(ordinary, victim, here, there, g) and CombatPerception.can_locate_target(tremor, victim, here, there, g) and not CombatPerception.can_see_target(tremor, victim, here, there, g), "S191 Hidden location requires discovery; Tremorsense pinpoints without sight")
	g.get_tile(there).custom_properties["contact_surface_id"] = "other_floor"
	check.call(not CombatPerception.has_required_sense(tremor, victim, here, there, g, "tremorsense"), "S191 Tremorsense requires same surface")
	g.get_tile(there).custom_properties.erase("contact_surface_id")
	victim["altitude_feet"] = 5
	check.call(not CombatPerception.has_required_sense(tremor, victim, here, there, g, "tremorsense"), "S191 Tremorsense cannot locate airborne target")
	victim.erase("altitude_feet")
	g.perception_participants = [{"character":tremor, "altitude_feet":5}]
	check.call(not CombatPerception.has_required_sense(tremor, victim, here, there, g, "tremorsense"), "S191 airborne observer cannot use ground Tremorsense")
	g.perception_participants.clear()
	CombatPerception.reveal_location(ordinary, victim, there, g)
	check.call(CombatPerception.can_locate_target(ordinary, victim, here, there, g) and not CombatPerception.can_see_target(ordinary, victim, here, there, g) and not CombatPerception.can_locate_target(dark, victim, here, there, g) and CombatAction.has_condition(victim, "hidden"), "S191 one observer's discovery neither removes Hidden nor reveals location to others")
	check.call(not CombatPerception.can_locate_target(ordinary, victim, here, Vector2i(3, 0), g), "S191 discovery cannot track Hidden movement by exact hex")
	CombatAction.apply_condition(victim, "hidden", 10, "hide_b")
	check.call(not CombatPerception.can_locate_target(ordinary, victim, here, there, g), "S191 new Hide invalidates earlier observer discovery")
	CombatPerception.reveal_location(ordinary, victim, there, g)
	CombatAction.resolve_movement_step(victim, there, Vector2i(3, 0))
	CombatAction.resolve_movement_step(victim, Vector2i(3, 0), there)
	check.call(not CombatPerception.can_locate_target(ordinary, victim, here, there, g), "S191 production movement away and back cannot revive stale Hidden discovery")
	CombatAction.remove_condition_source(victim, "hide_a", ["hidden"])
	CombatAction.remove_condition_source(victim, "hide_b", ["hidden"])
	var modes := CombatPerception.attack_visibility(ordinary, victim, 10, spatial(g))
	check.call(not modes.advantage and modes.disadvantage, "S191 known Invisible target gives actual observer Disadvantage")
	modes = CombatPerception.attack_visibility(blind, victim, 10, spatial(g))
	check.call(not modes.advantage and not modes.disadvantage, "S191 same Invisible target has no concealment roll modifier against Blindsight")
	CombatAction.remove_condition_source(victim, "cloak", ["invisible"])
	_devil_sight(check, g, victim)
	_sources(check, g, ordinary, victim)
	_weapon_and_spell(check, g, ordinary, blind, victim)
	_ai(check, g)
	_sensory_consumer(check, g, ordinary, blind)
	_noise(check)
	g.free()


static func _noise(check: Callable) -> void:
	var g := grid()
	var listener := actor("sound_listener")
	var source := target()
	var here := Vector2i.ZERO
	var there := Vector2i(2, 0)
	var sound := {"volume":"loud", "range_feet":10}
	g.obscurement_sources["fog"] = {"kind":"fog", "coords":[Vector2i(1, 0)]}
	listener.add_condition("blinded", 10)
	check.call(CombatNoiseRules.can_hear(listener, here, there, g, sound, source), "S237 loud sound reaches an inclusive authored distance despite fog and Blinded")
	sound.range_feet = 9
	check.call(not CombatNoiseRules.can_hear(listener, here, there, g, sound, source), "S237 sound outside its authored range is inaudible")
	sound.range_feet = 10
	listener.add_condition("deafened", 10)
	check.call(not CombatNoiseRules.can_hear(listener, here, there, g, sound, source), "S237 Deafened listener cannot hear a sound trigger")
	listener.remove_condition("deafened")
	source.plane = "ethereal"
	check.call(not CombatNoiseRules.can_hear(listener, here, there, g, sound, source), "S237 sound does not cross planes")
	source.erase("plane")
	listener.feature_uses["plane"] = "material"
	check.call(not CombatNoiseRules.can_hear(listener, here, there, g, sound, source, {"plane":"ethereal"}), "S237 sound uses the room plane for actors without their own plane declaration")
	listener.feature_uses.erase("plane")
	g.get_tile(Vector2i(1, 0)).custom_properties["blocks_sound"] = true
	check.call(not CombatNoiseRules.can_hear(listener, here, there, g, sound, source), "S237 a represented sound barrier blocks even a visually clear ray")
	g.get_tile(Vector2i(1, 0)).custom_properties["blocks_sound"] = false
	g.get_tile(Vector2i(1, 0)).custom_properties["blocks_sight"] = true
	check.call(CombatNoiseRules.can_hear(listener, here, there, g, sound, source), "S237 explicitly sound-permeable visual obstruction does not block hearing")
	g.get_tile(there).custom_properties["blocks_sound"] = true
	check.call(not CombatNoiseRules.can_hear(listener, here, there, g, sound, source), "S237 sound at a blocked endpoint cannot bypass a closed door")
	check.call(not CombatNoiseRules.error({"volume":"loud", "range_feet":0}).is_empty() and not CombatNoiseRules.error({"volume":"shout", "range_feet":60}).is_empty() and not CombatNoiseRules.error({"volume":"loud", "range_feet":60, "success":true}).is_empty(), "S237 invalid or invented sound declarations refuse")
	var room := {"walls":[[1, 0]], "wall_details":[{"position":[1, 0], "material":"glass"}], "objects":[]}
	check.call(not LocalRoomRules.blocks_sight(room, Vector2i(1, 0)) and LocalRoomRules.blocks_sound(room, Vector2i(1, 0)), "S237 actual glass wall passes sight while blocking this sound ray")
	g.free()

static func _weapon_and_spell(check: Callable, g: HexGrid, ordinary: Character, blind: Character, victim: Dictionary) -> void:
	g.obscurement_sources["dark"] = {"kind":"magical_darkness", "coords":[Vector2i(1, 0)]}
	var weapon := {"id":"perception_profile", "name":"Test profile", "damage":"1", "range":2, "attack_distance":2, "ability":"INT", "damage_type":"force"}
	var plain := CombatAction.resolve_weapon_attack(ordinary, victim, weapon, false, false, spatial(g))
	var sensed := CombatAction.resolve_weapon_attack(blind, victim, weapon, false, false, spatial(g))
	check.call(plain.has("activity_roll") and not plain.activity_roll.get("advantage", true) and not plain.activity_roll.get("disadvantage", true), "S190 mutual lack of sight cancels attack roll modifiers")
	check.call(sensed.get("activity_roll", {}).get("advantage", false) and not sensed.get("activity_roll", {}).get("disadvantage", true), "S190 actual weapon roll gains one-sided Blindsight advantage")
	var spell := DataLoader.get_spell("fixture:known_bolt")
	var result := CombatAction.resolve_spell(blind, victim, spell, false, spatial(g), [], 0, 10)
	check.call(result.get("success", false) and result.get("attack_advantage", false) and not result.get("attack_disadvantage", true), "S190 data-defined shared attack uses one-sided special sight")
	for id in ["fixture:sight_bolt", "fixture:renamed_sight_bolt"]:
		result = CombatAction.resolve_spell(ordinary, victim, DataLoader.get_spell(id), false, spatial(g), [], 0, 10)
		check.call(not result.get("success", true), "S190 renamed sight-required resolver refuses actual darkness: " + id)
	blind.add_condition("blinded", 10)
	result = CombatAction.resolve_spell(blind, victim, spell, false, spatial(g), [], 0, 10)
	check.call(result.get("attack_advantage", false) and not result.get("attack_disadvantage", true), "S190 Blinded special-sense caster retains correct shared roll mode")
	blind.remove_condition("blinded")
	g.obscurement_sources.clear()
	ordinary.add_condition("hidden", 10)
	CombatAction.resolve_weapon_attack(ordinary, victim, weapon, false, false, spatial(g))
	check.call(not ordinary.has_condition("hidden"), "S191 actual weapon attack reveals attacker after capturing concealment")
	ordinary.add_condition("hidden", 10)
	var hidden_spell := CombatAction.resolve_spell(ordinary, victim, DataLoader.get_spell("fixture:known_bolt"), false, spatial(g), [], 0, 10)
	check.call(hidden_spell.get("attack_advantage", false) and not ordinary.has_condition("hidden"), "S191 shared spell attack captures concealment then reveals attacker")
	ordinary.add_condition("hidden", 10)
	var types: Array[String] = []
	var capture := func(roll: Dictionary):
		if int(roll.get("sides", 0)) == 20 or str(roll.get("type", "")) in ["advantage", "disadvantage"]: types.append(str(roll.get("type", "")))
	Dice.dice_rolled.connect(capture)
	SpellProjectileResolver._resolve_scorching_ray(ordinary, victim, DataLoader.get_spell("scorching_ray"), spatial(g), 2, 10)
	Dice.dice_rolled.disconnect(capture)
	check.call(types.count("advantage") == 1 and not ordinary.has_condition("hidden"), "S191 projectile attacks recheck sight after first ray reveals Hidden attacker")

static func _ai(check: Callable, g: HexGrid) -> void:
	var hidden := actor("hidden_player")
	hidden.add_condition("invisible", 10)
	var monster := target()
	monster.id = "observer_a"; monster.hex_position = Vector2i.ZERO
	monster["attacks"] = [{"name":"Shot", "damage":"1", "range":6}]
	var players := [{"character":hidden, "hex_position":Vector2i(2, 0)}]
	var decision := AIController.get_monster_action(monster, Vector2i.ZERO, g, players)
	check.call(decision.get("action") == "attack" and AICommand.from_decision(decision, monster, players, g) != null, "S191 ordinary AI may attack a known Invisible location")
	hidden.add_condition("hidden", 10)
	check.call(AIController.get_monster_action(monster, Vector2i.ZERO, g, players).get("action") == "none", "S191 ordinary AI cannot select unknown Hidden occupied hex")
	CombatPerception.reveal_location(monster, hidden, Vector2i(2, 0), g)
	decision = AIController.get_monster_action(monster, Vector2i.ZERO, g, players)
	var other := monster.duplicate(true); other.id = "observer_b"
	check.call(decision.get("action") == "attack" and AIController.get_monster_action(other, Vector2i.ZERO, g, players).get("action") == "none", "S191 observer discovery changes only that AI's selection")
	var stale := AICommand.from_decision(decision, monster, players, g)
	hidden.add_condition("hidden", 10)
	check.call(stale != null and not stale.can_execute_attack(monster, players, g, Vector2i.ZERO), "S191 stale AI intent rechecks discovery before attack")
	hidden.remove_condition("hidden")
	var visible := actor("visible_player")
	players.append({"character":visible, "hex_position":Vector2i(0, 3)})
	g.get_tile(Vector2i(1, 0)).custom_properties["blocks_sight"] = true
	decision = AIController.get_monster_action(monster, Vector2i.ZERO, g, players)
	check.call(decision.get("target_id") == visible.character_name and AICommand.from_decision(decision, monster, players, g) != null, "S190 AI chooses legal visible candidate when closest known target is obstructed")
	g.get_tile(Vector2i(1, 0)).custom_properties["blocks_sight"] = false
	monster["spells"] = [{"id":"fixture:sight_bolt"}, {"id":"fixture:known_bolt"}]
	players.resize(1)
	decision = AIController.get_monster_action(monster, Vector2i.ZERO, g, players)
	check.call(decision.get("spell_id") == "fixture:known_bolt" and AICommand.from_decision({"action":"cast_spell", "target_id":hidden.character_name, "spell_id":"fixture:sight_bolt"}, monster, players, g) == null, "S190 AI chooses non-sight spell for known Invisible target and rejects forged sight spell intent")
	monster["senses"] = {"blindsight":10}
	decision = AIController.get_monster_action(monster, Vector2i.ZERO, g, players)
	var sight_command := AICommand.from_decision(decision, monster, players, g)
	check.call(decision.get("spell_id") == "fixture:sight_bolt" and sight_command != null, "S190 same AI observer gains sight-spell selection only within actual special-sense range")
	monster.erase("senses")
	check.call(sight_command != null and not sight_command.is_valid(monster, players, g), "S190 AI sight-spell intent revalidates source removal before execution")

static func _sensory_consumer(check: Callable, g: HexGrid, caster: Character, observer: Character) -> void:
	var host := SpellCastContext.new()
	host.caster = caster; host.grid = g
	host.spell_origin = Vector2i(8, 0)
	host.players = [{"character":caster, "hex_position":Vector2i.ZERO}, {"character":observer, "hex_position":Vector2i(2, 0)}]
	var cast := SpellResolutionContext.new()
	cast.caster = caster; cast.target = observer; cast.spatial_host = host
	check.call(SpellDamageRolls._required_sense_available(observer, cast, "blindsight"), "S190 sensory consumer measures to actual caster, not distant effect origin")
	g.get_tile(Vector2i(1, 0)).custom_properties["blocks_sight"] = true
	check.call(not SpellDamageRolls._required_sense_available(observer, cast, "see"), "S190 sensory consumer obeys actual obstruction despite special sense")
	g.get_tile(Vector2i(1, 0)).custom_properties["blocks_sight"] = false
	var monster := target()
	monster.hex_position = Vector2i.ZERO
	monster["conditions"] = {"invisible":10}
	monster["senses"] = {"blindsight":10}
	monster["blindsight_range_feet"] = 0
	check.call(CombatPerception._has_blindsight(monster, 10), "S190 zero default range cannot erase a declared native monster sense")
	var projected := CombatState._make_temp_monster_character(monster)
	cast.caster = projected; cast.spatial_host = null
	cast.decisions = spatial(g)
	g.perception_participants = [{"character":observer, "hex_position":Vector2i(2, 0)}]
	check.call(SpellDamageRolls._required_sense_available(observer, cast, "see"), "S190 monster spell sensory requirement sees actual Invisible caster through recipient's Blindsight")
	monster.hex_position = Vector2i(-1, 0)
	check.call(not SpellDamageRolls._required_sense_available(observer, cast, "see"), "S190 monster sensory requirement rechecks live caster movement rather than captured invocation position")
	g.perception_participants.clear()

static func _sources(check: Callable, g: HexGrid, observer: Character, victim: Dictionary) -> void:
	var spell := DataLoader.get_spell("see_invisibility")
	var source := SpellEffects.begin_cast(observer, spell)
	SpellEffects.grant(observer, source, "see_invisibility")
	CombatAction.apply_condition(victim, "invisible", 10, "cloak")
	check.call(CombatPerception.can_see_target(observer, victim, Vector2i.ZERO, victim.hex_position, g), "S191 native See Invisibility source supplies actual sight")
	SpellEffects.remove(observer, str(source.source_id))
	check.call(not CombatPerception.can_see_target(observer, victim, Vector2i.ZERO, victim.hex_position, g) and CombatPerception.can_locate_target(observer, victim, Vector2i.ZERO, victim.hex_position, g), "S191 ending native sight source restores Invisible without erasing known location")
	CombatAction.remove_condition_source(victim, "cloak", ["invisible"])
	var zones := CombatSpellZones.new()
	zones.hex_grid = g
	zones.monster_entities = [victim]
	zones.active_spell_zones["neutral:shade"] = {"spell_id":"renamed:shade", "obscurement_kind":"magical_darkness", "coords":[Vector2i(1, 0)]}
	zones.active_spell_zones["other:shade"] = {"spell_id":"different:shade", "obscurement_kind":"magical_darkness", "coords":[Vector2i(1, 0)]}
	zones._refresh_darkness_conditions()
	check.call(not CombatPerception.can_see_target(observer, victim, Vector2i.ZERO, victim.hex_position, g), "S190 renamed area source uses declared obstruction kind")
	zones._remove_spell_zone("neutral:shade")
	check.call(g.obscurement_sources.has("other:shade") and not CombatPerception.can_see_target(observer, victim, Vector2i.ZERO, victim.hex_position, g), "S190 removing one source retains overlapping obstruction")
	zones._remove_spell_zone("other:shade")
	check.call(CombatPerception.can_see_target(observer, victim, Vector2i.ZERO, victim.hex_position, g), "S190 ending last source restores sight")
	CombatAction.apply_condition(victim, "fog_cloud_obscured", 10)
	zones.active_spell_zones["unrelated"] = {"spell_id":"other"}
	zones._remove_spell_zone("unrelated")
	check.call(CombatAction.has_condition(victim, "fog_cloud_obscured"), "S190 unrelated source ending preserves native unsourced fog consumer")
	victim.conditions.erase("fog_cloud_obscured")

static func _devil_sight(check: Callable, g: HexGrid, victim: Dictionary) -> void:
	var warlock := Character.new()
	warlock.initialize("devil_sight", "human", "warlock", AbilityScores.new())
	warlock.character_id = "devil_sight"
	while warlock.level < 3: warlock.level_up()
	warlock.warlock_invocations.assign(["devils_sight"])
	g.obscurement_sources["dark"] = {"kind":"magical_darkness", "coords":[Vector2i(1, 0)]}
	check.call(CombatPerception.can_see_target(warlock, victim, Vector2i.ZERO, victim.hex_position, g), "S190 native selected Devil's Sight uses authored magical Darkvision")
	warlock.add_condition("blinded", 10)
	check.call(not CombatPerception.can_see_target(warlock, victim, Vector2i.ZERO, victim.hex_position, g), "S190 Devil's Sight does not overcome Blinded")
	warlock.remove_condition("blinded")
	CombatAction.apply_condition(victim, "invisible", 10, "cloak")
	check.call(not CombatPerception.can_see_target(warlock, victim, Vector2i.ZERO, victim.hex_position, g), "S190 Devil's Sight does not grant Invisible sight")
	CombatAction.remove_condition_source(victim, "cloak", ["invisible"])
	warlock.warlock_invocations.clear()
	check.call(not CombatPerception.can_see_target(warlock, victim, Vector2i.ZERO, victim.hex_position, g), "S190 removing selected invocation removes its darkness exception")
	g.obscurement_sources.clear()
