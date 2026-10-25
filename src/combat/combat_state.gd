## Combat State Controller
## Manages tactical round initiative, player actions, enemy AI turns, and win/lose checks.
class_name CombatState
extends Node2D

const CombatActivityRecordModel = preload("res://src/activity/combat_activity_record.gd")

@onready var hex_grid: HexGrid = $HexGrid
@onready var hud: CombatHUD = $CombatHUD
@onready var cam: Camera2D = $Camera2D
@onready var fx_layer: Node2D = $FxLayer


# Initiative queue
var tracker: InitiativeTracker = InitiativeTracker.new()
var action_history := CombatActionHistory.new()

# Tactical entities state
# Maps entity_id -> position (Vector2i)
var player_entities: Array[Dictionary] = [] # Elements same as PlayerManager.players
var last_reaction_trigger_receipts: Array[Dictionary] = [] # Batch 065: receipts of the last fired reaction trigger.
var monster_entities: Array[Dictionary] = [] # Keys: name, monster_id, current_hp, max_hp, armor_class, speed, attacks, hex_position, color, is_alive
var dropped_combat_items: Array[Dictionary] = []
var dancing_light_sets: Dictionary = {}
var light_spell_markers: Dictionary = {} # caster_id -> marker
var mage_hand_markers: Dictionary = {} # caster_id -> hand
var minor_illusion_markers: Dictionary = {} # caster_id -> illusion
var prestidigitation_effects: Dictionary = {} # caster_id -> active visible effects
var produce_flame_markers: Dictionary = {} # caster_id -> active held flame
var _spell_boundary_rounds: Dictionary = {}
var _detect_evil_and_good_targets: Dictionary = {}
var _detect_poison_and_disease_targets: Dictionary = {}
var _area_spells := CombatSpellZones.new()
var active_spell_zones: Dictionary: # Compatibility view of encounter-local area records.
	get: return _area_spells.active_spell_zones
	set(value): _area_spells.active_spell_zones = value
var _spell_zone_serial: int:
	get: return _area_spells._spell_zone_serial
	set(value): _area_spells._spell_zone_serial = value

# Input states
var current_player_idx: int = -1
var active_combatant: Dictionary = {} # Reference from tracker
var active_character: Character = null # If active_combatant is player
var remaining_speed: float = 0.0
var _movement_speed_shortfall := 0.0
var _movement_speed_owner: Character
var _movement_speed_snapshot := 0.0
var active_movement_mode := "walk"
var extra_movement_speed_hexes := 0.0
var player_moved_this_turn: bool = false
var rogue_steady_aim_armed: bool = false
var turn_budget: CombatTurnBudget = CombatTurnBudget.new()

# Targeting action mode
var pending_action_type: String = "" # "attack", "spell", "lay_on_hands", "bardic_inspiration", "unarmed_attack"
var resolving_player_action := false
var pool_recovery := CombatPoolRecovery.new()
var _pool_recovery_pending := false
var pending_spell_data: Dictionary = {}
var pending_divine_intervention := false
var pending_divine_intervention_wish := false
var pending_words_primary_target := Vector2i.ZERO
var pending_words_primary_selected := false
var pending_command_target_coords: Array[Vector2i] = []
var pending_command_target_ids: Array[String] = []
var pending_feature_data: Dictionary = {}
var fighter_move_choices: Dictionary = {}
var fighter_move_waiting := false
var fighter_move_done := false
var fighter_move_entity: Dictionary = {}
var remaining_attack_swings := 0
## Batch 070: swings this Attack action granted in total (spent = total - remaining).
var attack_action_total := 0
## Batch 077 (#39 follow-up): a damage-type pick that its rule declares lasts
## the whole Attack action ({source_instance_id, damage_type}); {} otherwise.
## In memory only and cleared whenever a new Attack action is spent.
var attack_action_damage_choice := {}
var attack_unit_substitution: Dictionary = {}
var child_actions := CombatChildActions.new()
var remaining_flurry_swings := 0
var strike_unit_parent := "attack"
var _cast_in_progress := false
var light_attack_weapon: Dictionary = {}
## Last completed input-driven shared spell's damage component receipts.
var last_spell_damage_receipts: Array[Dictionary] = []
## Last completed incoming monster weapon result, including each settled component.
var last_automatic_death_save: Dictionary = {}
var last_monster_weapon_attack_result: Dictionary = {}

# Guards against double-triggering battle end (victory/defeat).
var _battle_ending := false
## Initiative stays encounter-local, but recall does not reroll the same familiar.
var familiar_initiative: Dictionary = {}

# Last computed enemy intent preview text (drawn above monster tokens).
var _intent_preview: String = ""

# Hexes currently showing the move-path preview (cleared before redraw).
var _path_preview_hexes: Array[Vector2i] = []

# Whether the first-turn hint has been shown (show once per battle).
var _hint_shown := false

# A disconnected controller keeps ownership of its current combatant. The
# turn waits in place until that stable seat is rebound.
var _waiting_for_owner_rebind := false
var _rebind_wait_before_turn_setup := false


func _ready() -> void:
	hud.turn_budget = turn_budget
	# Connect HUD action selectors
	hud.action_selected.connect(_on_hud_action)
	hud.cancel_pressed.connect(_cancel_pending_action)
	hud.movement_mode_selected.connect(_on_movement_mode_selected)
	hud.flight_altitude_delta.connect(_on_flight_altitude_delta)
	hud.settings_pressed.connect(func(): Settings.open_settings(self))
	hud.sheet_pressed.connect(_on_sheet_pressed)
	PlayerManager.device_binding_changed.connect(_on_device_binding_changed)
	hex_grid.hex_clicked.connect(_on_hex_clicked)
	hex_grid.hex_hovered.connect(_on_hex_hovered)

	# Center the hex grid in the visible area between the left sidebar and right activity rail
	hex_grid.position = Vector2.ZERO
	cam.position = Vector2.ZERO

	# Build small tactical grid (radius 4)
	hex_grid.tiles.clear()
	var center := Vector2i.ZERO
	var cells := HexUtils.get_hexes_in_range(center, 4)
	if not LocalRoomCombat.room().is_empty():
		cells.clear()
		for cell in LocalRoomCombat.room()["cells"]: cells.append(LocalRoomRules.coord(cell))
	var terrain_str: String = GameManager.transition_context.get("terrain", "plains")
	var terrain_type = HexTile.TERRAIN_MAP.get(terrain_str, HexTile.TerrainType.PLAINS)

	for cell in cells:
		var tile := HexTile.new()
		tile.coord = cell
		tile.terrain = terrain_type
		tile.is_revealed = true
		tile.is_visible = true
		hex_grid.add_tile(tile)

	LocalRoomCombat.bind_grid(hex_grid)
	var room_illumination := str(LocalRoomCombat.room().get("ambient_light", "bright"))
	var encounter_illumination := str(GameManager.transition_context.get("ambient_light", room_illumination))
	CombatPerception.configure_ambient_light(hex_grid, encounter_illumination)
	# Populate players
	_setup_combat_monsters()
	_setup_combat_players()
	active_spell_zones = LocalRoomCombat.restore_spell_zones(player_entities)
	for source_id in active_spell_zones:
		var restored_zone: Dictionary = active_spell_zones[source_id]
		if str(restored_zone.get("spell_id", "")) == "moonbeam":
			var shape_locked_targets: Array = []
			var shape_lock_source := "%s:shape_lock" % str(source_id)
			for target in _spell_effect_targets():
				if target is Character and target.condition_sources.get("moonbeam_shape_lock", {}).has(shape_lock_source):
					shape_locked_targets.append(target)
				elif not target is Character and CombatAction.has_condition_source(target, shape_lock_source):
					shape_locked_targets.append(target)
			restored_zone["shape_locked_targets"] = shape_locked_targets
			continue
		if str(restored_zone.get("spell_id", "")) not in ["black_tentacles", "grease", "spike_growth", "entangle", "sleet_storm"]: continue
		hex_grid.add_difficult_terrain(str(source_id), restored_zone.get("coords", []))
		var restrained_targets: Array = []
		for target in _spell_effect_targets():
			var has_source := false
			if target is Character:
				for grants in target.condition_sources.values():
					if grants.has(str(source_id)): has_source = true; break
			else:
				has_source = CombatAction.has_condition_source(target, str(source_id))
			if has_source:
				restrained_targets.append(target)
		restored_zone["restrained_targets"] = restrained_targets

	# Build initiative tracker
	_roll_initiative_and_start()
	_update_grid_entities()


func _on_sheet_pressed() -> void:
	# Resolve the character when the button is pressed. A connection-time
	# closure would capture the null pre-turn value from _ready().
	CharacterSheet.show_sheet(active_character)


func _update_grid_entities() -> void:
	LocalRoomCombat.bind_grid(hex_grid)
	ItemProjectionRules.refresh(self)
	ClericRules.reconcile_turning(monster_entities, player_entities)
	SpellEffects.reconcile(_spell_casters(), _spell_effect_targets())
	_validate_identify_contacts()
	_refresh_fog_cloud_conditions()
	_refresh_darkness_conditions()
	_refresh_aura_of_life_protection()
	_enforce_tether_range() # Review 045 R1: a tether beyond its range ends as soon as positions change, not at round end.
	if hex_grid == null:
		return
	hex_grid.clear_entities()
	var active_character_id := active_character.character_id if active_character != null else ""
	hud.light_marker_active = light_spell_markers.has(active_character_id)
	hud.mage_hand_active = mage_hand_markers.has(active_character_id)
	_cleanup_dead_familiars()
	_sync_find_steeds()
	AuraRules.refresh_party_context(player_entities)
	
	# Add players
	for p in player_entities:
		if p.get("character") != null and p["character"].is_alive:
			var character: Character = p["character"]
			var emanation_source := _conjure_minor_elementals_zone_source_for_caster(character)
			var emanation_zone: Dictionary = active_spell_zones.get(emanation_source, {})
			var woodland_source := _conjure_woodland_beings_zone_source_for_caster(character)
			var woodland_zone: Dictionary = active_spell_zones.get(woodland_source, {})
			var guardians_source := _spirit_guardians_zone_source_for_caster(character)
			var guardians_zone: Dictionary = active_spell_zones.get(guardians_source, {})
			var life_source := _aura_of_life_zone_source_for_caster(character)
			var life_zone: Dictionary = active_spell_zones.get(life_source, {})
			var emanation_radius := int(emanation_zone.get("radius_hexes", woodland_zone.get("radius_hexes", guardians_zone.get("radius_hexes", life_zone.get("radius_hexes", 0)))))
			var emanation_color := Color(0.6, 0.83, 0.96) if not emanation_zone.is_empty() else Color(0.58, 0.9, 0.72) if not woodland_zone.is_empty() else Color(0.86, 0.78, 0.48) if not guardians_zone.is_empty() else Color(0.68, 0.9, 0.84)
			hex_grid.add_entity({
				"hex_position": p.get("hex_position", Vector2i.ZERO),
				"color": p.get("color", Color.WHITE),
				"is_player": true,
				"character": character,
				"spell_emanation_radius_hexes": emanation_radius,
				"spell_emanation_color": emanation_color,
			})
			for light_record in character.inventory.owned_instances():
				var bright_radius := LightSourceRules.bright_radius_hexes(light_record)
				var dim_radius := LightSourceRules.dim_radius_hexes(light_record)
				if dim_radius <= 0:
					continue
				hex_grid.add_entity({
					"hex_position": p.get("hex_position", Vector2i.ZERO),
					"color": Color(1.0, 0.78, 0.36),
					"is_physical_light_source": true,
					"light_instance_id": str(light_record.get("instance_id", "")),
					"bright_light_radius_hexes": bright_radius,
					"dim_light_radius_hexes": dim_radius,
				})
	
	# Add monsters
	for m in monster_entities:
		if m.get("is_alive", true):
			hex_grid.add_entity({
				"hex_position": m.get("hex_position", Vector2i.ZERO),
				"color": m.get("color", Color.RED),
				"is_player": false,
				"monster": m
			})
	for zone in active_spell_zones.values():
		if str(zone.get("spell_id", "")) == "conjure_elemental":
			hex_grid.add_entity({
				"hex_position": zone.get("center", Vector2i.ZERO),
				"color": Color(0.55, 0.82, 0.95),
				"is_conjure_elemental": true,
				"element": str(zone.get("element", "air")),
				"size": "Large",
			})
		elif str(zone.get("spell_id", "")) == "conjure_fey":
			hex_grid.add_entity({
				"hex_position": zone.get("center", Vector2i.ZERO),
				"color": Color(0.84, 0.63, 0.97),
				"is_conjure_fey": true,
				"size": "Medium",
			})
	for light_set in dancing_light_sets.values():
		for light_index in light_set.get("positions", []).size():
			var light_coord: Array = light_set["positions"][light_index]
			hex_grid.add_entity({
				"hex_position": Vector2i(int(light_coord[0]), int(light_coord[1])),
				"color": Color(0.65, 0.9, 1.0),
				"is_player": false,
				"is_dancing_light": true,
				"light_index": light_index,
				"humanoid_form": bool(light_set.get("humanoid_form", false)),
				"dim_light_radius_hexes": int(light_set.get("dim_light_radius_hexes", DancingLightsRules.DIM_LIGHT_RADIUS_HEXES)),
			})
	for light_spell_marker in light_spell_markers.values():
		var light_coord: Array = light_spell_marker.get("position", [0, 0])
		hex_grid.add_entity({
			"hex_position": Vector2i(int(light_coord[0]), int(light_coord[1])),
			"color": Color(1.0, 0.85, 0.38),
			"is_spell_light": true,
			"bright_light_radius_hexes": LightRules.BRIGHT_RADIUS_HEXES,
			"dim_light_radius_hexes": LightRules.DIM_RADIUS_HEXES,
		})
	for mage_hand_marker in mage_hand_markers.values():
		var hand_coord: Array = mage_hand_marker.get("position", [0, 0])
		hex_grid.add_entity({
			"hex_position": Vector2i(int(hand_coord[0]), int(hand_coord[1])),
			"color": Color(0.72, 0.58, 1.0),
			"is_mage_hand": true,
		})
	for illusion in minor_illusion_markers.values():
		var illusion_coord: Array = illusion.get("position", [0, 0])
		hex_grid.add_entity({
			"hex_position": Vector2i(int(illusion_coord[0]), int(illusion_coord[1])),
			"color": Color(0.56, 0.66, 1.0) if str(illusion.get("form", "")) == "sound" else Color(0.78, 0.57, 1.0),
			"is_minor_illusion": true,
			"form": str(illusion.get("form", "")),
			"description": str(illusion.get("description", "")),
		})
	for effects_value in prestidigitation_effects.values():
		for effect in effects_value:
			var effect_coord: Array = effect.get("position", [0, 0])
			hex_grid.add_entity({
				"hex_position": Vector2i(int(effect_coord[0]), int(effect_coord[1])),
				"color": Color(0.94, 0.77, 0.43) if str(effect.get("effect_type", "")) == "magic_mark" else Color(0.54, 0.85, 0.74),
				"is_prestidigitation": true,
				"effect_type": str(effect.get("effect_type", "")),
				"description": str(effect.get("description", "")),
			})
	for caster_id_value in produce_flame_markers.keys().duplicate():
		var caster_id := str(caster_id_value)
		var flame: Dictionary = produce_flame_markers[caster_id]
		var flame_caster_found := false
		for player in player_entities:
			var flame_caster: Character = player.get("character")
			if flame_caster == null or flame_caster.character_id != caster_id:
				continue
			flame_caster_found = true
			if not flame_caster.is_alive:
				produce_flame_markers.erase(caster_id)
				break
			var held_position: Vector2i = player.get("hex_position", Vector2i.ZERO)
			flame["position"] = [held_position.x, held_position.y]
			produce_flame_markers[caster_id] = flame
			break
		if not flame_caster_found or not produce_flame_markers.has(caster_id):
			produce_flame_markers.erase(caster_id)
			continue
		var flame_coord: Array = flame.get("position", [0, 0])
		hex_grid.add_entity({
			"hex_position": Vector2i(int(flame_coord[0]), int(flame_coord[1])),
			"color": Color(1.0, 0.45, 0.12),
			"is_produce_flame": true,
			"bright_light_radius_hexes": ProduceFlameRules.BRIGHT_LIGHT_RADIUS_HEXES,
			"dim_light_radius_hexes": ProduceFlameRules.DIM_LIGHT_RADIUS_HEXES,
		})


	LocalRoomCombat.add_objects(hex_grid)
	for dropped_object in dropped_combat_items:
		if bool(dropped_object.get("removed", false)) or int(dropped_object.get("hp", 1)) <= 0:
			continue
		var raw_position: Array = dropped_object.get("position", [0, 0])
		hex_grid.add_entity({
			"hex_position": Vector2i(int(raw_position[0]), int(raw_position[1])),
			"world_object": dropped_object,
		})
	_refresh_detect_evil_and_good_senses()
	_refresh_detect_poison_and_disease_senses()


func _refresh_detect_evil_and_good_senses() -> void:
	SpellEncounterPerception._refresh_detect_evil_and_good_senses(_spell_cast_context())


func _refresh_detect_poison_and_disease_senses() -> void:
	SpellEncounterPerception._refresh_detect_poison_and_disease_senses(_spell_cast_context())


func _familiar_spawn_position(owner: Dictionary, radius: int = 2, restore_position: bool = true) -> Vector2i:
	var owner_character: Character = owner.get("character")
	var origin: Vector2i = owner.get("hex_position", Vector2i.ZERO)
	var saved := FamiliarRules.position(owner_character, str(LocalRoomCombat.room().get("id", "")))
	var candidates: Array[Vector2i] = []
	if restore_position and saved != FamiliarRules.ABSENT:
		candidates.append(saved)
	candidates.append_array(HexUtils.get_hexes_in_range(origin, radius))
	for candidate in candidates:
		if candidate == origin or not hex_grid.has_tile(candidate) or not hex_grid.is_hex_passable(candidate): continue
		if LocalRoomRules.requires_surface_traversal(str(hex_grid.tiles[candidate].custom_properties.get("surface", "floor"))): continue
		var occupied := false
		for entity in player_entities:
			if entity.get("is_familiar", false) and entity.get("familiar_owner") == owner_character: continue
			if entity.get("hex_position") == candidate: occupied = true; break
		for monster in monster_entities:
			if monster.get("is_alive", true) and monster.get("hex_position") == candidate: occupied = true; break
		if not LocalRoomCombat.room().is_empty() and not LocalRoomRules.object_at(LocalRoomCombat.room(), candidate).is_empty(): occupied = true
		if not occupied: return candidate
	return FamiliarRules.ABSENT


func _add_wild_companion_entity(owner: Dictionary, add_to_initiative: bool, requested_position: Vector2i = FamiliarRules.ABSENT) -> Dictionary:
	var owner_character: Character = owner.get("character")
	var familiar := FamiliarRules.character(owner_character)
	if familiar == null:
		return {"success": false, "message": "No familiar is present."}
	var familiar_pos := requested_position if requested_position != FamiliarRules.ABSENT else _familiar_spawn_position(owner)
	if familiar_pos == FamiliarRules.ABSENT:
		return {"success": false, "message": "No unoccupied space is available for the familiar."}
	for existing in player_entities.duplicate():
		if existing.get("is_familiar", false) and existing.get("familiar_owner") == owner_character:
			tracker.remove_combatant(str(existing.get("combat_id", "")))
			player_entities.erase(existing)
	var combat_id := familiar.character_id
	var entity := {
		"name": familiar.character_name, "display_name": familiar.character_name,
		"player_id": int(owner.get("player_id", 0)) + 1000,
		"owner_player_index": int(owner.get("owner_player_index", -1)),
		"character": familiar, "hex_position": familiar_pos, "reaction_available": true,
		"color": owner.get("color", Color.WHITE), "is_familiar": true,
		"familiar_owner": owner_character, "combat_id": combat_id,
		"familiar_form_id": str(FamiliarRules.state(owner_character).get("form_id", "")),
		"size": familiar.get_creature_size(),
	}
	player_entities.append(entity)
	if add_to_initiative:
		var dex := familiar.ability_scores.get_score("DEX")
		var initiative: Dictionary = familiar_initiative.get(combat_id, {})
		if initiative.is_empty():
			var fam_init_d20 := RollTokenRules.resolve_d20_test(familiar, "initiative", false, false, {})
			initiative = {"roll": int(fam_init_d20.get("total", 1)) + AbilityScores.get_modifier(dex), "dex": dex}
			familiar_initiative[combat_id] = initiative
		tracker.add_combatant(combat_id, familiar.character_name, true, familiar, int(initiative["roll"]), int(initiative["dex"]))
		tracker.sort_initiative_preserving_active()
	_update_grid_entities()
	return {"success": true, "entity": entity}


func _add_find_steed_entity(owner: Dictionary, requested_position: Vector2i = Vector2i(9999, 9999), add_to_initiative: bool = false) -> Dictionary:
	var owner_character: Character = owner.get("character")
	var state := PaladinRules.find_steed_state(owner_character)
	if owner_character == null or state.is_empty() or owner_character.disintegrated or owner_character.death_save_failures >= 3 or int(state.get("current_hp", 0)) <= 0:
		return {"success": false, "message": "There is no living bonded steed to summon."}
	var summon: Dictionary = DataLoader.get_spell("find_steed").get("summoned_creature", {})
	var appearance := str(state.get("form", "horse"))
	var steed := Character.new()
	var scores := AbilityScores.new()
	scores.from_dict(state.get("ability_scores", summon.get("ability_scores", {})))
	steed.initialize("%s's %s" % [owner_character.character_name, appearance.capitalize()], "", "familiar", scores)
	steed.character_id = "paladin_steed_%s" % (owner_character.character_id if not owner_character.character_id.is_empty() else str(owner_character.get_instance_id()))
	steed.level = owner_character.level
	steed.proficiency_bonus = owner_character.proficiency_bonus
	steed.base_ac = int(state.get("armor_class", 12))
	steed.max_hp = int(state.get("max_hp", 25))
	steed.current_hp = clampi(int(state.get("current_hp", steed.max_hp)), 1, steed.max_hp)
	steed.speed = maxi(1, int(floor(float(state.get("speed_feet", 60)) / 5.0)))
	steed.set_movement_speed_feet("fly", int(state.get("fly_speed_feet", 0)))
	steed.is_alive = true
	steed.feature_uses["creature_type"] = str(state.get("creature_type", "fey"))
	steed.creature_type = str(state.get("creature_type", "fey"))
	steed.feature_uses["creature_size"] = "large"
	for steed_feature in PaladinRules.find_steed_features(state):
		steed.features.append(steed_feature)
		steed.feature_uses[str(steed_feature.get("id", ""))] = 0 if (str(steed_feature.get("uses_per", "")) == "long_rest" and bool(state.get("long_rest_ability_used", false))) else int(steed_feature.get("uses", 0))
	var owner_position: Vector2i = owner.get("hex_position", Vector2i.ZERO)
	var steed_position := requested_position
	if steed_position == FamiliarRules.ABSENT and not LocalRoomCombat.room().is_empty():
		steed_position = PaladinRules.find_steed_room_position(owner_character, str(LocalRoomCombat.room()["id"]))
		if steed_position != FamiliarRules.ABSENT and (not hex_grid.has_tile(steed_position) or not hex_grid.is_hex_passable(steed_position) or _is_occupied_hex(steed_position)):
			steed_position = FamiliarRules.ABSENT
	var begins_mounted := bool(state.get("mounted", false))
	if steed_position == Vector2i(9999, 9999):
		if begins_mounted:
			steed_position = owner_position
		else:
			steed_position = owner_position
			for candidate in HexUtils.get_hexes_in_range(owner_position, 1):
				if candidate != owner_position and hex_grid.has_tile(candidate) and hex_grid.is_hex_passable(candidate) and not _is_occupied_hex(candidate):
					steed_position = candidate
					break
	if (steed_position == owner_position and not begins_mounted) or not hex_grid.has_tile(steed_position) or not hex_grid.is_hex_passable(steed_position):
		return {"success": false, "message": "No unoccupied space is available for the steed."}
	for existing in player_entities.duplicate():
		if existing.get("is_steed", false) and existing.get("steed_owner") == owner_character:
			tracker.remove_combatant(str(existing.get("combat_id", "")))
			player_entities.erase(existing)
	var owner_index := int(owner.get("owner_player_index", -1))
	var combat_id := "steed_%s" % (owner_character.character_id if not owner_character.character_id.is_empty() else str(owner_character.get_instance_id()))
	var entity := {
		"name": steed.character_name,
		"display_name": steed.character_name,
		"player_id": int(owner.get("player_id", 0)) + 2000,
		"owner_player_index": owner_index,
		"character": steed,
		"hex_position": steed_position,
		"reaction_available": true,
		"color": owner.get("color", Color.WHITE),
		"is_steed": true,
		"steed_owner": owner_character,
		"steed_creature_type": str(state.get("creature_type", "celestial")),
		"steed_spell_level": int(state.get("spell_level", 2)),
		"steed_speed_feet": int(state.get("speed_feet", 60)),
		"steed_fly_speed_feet": int(state.get("fly_speed_feet", 0)),
		"mounted": begins_mounted,
		"combat_id": combat_id,
	}
	player_entities.append(entity)
	if add_to_initiative:
		var dex := steed.ability_scores.get_score("DEX")
		var owner_roll := int(active_combatant.get("roll", 0))
		dex = int(active_combatant.get("dex", dex))
		tracker.add_combatant(combat_id, steed.character_name, true, steed, owner_roll, dex)
		tracker.sort_initiative_preserving_active()
	_update_grid_entities()
	return {"success": true, "entity": entity}


func _sync_find_steeds() -> void:
	for entity in player_entities.duplicate():
		if not entity.get("is_steed", false):
			continue
		var steed: Character = entity.get("character")
		var owner: Character = entity.get("steed_owner")
		if steed == null or owner == null or owner.disintegrated or owner.death_save_failures >= 3 or not steed.is_alive or PaladinRules.find_steed_state(owner).is_empty():
			PaladinRules.dismiss_find_steed(owner)
			tracker.remove_combatant(str(entity.get("combat_id", "")))
			player_entities.erase(entity)
			continue
		PaladinRules.update_find_steed_hit_points(owner, steed.current_hp)
		if not LocalRoomCombat.room().is_empty():
			PaladinRules.set_find_steed_room_position(owner, str(LocalRoomCombat.room()["id"]), entity["hex_position"])


func _cleanup_dead_familiars() -> void:
	for entity in player_entities.duplicate():
		if not entity.get("is_familiar", false): continue
		var owner_character: Character = entity.get("familiar_owner")
		var familiar: Character = entity.get("character")
		var record := FamiliarRules.state(owner_character)
		if not record.is_empty() and not bool(record.get("pocket", false)) and familiar != null and familiar.is_alive:
			FamiliarRules.update_hp(owner_character, familiar.current_hp)
			if owner_character.familiar_senses == familiar:
				owner_character.familiar_senses_position = entity["hex_position"]
			if not LocalRoomCombat.room().is_empty():
				FamiliarRules.set_position(owner_character, str(LocalRoomCombat.room()["id"]), entity["hex_position"])
			continue
		if familiar != null and not familiar.is_alive: FamiliarRules.forget(owner_character)
		if owner_character != null: owner_character.familiar_senses = null
		var removed_id := str(entity.get("combat_id", ""))
		for monster in monster_entities:
			if str(monster.get("familiar_helped_by", "")) == removed_id: monster.erase("familiar_helped_by")
		tracker.remove_combatant(str(entity.get("combat_id", "")))
		player_entities.erase(entity)


## --- Combat feedback / juice -------------------------------------------
## Spawn a floating combat-text label at a hex (damage numbers, misses, crits).
## Gated by Settings.show_damage_numbers (a toggle in the settings overlay).
func _spawn_floating_text(coord: Vector2i, text: String, color: Color) -> void:
	if not Settings.show_damage_numbers:
		return
	if fx_layer == null:
		return
	var center := HexUtils.hex_to_pixel(coord)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 22)
	label.position = center - Vector2(0, 24)
	label.z_index = 100
	fx_layer.add_child(label)
	# Pop + float up + fade. No await on the main beat (tween is fire-and-forget).
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", center.y - 64.0, 0.9).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "scale", Vector2(1.25, 1.25), 0.15).from(Vector2(0.6, 0.6))
	tween.chain().tween_callback(label.queue_free)

## Brief camera shake on impact. Gated by Settings.screen_shake.
func _shake_camera(intensity: float = 6.0) -> void:
	if not Settings.screen_shake:
		return
	if cam == null:
		return
	var base := cam.position
	var tween := create_tween()
	for i in 5:
		var off := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(cam, "position", base + off, 0.04)
	tween.tween_property(cam, "position", base, 0.06)

## Flash a hex's occupant by briefly re-highlighting it (cheap hit feedback).
func _flash_hex(coord: Vector2i, color: Color) -> void:
	if hex_grid == null:
		return
	hex_grid.add_highlight(coord, color)
	await get_tree().create_timer(0.12).timeout
	hex_grid.clear_highlights()
	# Restore any action-specific highlights for the active player.
	if pending_action_type == "attack":
		_highlight_attack_targets()
	elif pending_action_type == "spell":
		_highlight_spell_targets()
	else:
		_highlight_reachable()


## Build a human-readable intent string for a monster's planned action.
func _describe_intent(monster: Dictionary, intent: Dictionary) -> String:
	if intent.is_empty():
		return ""
	var action: String = intent.get("action", "none")
	match action:
		"attack", "move_attack":
			var tid: String = intent.get("target_id", "?")
			if action == "move_attack":
				return "Move + Attack %s" % tid
			return "Attack %s" % tid
		"move":
			return "Move"
		"none":
			return "Hold"
		_:
			return action.capitalize()
	return ""


func _setup_combat_players() -> void:
	player_entities = []
	var active_members := PartyManager.get_active_party_members()
	if not active_members.is_empty():
		for i in active_members.size():
			var member: Dictionary = active_members[i]
			var member_character: Character = member["character"]
			var owner_index := int(member.get("owner_player_index", -1))
			player_entities.append({
				"name": member_character.character_name,
				"display_name": member_character.character_name,
				"player_id": i,
				"owner_player_index": owner_index,
				"party_slot_id": member.get("slot_id", ""),
				"is_companion": bool(member.get("is_companion", false)),
				"character": member_character,
				"is_alive": member_character.is_alive,
				"color": PlayerManager.get_player(owner_index).get("color", Color.WHITE) if owner_index >= 0 else Color.WHITE,
			})
	else:
		for p in PlayerManager.players:
			player_entities.append(p.duplicate())
	var player_count := player_entities.size()
	
	# Spawn players on the left side of the tactical grid using the party's
	# validated composition rather than encounter-local character assumptions.
	var spawn_points := PartyManager.get_formation_positions(player_count)
	
	for i in player_count:
		var pos = spawn_points[i]
		var local_position: Array = LocalRoomCombat.room().get("party_positions", {}).get(player_entities[i]["character"].character_id, [pos.x, pos.y])
		player_entities[i]["hex_position"] = LocalRoomRules.coord(local_position)
		var room_state := LocalRoomCombat.room()
		if not room_state.is_empty():
			player_entities[i]["altitude_feet"] = LocalRoomRules.altitude_feet(room_state, player_entities[i]["character"].character_id)
		player_entities[i]["reaction_available"] = true
		var char_data: Character = player_entities[i]["character"]
		if char_data != null:
			char_data.reset_combat_features()
			char_data.is_alive = char_data.current_hp > 0
			char_data.reaction_available = true
	var owners := player_entities.duplicate()
	for owner in owners:
		var owner_character: Character = owner.get("character")
		if owner_character != null and not FamiliarRules.state(owner_character).is_empty():
			_add_wild_companion_entity(owner, false)
		if owner_character != null and not PaladinRules.find_steed_state(owner_character).is_empty():
			_add_find_steed_entity(owner, Vector2i(9999, 9999), false)
	CreatedCreatureCombat.attach(self)
	# Rebuild durable created sources on encounter entry, including after load.
	for entity in owners:
		var owner: Character = entity.get("character")
		if owner != null and not CreatedActorRules.actors(owner).is_empty():
			CreatedActorRules.attach(self, owner, entity.get("hex_position", Vector2i.ZERO))
		if owner != null and not owner.item_projections.is_empty():
			ItemProjectionRules.attach(self, owner, entity.get("hex_position", Vector2i.ZERO))


func _setup_combat_monsters() -> void:
	monster_entities.clear()
	var monster_ids: Array = GameManager.transition_context.get("monster_ids", [])
	if monster_ids.is_empty() and LocalRoomCombat.room().is_empty():
		# Fallback to simple goblins if debug combat launched
		monster_ids = ["goblin", "goblin"]

	# Spawn monsters on the right side of tactical grid
	var spawn_points := [
		Vector2i(3, 0),
		Vector2i(3, -1),
		Vector2i(3, 1),
		Vector2i(2, 0)
	]

	if not LocalRoomCombat.room().is_empty():
		spawn_points.clear()
		for cell in LocalRoomCombat.room()["monster_spawns"]: spawn_points.append(LocalRoomRules.coord(cell))

	for i in monster_ids.size():
		var m_id = monster_ids[i]
		var base_monster := DataLoader.get_monster(m_id)
		if base_monster.is_empty(): continue

		# Make a unique clone for this combat instance
		var hp_str: String = base_monster.get("hit_points", "2d6")
		var max_hp := Dice.parse_dice_string(hp_str)
		
		var monster_inst := {
			"id": "monster_%d" % i,
			"name": "%s %d" % [base_monster.get("name", m_id), i + 1],
			"monster_id": m_id,
			"max_hp": max_hp,
			"current_hp": max_hp,
			"armor_class": int(base_monster.get("armor_class", 10)),
			"speed": int(base_monster.get("speed", 6)),
			"ability_scores": base_monster.get("ability_scores", {}),
			"attacks": base_monster.get("attacks", []),
			"spells": base_monster.get("spells", []).duplicate(true),
			"spell_slots": base_monster.get("spell_slots", {}).duplicate(true),
			"damage_immunities": base_monster.get("damage_immunities", []).duplicate(true),
			"damage_resistances": base_monster.get("damage_resistances", []).duplicate(true),
			"damage_vulnerabilities": base_monster.get("damage_vulnerabilities", []).duplicate(true),
			"senses": base_monster.get("senses", {}).duplicate(true),
			"darkvision_range_feet": int(base_monster.get("darkvision_range_feet", base_monster.get("senses", {}).get("darkvision", 0))),
			"blindsight_range_feet": int(base_monster.get("blindsight_range_feet", base_monster.get("senses", {}).get("blindsight", 0))),
			"truesight_range_feet": int(base_monster.get("truesight_range_feet", base_monster.get("senses", {}).get("truesight", 0))),
			"proficiency_bonus": int(base_monster.get("proficiency_bonus", 2)),
			"fly_speed_feet": int(base_monster.get("fly_speed_feet", 0)),
			"climb_speed_feet": int(base_monster.get("climb_speed_feet", 0)),
			"condition_immunities": base_monster.get("condition_immunities", []).duplicate(true),
			"saving_throw_bonuses": base_monster.get("saving_throw_bonuses", {}).duplicate(true),
			"special_abilities": base_monster.get("special_abilities", []).duplicate(true),
			"loot_table": base_monster.get("loot_table", []).duplicate(true),
			"is_boss": bool(base_monster.get("is_boss", false)),
			"creature_type": str(base_monster.get("creature_type", "")),
			"size": str(base_monster.get("size", "medium")),
			"ai_behavior": base_monster.get("ai_behavior", "aggressive"),
			"hex_position": spawn_points[i % spawn_points.size()],
			"color": Color(0.9, 0.3, 0.3),
			"is_alive": true,
			"conditions": {},
			"delayed_spell_damage": []
		}
		monster_entities.append(monster_inst)


func _roll_initiative_and_start() -> void:
	tracker.clear()
	action_history.reset()
	CombatAction.advance_combat_turn(null)
	CombatAction.reset_bounded_owner_turn_rider_locks()
	var seeded_init_map: Dictionary = GameManager.transition_context.get("initiative_decisions", {}) if GameManager.transition_context.get("initiative_decisions") is Dictionary else {}

	# Roll players
	for i in player_entities.size():
		var p := player_entities[i]
		var char_data: Character = p.get("character")
		if char_data == null or not char_data.is_alive: continue
		if p.get("is_created_actor", false): continue # Batch 056 S-157: joins by its declared initiative below.
		var initiative_recoveries := ClassProgression.apply_initiative_resource_recovery(char_data)
		for recovered_resource in initiative_recoveries:
			var recovery_count := int(initiative_recoveries[recovered_resource])
			hud.add_log("%s regains %d %s use%s at Initiative." % [char_data.character_name, recovery_count, recovered_resource.replace("_", " "), "" if recovery_count == 1 else "s"])
		var used_metabolism := false
		if char_data.has_feature("monk_uncanny_metabolism") and not char_data.feature_uses.get("uncanny_metabolism_used", false) and (char_data.get_focus_points() < char_data.get_max_focus_points() or char_data.current_hp < char_data.max_hp):
			if await hud.request_reaction(_owner_label_for_character(char_data), "uncanny_metabolism", "Restore all Focus and recover hit points (once per Long Rest).", "Use Uncanny Metabolism?", "Recover", "Uncanny Metabolism"):
				var recovery := char_data.use_uncanny_metabolism()
				hud.add_log(recovery.get("message", "Focus restored."))
				used_metabolism = true
		if not used_metabolism and char_data.has_feature("monk_perfect_focus"):
			if MonkRules.apply_perfect_focus(char_data):
				hud.add_log("%s regains Focus up to 4 with Perfect Focus." % char_data.character_name)
		if BarbarianRules.can_recover_rage_at_initiative(char_data):
			var rage_recovery_detail := "Recover all expended uses of Rage (once per Long Rest)."
			if await hud.request_reaction(_owner_label_for_character(char_data), "persistent_rage", rage_recovery_detail, "Recover your Rage uses?", "Recover Rage", "Persistent Rage"):
				var recovered_rages := BarbarianRules.recover_rage_at_initiative(char_data)
				if recovered_rages > 0:
					hud.add_log("%s regains %d uses of Rage." % [char_data.character_name, recovered_rages])
		var dex = char_data.ability_scores.get_score("DEX")
		var mod = AbilityScores.get_modifier(dex)
		var total = mod
		if p.get("is_steed", false):
			var steed_owner: Character = p.get("steed_owner")
			for owner_combatant in tracker.combatants:
				if owner_combatant.get("entity") == steed_owner:
					total = int(owner_combatant.get("roll", total))
					dex = int(owner_combatant.get("dex", dex))
					break
		else:
			var initiative_advantage := char_data.has_feature("champion_remarkable_athlete") or char_data.has_feature_effect("initiative_advantage")
			var char_init_seeded: Dictionary = seeded_init_map.get(char_data.character_id, {}) if seeded_init_map.get(char_data.character_id) is Dictionary else {}
			var init_decisions := await _collect_roll_token_decision(char_data, "initiative", "Initiative roll", char_init_seeded)
			var init_d20 := RollTokenRules.resolve_d20_test(char_data, "initiative", initiative_advantage, false, init_decisions)
			var roll = int(init_d20.get("total", 1)) - char_data.exhaustion_level * 2
			total = roll + mod
			await _recover_combat_pools(char_data, "initiative_rolled", 0)
			if not is_inside_tree(): return
		var owner_index := int(p.get("owner_player_index", -1))
		var turn_name := char_data.character_name
		if owner_index >= 0:
			turn_name += " [Seat %d]" % (owner_index + 1)

		var combatant_id := str(p.get("combat_id", "player_%d" % i))
		if p.get("is_familiar", false): familiar_initiative[combatant_id] = {"roll": total, "dex": dex}
		tracker.add_combatant(
			combatant_id,
			turn_name,
			true,
			char_data,
			total,
			dex
		)

	# Roll monsters
	for m in monster_entities:
		var m_id := str(m.get("id", ""))
		var m_init_seeded: Dictionary = seeded_init_map.get(m_id, {}) if seeded_init_map.get(m_id) is Dictionary else {}
		var m_init_decisions := await _collect_roll_token_decision(m, "initiative", "Initiative roll", m_init_seeded)
		var m_init_d20 := RollTokenRules.resolve_d20_test(m, "initiative", false, false, m_init_decisions)
		var roll = int(m_init_d20.get("total", 1))
		var monster_scores: Dictionary = m.get("ability_scores", {})
		var dex = int(monster_scores.get("DEX", 10))
		var mod = AbilityScores.get_modifier(dex)
		var total = roll + mod

		tracker.add_combatant(
			m["id"],
			m["name"],
			false,
			m,
			total,
			dex
		)

	_interrupt_work_for_combat()
	tracker.sort_initiative()
	for p in player_entities: # Batch 056 S-157: declared initiative for created actors.
		if p.get("is_created_actor", false):
			var created_owner := CreatedCommandRules.owner_entity(self, p)
			if created_owner != null: CreatedCommandRules.join_initiative(self, created_owner, p.character)
	# Initial construction has no interrupted turn to preserve. Include a summon
	# that rolled ahead of the original leader in the first round too.
	tracker.active_index = 0
	_start_combat_turn()


func _start_combat_turn() -> void:
	if _pool_recovery_pending: return
	CreatedCreatureCombat.reconcile(self)
	tracker.mark_turn_started()
	if tracker.get_active().get("scheduling_only", false):
		_start_created_actor_interval()
		return
	var next_entity: Variant = tracker.get_active().get("entity")
	action_history.begin_turn(next_entity, tracker.current_round)
	CombatAction.advance_combat_turn(next_entity if next_entity is Character else null, tracker.current_round)
	if next_entity is Character:
		CombatAction.start_bounded_owner_turn_interval(next_entity)
	for player in player_entities:
		var member: Character = player.get("character")
		if member != null:
			member.feature_uses.erase("stunning_strike_used")
			member.feature_uses.erase("fighter_cleave_used")
			member.feature_uses.erase("sneak_attack_used_this_turn")
	active_combatant = tracker.get_active()
	if active_combatant.is_empty():
		return

	# Clear targeting highlights
	pending_action_type = ""
	hex_grid.clear_highlights()
	_clear_path_preview()

	var is_player: bool = active_combatant["is_player"]
	if is_player:
		# Player Turn
		active_character = active_combatant["entity"]
		CreatedCommandRules.start_owner_turn(self, active_character)
		# This hit restriction ends when the target's next turn begins.
		CombatAction.clear_shocking_grasp(active_character)
		_clear_monk_turn_effects(active_character)
		remaining_attack_swings = 0
		attack_action_total = 0
		attack_action_damage_choice = {}
		light_attack_weapon = {}
		active_character.familiar_senses = null
		active_character.feature_uses.erase("stunning_strike_used")
		if active_character.feature_uses.has("monk_patient_dodge"):
			active_character.remove_condition("dodging")
			active_character.feature_uses.erase("monk_patient_dodge")
		current_player_idx = -1
		for i in player_entities.size():
			if player_entities[i]["character"] == active_character:
				current_player_idx = i
				break
		if current_player_idx >= 0:
			if player_entities[current_player_idx].get("is_steed", false):
				var mounted_owner: Character = player_entities[current_player_idx].get("steed_owner")
				if mounted_owner != null and mounted_owner.is_alive and PaladinRules.find_steed_is_mounted(mounted_owner) and not CombatAction.is_incapacitated(mounted_owner):
					_end_active_turn()
					return
			if not player_entities[current_player_idx].get("is_steed", false):
				active_character.feature_uses.erase("find_steed_mount_transition_used_this_turn")
			await _recover_combat_pools(active_character, "turn_started", tracker.current_round)
			if not is_inside_tree(): return
			_expire_conjure_fey_frightened(active_character)
			await _advance_cloudkill_zones_for_caster(active_character)
			await _resolve_spell_zone_start_turn(active_character, player_entities[current_player_idx].get("hex_position", Vector2i.ZERO))
		_tick_dancing_lights_duration(active_character)
		_tick_light_spell_duration(active_character)
		_tick_mage_hand_duration(active_character)
		_tick_minor_illusion_duration(active_character)
		_tick_prestidigitation_effects(active_character)
		_tick_produce_flame_duration(active_character)
		_tick_protection_from_energy_duration(active_character)
		_tick_protection_from_evil_and_good_duration(active_character)
		_tick_spell_effect_boundary(active_character, "start")
		SpellEffects.reconcile(_spell_casters(), _spell_effect_targets())
		for fall_message in LocalRoomCombat.reconcile_flight_altitudes(player_entities):
			hud.add_log(fall_message)
		if _check_battle_end_conditions():
			return
		SpellEffects.apply_turn_start(active_character)
		_tick_resilient_sphere_duration(active_character)
		_apply_regenerate_turn_start(active_character)
		_refresh_paladin_divine_sense(active_character)
		if active_character.class_id == "familiar" and current_player_idx >= 0:
			var familiar_id := str(player_entities[current_player_idx].get("combat_id", ""))
			for monster in monster_entities:
				if str(monster.get("familiar_helped_by", "")) == familiar_id:
					monster.erase("familiar_helped_by")
		var owner_index := _get_current_owner_index()
		if owner_index >= 0 and not PlayerManager.is_player_connected(owner_index):
			_wait_for_owner_rebind(owner_index, true)
			return
		FighterRules.clear_source_effects(active_character, monster_entities)
		var rally := FighterRules.start_turn(active_character)
		if rally > 0:
			hud.add_log("Survivor restores %d HP." % rally)
		var automatic_death_save := ZeroHpAftermathRules.pending_death_save_rule(active_character) if active_character.is_downed() else {}
		if not automatic_death_save.is_empty():
			# A declared no-roll outcome offers no d20 bonus, reroll or token choice.
			var automatic := active_character.make_death_save()
			last_automatic_death_save = automatic.duplicate(true)
			hud.add_log("Death save %s automatically (%d successes, %d failures)." % ["is canceled" if automatic.get("canceled", false) else "is a " + str(automatic.get("outcome", "")), int(automatic.get("successes", 0)), int(automatic.get("failures", 0))])
		elif active_character.is_downed():
			var use_bardic_inspiration := false
			var use_stroke_of_luck := false
			if active_character.has_feature("rogue_stroke_of_luck") and int(active_character.feature_uses.get("rogue_stroke_of_luck", 0)) > 0:
				var owner_label := _owner_label_for_character(active_character)
				use_stroke_of_luck = await hud.request_reaction(owner_label, "stroke_of_luck", "If this death save fails after any Indomitable reroll, turn its d20 into a 20?", "Use Stroke of Luck on this death save?", "Turn the d20 into 20", "Stroke of Luck — %s" % owner_label)
			if active_character.feature_uses.has("bardic_inspiration_die"):
				var inspiration_die := str(active_character.feature_uses.get("bardic_inspiration_die", "1d6"))
				var owner_label := _owner_label_for_character(active_character)
				use_bardic_inspiration = await hud.request_reaction(owner_label, "bardic_inspiration", "If this death save remains failed after any Indomitable reroll, add %s. Natural 1 keeps its special result." % inspiration_die, "Use Bardic Inspiration on a failed death save?", "Use Inspiration", "Bardic Inspiration — %s" % owner_label)
			var death_save_decisions := await _collect_roll_token_decision(active_character, "death_save", "Death Saving Throw")
			var death_save := active_character.make_death_save(use_bardic_inspiration, use_stroke_of_luck, death_save_decisions)
			if death_save.get("rolled", false):
				var inspiration_note := " Bardic Inspiration adds %d." % int(death_save.get("bardic_inspiration_bonus", 0)) if death_save.get("bardic_inspiration_used", false) else ""
				var stroke_note := " Stroke of Luck turns the death save into a 20." if death_save.get("stroke_of_luck_used", false) else ""
				hud.add_log("Death save: %d (%d successes, %d failures).%s%s" % [death_save.get("total", death_save["natural"]), death_save["successes"], death_save["failures"], inspiration_note, stroke_note])
		if not active_character.is_alive:
			hud.add_log("[color=gray]%s is %s and skips their turn.[/color]" % [active_character.character_name, "dead" if active_character.is_dead() else "unconscious"])
			await get_tree().create_timer(1.0).timeout
			_end_active_turn()
			return


		# Process turn-start condition effects (like poison)
		if active_character.has_condition("poisoned"):
			var dmg := Dice.roll(4) # 1d4 poison damage
			var actual := int(CombatAction.resolve_damage(active_character, dmg, "poison")["damage"])
			hud.add_log("[color=red]%s took %d poison damage from being poisoned![/color]" % [active_character.character_name, actual])
			var ppos: Vector2i = player_entities[current_player_idx]["hex_position"]
			_spawn_floating_text(ppos, "-%d" % actual, Color(0.3, 1.0, 0.3))
			_flash_hex(ppos, Color(0.3, 1.0, 0.3, 0.5))
			if not active_character.is_alive:
				hud.add_log("[color=red]%s was knocked out by poison![/color]" % active_character.character_name)
				await get_tree().create_timer(1.0).timeout
				_end_active_turn()
				return
		if not active_character.combat_command.is_empty():
			await _resolve_character_command(active_character, player_entities[current_player_idx], active_character.combat_command)
			_end_active_turn()
			return

		# Check turn-blocking conditions
		if active_character.has_condition("stunned") or active_character.has_condition("paralyzed"):
			var blocked_condition := "Paralyzed" if active_character.has_condition("paralyzed") else "Stunned"
			hud.add_log("[color=orange]%s is %s and skips their turn.[/color]" % [active_character.character_name, blocked_condition])
			await get_tree().create_timer(1.0).timeout
			_end_active_turn()
			return

		var speed_val := _movement_speed_feet("walk", active_character) / 5.0
		if active_character.has_condition("prone"):
			speed_val /= 2.0
		remaining_speed = speed_val
		active_movement_mode = "walk"
		hud.set_movement_modes(active_character, active_movement_mode, _movement_speed_overrides(active_character))
		_reset_turn_action_economy()
		if player_entities[current_player_idx].get("is_created_actor", false): # Batch 056 S-157: its own turn and budget.
			var created_line := CreatedCommandRules.take_turn(self, player_entities[current_player_idx])
			if not created_line.is_empty(): hud.add_log(created_line)
			await get_tree().process_frame
			_end_active_turn()
			return
		if player_entities[current_player_idx].get("is_created_creature", false):
			await CreatedCreatureCombat.take_turn(self, player_entities[current_player_idx])
			_end_active_turn()
			return
		var controlled_entity: Dictionary = player_entities[current_player_idx]
		var creature_owner: Character = controlled_entity.get("familiar_owner", controlled_entity.get("steed_owner"))
		if creature_owner != null and (not creature_owner.is_alive or CombatAction.is_incapacitated(creature_owner)):
			active_character.add_condition("dodging", 2)
			_spend_action_cost("action")
			hud.add_log("%s takes Dodge while its owner cannot command it." % active_character.character_name)
			await get_tree().create_timer(0.01).timeout
			_end_active_turn()
			return
		
		# Reset once-per-turn features/restrictions for this player
		active_character.feature_uses.erase("jump_spell_used_this_turn")
		active_character.feature_uses.erase("sorcerer_arcane_apotheosis_used_this_turn")
		active_character.feature_uses.erase("sorcerer_levelled_spell_cast_this_turn")
		active_character.feature_uses.erase("sorcerer_quickened_spell_cast_this_turn")
		for feature in active_character.features:
			if feature.get("uses_per", "") == "turn":
				active_character.feature_uses[feature.get("id", "")] = active_character.get_feature_max_uses(str(feature.get("id", "")))
		for effect in ClassProgression.selected_feature_effects_of_type(active_character, "weapon_damage_rider"):
			var marker := "%s_%s_used_this_turn" % [str(effect.get("id", "weapon_damage_rider")), active_character.class_id]
			active_character.feature_uses.erase(marker)
		if active_character.has_feature("barbarian_reckless_attack"):
			active_character.feature_uses["barbarian_reckless_attack_used_this_turn"] = 0
			active_character.remove_condition("reckless_attack")
		if active_character.has_feature("barbarian_brutal_strike"):
			active_character.feature_uses["barbarian_brutal_strike_used_this_turn"] = 0
			BarbarianRules.clear_turn_effects(active_character, monster_entities)
		if active_character.has_feature("ranger_favored_foe"):
			active_character.feature_uses["ranger_favored_foe_used_this_turn"] = 0
		
		hud.update_hud(active_character, tracker)
		hud.set_controls_disabled(false)
		hud.add_log("[color=yellow]=== Turn: %s (Player) ===[/color]" % active_character.character_name)
		# First-turn contextual hint (P1 readability), shown once per battle.
		if not _hint_shown:
			_hint_shown = true
			hud.show_hint("Your turn. Click a highlighted hex to move (path previews on hover). Click Attack to strike in range — red hexes show your reach. Enemies show their intent above their token.")
		_highlight_reachable()

	else:
		# Monster Turn
		var monster: Dictionary = active_combatant["entity"]
		monster["reaction_available"] = true
		CombatAction.clear_shocking_grasp(monster)
		await _resolve_spell_zone_start_turn(monster, monster.get("hex_position", Vector2i.ZERO))
		_apply_regenerate_turn_start(monster)
		
		# Process turn-start condition effects (like poison)
		var monster_conditions: Dictionary = monster.get("conditions", {})
		var command: Dictionary = monster.get("combat_command", {})
		if monster_conditions.has("prone") and str(command.get("action", "")) != "grovel":
			monster_conditions.erase("prone")
			monster["fighter_stood_up"] = true
			hud.add_log("%s stands from Prone, spending half its movement." % monster["name"])
		if monster_conditions.has("poisoned"):
			var dmg := Dice.roll(4)
			var actual := int(CombatAction.resolve_damage(monster, dmg, "poison")["damage"])
			hud.add_log("[color=red]%s took %d poison damage from being poisoned![/color]" % [monster["name"], actual])
			if monster["current_hp"] <= 0:
				monster["is_alive"] = false
				hud.add_log("[color=green]%s was defeated by poison![/color]" % monster["name"])
				tracker.remove_combatant(monster["id"])
				await get_tree().create_timer(1.0).timeout
				_end_active_turn()
				return

		# Check stunned condition
		if monster_conditions.has("stunned") or monster_conditions.has("paralyzed") or monster.get("stunning_strike_stunned", false):
			var blocked_monster_condition := "Paralyzed" if monster_conditions.has("paralyzed") else "Stunned"
			hud.add_log("[color=orange]%s is %s and skips their turn.[/color]" % [monster["name"], blocked_monster_condition])
			await get_tree().create_timer(1.0).timeout
			_end_active_turn()
			return

		hud.update_hud(null, tracker)
		hud.set_movement_modes(null, "")
		hud.set_controls_disabled(true)
		hud.add_log("[color=red]=== Turn: %s (Monster) ===[/color]" % active_combatant["name"])

		# --- Enemy intent preview (P1 readability) ---
		# Compute the monster's planned action from current state and surface it
		# above the token so the player can read what's coming.
		var monster_coord: Vector2i = monster.get("hex_position", Vector2i.ZERO)
		var intent := AIController.get_monster_action(monster, monster_coord, hex_grid, player_entities)
		monster["intent"] = intent
		_intent_preview = _describe_intent(monster, intent)
		monster["intent_text"] = _intent_preview
		# Re-draw so the badge appears immediately.
		hex_grid.queue_redraw()
		_update_grid_entities()

		await get_tree().create_timer(1.0).timeout
		_run_monster_ai()


func _get_current_owner_index() -> int:
	if current_player_idx < 0 or current_player_idx >= player_entities.size():
		return -1
	return int(player_entities[current_player_idx].get("owner_player_index", -1))


func _wait_for_owner_rebind(owner_index: int, before_turn_setup: bool) -> void:
	_waiting_for_owner_rebind = true
	_rebind_wait_before_turn_setup = before_turn_setup
	hud.set_controls_disabled(true)
	hex_grid.clear_highlights()
	_clear_path_preview()
	hud.add_log("[color=orange]Seat %d disconnected. Reconnect the controller or press Start to reclaim this turn.[/color]" % (owner_index + 1))


func _resolve_character_command(character: Character, entity: Dictionary, command: Dictionary) -> void:
	var action := str(command.get("action", "halt"))
	var origin: Vector2i = entity.get("hex_position", Vector2i.ZERO)
	if action == "grovel":
		character.add_condition("prone", 2)
		hud.add_log("%s grovels and ends their turn Prone." % character.character_name)
		return
	if action == "drop":
		for slot in [Inventory.Slot.WEAPON, Inventory.Slot.SHIELD, Inventory.Slot.OFFHAND]:
			var item_copy := character.inventory.drop_equipped_instance(slot)
			var dropped_object := CombatObjectRules.make_dropped_item(item_copy, origin, character.character_id)
			if not dropped_object.is_empty():
				dropped_combat_items.append(dropped_object)
		_update_grid_entities()
		hud.add_log("%s drops what they are holding and ends their turn." % character.character_name)
		return
	if action == "halt":
		hud.add_log("%s halts and ends their turn." % character.character_name)
		return
	var caster_coord := Vector2i.ZERO
	var caster_id := str(command.get("caster_id", ""))
	for player in player_entities:
		var caster: Character = player.get("character")
		if caster != null and (caster.character_id == caster_id or str(caster.get_instance_id()) == caster_id):
			caster_coord = player.get("hex_position", Vector2i.ZERO)
			break
	var movement_budget := float(character.get_speed()) * 2.0 if action == "flee" else float(character.get_speed())
	var reachable: Dictionary = _player_reachable(origin, movement_budget, character)
	var destination := origin
	var best_distance := HexUtils.get_distance(origin, caster_coord)
	for candidate_value in reachable:
		var candidate: Vector2i = candidate_value
		if candidate == origin or _is_occupied_hex(candidate):
			continue
		var distance := HexUtils.get_distance(candidate, caster_coord)
		var better := distance < best_distance if action == "approach" else distance > best_distance
		if better and (action != "approach" or distance > 0):
			best_distance = distance
			destination = candidate
	if destination != origin:
		var path := _player_path(origin, destination, character)
		await _check_opportunity_attacks_for_path(character, entity, path, false)
	hud.add_log("%s %s and ends their turn." % [character.character_name, "approaches" if action == "approach" else "flees"])


func _on_device_binding_changed(player_index: int, _device_id: int, connected: bool) -> void:
	if _battle_ending or active_combatant.is_empty() or not bool(active_combatant.get("is_player", false)):
		return
	if player_index != _get_current_owner_index():
		return
	if not connected:
		_wait_for_owner_rebind(player_index, false)
		return
	if not _waiting_for_owner_rebind:
		return
	var resume_before_setup := _rebind_wait_before_turn_setup
	_waiting_for_owner_rebind = false
	_rebind_wait_before_turn_setup = false
	hud.add_log("[color=green]Seat %d reconnected.[/color]" % (player_index + 1))
	if resume_before_setup:
		_start_combat_turn()
	else:
		hud.set_controls_disabled(false)
		if pending_action_type == "attack":
			_highlight_attack_targets()
		elif pending_action_type == "spell":
			_highlight_spell_targets()
		else:
			_highlight_reachable()


func _run_monster_ai() -> void:
	ClericRules.reconcile_turning(monster_entities, player_entities)
	var monster: Dictionary = active_combatant["entity"]
	var monster_coord: Vector2i = monster.get("hex_position", Vector2i.ZERO)
	var monster_conditions: Dictionary = monster.get("conditions", {})
	if monster_conditions.has("unconscious"):
		hud.add_log("%s is Unconscious and skips its turn." % monster.get("name", "The target"))
		_update_grid_entities()
		await get_tree().create_timer(1.0).timeout
		_end_active_turn()
		return
	var forced_command: Dictionary = monster.get("combat_command", {})
	if not forced_command.is_empty():
		await _resolve_monster_command(monster, forced_command)
		_update_grid_entities()
		await get_tree().create_timer(1.0).timeout
		_end_active_turn()
		return
	if monster_conditions.has("incapacitated"):
		if monster.has("turn_undead_origin"):
			await _move_turned_undead_away(monster)
		else:
			hud.add_log("%s is Incapacitated or Unconscious and skips its turn." % monster.get("name", "Undead"))
		_update_grid_entities()
		await get_tree().create_timer(1.0).timeout
		_end_active_turn()
		return
	if _try_monster_escape_tether(monster) or _try_monster_rescue_tether(monster) or _try_monster_escape_restrained_zone(monster):
		_update_grid_entities()
		await get_tree().create_timer(1.0).timeout
		_end_active_turn()
		return
	
	# Get AI decision
	var decision := AIController.get_monster_action(monster, monster_coord, hex_grid, player_entities)
	var command := AICommand.from_decision(decision, monster, player_entities, hex_grid)
	if command == null:
		hud.add_log("%s holds: invalid AI action was rejected." % monster["name"])
		_update_grid_entities()
		await get_tree().create_timer(1.2).timeout
		_end_active_turn()
		return
	var action_str: String = command.action_type
	if monster.get("conditions", {}).has("dazed") and action_str == "move_attack":
		action_str = "move"
		hud.add_log("%s is Dazed and can only move this turn." % monster.get("name", "The target"))
	if monster.has(PaladinRules.ABJURE_FOES_MARKER) and action_str == "move_attack":
		# Abjure Foes permits movement or an action on the turn, not both.
		action_str = "move"

	match action_str:
		"move":
			var dest: Vector2i = command.move_to()
			if PaladinRules.abjure_foes_forbids_movement_closer(monster, dest, player_entities):
				hud.add_log("%s cannot move closer to the source of its fear." % monster.get("name", "The creature"))
			else:
				var path := [monster_coord, dest]
				await _check_opportunity_attacks_for_path(null, monster, path, true)
				if monster["is_alive"]:
					hud.add_log("%s moved." % monster["name"])
		"attack":
			var target_name: String = command.target_id()
			var attack_idx: int = command.attack_idx()
			await _execute_monster_attack(monster, target_name, attack_idx)
		"cast_spell":
			await _execute_monster_spell(monster, command.target_id(), command.spell_id())
		"move_attack":
			# Move
			var dest: Vector2i = command.move_to()
			if PaladinRules.abjure_foes_forbids_movement_closer(monster, dest, player_entities):
				hud.add_log("%s cannot move closer to the source of its fear." % monster.get("name", "The creature"))
			else:
				var path := [monster_coord, dest]
				await _check_opportunity_attacks_for_path(null, monster, path, true)
				if monster["is_alive"]:
					# Attack
					var target_name: String = command.target_id()
					var attack_idx: int = command.attack_idx()
					hud.add_log("%s moved and attacked!" % monster["name"])
					await _execute_monster_attack(monster, target_name, attack_idx)
		_:
			hud.add_log("%s dodges." % monster["name"])

	_update_grid_entities()
	await get_tree().create_timer(1.2).timeout
	_end_active_turn()


func _move_turned_undead_away(monster: Dictionary) -> void:
	var origin: Vector2i = monster.get("hex_position", Vector2i.ZERO)
	var source: Vector2i = monster.get("turn_undead_origin", origin)
	var reachable: Dictionary = _enemy_reachable(origin, float(monster.get("speed", 6)), monster)
	var destination := origin
	var best_distance := HexUtils.get_distance(origin, source)
	for candidate in reachable:
		var cell: Vector2i = candidate
		if cell == origin or _is_occupied_hex(cell):
			continue
		var distance := HexUtils.get_distance(cell, source)
		if distance > best_distance:
			best_distance = distance
			destination = cell
	if destination == origin:
		hud.add_log("%s is turned but cannot move farther away." % monster.get("name", "Undead"))
		return
	var path := _enemy_path(origin, destination, monster)
	await _check_opportunity_attacks_for_path(null, monster, path, true)
	if monster.get("is_alive", false):
		hud.add_log("%s flees from Turn Undead." % monster.get("name", "Undead"))


func _resolve_monster_command(monster: Dictionary, command: Dictionary) -> void:
	if monster.get("conditions", {}).has("resilient_sphere"):
		hud.add_log("%s cannot move through the Resilient Sphere." % monster.get("name", "The creature"))
		return
	var action := str(command.get("action", "halt"))
	var name := str(monster.get("name", "The target"))
	var origin: Vector2i = monster.get("hex_position", Vector2i.ZERO)
	if action == "grovel":
		CombatAction.apply_condition(monster, "prone", 2)
		hud.add_log("%s grovels and ends its turn Prone." % name)
		return
	if action == "drop":
		var held: Array = monster.get("held_items", []).duplicate()
		for item_index in held.size():
			var definition_id := str(held[item_index])
			var record := {"instance_id": "monster:%s:drop:%d:%d" % [str(monster.get("id", "monster")), tracker.round_number, item_index], "definition_id": definition_id, "state": {}}
			var dropped_object := CombatObjectRules.make_dropped_item(record, origin, str(monster.get("id", "")))
			if not dropped_object.is_empty():
				dropped_combat_items.append(dropped_object)
		monster["held_items"] = []
		_update_grid_entities()
		hud.add_log("%s drops what it is holding and ends its turn." % name)
		return
	if action == "halt":
		hud.add_log("%s halts and ends its turn." % name)
		return
	var caster_id := str(command.get("caster_id", ""))
	var caster_coord := Vector2i.ZERO
	for player in player_entities:
		var caster: Character = player.get("character")
		if caster != null and (caster.character_id == caster_id or str(caster.get_instance_id()) == caster_id):
			caster_coord = player.get("hex_position", Vector2i.ZERO)
			break
	var monster_speed := 0.0 if monster.get("conditions", {}).has("restrained") else float(monster.get("speed", 6))
	var movement_budget := monster_speed * 2.0 if action == "flee" else monster_speed
	var reachable: Dictionary = _enemy_reachable(origin, movement_budget, monster)
	var destination := origin
	var best_distance := HexUtils.get_distance(origin, caster_coord)
	for candidate_value in reachable:
		var candidate: Vector2i = candidate_value
		if candidate == origin or _is_occupied_hex(candidate):
			continue
		var distance := HexUtils.get_distance(candidate, caster_coord)
		var better := distance < best_distance if action == "approach" else distance > best_distance
		if better and (action != "approach" or distance > 0):
			best_distance = distance
			destination = candidate
	if destination != origin:
		var path := _enemy_path(origin, destination, monster)
		await _check_opportunity_attacks_for_path(null, monster, path, true)
	if action == "approach" and HexUtils.get_distance(monster.get("hex_position", origin), caster_coord) <= 1:
		hud.add_log("%s approaches the caster and ends its turn." % name)
	else:
		hud.add_log("%s %s and ends its turn." % [name, "approaches" if action == "approach" else "flees"])


## S-168: a tethered monster uses its Action to escape that exact tether.
func _try_monster_escape_tether(monster: Dictionary) -> bool:
	var captors: Array = player_entities.map(func(p): return p.get("character"))
	var bindings := TetherRules.binding(monster, captors)
	if bindings.is_empty(): return false
	var r := TetherRules.escape(monster, captors, 0, str(bindings[0].relation))
	hud.add_log("[color=%s]%s[/color]" % ["green" if r.get("success", false) else "orange", str(r.get("message", ""))])
	return true


## S-169: a monster beside a tethered ally spends its turn freeing it: it cuts a tether
## that has hp, otherwise pulls with a declared rescue check. Only that tether ends.
func _try_monster_rescue_tether(monster: Dictionary) -> bool:
	var captors: Array = player_entities.map(func(p): return p.get("character"))
	var origin: Vector2i = monster.get("hex_position", Vector2i.ZERO)
	for ally in monster_entities:
		if ally == monster or not ally.get("is_alive", false) or HexUtils.get_distance(origin, ally.get("hex_position", Vector2i.ZERO)) > 1: continue
		for mode in ["strike", "check"]:
			for binding in TetherRules.binding(ally, captors):
				var relation := str(binding.relation)
				if not TetherRules.rescue_error(monster, ally, captors, mode, relation).is_empty(): continue
				var r := TetherRules.rescue(monster, ally, captors, mode, relation)
				hud.add_log("[color=%s]%s[/color]" % ["green" if r.get("success", false) else "orange", str(r.get("message", ""))])
				return true
	return false


## S-169: the active character spends its Action to free an adjacent tethered ally.
func _try_rescue_tether(character: Character, coord: Vector2i, player_pos: Vector2i) -> bool:
	if character == null or HexUtils.get_distance(coord, player_pos) != 1: return false
	var ally: Character = null
	for p in player_entities:
		if p.get("hex_position", Vector2i(-99, -99)) == coord and p.get("character") is Character: ally = p.character
	if ally == null: return false
	var captors: Array = player_entities.map(func(p): return p.get("character"))
	var options: Array[String] = []
	var labels: Dictionary = {}
	for binding in TetherRules.binding(ally, captors):
		for mode in ["strike", "check"]:
			if not TetherRules.rescue_error(character, ally, captors, mode, str(binding.relation)).is_empty(): continue
			options.append("%s|%s" % [mode, binding.relation])
			labels[options.back()] = "%s: %s (%s) · %s" % ["Cut" if mode == "strike" else "Pull free", binding.captor.character_name, DataLoader.get_spell(str(binding.tether.spell_id)).get("name", "Tether"), binding.relation]
	if options.is_empty() or not _can_spend_action_cost("action"): return false
	var selection := options[0]
	if options.size() > 1:
		resolving_player_action = true
		selection = await hud._request_popup_choice("Choose tether rescue", options, labels)
		resolving_player_action = false
	if selection not in options: return true
	var mode := selection.get_slice("|", 0)
	var relation := selection.substr(mode.length() + 1)
	# Checklist (a): refuse before the Action is spent.
	if character != active_character or not TetherRules.rescue_error(character, ally, captors, mode, relation).is_empty() or not _can_spend_action_cost("action") or not _tether_rescue_adjacent(character, ally): return true
	_spend_action_cost("action")
	var r := TetherRules.rescue(character, ally, captors, mode, relation)
	hud.add_log("[color=%s]%s[/color]" % ["green" if r.get("success", false) else "orange", str(r.get("message", ""))])
	hud.update_hud(active_character, tracker)
	_highlight_reachable()
	return true


func _tether_rescue_adjacent(rescuer: Character, victim: Character) -> bool:
	var a: Dictionary = {}
	var b: Dictionary = {}
	for player in player_entities:
		if player.get("character") == rescuer: a = player
		if player.get("character") == victim: b = player
	return not a.is_empty() and not b.is_empty() and HexUtils.get_distance(a.hex_position, b.hex_position) == 1


## S-168: the active character spends its Action to escape an exact tether.
func _try_escape_tether(character: Character) -> bool:
	if character == null or not _can_spend_action_cost("action"): return false
	var captors: Array = player_entities.map(func(p): return p.get("character"))
	var bindings := TetherRules.binding(character, captors)
	if bindings.is_empty(): return false
	var options: Array[String] = []
	var labels: Dictionary = {}
	for binding in bindings:
		options.append(str(binding.relation))
		labels[str(binding.relation)] = "%s (%s) · %s" % [binding.captor.character_name, DataLoader.get_spell(str(binding.tether.spell_id)).get("name", "Tether"), binding.relation]
	var relation := options[0]
	if options.size() > 1:
		resolving_player_action = true
		relation = await hud._request_popup_choice("Choose tether to escape", options, labels)
		resolving_player_action = false
	if relation not in options: return true
	if character != active_character or not _can_spend_action_cost("action") or not TetherRules.binding(character, captors).any(func(b): return str(b.relation) == relation): return true
	_spend_action_cost("action")
	var r := TetherRules.escape(character, captors, 0, relation)
	hud.add_log("[color=%s]%s[/color]" % ["green" if r.get("success", false) else "orange", str(r.get("message", ""))])
	hud.update_hud(active_character, tracker)
	_highlight_reachable()
	return true


func _try_monster_escape_restrained_zone(monster: Dictionary) -> bool:
	var sources: Dictionary = monster.get("condition_sources", {}).get("restrained", {})
	for source_value in sources.keys():
		var source_id := str(source_value)
		if not (source_id.begins_with("entangle:") or source_id.begins_with("black_tentacles:")):
			continue
		var zone: Dictionary = active_spell_zones.get(source_id, {})
		if zone.is_empty():
			CombatAction.remove_condition_source(monster, source_id, ["restrained"])
			continue
		var ability_scores: Dictionary = monster.get("ability_scores", {})
		var strength_modifier := AbilityScores.get_modifier(int(ability_scores.get("STR", 10)))
		var athletics_modifier := strength_modifier
		var skills: Variant = monster.get("skills", {})
		if skills is Dictionary:
			athletics_modifier = int(skills.get("Athletics", strength_modifier))
		var total := Dice.roll(20) + athletics_modifier
		var dc := int(zone.get("save_dc", 10))
		if total >= dc:
			CombatAction.remove_condition_source(monster, source_id, ["restrained"])
			var restrained_targets: Array = zone.get("restrained_targets", [])
			restrained_targets.erase(monster)
			zone["restrained_targets"] = restrained_targets
			hud.add_log("[color=green]%s uses its Action to break free of %s (%d vs DC %d).[/color]" % [str(monster.get("name", "The creature")), str(zone.get("spell_id", "the restraint")).capitalize().replace("_", " "), total, dc])
		else:
			hud.add_log("[color=orange]%s uses its Action to escape %s, but fails (%d vs DC %d).[/color]" % [str(monster.get("name", "The creature")), str(zone.get("spell_id", "the restraint")).capitalize().replace("_", " "), total, dc])
		return true
	return false


func _execute_monster_attack(monster: Dictionary, target_player_name: String, attack_idx: int) -> void:
	var attack_data: Dictionary = monster["attacks"][attack_idx]
	
	# Find target player char and position
	var target_char: Character = null
	var target_pos := Vector2i.ZERO
	for p in player_entities:
		if p["character"].character_name == target_player_name:
			target_char = p["character"]
			target_pos = p["hex_position"]
			break

	if target_char == null: return
	var monster_origin: Vector2i = monster.get("hex_position", Vector2i.ZERO)
	if _spell_zones()._antilife_shell_blocks_melee(monster, monster_origin, target_pos, attack_data):
		hud.add_log("Antilife Shell prevents %s's melee attack from reaching through its barrier." % str(monster.get("name", "The creature")))
		return
	if not Targeting.has_line_of_sight(monster_origin, target_pos, hex_grid):
		hud.add_log("%s's attack is blocked by a wall or closed door." % str(monster.get("name", "The creature")))
		return

	# Determine advantage & disadvantage based on conditions
	var has_advantage := false
	var has_disadvantage: bool = target_char.has_condition("dodging") or bool(monster.get("conditions", {}).has("restrained"))
	var attack_distance_feet := HexUtils.get_distance(monster.get("hex_position", Vector2i.ZERO), target_pos) * 5
	if not CombatPerception.can_see_target(monster, target_char, monster_origin, target_pos, hex_grid):
		has_disadvantage = true
	var monster_perceives_invisible := CombatAction.can_perceive_invisible(monster, attack_distance_feet)
	if CombatAction.is_invisible(target_char) and not monster_perceives_invisible:
		has_disadvantage = true
	if CombatAction.is_invisible(monster) and not CombatAction.can_perceive_invisible(target_char, attack_distance_feet):
		has_advantage = true
	
	# Monster conditions (blinded/poisoned)
	var monster_conditions: Dictionary = monster.get("conditions", {})
	if monster_conditions.has("blinded") or monster_conditions.has("poisoned"):
		has_disadvantage = true
	var abjure_source_position: Variant = PaladinRules.abjure_foes_source_position(monster, player_entities)
	if monster_conditions.has("frightened") and abjure_source_position is Vector2i and Targeting.has_line_of_sight(monster_origin, abjure_source_position, hex_grid):
		has_disadvantage = true

	# Target conditions (blinded or prone)
	if target_char.has_condition("blinded"):
		has_advantage = true
	if target_char.has_condition("reckless_attack"):
		has_advantage = true
	if target_char.has_condition("restrained"):
		has_advantage = true
	if target_char.has_condition("prone"):
		var dist := HexUtils.get_distance(monster.get("hex_position", Vector2i.ZERO), target_pos)
		if dist == 1:
				has_advantage = true
		else:
				has_disadvantage = true

	if not monster.get("fighter_sap_sources", []).is_empty():
		has_disadvantage = true
		monster.erase("fighter_sap_sources")
	await _fire_reaction_trigger(target_char, "on_attacked", monster, target_pos, monster_origin)
	if not bool(monster.get("is_alive", false)) or int(monster.get("current_hp", 0)) <= 0:
		_check_battle_end_conditions()
		return
	var reaction_decisions := await _collect_reaction_decisions(target_char)
	var zero_live := SharedStepExecutor.zero_hp_options(target_char)
	var zero_options := zero_live.duplicate(true)
	if not zero_options.is_empty():
		var selected := await SpellCastResults.choose_zero_hp_source(hud, target_char, zero_options)
		for rule in zero_options:
			if str(rule.source_instance_id) == selected:
				reaction_decisions["zero_hp_choice"] = {"rule": rule, "live_rule": zero_live[zero_options.find(rule)], "target": target_char, "used": false}

	reaction_decisions["players"] = player_entities
	reaction_decisions["monsters"] = monster_entities
	reaction_decisions["damage_source_actor_id"] = str(monster.get("id", ""))
	reaction_decisions["damage_source_instance_id"] = str(monster.get("id", ""))

	# Roll attack
	var monster_attacker := _make_temp_monster_character(monster)
	reaction_decisions.merge(await _collect_roll_token_decision(monster_attacker, "attack", "%s attack roll against %s" % [str(monster.get("name", "Monster")), target_char.character_name], reaction_decisions), true)
	var result := CombatAction.resolve_weapon_attack(
		monster_attacker,
		target_char,
		attack_data,
		has_advantage,
		has_disadvantage,
		reaction_decisions
	)
	last_monster_weapon_attack_result = result.duplicate(true)
	if result.has("attack_roll"):
		# The AI's selected command can still fail target/LOS/movement checks.
		# Record only a real roll, using the monster rather than its temporary
		# Character projection (which has no stable actor ID).
		action_history.record_action(monster)
		action_history.record_attack(monster, target_char)
		SpellEffects.consume_spell(monster, "invisibility")
	_sync_consumed_monster_attack_conditions(monster, monster_attacker)
	var rider_save_decisions: Dictionary = {}
	if result.get("hit", false):
		for effect in attack_data.get("extra_effects", []):
			if str(effect.get("type", "")) in ["poison_save", "restrain", "paralyze_save"]:
				rider_save_decisions = await _collect_roll_token_decision(target_char, "save", "%s saving throw against %s" % [str(effect.get("save", "CON")), str(monster.get("name", "attack"))])
				break
	# Base and primary rider damage share the accepted single-use authorization.
	# Keep the live reference and its consumed flag; copying it could reopen a use.
	if reaction_decisions.has("zero_hp_choice"):
		rider_save_decisions["zero_hp_choice"] = reaction_decisions["zero_hp_choice"]
	rider_save_decisions.merge({"players": player_entities, "monsters": monster_entities, "damage_source_actor_id": str(monster.get("id", "")), "damage_source_instance_id": str(monster.get("id", ""))}, true)
	var rider_results := CombatAction.resolve_monster_attack_effects(monster, target_char, attack_data, result, rider_save_decisions, monster_attacker)
	var rider_resolved := 0
	for rider in rider_results:
		hud.add_log("[color=orange]%s[/color]" % rider.get("message", "Monster effect resolved."))
		result["damage"] = int(result.get("damage", 0)) + int(rider.get("damage", 0))
		rider_resolved += int(rider.get("resolved", rider.get("damage", 0)))
		if rider.has("damage_components"):
			if not result.has("damage_components"): result["damage_components"] = []
			result["damage_components"].append_array(rider["damage_components"])
	last_monster_weapon_attack_result = result.duplicate(true)
	if result.get("deflected", false) and rider_results.is_empty():
		await _offer_deflect_redirect(target_char, target_pos, attack_data, result)

	hud.add_log(result.get("message", "Miss!"))
	if result.get("hit", false):
		await _fire_reaction_trigger(target_char, "on_hit_by_attack", monster, target_pos, monster.get("hex_position", monster_origin))
	if int(result.get("damage", 0)) > 0:
		await _fire_reaction_trigger(target_char, "on_damaged_by_creature", monster, target_pos, monster.get("hex_position", monster_origin))

	# --- Feedback / juice ---
	var m_dmg: int = int(result.get("damage", 0))
	if result.get("hit", false) and m_dmg > 0:
		var m_crit: bool = result.get("crit", false)
		var m_color := Color.GOLD if m_crit else Color(1.0, 0.3, 0.3)
		var m_txt := ("CRIT %d!" % m_dmg) if m_crit else ("-%d" % m_dmg)
		_spawn_floating_text(target_pos, m_txt, m_color)
		_shake_camera(9.0 if m_crit else 5.0)
		_flash_hex(target_pos, Color(1.0, 0.3, 0.3, 0.6))
	else:
		_spawn_floating_text(target_pos, "Miss", Color(0.7, 0.7, 0.7, 0.9))
	# ---

	# Check if target died
	var linked_recipients := DamageLinkRules.recipient_settlements(target_char, result, monster_entities)
	if not linked_recipients.is_empty():
		for recipient in linked_recipients:
			var actor = recipient["actor"]
			var taken := int(recipient["resolved"])
			if actor is Dictionary:
				if int(actor.get("current_hp", 0)) <= 0 and not bool(actor.get("_defeat_processed", false)):
					actor["_defeat_processed"] = true
					actor["is_alive"] = false
					tracker.remove_combatant(str(actor.get("id", "")))
					_trigger_enemy_defeat_features(actor, recipient.get("source_actor"))
				continue
			if not actor.is_alive or bool(recipient.get("knocked_out", false)):
				hud.add_log("[color=red]%s has been knocked out![/color]" % actor.character_name)
				_end_concentration(actor)
			elif taken > 0:
				await _check_concentration_save(actor, taken)
		return
	if not target_char.is_alive:
		hud.add_log("[color=red]%s has been knocked out![/color]" % target_char.character_name)
		if not target_char.concentrating_on.is_empty():
			_end_concentration(target_char)
	else:
		var conc_damage := int(result.get("resolved", result.get("damage", 0))) + rider_resolved
		if result.get("hit", false) and conc_damage > 0:
			await _check_concentration_save(target_char, conc_damage)


func _make_monster_spellcaster(monster: Dictionary) -> Character:
	var caster := _make_temp_monster_character(monster)
	caster.class_id = "wizard"
	caster.level = maxi(1, int(monster.get("spellcaster_level", 8)))
	var monster_save_bonuses: Dictionary = monster.get("saving_throw_bonuses", {})
	for ability in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
		if monster_save_bonuses.has(ability):
			var ability_score := int(monster.get("ability_scores", {}).get(ability, 10))
			caster.add_modifier("roll", "save:%s" % ability, int(monster_save_bonuses[ability]) - AbilityScores.get_modifier(ability_score), 999999)
	caster.known_spells.clear()
	for known in monster.get("spells", []):
		var spell_id := str(known.get("id", ""))
		if not spell_id.is_empty():
			caster.known_spells.append(spell_id)
	caster.spell_slots = monster.get("spell_slots", {}).duplicate(true)
	return caster


func _execute_monster_spell(monster: Dictionary, target_player_name: String, spell_id: String) -> void:
	var target_char: Character = null
	var target_pos := Vector2i.ZERO
	for p in player_entities:
		if p["character"].character_name == target_player_name:
			target_char = p["character"]
			target_pos = p["hex_position"]
			break
	if target_char == null or not target_char.is_alive:
		return
	var spell_data: Dictionary = DataLoader.get_spell(spell_id)
	if bool(spell_data.get("requires_target_sight", false)) and not CombatPerception.can_see_target(monster, target_char, monster.get("hex_position", Vector2i.ZERO), target_pos, hex_grid):
		hud.add_log("%s cannot see a target for %s." % [str(monster.get("name", "The creature")), str(spell_data.get("name", "the spell"))])
		return
	var caster := _make_monster_spellcaster(monster)
	var counterspell_context := await _collect_counterspell_decisions(caster, spell_data, monster.get("hex_position", Vector2i.ZERO), monster)
	var countercharm_context := await _collect_countercharm_decisions(target_char, target_pos, spell_data)
	var inspiration_context := await _collect_bardic_inspiration_save_decision(target_char, spell_data)
	var stroke_context := await _collect_stroke_of_luck_save_decision(target_char, str(spell_data.get("name", "this spell"))) if CombatAction.spell_requires_saving_throw(spell_data) else {}
	var spell_reaction_decisions: Dictionary = counterspell_context.get("decisions", {}).duplicate()
	spell_reaction_decisions.merge(countercharm_context.get("decisions", {}), true)
	spell_reaction_decisions.merge(inspiration_context, true)
	spell_reaction_decisions.merge(stroke_context, true)
	spell_reaction_decisions.merge(await _collect_spell_shield_decision(target_char, spell_data, spell_reaction_decisions), true)
	if CombatAction.spell_requires_saving_throw(spell_data):
		spell_reaction_decisions.merge(await _collect_roll_token_decision(target_char, "save", "%s saving throw against %s" % [str(spell_data.get("save", "Spell")), str(spell_data.get("name", "spell"))], spell_reaction_decisions), true)
	elif str(spell_data.get("attack_type", "none")) != "none":
		spell_reaction_decisions.merge(await _collect_roll_token_decision(caster, "attack", "%s spell attack against %s" % [str(spell_data.get("name", "Spell")), target_char.character_name], spell_reaction_decisions), true)
	if spell_data.has("damage") or spell_data.has("damage_per_dart") or spell_data.has("damage_per_ray"):
		spell_reaction_decisions.merge(await _collect_projected_ward_decision(target_char, spell_reaction_decisions), true)
	var spell_reaction_observers: Array = counterspell_context.get("observers", []).duplicate()
	spell_reaction_observers.append_array(countercharm_context.get("observers", []))
	var spell_target_distance := HexUtils.get_distance(monster.get("hex_position", Vector2i.ZERO), target_pos) * 5
	var result := CombatAction.resolve_spell(caster, target_char, spell_data, true, spell_reaction_decisions, spell_reaction_observers, 0, spell_target_distance)
	if bool(result.get("success", false)) or bool(result.get("countered", false)):
		action_history.record_action(monster)
	monster["spell_slots"] = caster.spell_slots.duplicate(true)
	hud.add_log(result.get("message", "%s's spell failed." % monster.get("name", "Monster")))
	if spell_reaction_decisions.has("counterspell_saved_by"):
		hud.add_log("[color=yellow]%s resists Counterspell; the spell continues.[/color]" % str(spell_reaction_decisions["counterspell_saved_by"]))
	var damage := int(result.get("damage", 0))
	var resolved_damage := int(result.get("resolved", damage))
	if result.get("success", false) and (damage > 0 or resolved_damage > 0):
		if damage > 0:
			_spawn_floating_text(target_pos, "-%d" % damage, Color(0.8, 0.3, 1.0))
			_flash_hex(target_pos, Color(0.7, 0.2, 1.0, 0.6))
		if resolved_damage > 0:
			await _check_concentration_save(target_char, resolved_damage)
	if not target_char.is_alive:
		hud.add_log("[color=red]%s was knocked out by %s's spell![/color]" % [target_char.character_name, monster.get("name", "Monster")])


func _collect_countercharm_decisions(target: Character, target_position: Vector2i, spell_data: Dictionary) -> Dictionary:
	var decisions: Dictionary = {}
	var observers: Array[Character] = []
	var condition := ""
	for candidate in ["charmed", "frightened"]:
		if CombatAction.spell_grants_condition(spell_data, candidate):
			condition = candidate
			break
	if target == null or condition not in ["charmed", "frightened"]:
		return {"decisions": decisions, "observers": observers}
	for player_entity in player_entities:
		var bard: Character = player_entity.get("character")
		if bard == null or not bard.is_alive or CombatAction.is_incapacitated(bard) or not bard.has_feature("bard_countercharm") or not bard.reaction_available:
			continue
		var bard_position: Vector2i = player_entity.get("hex_position", Vector2i.ZERO)
		if not Targeting.is_in_range(bard_position, target_position, 6):
			continue
		observers.append(bard)
		var key := "countercharm:%s" % bard.character_id
		decisions[key] = await hud.request_reaction(_owner_label_for_character(bard), "countercharm", "If %s fails its save against this %s effect, use your Reaction to reroll with Advantage?" % [target.character_name, condition], "Use Countercharm?", "Use Reaction", "Countercharm — %s" % _owner_label_for_character(bard))
	return {"decisions": decisions, "observers": observers}


func _collect_bardic_inspiration_save_decision(target: Character, spell_data: Dictionary) -> Dictionary:
	if target == null or not target.feature_uses.has("bardic_inspiration_die"):
		return {}
	var spell_has_save := CombatAction.spell_requires_saving_throw(spell_data)
	var has_relentless_rage_damage := target.has_feature("barbarian_relentless_rage") and target.has_condition("raging") and (spell_data.has("damage") or spell_data.has("damage_per_dart") or spell_data.has("damage_per_ray"))
	if not spell_has_save and not has_relentless_rage_damage:
		return {}
	var die := str(target.feature_uses.get("bardic_inspiration_die", "1d6"))
	var owner_label := _owner_label_for_character(target)
	var detail := "If your save against %s still fails, add %s to the roll." % [str(spell_data.get("name", "this spell")), die] if spell_has_save else "If this spell's damage triggers a failed Relentless Rage save, add %s." % die
	if spell_has_save and has_relentless_rage_damage:
		detail += " If you succeed on the spell save, you can still use the die on a later Relentless Rage save caused by its damage."
	var accepted := await hud.request_reaction(owner_label, "bardic_inspiration", detail, "Use Bardic Inspiration if a save fails?", "Use Inspiration", "Bardic Inspiration — %s" % owner_label)
	var decisions := {"bardic_inspiration": accepted} if spell_has_save else {}
	if has_relentless_rage_damage:
		decisions["relentless_rage_bardic_inspiration"] = accepted
	return decisions


func _collect_stroke_of_luck_save_decision(target: Character, source_name: String) -> Dictionary:
	if target == null or not target.has_feature("rogue_stroke_of_luck") or int(target.feature_uses.get("rogue_stroke_of_luck", 0)) <= 0:
		return {}
	var owner_label := _owner_label_for_character(target)
	var accepted := await hud.request_reaction(owner_label, "stroke_of_luck", "If your saving throw against %s fails, turn its d20 into a 20?" % source_name, "Use Stroke of Luck if the save fails?", "Turn the d20 into 20", "Stroke of Luck — %s" % owner_label)
	return {"stroke_of_luck:%s" % target.character_id: accepted}


func _collect_reaction_decisions(target: Character) -> Dictionary:
	var decisions: Dictionary = {}
	if target == null:
		return decisions
	decisions["combat_history"] = action_history
	var owner_label := target.character_name
	for player_entity in player_entities:
		if player_entity.get("character") != target:
			continue
		var owner_index := int(player_entity.get("owner_player_index", -1))
		owner_label = "Seat %d - %s" % [owner_index + 1, target.character_name] if owner_index >= 0 else target.character_name
		break
	if target.reaction_available and (target.has_feature("uncanny_dodge") or target.has_feature("rogue_uncanny_dodge")):
		decisions["uncanny_dodge"] = await hud.request_reaction(owner_label, "uncanny_dodge", "Halve the incoming weapon damage.")
	if target.reaction_available and not SpellPermissionRules.payment_choices(target, "shield").is_empty():
		decisions["shield"] = await hud.request_reaction(owner_label, "shield", "Add the Shield spell's AC bonus before the attack resolves.")
		if decisions["shield"]:
			var payment := await hud.request_spell_payment(target, "shield")
			decisions["shield"] = not payment.is_empty()
			decisions[SpellPermissionRules.reaction_key(target, "shield")] = payment
	if target.reaction_available and target.has_feature("monk_deflect_attacks"):
		var prompt_text := "Use your Reaction to reduce incoming damage if this attack hits." if target.has_feature("monk_deflect_energy") else "Use your Reaction to reduce damage if this physical attack hits."
		decisions["deflect_attacks"] = await hud.request_reaction(owner_label, "deflect_attacks", prompt_text)
	if target.has_feature("barbarian_relentless_rage") and target.has_condition("raging") and target.feature_uses.has("bardic_inspiration_die"):
		var die := str(target.feature_uses.get("bardic_inspiration_die", "1d6"))
		decisions["relentless_rage_bardic_inspiration"] = await hud.request_reaction(owner_label, "bardic_inspiration", "If this attack drops you to 0 HP and your Relentless Rage save fails, add %s." % die, "Use Bardic Inspiration on a failed Relentless Rage save?", "Bardic Inspiration — %s" % owner_label)
	decisions.merge(await _collect_projected_ward_decision(target, decisions), true)
	return decisions


func _clear_monk_turn_effects(monk: Character) -> void:
	for monster in monster_entities:
		var stun_sources: Array = monster.get("stunning_strike_stun_sources", [])
		var slow_sources: Array = monster.get("stunning_strike_slow_sources", [])
		stun_sources.erase(monk.get_instance_id())
		slow_sources.erase(monk.get_instance_id())
		if slow_sources.is_empty() and monster.has("stunning_strike_speed"):
			monster["speed"] = int(monster["stunning_strike_speed"])
			monster.erase("stunning_strike_speed")
		if stun_sources.is_empty() and monster.get("stunning_strike_owns_condition", false):
			monster.get("conditions", {}).erase("stunned")
			monster.erase("stunning_strike_owns_condition")
		if stun_sources.is_empty():
			monster.erase("stunning_strike_stunned")
		if monster.get("stunning_strike_advantage_source", -1) == monk.get_instance_id():
			monster.erase("stunning_strike_advantage")
			monster.erase("stunning_strike_advantage_source")
		if stun_sources.is_empty() and slow_sources.is_empty():
			monster.erase("stunning_strike_source")
			monster.erase("stunning_strike_stun_sources")
			monster.erase("stunning_strike_slow_sources")


## Batch 065 (queue item 6): fire one data-declared reaction trigger. Only
## spells and modes whose data declares a matching `reaction_trigger` are
## offered (no engine default). Each prompt goes through the existing
## request_reaction path; a declined prompt, a cancelled payment or a refusal
## spends nothing. The first confirmed reaction spends the Reaction and closes
## the event, so later offers for it are stale.
func _fire_reaction_trigger(reactor: Character, kind: String, source: Variant, reactor_pos: Vector2i, source_pos: Vector2i) -> Array[Dictionary]:
	var receipts: Array[Dictionary] = []
	if reactor == null or not reactor.is_alive: return receipts
	var distance := HexUtils.get_distance(reactor_pos, source_pos) * 5
	var visible := CombatPerception.can_see_target(reactor, source, reactor_pos, source_pos, hex_grid)
	var event := ReactionTriggers.make_event(kind, reactor, source, distance, visible)
	var offered_turn := CombatAction.active_turn_serial
	var source_name: String = str(source.get("name", "the creature")) if source is Dictionary else (source.character_name if source is Character else "the creature")
	for offer in ReactionTriggers.offers(reactor, event):
		if not bool(event.open): break
		var label := _owner_label_for_character(reactor)
		var accepted := await hud.request_reaction(label, str(offer.id), "%s (%s). Use your Reaction?" % [str(offer.name), source_name], "Use %s?" % str(offer.name), "Use Reaction", "%s — %s" % [str(offer.name), label])
		var choice: Variant = null
		if accepted and offer.kind == "spell":
			choice = await hud.request_spell_payment(reactor, str(offer.id))
		elif accepted and offer.kind == "mode":
			var options := ModeControls.options(ModeControls.row(reactor, str(offer.id)), "switch")
			var labels := {}
			for o in options: labels[o] = o.capitalize()
			choice = "" if options.is_empty() else (options[0] if options.size() == 1 or GameManager.test_mode else await hud._request_popup_choice("%s: switch to" % str(offer.name), options, labels))
		# Prompts can outlive their turn or an effect that moved/removed the source.
		if offered_turn != CombatAction.active_turn_serial or _battle_ending:
			ReactionTriggers.close(event)
		var live_reactor := CreatedCommandRules._entity(self, reactor.character_id)
		if live_reactor.is_empty():
			for entity in player_entities:
				if entity.get("character") == reactor: live_reactor = entity
		var live_source: Dictionary = source if source is Dictionary else {}
		if source is Character:
			for entity in player_entities:
				if entity.get("character") == source: live_source = entity
		if live_reactor.is_empty() or live_source.is_empty() or (source is Dictionary and not monster_entities.any(func(m): return is_same(m, source))):
			ReactionTriggers.close(event)
		else:
			var here: Vector2i = live_reactor.get("hex_position", reactor_pos)
			var there: Vector2i = live_source.get("hex_position", source_pos)
			event.distance_feet = HexUtils.get_distance(here, there) * 5
			event.source_visible = CombatPerception.can_see_target(reactor, source, here, there, hex_grid)
		var receipt := ReactionTriggers.confirm(reactor, offer, event, accepted, choice)
		receipt["offer"] = offer.duplicate()
		receipts.append(receipt)
		if not bool(receipt.get("success", false)): continue
		for player_entity in player_entities:
			if player_entity.get("character") == reactor: player_entity["reaction_available"] = false
		if offer.kind == "spell":
			var recipient: Variant = ReactionTriggers.target(reactor, receipt.spell, event)
			var cast := CombatAction.resolve_spell(reactor, recipient, receipt.spell, false, {}, [], int(receipt.get("slot_level", 0)), 0 if is_same(recipient, reactor) else int(event.distance_feet))
			receipt["cast_result"] = cast
			hud.add_log("[color=cyan]%s uses %s in response.[/color] %s" % [reactor.character_name, str(offer.name), str(cast.get("message", ""))])
			if source is Dictionary and int(source.get("current_hp", 1)) <= 0 and bool(source.get("is_alive", true)):
				source["is_alive"] = false
				tracker.remove_combatant(str(source.get("id", "")))
				_trigger_enemy_defeat_features(source, reactor)
		else:
			hud.add_log("[color=cyan]%s spends a Reaction: %s switches to %s.[/color]" % [reactor.character_name, str(offer.name), str(choice)])
	ReactionTriggers.close(event)
	last_reaction_trigger_receipts = receipts
	return receipts


func _offer_stunning_strike(target: Dictionary, weapon: Dictionary, hit_result: Dictionary, caster: Character = null) -> void:
	if caster == null:
		caster = active_character
	if caster == null or not hit_result.get("hit", false) or int(target.get("current_hp", 0)) <= 0 or not caster.has_feature("monk_stunning_strike") or caster.get_focus_points() < 1 or int(caster.feature_uses.get("stunning_strike_used", 0)) > 0:
		return
	if weapon.get("id", "") != "unarmed_strike" and not caster.is_monk_weapon(weapon):
		return
	if await hud.request_reaction(_owner_label_for_character(caster), "stunning_strike", "Spend 1 Focus after this hit? %d remaining." % caster.get_focus_points(), "Use Stunning Strike?", "Stun", "Stunning Strike"):
		var stun_decisions := await _collect_roll_token_decision(target, "monster_save", "CON saving throw against Stunning Strike")
		var result := CombatAction.resolve_stunning_strike(caster, target, stun_decisions)
		hud.add_log(result.get("message", "Stunning Strike unavailable."))
		hud.update_hud(active_character, tracker)


func _offer_deflect_redirect(monk: Character, origin: Vector2i, attack: Dictionary, result: Dictionary) -> void:
	if monk.get_focus_points() < 1:
		return
	var candidates: Array[Dictionary] = []
	var reach := 12 if int(attack.get("range", 1)) > 1 else 1
	for monster in monster_entities:
		if monster.get("is_alive", false) and Targeting.is_in_range(origin, monster.get("hex_position", Vector2i.ZERO), reach):
			candidates.append(monster)
	var selected := await hud.request_deflect_target(candidates)
	if selected < 0 or selected >= candidates.size():
		return
	var target := candidates[selected]
	if not target.get("is_alive", false):
		return
	var redirected := CombatAction.resolve_deflect_redirect(monk, target, str(result.get("damage_type", "bludgeoning")))
	if redirected.get("success", false):
		hud.add_log(redirected.get("message", "Attack redirected."))
		if int(target.get("current_hp", 0)) <= 0:
			target["is_alive"] = false
			tracker.remove_combatant(target.get("id", ""))
		_update_grid_entities()


func _collect_counterspell_decisions(caster: Character, spell_data: Dictionary = {}, caster_position: Vector2i = Vector2i.ZERO, visibility_target = null) -> Dictionary:
	var decisions: Dictionary = {}
	var observers: Array[Character] = []
	if caster == null: return {"decisions":decisions,"observers":observers}
	# This reaction window observes a perceptible component-bearing cast.
	var components: Array = spell_data.get("components", [])
	if not components.any(func(component): return str(component) in ["V", "S", "M"]):
		return {"decisions":decisions,"observers":observers}
	var stopping_spells: Array[Dictionary] = []
	var native := DataLoader.get_spell("counterspell")
	if SpellSupport.is_available(native): stopping_spells.append(native)
	for candidate in DataLoader.get_all_spells():
		if candidate.get("id", "") != "counterspell" and candidate.get("casting_time", "") == "reaction" and candidate.has("cancellation_rule") and SpellSupport.is_available(candidate):
			stopping_spells.append(candidate)
	var incoming := SpellResolutionContext.new()
	incoming.caster = caster
	incoming.spell = spell_data
	incoming.spell_definition_id = str(spell_data.get("id", ""))
	incoming.slot_level = int(spell_data.get("_selected_spell_slot_level", spell_data.get("level", 0)))
	# The normal command carries its validated pre-payment permission even when
	# the last use has just been spent. Resolution still checks the paid receipt.
	for permission in spell_data.get("_source_permissions", []):
		if permission.get("id", "") == spell_data.get("_source_permission_id", ""):
			incoming.decisions["cast_payment_receipt"] = {"permission_kind":permission.get("kind", "")}
	var visible_target = visibility_target if visibility_target != null else caster
	for player_entity in player_entities:
		var observer: Character = player_entity.get("character")
		if observer == null or observer == caster or not observer.is_alive or not observer.reaction_available or CombatAction.is_incapacitated(observer): continue
		var observer_position: Vector2i = player_entity.get("hex_position", Vector2i.ZERO)
		var distance_feet := HexUtils.get_distance(observer_position, caster_position) * 5
		if not CombatPerception.can_see_target(observer, visible_target, observer_position, caster_position, hex_grid) or not CombatAction.spell_target_is_visible_to(observer, visible_target, {"requires_target_sight":true}, distance_feet): continue
		for stopping in stopping_spells:
			var id := str(stopping.id)
			if not Targeting.is_in_range(observer_position, caster_position, int(stopping.get("range", 12))) or SpellPermissionRules.payment_choices(observer, id).is_empty(): continue
			if stopping.has("cancellation_rule") and not CastInterruptionRules.is_cast_matching_cancellation(incoming, stopping.cancellation_rule).get("matches", false): continue
			if observer not in observers: observers.append(observer)
			var detail := "You see %s casting a spell. Use %s to try to interrupt it?" % [caster.character_name, str(stopping.get("name", id))]
			if id == "counterspell": detail = "You see %s casting a spell within 60 feet. Force a Constitution save against your spell save DC to interrupt it?" % caster.character_name
			var accepted := await hud.request_reaction(_owner_label_for_character(observer), id, detail)
			if not accepted: continue
			var payment := await hud.request_spell_payment(observer, id)
			if payment.is_empty(): continue
			decisions[SpellPermissionRules.reaction_key(observer, id)] = payment
			if id == "counterspell": decisions["counterspell:%s" % observer.character_name] = true
			else: decisions["stopping_spell:%s" % observer.character_name] = id
			break
	return {"decisions":decisions,"observers":observers}


static func _make_temp_monster_character(m: Dictionary) -> Character:
	var c := Character.new()
	c.character_name = m["name"]
	c.creature_type = str(m.get("creature_type", ""))
	c.feature_uses["is_monster_actor"] = true
	c.feature_uses["monster_source"] = m
	var senses: Dictionary = m.get("senses", {})
	c.feature_uses["monster_blindsight_range_feet"] = int(m.get("blindsight_range_feet", senses.get("blindsight", 0)))
	c.feature_uses["creature_blindsight_range_feet"] = c.feature_uses["monster_blindsight_range_feet"]
	c.feature_uses["monster_truesight_range_feet"] = int(m.get("truesight_range_feet", senses.get("truesight", 0)))
	c.darkvision_feet = int(m.get("darkvision_range_feet", senses.get("darkvision", 0)))
	c.darkvision = c.darkvision_feet > 0
	c.speed = int(m.get("speed", 6))
	c.set_movement_speed_feet("fly", int(m.get("fly_speed_feet", 0)))
	c.set_movement_speed_feet("climb", int(m.get("climb_speed_feet", 0)))
	c.ability_scores.from_dict(m.get("ability_scores", {}))
	c.proficiency_bonus = int(m.get("proficiency_bonus", 2))
	var conditions: Dictionary = m.get("conditions", {})
	if conditions.has("vicious_mockery_disadvantage"):
		c.add_condition("vicious_mockery_disadvantage", int(conditions["vicious_mockery_disadvantage"]))
	if conditions.has("ray_of_enfeeblement"):
		c.add_condition("ray_of_enfeeblement", int(conditions["ray_of_enfeeblement"]))
	if conditions.has("blessed"):
		c.add_condition("blessed", int(conditions["blessed"]))
	if conditions.has("baned"):
		c.add_condition("baned", int(conditions["baned"]))
	if conditions.has("resilient_sphere"):
		c.add_condition("resilient_sphere", int(conditions["resilient_sphere"]))
	return c


func _collect_eligible_roll_token_entries(test_kind: String, roller, explicit_roller_pos: Variant = null, extra_context: Dictionary = {}) -> Array[Dictionary]:
	var actual_roller = roller
	if roller is Character and bool(roller.feature_uses.get("is_monster_actor", false)) and roller.feature_uses.get("monster_source") is Dictionary:
		actual_roller = roller.feature_uses["monster_source"]
	var roller_pos := Vector2i.ZERO
	var found_roller_pos := false
	if explicit_roller_pos is Vector2i:
		roller_pos = explicit_roller_pos
		found_roller_pos = true
	elif actual_roller is Character:
		for player_entity in player_entities:
			if player_entity.get("character") == actual_roller:
				roller_pos = player_entity.get("hex_position", Vector2i.ZERO)
				found_roller_pos = true
				break
	elif actual_roller is Dictionary:
		roller_pos = actual_roller.get("hex_position", Vector2i.ZERO)
		found_roller_pos = true
	var options: Array[Dictionary] = []
	for player_entity in player_entities:
		var owner: Character = player_entity.get("character")
		if owner == null or not owner.is_alive or CombatAction.is_incapacitated(owner):
			continue
		var owner_pos: Vector2i = player_entity.get("hex_position", Vector2i.ZERO)
		for pool in RollTokenRules.pool_definitions(owner):
			var pool_id := str(pool.get("pool_id", ""))
			if not RollTokenRules.can_use_pool_this_turn(owner, pool):
				continue
			var tokens: Array = RollTokenRules.available_tokens(owner, pool_id)
			if tokens.is_empty():
				continue
			var predicate := str(pool.get("target_predicate", "any_visible"))
			var eligible := false
			if actual_roller is Character and actual_roller == owner:
				eligible = predicate in ["self", "self_only", "any_visible", "self_or_visible_creature", "ally_visible"]
			elif predicate in ["self", "self_only"]:
				eligible = false
			elif predicate == "ally_visible":
				eligible = actual_roller is Character and found_roller_pos and CombatPerception.can_see_target(owner, actual_roller, owner_pos, roller_pos, hex_grid)
			elif predicate == "enemy_visible":
				eligible = actual_roller is Dictionary and found_roller_pos and CombatPerception.can_see_target(owner, actual_roller, owner_pos, roller_pos, hex_grid)
			else:
				eligible = found_roller_pos and CombatPerception.can_see_target(owner, actual_roller, owner_pos, roller_pos, hex_grid)
			if not eligible:
				continue
			var source_name := str(pool.get("feature_name", "Roll Token"))
			for token in tokens:
				var tid := str(token.get("token_id", token.get("id", "")))
				options.append({
					"owner": owner,
					"owner_id": owner.character_id,
					"owner_name": owner.character_name,
					"pool_id": pool_id,
					"token_id": tid,
					"value": int(token.get("value", 0)),
					"source_name": source_name,
					"label": "%s — %s: %d" % [owner.character_name, source_name, int(token.get("value", 0))],
				})
	return options


func _collect_roll_token_decision(roller, test_kind: String, test_label: String, seeded_decisions: Dictionary = {}) -> Dictionary:
	var normalized := RollTokenRules.normalize_decision(seeded_decisions)
	if not normalized.is_empty():
		return {"roll_token_replacement": normalized}
	var actual_roller = roller
	if roller is Character and bool(roller.feature_uses.get("is_monster_actor", false)) and roller.feature_uses.get("monster_source") is Dictionary:
		actual_roller = roller.feature_uses["monster_source"]
	var options := _collect_eligible_roll_token_entries(test_kind, roller)
	if options.is_empty() or hud == null or not hud.has_method("request_roll_token_replacement"):
		return {}
	var roller_name: String = actual_roller.character_name if actual_roller is Character else str(actual_roller.get("name", "Creature")) if actual_roller is Dictionary else "Creature"
	var chosen: Dictionary = await hud.request_roll_token_replacement(roller_name, test_label, options)
	if chosen.is_empty():
		return {}
	return {"roll_token_replacement": chosen}


func _collect_projected_ward_decision(target: Character, seeded_decisions: Dictionary = {}) -> Dictionary:
	if seeded_decisions.get("projected_ward") is Dictionary and not (seeded_decisions["projected_ward"] as Dictionary).is_empty():
		return {"projected_ward": seeded_decisions["projected_ward"]}
	if target == null or not target.is_alive or hud == null or not hud.has_method("request_reaction"):
		return {}
	var target_pos := Vector2i.ZERO
	var found_target := false
	for player_entity in player_entities:
		if player_entity.get("character") == target:
			target_pos = player_entity.get("hex_position", Vector2i.ZERO)
			found_target = true
			break
	if not found_target:
		return {}
	for player_entity in player_entities:
		var owner: Character = player_entity.get("character")
		if owner == null or owner == target or not owner.is_alive or CombatAction.is_incapacitated(owner) or not owner.reaction_available:
			continue
		var owner_pos: Vector2i = player_entity.get("hex_position", Vector2i.ZERO)
		for feature_entry in WardRules.feature_definitions_for_character(owner):
			var feature: Dictionary = feature_entry
			for raw_effect in feature.get("effects", []):
				if not (raw_effect is Dictionary) or str(raw_effect.get("type", "")).strip_edges() != "damage_ward_projection":
					continue
				var effect: Dictionary = raw_effect
				var pool_id := str(effect.get("pool_id", "")).strip_edges()
				var state := WardRules.ward_state(owner, pool_id)
				if not bool(state.get("active", false)) or int(state.get("current_hp", 0)) <= 0:
					continue
				var range_feet := int(effect.get("range_feet", 30))
				var range_hexes := maxi(1, int(ceil(float(range_feet) / 5.0)))
				if not Targeting.is_in_range(owner_pos, target_pos, range_hexes):
					continue
				if bool(effect.get("requires_sight", true)) and not CombatPerception.can_see_target(owner, target, owner_pos, target_pos, hex_grid):
					continue
				var owner_label := _owner_label_for_character(owner)
				var feature_name := str(feature.get("name", "Projected Ward"))
				var ward_name := WardRules.ward_display_name(owner, pool_id)
				var ward_hp := int(state.get("current_hp", 0))
				var ward_max := int(state.get("max_hp", 0))
				var accepted := await hud.request_reaction(
					owner_label,
					"projected_ward",
					"Protect %s with %s (%d/%d HP) if they take damage?" % [target.character_name, ward_name, ward_hp, ward_max],
					"Use %s?" % feature_name,
					"Project Ward",
					"%s — %s" % [feature_name, owner_label]
				)
				if accepted:
					return {
						"projected_ward": {
							"owner": owner,
							"pool_id": pool_id,
							"feature_id": str(feature.get("id", "")),
							"distance_feet": HexUtils.get_distance(owner_pos, target_pos) * 5,
							"can_see": true,
						}
					}
	return {}


static func _sync_consumed_monster_attack_conditions(monster: Dictionary, attacker: Character) -> void:
	if attacker.has_condition("vicious_mockery_disadvantage"):
		return
	var conditions: Dictionary = monster.get("conditions", {})
	conditions.erase("vicious_mockery_disadvantage")
	monster["conditions"] = conditions
	var sources: Dictionary = monster.get("condition_sources", {})
	sources.erase("vicious_mockery_disadvantage")
	monster["condition_sources"] = sources


func _highlight_reachable() -> void:
	_sync_changed_movement_speed()
	_clear_path_preview()
	if hex_grid == null or player_entities.is_empty() or current_player_idx < 0 or current_player_idx >= player_entities.size():
		return
	hud.set_movement_modes(active_character, active_movement_mode, _movement_speed_overrides(active_character))
	var pos: Vector2i = player_entities[current_player_idx]["hex_position"]
	var reachable := _player_reachable(pos, remaining_speed, active_character)
	
	# Don't draw A* route on active player hex
	var highlights := {}
	for hex in reachable:
		if hex == pos: continue
		highlights[hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.MOVEMENT]
	if _can_use_spell_jump() and remaining_speed >= 2.0:
		for hex in hex_grid.tiles:
			if _spell_jump_move_cost(pos, hex, reachable) >= 0.0:
				highlights[hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.MOVEMENT]
	
	hex_grid.set_highlights(highlights)


func _on_movement_mode_selected(mode: String) -> void:
	_sync_changed_movement_speed()
	if active_character == null:
		hud.set_movement_modes(active_character, active_movement_mode, _movement_speed_overrides(active_character))
		return
	if mode not in ["walk", "climb", "swim", "fly"] or _movement_speed_feet(mode, active_character) <= 0:
		hud.set_movement_modes(active_character, active_movement_mode, _movement_speed_overrides(active_character))
		return
	var prone_factor := 0.5 if active_character.has_condition("prone") else 1.0
	var used_speed := maxf(0.0, _active_movement_speed_hexes() * prone_factor + extra_movement_speed_hexes - remaining_speed + _movement_speed_shortfall)
	active_movement_mode = mode
	var available_speed := _active_movement_speed_hexes() * prone_factor + extra_movement_speed_hexes - used_speed
	active_character.feature_uses.erase("find_steed_just_mounted_this_turn")
	_set_remaining_movement(available_speed)
	_movement_speed_snapshot = _active_movement_speed_hexes()
	_highlight_reachable()


func _on_flight_altitude_delta(delta_feet: int) -> void:
	var room := LocalRoomCombat.room()
	if room.is_empty() or active_character == null or current_player_idx < 0:
		return
	if SpellEffects.has_spell(active_character, "levitate"):
		if active_movement_mode != "walk" or abs(delta_feet) != 5 or remaining_speed < 1.0:
			hud.add_log("Spend 5 feet of movement to change Levitate altitude.")
			return
		var levitating_player: Dictionary = player_entities[current_player_idx]
		var levitating_position: Vector2i = levitating_player.get("hex_position", Vector2i.ZERO)
		var levitating_floor := LocalRoomRules.elevation_feet(room, levitating_position)
		var levitating_altitude := int(levitating_player.get("altitude_feet", LocalRoomRules.altitude_feet(room, active_character.character_id)))
		var next_levitating_altitude := levitating_altitude + delta_feet
		if next_levitating_altitude < levitating_floor or next_levitating_altitude + 5 > LocalRoomRules.ceiling_feet(room, levitating_position):
			hud.add_log("That altitude is blocked by the floor or ceiling.")
			return
		levitating_player["altitude_feet"] = next_levitating_altitude
		var levitating_altitudes: Dictionary = room.get("party_altitudes", {}).duplicate(true)
		levitating_altitudes[active_character.character_id] = next_levitating_altitude
		room["party_altitudes"] = levitating_altitudes
		remaining_speed -= 1.0
		player_moved_this_turn = true
		hud.add_log("%s levitates to altitude %d ft." % [active_character.character_name, next_levitating_altitude])
		_highlight_reachable()
		return
	if active_movement_mode != "fly":
		return
	if abs(delta_feet) != 5 or remaining_speed < 1.0:
		hud.add_log("Spend at least 5 feet of Fly Speed to change altitude.")
		return
	var player: Dictionary = player_entities[current_player_idx]
	var position: Vector2i = player.get("hex_position", Vector2i.ZERO)
	var floor_feet := LocalRoomRules.elevation_feet(room, position)
	var altitude := int(player.get("altitude_feet", LocalRoomRules.altitude_feet(room, active_character.character_id)))
	var next_altitude := altitude + delta_feet
	if next_altitude < floor_feet or next_altitude + 5 > LocalRoomRules.ceiling_feet(room, position):
		hud.add_log("That altitude is blocked by the floor or ceiling.")
		return
	player["altitude_feet"] = next_altitude
	var party_altitudes: Dictionary = room.get("party_altitudes", {}).duplicate(true)
	party_altitudes[active_character.character_id] = next_altitude
	room["party_altitudes"] = party_altitudes
	var altitude_modes: Dictionary = room.get("party_altitude_modes", {}).duplicate(true)
	altitude_modes[active_character.character_id] = "fly"
	room["party_altitude_modes"] = altitude_modes
	_sync_mounted_steed_position(active_character, position)
	remaining_speed -= 1.0
	player_moved_this_turn = true
	hud.add_log("%s flies to altitude %d ft." % [active_character.character_name, next_altitude])
	_highlight_reachable()


func _active_movement_speed_hexes() -> float:
	if active_character == null:
		return 0.0
	return float(_movement_speed_feet(active_movement_mode, active_character)) / 5.0


func _movement_speed_feet(mode: String, character: Character) -> int:
	if character == null:
		return 0
	if not PaladinRules.find_steed_is_mounted(character):
		var speed_feet := character.movement_speed_feet(mode)
		return character.movement_speed_feet("walk") if mode in ["climb", "swim"] and speed_feet <= 0 else speed_feet
	var steed := _find_steed_entity(character)
	var steed_character: Character = steed.get("character")
	if steed_character == null:
		return 0
	return steed_character.movement_speed_feet(mode)


func _movement_speed_overrides(character: Character) -> Dictionary:
	if character == null:
		return {}
	return {
		"walk": _movement_speed_feet("walk", character),
		"climb": _movement_speed_feet("climb", character),
		"swim": _movement_speed_feet("swim", character),
		"fly": _movement_speed_feet("fly", character),
	}


func _find_steed_entity(owner: Character) -> Dictionary:
	if owner == null:
		return {}
	for entity in player_entities:
		if entity.get("is_steed", false) and entity.get("steed_owner") == owner:
			return entity
	return {}


func _toggle_find_steed_mount() -> void:
	var steed_entity := _find_steed_entity(active_character)
	if steed_entity.is_empty():
		hud.add_log("Your bonded steed is not present in this encounter.")
		return
	var steed_character: Character = steed_entity.get("character")
	if steed_character == null or not steed_character.is_alive or CombatAction.is_incapacitated(active_character):
		hud.add_log("You cannot mount or dismount right now.")
		return
	var half_speed_cost := int(floor(float(active_character.get_speed()) / 2.0))
	if remaining_speed < float(half_speed_cost):
		hud.add_log("You need %d feet of movement remaining to mount or dismount." % (half_speed_cost * 5))
		return
	var rider_entity: Dictionary = player_entities[current_player_idx]
	var rider_position: Vector2i = rider_entity.get("hex_position", Vector2i.ZERO)
	var steed_position: Vector2i = steed_entity.get("hex_position", Vector2i.ZERO)
	var was_mounted := PaladinRules.find_steed_is_mounted(active_character)
	if not was_mounted and HexUtils.get_distance(rider_position, steed_position) > 1:
		hud.add_log("Move within 5 feet of your steed before mounting.")
		return
	var destination := rider_position
	if was_mounted:
		var found_space := false
		for candidate in HexUtils.get_hexes_in_range(steed_position, 1):
			if candidate == steed_position or not hex_grid.has_tile(candidate) or not hex_grid.is_hex_passable(candidate) or _is_occupied_hex(candidate):
				continue
			destination = candidate
			found_space = true
			break
		if not found_space:
			hud.add_log("There is no open space beside the steed to dismount.")
			return
	_sync_changed_movement_speed()
	var old_speed := _active_movement_speed_hexes()
	var used_speed := maxf(0.0, old_speed - remaining_speed + _movement_speed_shortfall)
	var mount_state := PaladinRules.find_steed_state(active_character)
	if not PaladinRules.set_find_steed_mounted(active_character, not was_mounted):
		hud.add_log("The bonded steed state is unavailable.")
		return
	if was_mounted:
		rider_entity["hex_position"] = destination
		var rider_speed := float(active_character.movement_speed_feet("walk")) / 5.0
		_set_remaining_movement(rider_speed - used_speed - float(half_speed_cost))
		hud.add_log("You dismount, spending %d feet of movement." % (half_speed_cost * 5))
	else:
		steed_entity["hex_position"] = steed_position
		rider_entity["hex_position"] = steed_position
		var steed_speed := float(mount_state.get("speed_feet", 60)) / 5.0
		_set_remaining_movement(steed_speed - used_speed - float(half_speed_cost))
		active_character.feature_uses["find_steed_just_mounted_this_turn"] = true
		if int(mount_state.get("fly_speed_feet", 0)) > 0:
			steed_character.set_movement_speed_feet("fly", int(mount_state["fly_speed_feet"]))
		hud.add_log("You mount your steed, spending %d feet of movement." % (half_speed_cost * 5))
	player_moved_this_turn = true
	active_movement_mode = "walk"
	_movement_speed_snapshot = _active_movement_speed_hexes()
	player_entities[current_player_idx]["altitude_feet"] = int(player_entities[current_player_idx].get("altitude_feet", 0))
	steed_entity["altitude_feet"] = player_entities[current_player_idx]["altitude_feet"]
	hud.set_movement_modes(active_character, active_movement_mode, _movement_speed_overrides(active_character))
	_update_grid_entities()
	_highlight_reachable()


func _sync_mounted_steed_position(owner: Character, position: Vector2i) -> void:
	if owner == null or not PaladinRules.find_steed_is_mounted(owner):
		return
	var steed_entity := _find_steed_entity(owner)
	if steed_entity.is_empty():
		return
	steed_entity["hex_position"] = position
	for player in player_entities:
		if player.get("character") == owner:
			steed_entity["altitude_feet"] = int(player.get("altitude_feet", 0))
			break


func _grant_extra_movement_speed() -> void:
	_sync_changed_movement_speed()
	var bonus := _active_movement_speed_hexes()
	extra_movement_speed_hexes += bonus
	_set_remaining_movement(remaining_speed - _movement_speed_shortfall + bonus)


func _can_use_spell_jump() -> bool:
	return active_character != null and active_character.has_condition("jumping") and not bool(active_character.feature_uses.get("jump_spell_used_this_turn", false))


func _spell_jump_move_cost(origin: Vector2i, destination: Vector2i, reachable: Dictionary) -> float:
	if not _can_use_spell_jump() or remaining_speed < 2.0 or destination == origin:
		return -1.0
	if HexUtils.get_distance(origin, destination) > 6 or not hex_grid.is_hex_passable(destination) or _is_occupied_hex(destination):
		return -1.0
	var walking_cost := float(reachable.get(destination, INF))
	if walking_cost <= remaining_speed:
		return -1.0
	return 2.0


# --- Action handlers ---

func _on_hud_action(action_type: String, extra_data: Dictionary) -> void:
	if _pool_recovery_pending or _cast_in_progress: return
	if not child_actions.frame.is_empty():
		if action_type == "cancel" and not resolving_player_action:
			pending_action_type = ""
			pending_spell_data = {}
			await child_actions.cancel(self)
		return
	if fighter_move_waiting:
		if action_type == "cancel":
			fighter_move_done = true
		return
	if resolving_player_action or current_player_idx < 0:
		return
	var command := CombatCommand.from_hud_for_character(action_type, extra_data, active_character)
	if command == null:
		hud.add_log("Invalid combat action.")
		return
	action_type = command.action_type
	extra_data = command.payload
	if active_character.class_id == "familiar" and action_type not in ["move", "dodge", "end_turn", "cancel", "use_feature"]:
		hud.add_log("A familiar can move, Dodge, or take another non-attack action.")
		return
	if action_type in ["cast_spell", "activate_magic_item"] and active_character != null:
		var support := SpellSupport.availability(extra_data.get("spell", {}))
		if not support["available"]:
			hud.add_log(support["reason"])
			return
		var quickened_spell := await SpellCastSelection.choose_quickened(_spell_cast_context(), extra_data.get("spell", {}).duplicate(true))
		if not quickened_spell.is_empty():
			extra_data["spell"] = quickened_spell
	if action_type == "command_created_actor": # Batch 055 S-156: the command itself charges the declared cost once.
		var commanded := CreatedCommandRules.issue(self, active_character, str(extra_data.get("actor_id", "")), str(extra_data.get("order", "")), str(extra_data.get("target_id", "")))
		hud.add_log(str(commanded.message))
		if commanded.success: _check_battle_end_conditions()
		hud.update_hud(active_character, tracker)
		return
	var cost_type := _action_cost_for_command(action_type, extra_data)
	if action_type == "cast_spell" and SorcererRules.quickened_spell_blocks_cast(active_character, extra_data.get("spell", {})):
		hud.add_log("You can't cast another level 1+ spell this turn after using Quickened Spell.")
		return
	var has_action_budget := active_character.reaction_available if cost_type == "reaction" and extra_data.get("feature", {}).has("child_actions") else _can_spend_action_cost(cost_type)
	var selected_spell: Dictionary = extra_data.get("spell", {})
	var definition: Dictionary = selected_spell if action_type == "cast_spell" else extra_data.get("item", {}) if action_type == "use_item" else extra_data.get("feature", {}) if action_type == "use_feature" else {}
	var attack_substitution_units := _attack_unit_substitution_units(definition) if action_type == "cast_spell" else CombatChildActions.units(definition)
	var use_attack_substitution := cost_type in ["action", "magic_action"] and attack_substitution_units > 0 and _remaining_strike_units() >= attack_substitution_units
	if use_attack_substitution:
		has_action_budget = true
	var choosing_produce_flame_mode := action_type == "cast_spell" and str(selected_spell.get("id", "")) == "produce_flame" and active_character != null and produce_flame_markers.has(active_character.character_id)
	if action_type == "use_feature" and str(extra_data.get("feature", {}).get("id", "")) in ["monk_flurry_of_blows", "monk_bonus_unarmed_strike"] and remaining_flurry_swings > 0:
		has_action_budget = true
	if not has_action_budget and choosing_produce_flame_mode:
		has_action_budget = _can_spend_action_cost("magic_action") or _can_spend_action_cost("bonus_action")
	if not has_action_budget and not (action_type == "attack" and remaining_attack_swings > 0) and action_type not in ["end_turn", "cancel", "move", "toggle_find_steed_mount"]:
		hud.add_log("You have no %s available this turn." % cost_type.replace("_", " "))
		return

	# Dismiss the first-turn hint once the player acts.
	hud.hide_hint()

	match action_type:
		"cancel":
			_cancel_pending_action()
			return
		"use_captured_grant":
			var result := CapturedGrantRules.use(active_character, str(extra_data.get("grant_id", "")), turn_budget)
			if result.get("success", false):
				if result.grant.use_cost != "reaction": action_history.record_action(active_character)
				for entry in player_entities:
					if entry.get("character") == active_character: entry["reaction_available"] = active_character.reaction_available
				hud.add_log(result.message)
				print("CAPTURED GIFT USE: " + JSON.stringify(result))
			hud.update_hud(active_character, tracker)
			return
		"choose_aura_protection":
			await _choose_aura_protection(str(extra_data.get("group", "")))
			return
		"choose_protection":
			var protection_owner := active_character
			var request := ProtectionRules.begin_choice(protection_owner,str(extra_data.get("group","")))
			var selected_id: String = await hud.request_protection_choice(request)
			if active_character!=protection_owner or hud.active_character!=protection_owner or not is_inside_tree() or not player_entities.any(func(entry): return entry.get("character")==protection_owner):
				ProtectionRules.answer(protection_owner,request,"")
				return
			if not ProtectionRules.answer(protection_owner,request,selected_id): hud.add_log("That protection choice is no longer available.")
			hud.update_hud(active_character,tracker)
			return
		"dismiss_source_benefit":
			if SourceBenefitRules.dismiss(active_character, str(extra_data.get("source_instance_id", ""))):
				hud.add_log("The selected spell benefit ends.")
			hud.update_hud(active_character, tracker)
			_highlight_reachable()
			return
		"dismiss_timed_numeric_modifier":
			var dismissed := active_character.dismiss_campaign_modifier(str(extra_data.get("source_instance_id", "")), str(extra_data.get("grant_instance_id", "")), int(GameManager.campaign_elapsed_seconds))
			if dismissed.get("success", false):
				var end_message := "The timed benefit ends without a cooldown." if int(dismissed.get("cooldown_seconds", 0)) == 0 else "The timed benefit ends; this source's cooldown begins now."
				hud.add_log(end_message)
			else:
				hud.add_log(str(dismissed.get("message", "That timed benefit is no longer active.")))
			hud.update_hud(active_character, tracker)
			return
		"toggle_find_steed_mount":
			_toggle_find_steed_mount()
			return
		"font_of_magic_convert":
			var conversion := SorcererRules.convert_slot_to_points(active_character, int(extra_data.get("slot_level", 0)))
			hud.add_log(str(conversion.get("message", "Font of Magic conversion failed.")))
			hud.update_hud(active_character, tracker)
			return
		"font_of_magic_create":
			var creation := SorcererRules.create_spell_slot(active_character, int(extra_data.get("slot_level", 0)), turn_budget)
			hud.add_log(str(creation.get("message", "Font of Magic could not create a slot.")))
			hud.update_hud(active_character, tracker)
			return
		"move_dancing_lights":
			pending_action_type = "dancing_lights_move"
			hud.add_log("Choose a space to move the linked lights up to 60 feet. They stay linked and within 120 feet.")
			_highlight_dancing_lights_movement()
			return
		"move_moonbeam":
			if not turn_budget.can_spend("magic_action"):
				return
			var moonbeam_source := _moonbeam_zone_source_for_caster(active_character)
			var moonbeam_zone: Dictionary = active_spell_zones.get(moonbeam_source, {})
			if moonbeam_zone.is_empty() or not _moonbeam_can_move(moonbeam_zone):
				hud.add_log("[color=orange]You can move Moonbeam with a Magic action on a later turn.[/color]")
				return
			pending_action_type = "moonbeam_move"
			hud.add_log("Choose a new center for the Moonbeam Cylinder, up to 60 feet from its current center.")
			_highlight_moonbeam_movement()
			return
		"move_cloud_of_daggers":
			if not turn_budget.can_spend("magic_action"):
				return
			var daggers_source := _cloud_of_daggers_zone_source_for_caster(active_character)
			var daggers_zone: Dictionary = active_spell_zones.get(daggers_source, {})
			if daggers_zone.is_empty() or not _cloud_of_daggers_can_move(daggers_zone):
				hud.add_log("[color=orange]You can teleport Cloud of Daggers with a Magic action on a later turn.[/color]")
				return
			pending_action_type = "cloud_of_daggers_move"
			hud.add_log("Choose a new space for Cloud of Daggers, up to 30 feet from its current space.")
			_highlight_cloud_of_daggers_movement()
			return
		"move_conjure_animals":
			var animals_source := _conjure_animals_zone_source_for_caster(active_character)
			var animals_zone: Dictionary = active_spell_zones.get(animals_source, {})
			if animals_zone.is_empty() or not player_moved_this_turn or bool(active_character.feature_uses.get("conjure_animals_pack_moved_this_turn", false)):
				hud.add_log("[color=orange]Move Conjure Animals after you move, once per turn.[/color]")
				return
			pending_action_type = "conjure_animals_move"
			hud.add_log("Choose an unoccupied pack space up to 30 feet away.")
			_highlight_conjure_animals_movement()
			return
		"move_conjure_celestial":
			var celestial_source := _conjure_celestial_zone_source_for_caster(active_character)
			var celestial_zone: Dictionary = active_spell_zones.get(celestial_source, {})
			if celestial_zone.is_empty() or not player_moved_this_turn or bool(active_character.feature_uses.get("conjure_celestial_pillar_moved_this_turn", false)):
				hud.add_log("[color=orange]Move Conjure Celestial after you move, once per turn.[/color]")
				return
			pending_action_type = "conjure_celestial_move"
			hud.add_log("Choose a new center for the Conjure Celestial Cylinder, up to 30 feet away.")
			_highlight_conjure_celestial_movement()
			return
		"move_conjure_fey":
			if not turn_budget.can_spend("bonus_action"):
				hud.add_log("Conjure Fey needs your Bonus Action to teleport and attack.")
				return
			var fey_source := _conjure_fey_zone_source_for_caster(active_character)
			var fey_zone: Dictionary = active_spell_zones.get(fey_source, {})
			if fey_zone.is_empty() or str(fey_zone.get("cast_turn", "")) == _current_spell_trigger_turn():
				hud.add_log("Conjure Fey's spirit can teleport on a later turn while you concentrate.")
				return
			pending_action_type = "conjure_fey_move"
			hud.add_log("Choose a space up to 30 feet from the Conjure Fey spirit, then choose a creature it can reach.")
			_highlight_conjure_fey_movement()
			return
		"conjure_woodland_beings_disengage":
			var woodland_source := _conjure_woodland_beings_zone_source_for_caster(active_character)
			if woodland_source.is_empty() or not _spend_action_cost("bonus_action"):
				return
			active_character.add_condition("disengaging", 1)
			hud.add_log("[color=green]%s uses Conjure Woodland Beings: Disengage.[/color]" % active_character.character_name)
			hud.update_hud(active_character, tracker)
			return
		"dismiss_light":
			light_spell_markers.erase(active_character.character_id)
			hud.add_log("The magical light fades.")
			_spend_action_cost("action")
			_update_grid_entities()
			hud.update_hud(active_character, tracker)
			_highlight_reachable()
			return
		"detect_magic_inspect":
			var origin: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
			var auras := DetectMagicRules.auras_within(origin, player_entities, monster_entities, active_spell_zones)
			if auras.is_empty():
				hud.add_log("Detect Magic senses no represented magical effects within 30 feet.")
				return
			_spend_action_cost("magic_action")
			for aura in auras:
				var school: String = str(aura.get("school", ""))
				var school_text := (" (%s)" % school.capitalize()) if not school.is_empty() else ""
				hud.add_log("[color=cyan]%s aura: %s%s.[/color]" % [str(aura.get("name", "Magic")), str(aura.get("location", "nearby")), school_text])
			hud.update_hud(active_character, tracker)
			_highlight_reachable()
			return
		"control_mage_hand":
			if not mage_hand_markers.has(active_character.character_id):
				hud.add_log("You can control only your own Mage Hand.")
				return
			pending_action_type = "mage_hand_move"
			hud.add_log("Choose a space up to 30 feet away; the hand must remain within 30 feet of you.")
			_highlight_mage_hand_movement()
			return
		"dismiss_mage_hand":
			if not mage_hand_markers.has(active_character.character_id):
				hud.add_log("You can dismiss only your own Mage Hand.")
				return
			mage_hand_markers.erase(active_character.character_id)
			_spend_action_cost("magic_action")
			hud.add_log("The spectral hand vanishes.")
			hud.update_hud(active_character, tracker)
			_update_grid_entities()
			_highlight_reachable()
			return
		"attack":
			strike_unit_parent = "attack"
			pending_action_type = "attack"
			hud.show_hint("Attack: click an enemy in highlighted reach. Esc/Cancel to back out.")
			hud.add_log("Click on an enemy to attack with your Beast form." if DruidRules.is_shaped(active_character) else "Click on an enemy to Attack.")
			_highlight_attack_targets()
		"cast_spell":
			if await SpellCastSelection.choose(_spell_cast_context(), extra_data.get("spell", {})):
				if use_attack_substitution:
					pending_spell_data["_attack_unit_substitution_units"] = attack_substitution_units
					pending_spell_data["_parent_action_id"] = "attack"
				_highlight_spell_targets()
		"activate_magic_item":
			if await SpellCastSelection.choose(_spell_cast_context(), extra_data.get("spell", {})):
				_highlight_spell_targets()
		"use_feature":
			var feature: Dictionary = extra_data.get("feature", {})
			if feature.has("child_actions"):
				await child_actions.start(self, feature)
				return
			if use_attack_substitution and feature.has("executor") and feature.get("effects", []).all(func(effect): return str(effect.get("type", "")) in ["heal", "heal_self"]):
				var result := ClassFeature.execute(active_character, feature, null, null)
				if result.get("success", false):
					_consume_strike_units(attack_substitution_units)
					hud.add_log("%s replaces %d strike units." % [feature.get("name", "Healing"), attack_substitution_units])
					hud.update_hud(active_character, tracker)
				return
			if feature.has("resource_pool") and feature["resource_pool"].has("die_size"):
				var pool_state := ResourcePoolRules.availability(active_character, str(feature.get("source_instance_id", "")))
				if not pool_state.get("available", false):
					hud.add_log(str(pool_state.get("message", "No dice remain for that source.")))
					return
			if str(feature.get("id", "")) in ["created_attack", "created_guard"]:
				if str(feature["id"]) == "created_attack":
					pending_action_type = "created_creature_order"
					hud.add_log("Choose an enemy. All controlled Undead within 60 feet receive the same attack order.")
				else:
					hud.add_log(str(CreatedCreatureCombat.issue(self, "guard")["message"]))
					hud.update_hud(active_character, tracker)
				return
			if str(feature.get("resolver", "")) == "paladin_rules" and str(feature.get("id", "")) == "paladin_abjure_foes":
				var origin: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
				var candidates: Array[Dictionary] = []
				for monster in monster_entities:
					if monster.get("is_alive", false) and HexUtils.get_distance(origin, monster.get("hex_position", Vector2i.ZERO)) <= 12:
						candidates.append(monster)
				if candidates.is_empty():
					hud.add_log("No foes are within 60 feet for Abjure Foes.")
					return
				var max_targets := maxi(1, active_character.ability_scores.get_ability_modifier("CHA"))
				var selected_ids := await hud.request_abjure_foes_targets(candidates, max_targets)
				if selected_ids.is_empty():
					return
				if not turn_budget.can_spend("magic_action") or not active_character.use_feature(str(feature.get("id", ""))):
					hud.add_log("No Channel Divinity use or Magic action remains.")
					return
				_spend_action_cost("magic_action")
				var selected_targets: Array[Dictionary] = []
				for monster in candidates:
					if str(monster.get("id", "")) in selected_ids:
						selected_targets.append(monster)
				for result in PaladinRules.resolve_abjure_foes(active_character, selected_targets, origin):
					hud.add_log(str(result.get("message", "Abjure Foes resolves.")))
				hud.update_hud(active_character, tracker)
				_update_grid_entities()
				_highlight_reachable()
				return
			var controlled_steed := _find_steed_entity(active_character)
			var steed_feature_usable: bool = bool(player_entities[current_player_idx].get("is_steed", false)) or PaladinRules.find_steed_is_mounted(active_character)
			if str(feature.get("id", "")).begins_with("otherworldly_steed_") and not controlled_steed.is_empty() and steed_feature_usable:
				pending_action_type = "steed_feature"
				pending_feature_data = feature
				hud.add_log("%s: select a valid target or destination." % feature.get("name", "Steed feature"))
				_highlight_steed_feature_targets(feature)
				return
			if str(feature.get("id", "")) == "familiar_help":
				pending_action_type = "familiar_help"
				hud.add_log("Help: select an enemy within 5 feet.")
				_highlight_familiar_help_targets()
				return
			if str(feature.get("id", "")) == "familiar_senses":
				var sense_entity := FamiliarSpellDelivery.creature(active_character, player_entities, false)
				if sense_entity.is_empty() or not turn_budget.can_spend("bonus_action"):
					hud.add_log("Sharing senses needs a conscious familiar within 100 feet and your Bonus Action.")
					return
				active_character.familiar_senses = sense_entity["character"]
				active_character.familiar_senses_position = sense_entity["hex_position"]
				_spend_action_cost("bonus_action")
				hud.add_log("You perceive through your familiar until the start of your next turn, including its special senses.")
				hud.update_hud(active_character, tracker)
				return
			if str(feature.get("id", "")) in ["familiar_dismiss", "familiar_recall", "familiar_release"]:
				var familiar_record := FamiliarRules.state(active_character)
				if familiar_record.is_empty() or not turn_budget.can_spend("magic_action"):
					hud.add_log("No familiar or Magic action is available.")
					return
				var familiar_command := str(feature["id"])
				if familiar_command == "familiar_recall":
					if not bool(familiar_record.get("pocket", false)): return
					var destination := _familiar_spawn_position(player_entities[current_player_idx], 6, false)
					if destination == FamiliarRules.ABSENT:
						hud.add_log("No unoccupied space is available; no action was spent.")
						return
					FamiliarRules.set_pocket(active_character, false)
					_add_wild_companion_entity(player_entities[current_player_idx], true, destination)
					hud.add_log("Your familiar returns with its retained Hit Points.")
				elif familiar_command == "familiar_dismiss":
					if bool(familiar_record.get("pocket", false)): return
					_cleanup_dead_familiars()
					FamiliarRules.set_pocket(active_character, true)
					hud.add_log("Your familiar waits in its pocket dimension.")
				else:
					FamiliarRules.forget(active_character)
					hud.add_log("Your familiar is released; another summon requires a new resource.")
				_spend_action_cost("magic_action")
				_update_grid_entities()
				hud.update_hud(active_character, tracker)
				_highlight_reachable()
				return
			if str(feature.get("id", "")) == "druid_wild_companion":
				if not turn_budget.can_spend("magic_action"):
					hud.add_log("No Magic action remains for Wild Companion.")
					return
				var familiar_destination := _familiar_spawn_position(player_entities[current_player_idx], 2, false)
				if familiar_destination == FamiliarRules.ABSENT:
					hud.add_log("No unoccupied space is available for the familiar; no resource was spent.")
					return
				var companion_choice: Dictionary = extra_data.get("wild_companion_choice", {})
				var companion_result := DruidRules.summon_wild_companion(active_character, str(companion_choice.get("form_id", "")), str(companion_choice.get("cost", "")))
				if not companion_result.get("success", false):
					hud.add_log(str(companion_result.get("message", "Wild Companion failed.")))
					return
				_add_wild_companion_entity(player_entities[current_player_idx], true, familiar_destination)
				_spend_action_cost("magic_action")
				hud.add_log(str(companion_result.get("message", "Wild Companion summoned.")))
				hud.update_hud(active_character, tracker)
				_highlight_reachable()
				return
			if str(feature.get("id", "")) == "druid_nature_magician":
				var uses_to_convert := int(extra_data.get("wild_shape_uses", 0))
				var nature_result := DruidRules.use_nature_magician(active_character, uses_to_convert)
				hud.add_log(str(nature_result.get("message", "Nature Magician is unavailable.")))
				hud.update_hud(active_character, tracker)
				_highlight_reachable()
				return
			if str(feature.get("resolver", "")) == "druid_rules" and str(feature.get("id", "")) == "druid_wild_resurgence":
				var resurgence_state := DruidRules.wild_resurgence_state(active_character)
				var slot_level := 0
				if str(resurgence_state.get("mode", "")) == "slot_to_wild_shape":
					slot_level = await hud.request_spell_slot(active_character)
					if slot_level <= 0:
						return
				var resurgence_result := DruidRules.use_wild_resurgence(active_character, slot_level)
				if resurgence_result.get("success", false):
					hud.add_log(str(resurgence_result.get("message", "Wild Resurgence restores a resource.")))
				else:
					hud.add_log(str(resurgence_result.get("message", "Wild Resurgence is unavailable.")))
				hud.update_hud(active_character, tracker)
				_highlight_reachable()
				return
			if str(feature.get("resolver", "")) == "druid_rules" and str(feature.get("id", "")) == "druid_wild_shape":
				var form_id := await hud.request_wild_shape_form(active_character)
				if form_id.is_empty():
					return
				if form_id == "__revert":
					if DruidRules.revert(active_character):
						_spend_action_cost("bonus_action")
						hud.add_log("%s returns to normal form." % active_character.character_name)
				else:
					var shape_result := DruidRules.transform(active_character, form_id)
					if not shape_result.get("success", false):
						hud.add_log(str(shape_result.get("message", "Wild Shape failed.")))
						return
					_spend_action_cost("bonus_action")
					hud.add_log("%s becomes a %s and gains %d Temporary Hit Points." % [active_character.character_name, str(shape_result["form"].get("name", "Beast")), active_character.level])
				hud.update_hud(active_character, tracker)
				_highlight_reachable()
				return
			if str(feature.get("resolver", "")) == "cleric_rules" and str(feature.get("id", "")) == "cleric_divine_intervention":
				resolving_player_action = true
				var intervention_spell := await hud.request_divine_intervention_spell(active_character)
				if intervention_spell.is_empty():
					resolving_player_action = false
					hud.add_log("Divine Intervention spell selection was cancelled or no eligible spell is available.")
					return
				var casts_wish := str(intervention_spell.get("id", "")) == "wish"
				if casts_wish:
					intervention_spell = await hud.request_wish_duplication_spell()
					if intervention_spell.is_empty():
						resolving_player_action = false
						hud.add_log("Wish duplication was cancelled; Divine Intervention remains available.")
						return
				pending_action_type = "spell"
				resolving_player_action = false
				pending_divine_intervention = true
				pending_divine_intervention_wish = casts_wish
				pending_spell_data = intervention_spell.duplicate(true)
				pending_spell_data["casting_time"] = "action"
				pending_spell_data["_wish_duplicate"] = casts_wish
				pending_spell_data["_ignore_material_components"] = true
				if str(pending_spell_data.get("id", "")) == "produce_flame":
					pending_spell_data["_produce_flame_create"] = true
				hud.add_log("Divine Intervention casts %s without a spell slot. Select its target." % intervention_spell.get("name", "the spell"))
				_highlight_spell_targets()
				return
			if str(feature.get("resolver", "")) == "cleric_rules":
				var channel_error := ClericRules.channel_divinity_error(active_character)
				if not channel_error.is_empty():
					hud.add_log(channel_error)
					return
				if str(feature.get("id", "")) == "cleric_divine_spark":
					pending_action_type = "cleric_divine_spark"
					pending_feature_data = feature
					hud.add_log("Divine Spark: select another creature within 30 feet.")
					_highlight_divine_spark_targets()
					return
				if str(feature.get("id", "")) == "cleric_turn_undead":
					await _execute_cleric_turn_undead(feature)
					return
			var slot_recovery_effect: Dictionary = {}
			var ward_recharge_effect: Dictionary = {}
			for effect in feature.get("effects", []):
				if effect.get("type", "") == "resource_from_spell_slot":
					slot_recovery_effect = effect
				elif effect.get("type", "") == "damage_ward_pool" and bool(effect.get("bonus_action_slot_recharge", false)):
					ward_recharge_effect = effect
			if not slot_recovery_effect.is_empty():
				var slot_level := int(feature.get("selected_spell_slot_level", 0))
				var recovery := ClassProgression.restore_resource_from_spell_slot(active_character, str(slot_recovery_effect.get("resource_id", "")), slot_level, int(slot_recovery_effect.get("amount", 1)))
				if recovery.get("success", false):
					hud.add_log("Font of Inspiration restores %d Bardic Inspiration use by spending a level %d spell slot." % [int(recovery.get("restored", 0)), int(recovery.get("slot_level", 0))])
				else:
					hud.add_log(recovery.get("message", "Unable to recover that resource."))
				hud.update_hud(active_character, tracker)
				_highlight_reachable()
				return
			if not ward_recharge_effect.is_empty():
				if not turn_budget.can_spend("bonus_action"):
					hud.add_log("No Bonus Action remains to recharge %s." % str(feature.get("name", "the ward")))
					return
				var ward_slot_level := int(feature.get("selected_spell_slot_level", 0))
				var recharge := WardRules.spend_slot_for_ward_recharge(active_character, str(feature.get("id", "")), ward_slot_level)
				if recharge.get("success", false):
					_spend_action_cost("bonus_action")
					hud.add_log("[color=cyan]%s[/color]" % str(recharge.get("message", "Ward recharged.")))
				else:
					hud.add_log("[color=orange]%s[/color]" % str(recharge.get("message", "Unable to recharge ward.")))
				hud.update_hud(active_character, tracker)
				_highlight_reachable()
				return
			if feature.get("id", "") == "bard_bardic_inspiration":
				pending_action_type = "bardic_inspiration"
				pending_feature_data = feature
				hud.add_log("Bardic Inspiration: select another ally within range.")
				_highlight_bardic_inspiration_targets()
				return
			if feature.get("id", "") == "paladin_lay_on_hands":
				pending_action_type = "lay_on_hands"
				pending_feature_data = feature
				hud.add_log("Lay on Hands: select an ally within touch range.")
				_highlight_lay_on_hands_targets()
				return
			if feature.get("id", "") in ["monk_bonus_unarmed_strike", "monk_flurry_of_blows"]:
				if feature.get("id", "") == "monk_bonus_unarmed_strike" and not active_character.can_use_martial_arts():
					hud.add_log("Martial Arts requires no armor or shield and only Monk weapons.")
					return
				if remaining_flurry_swings <= 0 and active_character.get_focus_points() < int(feature.get("focus_cost", 0)):
					hud.add_log("Not enough Focus.")
					return
				pending_action_type = "unarmed_attack"
				pending_feature_data = feature
				var unarmed_label := "Flurry of Blows" if feature.get("id", "") == "monk_flurry_of_blows" else "Bonus Unarmed Strike"
				hud.add_log("%s: select an adjacent enemy." % unarmed_label)
				_highlight_unarmed_targets()
				return
			_execute_class_feature(feature)
		"use_item":
			var item: Dictionary = extra_data.get("item", {})
			_execute_item(item, attack_substitution_units if use_attack_substitution else 0)
		"eat_goodberry":
			_execute_goodberry()
		"dodge":
			pending_action_type = ""
			active_character.add_condition("dodging", 1)
			hud.add_log("%s is dodging (Attacks against them have disadvantage)." % active_character.character_name)
			_spend_action_cost("action")
			_highlight_reachable()
		"end_turn":
			_end_active_turn()


## Cancel any in-progress targeting (attack/spell) and return to movement.
## Bound to the HUD Cancel button and the Esc key so the player is never
## trapped in targeting mode with no way back to movement.
func _cancel_pending_action() -> void:
	if not child_actions.frame.is_empty():
		pending_action_type = ""
		pending_spell_data = {}
		await child_actions.cancel(self)
		return
	if fighter_move_waiting:
		fighter_move_done = true
		return
	if pending_action_type.is_empty():
		return
	var old := pending_action_type
	pending_action_type = ""
	attack_unit_substitution = {}
	pending_spell_data = {}
	pending_divine_intervention = false
	pending_divine_intervention_wish = false
	pending_feature_data = {}
	pending_words_primary_selected = false
	pending_command_target_coords.clear()
	pending_command_target_ids.clear()
	if hex_grid != null:
		hex_grid.clear_highlights()
	_clear_path_preview()
	_highlight_reachable()
	if hud != null:
		hud.hide_dice()
		hud.add_log("[color=yellow]Cancelled %s targeting.[/color]" % old)


func _clear_path_preview() -> void:
	if hex_grid != null:
		for h in _path_preview_hexes:
			hex_grid.clear_highlight(h)
	_path_preview_hexes.clear()


func _highlight_attack_targets() -> void:
	_clear_path_preview()
	hex_grid.clear_highlights()
	
	var pos: Vector2i = player_entities[current_player_idx]["hex_position"]
	var weapon := DruidRules.current_attack_profile(active_character) if DruidRules.is_shaped(active_character) else DataLoader.get_item(active_character.inventory.get_weapon())
	var max_range := int(weapon.get("range", 1))

	var highlights := {}
	# Show the weapon's reach as a ring of highlighted hexes (P1 readability),
	# so the player can see engagement range at a glance.
	if max_range >= 1:
		var ring := HexUtils.get_hexes_in_range(pos, max_range)
		for h in ring:
			if h == pos: continue
			# Subtle fill for range; targets keep the brighter attack color below.
			highlights[h] = Color(0.35, 0.07, 0.07, 0.35)
	for m in monster_entities:
		if not m["is_alive"]: continue
		var m_pos: Vector2i = m["hex_position"]
		if Targeting.is_in_range(pos, m_pos, max_range) and Targeting.has_line_of_sight(pos, m_pos, hex_grid):
			highlights[m_pos] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.ATTACK]

	hex_grid.set_highlights(highlights)


func _highlight_familiar_help_targets() -> void:
	var origin: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
	var highlights := {}
	for monster in monster_entities:
		var target_hex: Vector2i = monster.get("hex_position", Vector2i.ZERO)
		if monster.get("is_alive", false) and Targeting.is_in_range(origin, target_hex, 1):
			highlights[target_hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.ATTACK]
	hex_grid.set_highlights(highlights)


func _highlight_steed_feature_targets(feature: Dictionary) -> void:
	hex_grid.clear_highlights()
	var origin: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
	var feature_id := str(feature.get("id", ""))
	var highlights := {}
	if feature_id == "otherworldly_steed_fey_step":
		for target_hex in HexUtils.get_hexes_in_range(origin, 12):
			if target_hex != origin and hex_grid.has_tile(target_hex) and hex_grid.is_hex_passable(target_hex) and not _is_occupied_hex(target_hex):
				highlights[target_hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]
	elif feature_id == "otherworldly_steed_healing_touch":
		for player in player_entities:
			var target: Character = player.get("character")
			var target_hex: Vector2i = player.get("hex_position", Vector2i.ZERO)
			if target != null and target.is_alive and target.current_hp < target.max_hp and Targeting.is_in_range(origin, target_hex, 1):
				highlights[target_hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]
	elif feature_id == "otherworldly_steed_fell_glare":
		for monster in monster_entities:
			var target_hex: Vector2i = monster.get("hex_position", Vector2i.ZERO)
			if monster.get("is_alive", false) and Targeting.is_in_range(origin, target_hex, 2):
				highlights[target_hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]
	else:
		for monster in monster_entities:
			var target_hex: Vector2i = monster.get("hex_position", Vector2i.ZERO)
			if monster.get("is_alive", false) and Targeting.is_in_range(origin, target_hex, 1):
				highlights[target_hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.ATTACK]
	hex_grid.set_highlights(highlights)


func _request_weapon_damage_rider_choices(character: Character) -> Dictionary:
	var choices: Dictionary = {}
	for effect in ClassProgression.selected_feature_effects_of_type(character, "weapon_damage_rider"):
		var id := str(effect.get("id", ""))
		var marker := "%s_%s_used_this_turn" % [id, character.class_id]
		if bool(effect.get("own_turn_only", false)) and CombatAction.active_turn_actor_id != character.get_instance_id():
			continue
		if effect.get("uses_per", "") == "turn" and int(character.feature_uses.get(marker, 0)) > 0:
			continue
		if bool(effect.get("optional", false)) and not await hud.request_reaction(_owner_label_for_character(character), id, "Add Divine Strike damage to this weapon hit?", "Use Divine Strike?", "Add damage", "Divine Strike"):
			continue
		var options: Array = effect.get("damage_type_options", [])
		if options.is_empty():
			continue
		var selected := await hud.request_damage_type_choice(options, id.replace("_", " ").capitalize())
		if not selected.is_empty():
			choices[id] = selected
	return choices


func _offer_potent_spellcasting_vitality(spell: Dictionary, damage_dealt: int) -> void:
	if damage_dealt <= 0 or int(spell.get("level", -1)) != 0 or not active_character.has_feature("cleric_improved_blessed_strikes") or str(spell.get("id", "")) not in DataLoader.get_character_class("cleric").get("spell_list_ids", []):
		return
	if not ClassProgression.selected_feature_effects_of_type(active_character, "spell_cast_temporary_hp").any(func(effect): return bool(effect.get("requires_damage", false))):
		return
	var origin: Vector2i = player_entities[current_player_idx]["hex_position"]
	var candidates: Array[Dictionary] = []
	for player in player_entities:
		var character: Character = player.get("character")
		if character != null and ClericRules.can_receive_spark(character) and Targeting.is_in_range(origin, player["hex_position"], 12):
			candidates.append({"id": character.character_id, "name": character.character_name, "target": character})
	for monster in monster_entities:
		if monster.get("is_alive", false) and Targeting.is_in_range(origin, monster["hex_position"], 12):
			candidates.append({"id": str(monster["id"]), "name": str(monster["name"]), "target": monster})
	var selected := await hud.request_cleric_vitality_target(candidates)
	for candidate in candidates:
		if str(candidate["id"]) == selected:
			for rider in CombatAction.resolve_spell_cast_riders(active_character, spell, "magic_action", damage_dealt, candidate["target"]):
				hud.add_log("Potent Spellcasting grants %s %d temporary Hit Points." % [candidate["name"], int(rider.get("granted", 0))])
			break

func _offer_weapon_damage_riders(actor: Character, target: Dictionary, weapon: Dictionary, result: Dictionary) -> void:
	if not result.get("hit", false) or str(weapon.get("type", "")) != "weapon":
		return
	var choices := await _request_weapon_damage_rider_choices(actor)
	for rider in CombatAction.resolve_weapon_damage_riders(actor, target, choices, weapon, bool(result.get("crit", false)), true, result):
		result["damage"] = int(result.get("damage", 0)) + int(rider.get("damage", 0))
		if not result.has("weapon_riders"): result["weapon_riders"] = []
		result["weapon_riders"].append(rider.duplicate(true))
		hud.add_log("%s deals %d extra %s damage." % [str(rider.get("feature_id", "Damage rider")), int(rider.get("damage", 0)), str(rider.get("damage_type", "radiant"))], false)


## Batch 077: keep a pick for the rest of this Attack action only when its rule
## declares choice_duration "attack_action"; a per-attack pick is never kept.
func _remember_attack_action_choice(weapon: Dictionary, chosen: String) -> void:
	var record := AttackProfileRules.carry_record(active_character, weapon, chosen)
	if not record.is_empty():
		attack_action_damage_choice = record


## Batch 077 (#39 follow-up): the activation-window answer for one Extra Attack
## swing. Returns {"damage_type": String} or {"held": true}. A carried
## "attack_action" pick is reused (and rechecked); a per-attack rule asks again
## through the same real menu. Dismissal or a stale answer holds the swing.
func _extra_swing_damage_choice(weapon: Dictionary, target: Dictionary, extra_index: int) -> Dictionary:
	var choice := AttackProfileRules.damage_type_choice(active_character, weapon)
	var carried := AttackProfileRules.carried_choice(active_character, weapon, attack_action_damage_choice)
	if not carried.is_empty():
		hud.add_log("%s: %s carries to this swing." % [str(choice.get("name", "Damage type")), carried.capitalize()], false)
		return {"damage_type": carried}
	if str(choice.get("window", "")) != "activation":
		return {"damage_type": ""}
	var picked := await hud.request_damage_type_choice(choice.options, "%s (Extra Attack %d)" % [str(choice.name), extra_index + 1])
	var stale := "" if picked.is_empty() else AttackProfileRules.activation_choice_error(active_character, weapon, choice, picked)
	if stale.is_empty() and not picked.is_empty() and (not bool(target.get("is_alive", false)) or target not in monster_entities):
		stale = "The target is no longer there."
	if picked.is_empty() or not stale.is_empty():
		var reason := "damage-type choice cancelled" if picked.is_empty() else stale.trim_suffix(" nothing was spent.").trim_suffix(";")
		hud.add_log("[color=yellow]%s: %s; this swing is held and not spent.[/color]" % [str(choice.get("name", "Damage type")), reason])
		return {"held": true}
	return {"damage_type": picked}


func _resolve_player_weapon_attack(attacker: Character, target, weapon: Dictionary, advantage: bool, disadvantage: bool, decisions: Dictionary, additional_damage: Dictionary) -> Dictionary:
	return await _settle_attack_profile_hit_choice(await _resolve_player_weapon_attack_roll(attacker, target, weapon, advantage, disadvantage, decisions, additional_damage))


## S-127: a captured hit asks its authored damage-type choice before damage.
## Dismissing the menu keeps the inherited type; the choice itself costs nothing.
func _settle_attack_profile_hit_choice(result: Dictionary) -> Dictionary:
	if not result.has("attack_profile_choice_request"):
		return result
	var request: Dictionary = result["attack_profile_choice_request"]
	var chosen := await hud.request_damage_type_choice(request.get("options", []), str(request.get("name", "Damage type")))
	var settled := AttackProfileRules.resume_hit_choice(result, chosen)
	if bool(settled.get("attack_profile_choice_stale", false)):
		hud.add_log("[color=yellow]%s is no longer an eligible damage type; the weapon's own type is used.[/color]" % chosen.capitalize())
	elif chosen.is_empty() and not bool(settled.get("refused", false)):
		# Batch 077: a dismissed hit-window choice is reported, never silent.
		hud.add_log("[color=yellow]%s: no damage type chosen; this hit deals the weapon's own damage type.[/color]" % str(request.get("name", "Damage type")))
	if result.get("weapon_attack_bonus_settled", false):
		settled["weapon_attack_bonus_settled"] = true
	return settled


func _resolve_player_weapon_attack_roll(attacker: Character, target, weapon: Dictionary, advantage: bool, disadvantage: bool, decisions: Dictionary, additional_damage: Dictionary) -> Dictionary:
	var attack_decisions := decisions.duplicate(true)
	attack_decisions["combat_history"] = action_history
	if child_actions.current("strike"):
		attack_decisions["parent_action"] = {"invocation_id":child_actions.frame.invocation, "action_id":child_actions.frame.feature.child_actions.classification, "source_id":child_actions.frame.feature.id}
	attack_decisions["allow_weapon_attack_bonus"] = true
	attack_decisions["players"] = player_entities
	attack_decisions["monsters"] = monster_entities
	var result := CombatAction.resolve_weapon_attack(attacker, target, weapon, advantage, disadvantage, attack_decisions, additional_damage)
	if not result.has("weapon_attack_bonus_request"):
		return result
	var record := SpellDamageRolls.weapon_attack_bonus_record(attacker, target, result)
	if record.is_empty():
		return SpellDamageRolls.settle_weapon_attack_bonus(attacker, target, result, "")
	if attacker.has_feature("rogue_stroke_of_luck") and int(attacker.feature_uses.get("rogue_stroke_of_luck", 0)) > 0:
		var stroke_accepted := await hud.request_reaction(_owner_label_for_character(attacker), "stroke_of_luck", "This attack failed (%d vs AC %d). Turn the captured d20 into a 20?" % [int(result.get("attack_roll", 0)), int(result.get("target_ac", 0))], "Use Stroke of Luck?", "Stroke of Luck", "Stroke of Luck — %s" % _owner_label_for_character(attacker))
		if stroke_accepted:
			var stroke_settlement := SpellDamageRolls.settle_weapon_attack_bonus_with_stroke(attacker, target, result, true)
			if not bool(stroke_settlement.get("refused", false)):
				return stroke_settlement
			hud.add_log("[color=yellow]%s[/color]" % str(stroke_settlement.get("message", "Stroke of Luck was no longer available.")))
	var source_id := await hud.request_weapon_attack_numeric_bonus(_owner_label_for_character(attacker), int(result.get("attack_roll", 0)), int(result.get("target_ac", 0)), record.get("options", []), "weapon attack", bool(record.get("context", {}).get("provisional_hit", false)))
	var settled := SpellDamageRolls.settle_weapon_attack_bonus(attacker, target, result, source_id)
	if settled.has("reroll_keep_request"):
		var keep_request: Dictionary = settled["reroll_keep_request"]
		var keep_choice := await hud.request_reroll_keep_choice(_owner_label_for_character(attacker), str(keep_request.get("domain", "weapon_attack")), int(keep_request.get("original_total", 0)), int(keep_request.get("new_total", 0)))
		settled = SpellDamageRolls.settle_weapon_attack_reroll_keep(settled, keep_choice)
	if bool(settled.get("refused", false)):
		hud.add_log("[color=yellow]%s The attack bonus was declined; the captured roll continues unchanged.[/color]" % str(settled.get("message", "The selected source is no longer valid.")))
		settled = SpellDamageRolls.settle_weapon_attack_bonus(attacker, target, result, "")
	if settled is Dictionary:
		settled["weapon_attack_bonus_settled"] = true
	return settled

func _pending_spell_origin() -> Vector2i:
	var origin: Vector2i = player_entities[current_player_idx]["hex_position"]
	return FamiliarSpellDelivery.origin(active_character, player_entities, pending_spell_data, origin)


func _highlight_spell_targets() -> void:
	if hex_grid == null:
		return
	hex_grid.clear_highlights()
	
	var pos := _pending_spell_origin()
	var max_range := _spell_target_range(pending_spell_data)

	var highlights := {}
	# Display standard spellcasting range circles
	var area_hexes := HexUtils.get_hexes_in_range(pos, max_range)
	for hex in area_hexes:
		if hex_grid.has_tile(hex):
			highlights[hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]

	hex_grid.set_highlights(highlights)


func _highlight_dancing_lights_movement() -> void:
	var owner_id := active_character.character_id if active_character != null else ""
	var light_set: Dictionary = dancing_light_sets.get(owner_id, {})
	var anchor_value: Array = light_set.get("anchor", [])
	if anchor_value.size() != 2:
		return
	var anchor := Vector2i(int(anchor_value[0]), int(anchor_value[1]))
	var origin: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
	var highlights: Dictionary = {}
	for candidate in hex_grid.tiles.keys():
		var moved := DancingLightsRules.move_light_set(light_set, origin, candidate)
		if not moved.get("success", false):
			continue
		var all_positions_on_map := true
		for position in moved.get("light_set", {}).get("positions", []):
			if not hex_grid.has_tile(Vector2i(int(position[0]), int(position[1]))):
				all_positions_on_map = false
				break
		if all_positions_on_map:
			highlights[candidate] = Color(0.45, 0.8, 1.0, 0.72)
	hex_grid.set_highlights(highlights)


func _highlight_mage_hand_movement() -> void:
	if current_player_idx < 0:
		return
	var player_pos: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
	var mage_hand_marker: Dictionary = mage_hand_markers.get(active_character.character_id, {})
	var current_pos_array: Array = mage_hand_marker.get("position", [0, 0])
	if current_pos_array.size() != 2:
		return
	var hand_pos := Vector2i(int(current_pos_array[0]), int(current_pos_array[1]))
	var highlights: Dictionary = {}
	for candidate in hex_grid.tiles.keys():
		if MageHandRules.can_move(mage_hand_marker, player_pos, candidate):
			highlights[candidate] = Color(0.74, 0.58, 1.0, 0.72)
	hex_grid.set_highlights(highlights)


func _spell_target_range(spell_data: Dictionary) -> int:
	return SpellCastTargeting._spell_target_range(_spell_cast_context(), spell_data)


func _spell_grants_additional_target(character: Character, spell_data: Dictionary) -> bool:
	return SpellCastTargeting._spell_grants_additional_target(_spell_cast_context(), character, spell_data)


func _spell_upcast_maximum_targets(spell_data: Dictionary) -> int:
	return SpellCastTargeting._spell_upcast_maximum_targets(_spell_cast_context(), spell_data)


func _magic_missile_dart_total(spell_data: Dictionary) -> int:
	return SpellCastTargeting._magic_missile_dart_total(_spell_cast_context(), spell_data)


func _spell_projectile_total(spell_data: Dictionary) -> int:
	return SpellCastTargeting._spell_projectile_total(_spell_cast_context(), spell_data)


func _valid_additional_spell_target(first_target: Vector2i, candidate: Vector2i, spell_data: Dictionary, prior_targets: Array[Vector2i] = []) -> bool:
	return SpellCastTargeting._valid_additional_spell_target(_spell_cast_context(), first_target, candidate, spell_data, prior_targets)


func _creature_at_coord_matches_types(coord: Vector2i, required_types: Array) -> bool:
	return SpellCastTargeting._creature_at_coord_matches_types(_spell_cast_context(), coord, required_types)


func _spell_target_visible_to_active_character(coord: Vector2i, spell_data: Dictionary) -> bool:
	return SpellCastTargeting._spell_target_visible_to_active_character(_spell_cast_context(), coord, spell_data)


func _has_spell_creature_at(coord: Vector2i, spell: Dictionary) -> bool:
	return SpellCastTargeting._has_spell_creature_at(_spell_cast_context(), coord, spell)


func _has_spell_target_at(coord: Vector2i, spell: Dictionary) -> bool:
	return SpellCastTargeting._has_spell_target_at(_spell_cast_context(), coord, spell)


func _has_creature_at(coord: Vector2i) -> bool:
	return _spell_zones()._has_creature_at(coord)


func _identify_creature_id_at(coord: Vector2i) -> String:
	return SpellCastTargeting._identify_creature_id_at(_spell_cast_context(), coord)


func _is_occupied_hex(coord: Vector2i) -> bool:
	return _spell_zones()._is_occupied_hex(active_character, coord)


func _is_unoccupied_conjure_elemental_space(center: Vector2i) -> bool:
	return _spell_zones()._is_unoccupied_conjure_elemental_space(center)


func _highlight_divine_spark_targets() -> void:
	hex_grid.clear_highlights()
	var origin: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
	var highlights := {}
	for player in player_entities:
		var target: Character = player.get("character")
		if target == null or target == active_character or not ClericRules.can_receive_spark(target):
			continue
		var target_hex: Vector2i = player.get("hex_position", Vector2i.ZERO)
		if Targeting.is_in_range(origin, target_hex, 6):
			highlights[target_hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]
	for monster in monster_entities:
		if monster.get("is_alive", false) and Targeting.is_in_range(origin, monster.get("hex_position", Vector2i.ZERO), 6):
			highlights[monster["hex_position"]] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]
	hex_grid.set_highlights(highlights)


func _highlight_lay_on_hands_targets() -> void:
	hex_grid.clear_highlights()
	var origin: Vector2i = player_entities[current_player_idx]["hex_position"]
	var highlights := {}
	for player in player_entities:
		var target: Character = player.get("character")
		if target == null:
			continue
		var can_heal := target.current_hp < target.max_hp
		var can_cleanse := int(active_character.feature_uses.get("paladin_lay_on_hands", 0)) >= 5 and not PaladinRules.lay_on_hands_conditions(active_character, target).is_empty()
		if not can_heal and not can_cleanse:
			continue
		var target_hex: Vector2i = player.get("hex_position", Vector2i.ZERO)
		if Targeting.is_in_range(origin, target_hex, 1):
			highlights[target_hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]
	hex_grid.set_highlights(highlights)


func _highlight_bardic_inspiration_targets() -> void:
	hex_grid.clear_highlights()
	var origin: Vector2i = player_entities[current_player_idx]["hex_position"]
	var highlights := {}
	for player in player_entities:
		var target: Character = player.get("character")
		if target == null:
			continue
		var target_hex: Vector2i = player.get("hex_position", Vector2i.ZERO)
		if BardicInspirationRules.can_receive(active_character, target, HexUtils.get_distance(origin, target_hex) * 5) and not BardicInspirationRules.has_die(target):
			highlights[target_hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL]
	hex_grid.set_highlights(highlights)


func _highlight_unarmed_targets() -> void:
	hex_grid.clear_highlights()
	var origin: Vector2i = player_entities[current_player_idx]["hex_position"]
	var highlights := {}
	for monster in monster_entities:
		if not monster.get("is_alive", false):
			continue
		var target_hex: Vector2i = monster.get("hex_position", Vector2i.ZERO)
		if Targeting.is_in_range(origin, target_hex, 1):
			highlights[target_hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.ATTACK]
	hex_grid.set_highlights(highlights)


func _on_hex_clicked(coord: Vector2i) -> void:
	if _pool_recovery_pending or _cast_in_progress: return
	if not child_actions.frame.is_empty() and not child_actions.valid(self):
		child_actions.clear()
		_cancel_pending_action()
		return
	var child_move := child_actions.current("move")
	var move_origin: Vector2i = player_entities[current_player_idx].hex_position if current_player_idx >= 0 else Vector2i.ZERO
	if child_move:
		if resolving_player_action or HexUtils.get_distance(move_origin, coord) > int(child_actions.frame.current.distance): return
		var reachable := _player_reachable(move_origin, remaining_speed, active_character)
		if not reachable.has(coord) or float(reachable[coord]) > float(child_actions.frame.current.distance) or coord == move_origin: return
		pending_action_type = ""
	_sync_changed_movement_speed()
	if fighter_move_waiting:
		if coord in fighter_move_choices:
			var entity: Dictionary = fighter_move_entity
			var movement_result := CombatAction.resolve_movement_step(entity, entity["hex_position"], coord)
			if movement_result.get("success", false): _publish_source_range_events()
			fighter_move_done = true
		return
	if current_player_idx == -1 or resolving_player_action: return # Not player turn

	var player_pos: Vector2i = player_entities[current_player_idx]["hex_position"]
	if pending_action_type == "created_creature_order":
		var target_id := ""
		for target in monster_entities:
			if target.get("is_alive", false) and target["hex_position"] == coord: target_id = str(target["id"]); break
		var order_result := CreatedCreatureCombat.issue(self, "attack", target_id)
		hud.add_log(str(order_result["message"]))
		if order_result.get("success", false): pending_action_type = ""
		hud.update_hud(active_character, tracker)
		return
	if pending_action_type.is_empty() and coord == player_pos and _try_freedom_of_movement_escape(active_character):
		return
	if pending_action_type.is_empty() and coord == player_pos and (await _try_escape_tether(active_character) or _try_escape_restrained_zone(active_character)):
		return
	if pending_action_type.is_empty() and await _try_rescue_tether(active_character, coord, player_pos):
		return
	if pending_action_type.is_empty() and _try_shake_sleeping_creature(coord, player_pos):
		return
	if pending_action_type == "dancing_lights_move":
		var owner_id := active_character.character_id
		var light_set: Dictionary = dancing_light_sets.get(owner_id, {})
		if light_set.is_empty():
			pending_action_type = ""
			return
		var movement := DancingLightsRules.move_light_set(light_set, player_pos, coord)
		if not movement.get("success", false):
			hud.add_log("[color=orange]%s[/color]" % movement.get("message", "Those lights cannot move there."))
			return
		for position in movement.get("light_set", {}).get("positions", []):
			if not hex_grid.has_tile(Vector2i(int(position[0]), int(position[1]))):
				hud.add_log("[color=orange]Choose a destination on the visible battlefield.[/color]")
				return
		dancing_light_sets[owner_id] = movement["light_set"]
		_spend_action_cost("bonus_action")
		pending_action_type = ""
		hud.add_log("[color=cyan]The Dancing Lights drift to their new position.[/color]")
		hud.update_hud(active_character, tracker)
		_update_grid_entities()
		_highlight_reachable()
		return
	if pending_action_type == "moonbeam_move":
		var source_id := _moonbeam_zone_source_for_caster(active_character)
		var zone: Dictionary = active_spell_zones.get(source_id, {})
		var old_center: Vector2i = zone.get("center", Vector2i.ZERO)
		if zone.is_empty() or not _moonbeam_can_move(zone) or not Targeting.is_in_range(old_center, coord, 12) or not hex_grid.has_tile(coord):
			hud.add_log("[color=orange]Choose a Moonbeam center up to 60 feet away, on a later turn.[/color]")
			return
		var old_coords: Array = zone.get("coords", []).duplicate()
		var new_coords := Targeting.get_sphere_targets(coord, 1, hex_grid)
		zone["center"] = coord
		zone["coords"] = new_coords
		zone["last_trigger_turn_by_target"] = zone.get("last_trigger_turn_by_target", {})
		zone["shape_locked_targets"] = zone.get("shape_locked_targets", [])
		_spend_action_cost("magic_action")
		pending_action_type = ""
		hud.add_log("[color=cyan]You move the Moonbeam Cylinder to its new center.[/color]")
		await _resolve_moonbeam_area_movement(zone, old_coords, new_coords)
		hud.update_hud(active_character, tracker)
		_update_grid_entities()
		_highlight_reachable()
		return
	if pending_action_type == "cloud_of_daggers_move":
		var source_id := _cloud_of_daggers_zone_source_for_caster(active_character)
		var zone: Dictionary = active_spell_zones.get(source_id, {})
		var old_center: Vector2i = zone.get("center", Vector2i.ZERO)
		if zone.is_empty() or not _cloud_of_daggers_can_move(zone) or not Targeting.is_in_range(old_center, coord, 6) or not hex_grid.has_tile(coord):
			hud.add_log("[color=orange]Choose a Cloud of Daggers space up to 30 feet away on a later turn.[/color]")
			return
		var old_coords: Array = zone.get("coords", []).duplicate()
		var new_coords: Array[Vector2i] = [coord]
		zone["center"] = coord
		zone["coords"] = new_coords
		_spend_action_cost("magic_action")
		pending_action_type = ""
		hud.add_log("[color=cyan]You teleport the Cloud of Daggers Cube to its new space.[/color]")
		await _resolve_cloud_of_daggers_area_movement(zone, old_coords, new_coords)
		hud.update_hud(active_character, tracker)
		_update_grid_entities()
		_highlight_reachable()
		return
	if pending_action_type == "conjure_animals_move":
		var source_id := _conjure_animals_zone_source_for_caster(active_character)
		var zone: Dictionary = active_spell_zones.get(source_id, {})
		var old_center: Vector2i = zone.get("center", Vector2i.ZERO)
		if zone.is_empty() or not player_moved_this_turn or bool(active_character.feature_uses.get("conjure_animals_pack_moved_this_turn", false)) or not Targeting.is_in_range(old_center, coord, 6) or not hex_grid.has_tile(coord) or _is_occupied_hex(coord):
			hud.add_log("[color=orange]Choose an unoccupied Conjure Animals pack space up to 30 feet away, after you move.[/color]")
			return
		var path: Array[Vector2i] = HexUtils.hex_line(old_center, coord)
		var path_is_on_map := true
		for path_hex in path:
			if not hex_grid.has_tile(path_hex):
				path_is_on_map = false
				break
		if not path_is_on_map:
			hud.add_log("[color=orange]The pack must move through mapped spaces.[/color]")
			return
		pending_action_type = ""
		active_character.feature_uses["conjure_animals_pack_moved_this_turn"] = true
		var previous_coords: Array = zone.get("coords", []).duplicate()
		for path_index in range(1, path.size()):
			var next_center: Vector2i = path[path_index]
			var next_coords: Array[Vector2i] = Targeting.get_sphere_targets(next_center, int(zone.get("radius_hexes", 2)), hex_grid)
			zone["center"] = next_center
			zone["coords"] = next_coords
			await _resolve_conjure_animals_area_movement(zone, previous_coords, next_coords)
			previous_coords = next_coords
		_refresh_conjure_animals_strength_advantage(active_character)
		hud.add_log("[color=cyan]You move the spectral animal pack up to 30 feet.[/color]")
		hud.update_hud(active_character, tracker)
		_update_grid_entities()
		_highlight_reachable()
		return
	if pending_action_type == "conjure_celestial_move":
		var source_id := _conjure_celestial_zone_source_for_caster(active_character)
		var zone: Dictionary = active_spell_zones.get(source_id, {})
		var old_center: Vector2i = zone.get("center", Vector2i.ZERO)
		if zone.is_empty() or not player_moved_this_turn or bool(active_character.feature_uses.get("conjure_celestial_pillar_moved_this_turn", false)) or not Targeting.is_in_range(old_center, coord, 6) or not hex_grid.has_tile(coord):
			hud.add_log("[color=orange]Choose a Conjure Celestial Cylinder center up to 30 feet away, after you move.[/color]")
			return
		var path: Array[Vector2i] = HexUtils.hex_line(old_center, coord)
		var path_is_on_map := true
		for path_hex in path:
			if not hex_grid.has_tile(path_hex):
				path_is_on_map = false
				break
		if not path_is_on_map:
			hud.add_log("[color=orange]The Cylinder must move through mapped spaces.[/color]")
			return
		pending_action_type = ""
		active_character.feature_uses["conjure_celestial_pillar_moved_this_turn"] = true
		var previous_coords: Array = zone.get("coords", []).duplicate()
		for path_index in range(1, path.size()):
			var next_center: Vector2i = path[path_index]
			var next_coords: Array[Vector2i] = Targeting.get_sphere_targets(next_center, int(zone.get("radius_hexes", 2)), hex_grid)
			zone["center"] = next_center
			zone["coords"] = next_coords
			await _resolve_conjure_celestial_area_movement(zone, previous_coords, next_coords)
			previous_coords = next_coords
		hud.add_log("[color=cyan]You move the Conjure Celestial Cylinder up to 30 feet.[/color]")
		hud.update_hud(active_character, tracker)
		_update_grid_entities()
		_highlight_reachable()
		return
	if pending_action_type == "conjure_fey_move":
		var source_id := _conjure_fey_zone_source_for_caster(active_character)
		var zone: Dictionary = active_spell_zones.get(source_id, {})
		var old_center: Vector2i = zone.get("center", Vector2i.ZERO)
		if zone.is_empty() or str(zone.get("cast_turn", "")) == _current_spell_trigger_turn() or not turn_budget.can_spend("bonus_action") or not Targeting.is_in_range(old_center, coord, 6) or not _is_unoccupied_conjure_fey_space(coord):
			hud.add_log("[color=orange]Choose an unoccupied Conjure Fey space up to 30 feet away on a later turn.[/color]")
			return
		var possible_targets := _conjure_fey_targets_within(coord)
		var target_id := str(zone.get("_test_target_id", ""))
		if not possible_targets.is_empty():
			if target_id.is_empty():
				target_id = await hud.request_conjure_fey_attack_target(possible_targets)
			if target_id.is_empty():
				return
			var target_is_available := false
			for possible_target in possible_targets:
				if str(possible_target.get("id", "")) == target_id:
					target_is_available = true
					break
			if not target_is_available:
				hud.add_log("[color=orange]Choose a creature within 5 feet of the spirit's new space.[/color]")
				return
		zone["center"] = coord
		zone["cast_turn"] = _current_spell_trigger_turn()
		_spend_action_cost("bonus_action")
		pending_action_type = ""
		hud.add_log("[color=cyan]You teleport the Conjure Fey spirit up to 30 feet.[/color]")
		if not target_id.is_empty():
			var fey_target = _conjure_fey_target_by_id(target_id)
			if fey_target != null:
				await _resolve_conjure_fey_attack(zone, fey_target)
		hud.update_hud(active_character, tracker)
		_update_grid_entities()
		_highlight_reachable()
		return
	if pending_action_type == "mage_hand_move":
		if not mage_hand_markers.has(active_character.character_id):
			pending_action_type = ""
			return
		var owned_mage_hand: Dictionary = mage_hand_markers[active_character.character_id]
		if not MageHandRules.can_move(owned_mage_hand, player_pos, coord) or not hex_grid.has_tile(coord):
			hud.add_log("[color=orange]That Mage Hand destination is too far away.[/color]")
			return
		owned_mage_hand["position"] = [coord.x, coord.y]
		_spend_action_cost("magic_action")
		pending_action_type = ""
		hud.add_log("[color=violet]You control the Mage Hand to its new space.[/color]")
		hud.update_hud(active_character, tracker)
		_update_grid_entities()
		_highlight_reachable()
		return
	if pending_action_type == "steed_feature":
		var steed_entity: Dictionary = player_entities[current_player_idx] if player_entities[current_player_idx].get("is_steed", false) else _find_steed_entity(active_character)
		if steed_entity.is_empty():
			pending_action_type = ""
			pending_feature_data = {}
			return
		var steed: Character = steed_entity.get("character")
		var owner: Character = steed_entity.get("steed_owner")
		var feature_id := str(pending_feature_data.get("id", ""))
		var owner_state := PaladinRules.find_steed_state(owner)
		var selected_monster: Dictionary = {}
		var selected_ally: Character = null
		for monster in monster_entities:
			if monster.get("is_alive", false) and monster.get("hex_position", Vector2i.ZERO) == coord:
				selected_monster = monster
				break
		for player in player_entities:
			var candidate: Character = player.get("character")
			if candidate != null and candidate.is_alive and candidate.current_hp < candidate.max_hp and player.get("hex_position", Vector2i.ZERO) == coord:
				selected_ally = candidate
				break
		if feature_id == "otherworldly_steed_slam":
			if selected_monster.is_empty() or not Targeting.is_in_range(player_pos, coord, 1):
				return
			var slam := PaladinRules.resolve_steed_slam(owner, steed, selected_monster, str(steed_entity.get("steed_creature_type", "celestial")), int(steed_entity.get("steed_spell_level", 2)))
			hud.add_log(str(slam.get("message", "Otherworldly Slam failed.")))
			if int(selected_monster.get("current_hp", 0)) <= 0:
				selected_monster["is_alive"] = false
				hud.add_log("[color=green]%s was defeated![/color]" % selected_monster.get("name", "Enemy"))
				tracker.remove_combatant(str(selected_monster.get("id", "")))
			_spend_action_cost("action")
		elif feature_id == "otherworldly_steed_healing_touch":
			if selected_ally == null or not Targeting.is_in_range(player_pos, coord, 1):
				return
			if not _can_spend_action_cost("bonus_action") or not steed.use_feature(feature_id) or not PaladinRules.mark_find_steed_ability_used(owner):
				hud.add_log("Healing Touch has already been used since the last Long Rest.")
				return
			var rolled_healing := Dice.parse_dice_string("2d8+%d" % int(owner_state.get("spell_level", 2)), {}, owner)
			var healing := selected_ally.heal(rolled_healing)
			hud.add_log("Healing Touch restores %d Hit Points to %s." % [healing, selected_ally.character_name])
			_spend_action_cost("bonus_action")
		elif feature_id == "otherworldly_steed_fell_glare":
			if selected_monster.is_empty() or not Targeting.is_in_range(player_pos, coord, 2):
				return
			if not _can_spend_action_cost("bonus_action") or not steed.use_feature(feature_id) or not PaladinRules.mark_find_steed_ability_used(owner):
				hud.add_log("Fell Glare has already been used since the last Long Rest.")
				return
			var immunities: Array = selected_monster.get("condition_immunities", [])
			if "frightened" in immunities:
				hud.add_log("%s is immune to Frightened." % selected_monster.get("name", "Target"))
			else:
				var save_total := BarbarianRules.roll_monster_save(selected_monster, "WIS")
				var save_dc := owner.get_spell_save_dc()
				if save_total < save_dc:
					CombatAction.apply_condition(selected_monster, "frightened", 1)
					hud.add_log("%s is Frightened by the steed until its next turn." % selected_monster.get("name", "Target"))
				else:
					hud.add_log("%s resists Fell Glare (WIS %d vs. DC %d)." % [selected_monster.get("name", "Target"), save_total, save_dc])
			_spend_action_cost("bonus_action")
		elif feature_id == "otherworldly_steed_fey_step":
			if coord == player_pos or not hex_grid.has_tile(coord) or not hex_grid.is_hex_passable(coord) or _is_occupied_hex(coord) or not Targeting.is_in_range(player_pos, coord, 12):
				return
			if not _can_spend_action_cost("bonus_action") or not steed.use_feature(feature_id) or not PaladinRules.mark_find_steed_ability_used(owner):
				hud.add_log("Fey Step has already been used since the last Long Rest.")
				return
			steed_entity["hex_position"] = coord
			if PaladinRules.find_steed_is_mounted(owner):
				for rider_entity in player_entities:
					if rider_entity.get("character") == owner:
						rider_entity["hex_position"] = coord
						break
			hud.add_log("The Fey steed teleports up to 60 feet.")
			_spend_action_cost("bonus_action")
		pending_action_type = ""
		pending_feature_data = {}
		hud.update_hud(active_character, tracker)
		_update_grid_entities()
		_check_battle_end_conditions()
		_highlight_reachable()
		return
	if pending_action_type == "familiar_help":
		var help_target: Dictionary = {}
		for monster in monster_entities:
			if monster.get("is_alive", false) and monster.get("hex_position", Vector2i.ZERO) == coord:
				help_target = monster
				break
		if help_target.is_empty() or not Targeting.is_in_range(player_pos, coord, 1):
			return
		var familiar_id := str(player_entities[current_player_idx].get("combat_id", ""))
		help_target["familiar_helped_by"] = familiar_id
		pending_action_type = ""
		_spend_action_cost("action")
		hud.add_log("%s helps against %s. The next ally attack against it has Advantage." % [active_character.character_name, str(help_target.get("name", "the target"))])
		hud.update_hud(active_character, tracker)
		_highlight_reachable()
		return

	if pending_action_type == "cleric_divine_spark":
		var target = null
		for player in player_entities:
			var candidate: Character = player.get("character")
			if candidate != null and candidate != active_character and ClericRules.can_receive_spark(candidate) and player.get("hex_position", Vector2i.ZERO) == coord:
				target = candidate
				break
		if target == null:
			for monster in monster_entities:
				if monster.get("is_alive", false) and monster.get("hex_position", Vector2i.ZERO) == coord:
					target = monster
					break
		if target == null or not Targeting.is_in_range(player_pos, coord, 6):
			return
		if active_character.has_condition("blinded") or not CombatAction.spell_target_is_visible_to(active_character, target, {"requires_target_sight": true}, HexUtils.get_distance(player_pos, coord) * 5):
			hud.add_log("Divine Spark needs a creature you can see.")
			return
		resolving_player_action = true
		var choice: Dictionary = await hud.request_divine_spark_choice()
		resolving_player_action = false
		if choice.is_empty():
			return
		var feature_id := str(pending_feature_data.get("id", ""))
		if not ClericRules.channel_divinity_error(active_character).is_empty() or not turn_budget.can_spend("magic_action") or not active_character.use_feature(feature_id):
			hud.add_log("No Channel Divinity use or Magic action remains.")
			_cancel_pending_action()
			return
		_spend_action_cost("magic_action")
		pending_action_type = ""
		var result := ClericRules.resolve_divine_spark(active_character, target, str(choice["mode"]), str(choice["damage_type"]))
		hud.add_log(result.get("message", "Divine Spark resolves."))
		if target is Dictionary and int(target.get("current_hp", 0)) <= 0:
			target["is_alive"] = false
			tracker.remove_combatant(str(target.get("id", "")))
		pending_feature_data = {}
		_update_grid_entities()
		hud.update_hud(active_character, tracker)
		_check_battle_end_conditions()
		_highlight_reachable()
		return

	if pending_action_type == "attack":
		# Attack enemy at hex
		var clicked_monster: Dictionary = {}
		for m in monster_entities:
			if m["hex_position"] == coord and m["is_alive"]:
				clicked_monster = m
				break

		if clicked_monster.is_empty():
			return # No valid monster selected
		var attacker_position: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
		if not Targeting.has_line_of_sight(attacker_position, coord, hex_grid):
			hud.add_log("A wall or closed door blocks the attacker's sight.")
			return

		# Enforce weapon range on execution (mirrors _highlight_attack_targets).
		var weapon := DruidRules.current_attack_profile(active_character) if DruidRules.is_shaped(active_character) else DataLoader.get_item(active_character.inventory.get_weapon())
		if weapon.is_empty():
			weapon = CombatAction.unarmed_attack_profile(active_character)
		var max_range := int(weapon.get("range", 1))
		var atk_dist := HexUtils.get_distance(player_pos, coord)
		if not Targeting.is_in_range(player_pos, coord, max_range):
			var w_name: String = str(weapon.get("name", weapon.get("id", "unarmed"))) if not weapon.is_empty() else "unarmed"
			hud.add_log("[color=red]%s is out of range of %s (distance %d, range %d).[/color]" % [clicked_monster["name"], w_name, atk_dist, max_range])
			return # out of range — do not resolve the attack
		if _spell_zones()._antilife_shell_blocks_melee(active_character, attacker_position, coord, weapon):
			hud.add_log("Antilife Shell prevents this melee attack from reaching through its barrier.")
			return

		# A valid target commits the Attack action before any optional prompts
		# yield. Clearing targeting here prevents a second click from starting a
		# concurrent attack while an optional feature decision is open.
		var parent_strike := child_actions.current("strike")
		if parent_strike and not child_actions.valid(self): return
		reclamp_attack_units()
		if not parent_strike and remaining_attack_swings <= 0 and not turn_budget.can_spend("action"):
			hud.add_log("No action remains for this attack.")
			return
		# S-127: an authored activation-window damage-type choice is asked before
		# anything is committed. Cancelling or a stale choice spends nothing.
		var profile_choice := AttackProfileRules.damage_type_choice(active_character, weapon)
		var activation_damage_type := ""
		# Batch 077: a later click inside the same Attack action reuses a pick
		# only when the rule declares choice_duration "attack_action".
		var carried_damage_type := AttackProfileRules.carried_choice(active_character, weapon, attack_action_damage_choice) if not parent_strike and remaining_attack_swings > 0 else ""
		if not carried_damage_type.is_empty():
			hud.add_log("%s: %s carries for the rest of this Attack action." % [str(profile_choice.get("name", "Damage type")), carried_damage_type.capitalize()], false)
		if str(profile_choice.get("window", "")) == "activation" and not carried_damage_type.is_empty():
			activation_damage_type = carried_damage_type
		elif str(profile_choice.get("window", "")) == "activation":
			pending_action_type = ""
			resolving_player_action = true
			activation_damage_type = await hud.request_damage_type_choice(profile_choice.options, str(profile_choice.name))
			resolving_player_action = false
			pending_action_type = "attack"
			if activation_damage_type.is_empty():
				hud.add_log("%s: damage-type choice cancelled; nothing was spent." % str(profile_choice.name))
				return
			var stale_choice := AttackProfileRules.activation_choice_error(active_character, weapon, profile_choice, activation_damage_type)
			if stale_choice.is_empty() and (not bool(clicked_monster.get("is_alive", false)) or clicked_monster.get("hex_position", Vector2i.ZERO) != coord or clicked_monster not in monster_entities):
				stale_choice = "The target is no longer there; nothing was spent."
			if stale_choice.is_empty() and ((parent_strike and not child_actions.valid(self)) or (not parent_strike and remaining_attack_swings <= 0 and not turn_budget.can_spend("action"))):
				stale_choice = "No action remains for this attack; nothing was spent."
			if not stale_choice.is_empty():
				hud.add_log("[color=yellow]%s[/color]" % stale_choice)
				return
		weapon["attack_distance"] = atk_dist
		pending_action_type = ""
		resolving_player_action = true
		if parent_strike:
			if not child_actions.settle(self):
				resolving_player_action = false
				return
		elif remaining_attack_swings <= 0:
			_spend_action_cost("action")
			remaining_attack_swings = 1 if "loading" in weapon.get("properties", []) else 1 + RuleUpgradeRules.extra_attacks(active_character)
			attack_action_total = remaining_attack_swings
			attack_action_damage_choice = {}
			carried_damage_type = ""
		if not parent_strike: remaining_attack_swings -= 1
		if "light" in weapon.get("properties", []):
			light_attack_weapon = weapon

		# (weapon / weapon_id already resolved above; reused for the attack roll)
		
		# Determine advantage/disadvantage based on conditions
		var has_advantage := false
		var has_disadvantage := false
		var attack_distance_feet := atk_dist * 5
		if not CombatPerception.can_see_target(active_character, clicked_monster, attacker_position, coord, hex_grid):
			has_disadvantage = true
		var target_perceives_invisible := CombatAction.can_perceive_invisible(clicked_monster, attack_distance_feet)
		if CombatAction.is_invisible(clicked_monster) and not CombatAction.can_perceive_invisible(active_character, attack_distance_feet):
			has_disadvantage = true
		if CombatAction.is_invisible(active_character) and not target_perceives_invisible:
			has_advantage = true
		var attack_reaction_decisions: Dictionary = {AttackProfileRules.ALLOW_KEY: true}
		if not activation_damage_type.is_empty():
			attack_reaction_decisions[AttackProfileRules.DECISION_KEY] = activation_damage_type
		elif not carried_damage_type.is_empty():
			attack_reaction_decisions[AttackProfileRules.DECISION_KEY] = carried_damage_type
		
		# Attacker conditions
		if active_character.has_condition("blinded") or active_character.has_condition("poisoned"):
			has_disadvantage = true
		if active_character.has_condition("hidden"):
			has_advantage = true
			active_character.remove_condition("hidden") # Reveal after attacking
			hud.add_log("[color=green]%s attacks with Advantage from hiding![/color]" % active_character.character_name)
		if DruidRules.pack_tactics_advantage(active_character, clicked_monster, player_entities):
			has_advantage = true
		if not str(clicked_monster.get("familiar_helped_by", "")).is_empty():
			has_advantage = true
			clicked_monster.erase("familiar_helped_by")

		# Target conditions (blinded or prone)
		var monster_conditions: Dictionary = clicked_monster.get("conditions", {})
		if monster_conditions.has("blinded"):
			has_advantage = true
		if monster_conditions.has("prone"):
			var dist := HexUtils.get_distance(player_pos, coord)
			if dist == 1:
				has_advantage = true
			else:
				has_disadvantage = true

		# Reckless Attack exposes the barbarian to advantage until their next
		# turn, while the activating attack itself gains advantage below.
		if active_character.has_feature("barbarian_reckless_attack") and int(active_character.feature_uses.get("barbarian_reckless_attack_used_this_turn", 0)) <= 0:
			var reckless_detail := "Gain Advantage on Strength attacks until your next turn; enemies gain Advantage against you for the same time."
			if await hud.request_reaction(_owner_label_for_character(active_character), "reckless_attack", reckless_detail, "Attack recklessly?", "Reckless Attack", "Reckless Attack — %s" % _owner_label_for_character(active_character)):
				var reckless_result := CombatAction.activate_reckless_attack(active_character)
				if reckless_result.get("success", false):
					has_advantage = str(weapon.get("ability", "STR")) == "STR" or has_advantage
			# The decision belongs to the first attack, including a declined offer.
			active_character.feature_uses["barbarian_reckless_attack_used_this_turn"] = 1
		if rogue_steady_aim_armed:
			has_advantage = true

		var brutal_effects := await _request_brutal_strike(active_character, weapon, has_disadvantage)
		if not brutal_effects.is_empty():
			attack_reaction_decisions["barbarian_brutal_strike_effects"] = brutal_effects

		# A held die is spent only if this D20 Test fails and the character chooses it.
		attack_reaction_decisions.merge(await _collect_attack_inspiration_decision(active_character), true)
		attack_reaction_decisions.merge(await _collect_roll_token_decision(active_character, "attack", "%s attack roll against %s" % [active_character.character_name, str(clicked_monster.get("name", "target"))], attack_reaction_decisions), true)

		# Shillelagh lets each attack choose Force or the weapon's normal damage type.
		if active_character.has_condition("shillelagh") and str(weapon.get("id", "")) == active_character.shillelagh_weapon_id:
			var shillelagh_damage_type := await hud.request_damage_type_choice(["force", str(weapon.get("damage_type", "bludgeoning"))], "Shillelagh")
			if not shillelagh_damage_type.is_empty():
				attack_reaction_decisions["shillelagh_damage_type"] = shillelagh_damage_type
		# Resolve weapon attack
		var conjure_minor_elementals_packet := await _conjure_minor_elementals_damage_choice(active_character, clicked_monster)
		var attack_additional_damage := {"packets": [conjure_minor_elementals_packet]} if not conjure_minor_elementals_packet.is_empty() else {}
		var result := await _resolve_player_weapon_attack(active_character, clicked_monster, weapon, has_advantage, has_disadvantage, attack_reaction_decisions, attack_additional_damage)
		rogue_steady_aim_armed = false
		if not bool(result.get("weapon_attack_bonus_settled", false)) and not result.get("hit", false) and active_character.has_feature("rogue_stroke_of_luck") and int(active_character.feature_uses.get("rogue_stroke_of_luck", 0)) > 0:
			var stroke_accepted := await hud.request_reaction(_owner_label_for_character(active_character), "stroke_of_luck", "This attack failed (%d vs AC %d). Turn the d20 into a 20?" % [int(result.get("attack_roll", 0)), int(result.get("target_ac", 0))], "Use Stroke of Luck?", "Stroke of Luck", "Stroke of Luck — %s" % _owner_label_for_character(active_character))
			if stroke_accepted:
				attack_reaction_decisions["stroke_of_luck"] = true
				result = await _settle_attack_profile_hit_choice(CombatAction.resolve_weapon_attack(active_character, clicked_monster, weapon, has_advantage, has_disadvantage, attack_reaction_decisions, attack_additional_damage))
		DruidRules.apply_attack_effects(active_character, clicked_monster, weapon, result)
		if not parent_strike:
			_remember_attack_action_choice(weapon, str(attack_reaction_decisions.get(AttackProfileRules.DECISION_KEY, result.get("attack_profile_damage_type", ""))))
		if result.get("hit", false):
			await _fire_reaction_trigger(active_character, "on_hit_with_attack", clicked_monster, player_entities[current_player_idx]["hex_position"], clicked_monster.get("hex_position", Vector2i.ZERO))

		var attack_results: Array[Dictionary] = [result]
		await _offer_divine_smite(clicked_monster, weapon, result)

		await _offer_sneak_attack(clicked_monster, weapon, result, active_character, has_advantage, has_disadvantage)
		await _finish_fighter_attack(clicked_monster, weapon, result)
		await _offer_stunning_strike(clicked_monster, weapon, result)

		hud.add_log(result.get("message", "Miss!"), false) # The settled attack card owns this outcome.

		# --- Feedback / juice ---
		var dmg_dealt: int = int(result.get("damage", 0))
		if result.get("hit", false) and dmg_dealt > 0:
			var crit: bool = result.get("crit", false)
			var dmg_color := Color.GOLD if crit else Color(1.0, 0.4, 0.3)
			var txt := ("CRIT %d!" % dmg_dealt) if crit else ("-%d" % dmg_dealt)
			_spawn_floating_text(coord, txt, dmg_color)
			_shake_camera(9.0 if crit else 5.0)
			_flash_hex(coord, Color(1.0, 0.3, 0.3, 0.6))
		else:
			_spawn_floating_text(coord, "Miss", Color(0.7, 0.7, 0.7, 0.9))
		# ---

		# Check if dead
		if int(clicked_monster.get("current_hp", 0)) <= 0:
			clicked_monster["is_alive"] = false
			hud.add_log("[color=green]%s was defeated![/color]" % clicked_monster["name"])
			tracker.remove_combatant(clicked_monster["id"])
			_trigger_enemy_defeat_features(clicked_monster, active_character)

		# Extra Attack is part of one Attack action, not a second action-cost.
		# Resolve the additional swings through the same CombatAction boundary.
		for extra_index in (0 if parent_strike or _has_attack_substitutions() else remaining_attack_swings):
			if not clicked_monster.get("is_alive", false):
				break
			var live_origin: Vector2i = player_entities[current_player_idx]["hex_position"]
			if not Targeting.is_in_range(live_origin, clicked_monster["hex_position"], max_range):
				break
			# Batch 077 (#39 follow-up): every swing asks its own per-attack
			# choice; only an "attack_action" rule carries the earlier pick. A
			# dismissed or stale answer holds this swing (nothing silently falls
			# back to the weapon's own type) and the swing stays available.
			var swing_choice := await _extra_swing_damage_choice(weapon, clicked_monster, extra_index)
			if bool(swing_choice.get("held", false)):
				break
			remaining_attack_swings -= 1
			weapon["attack_distance"] = HexUtils.get_distance(live_origin, clicked_monster["hex_position"])
			var extra_decisions := await _collect_attack_inspiration_decision(active_character)
			extra_decisions[AttackProfileRules.ALLOW_KEY] = true
			if not str(swing_choice.get("damage_type", "")).is_empty():
				extra_decisions[AttackProfileRules.DECISION_KEY] = str(swing_choice.damage_type)
			extra_decisions.merge(await _collect_roll_token_decision(active_character, "attack", "%s Extra Attack roll against %s" % [active_character.character_name, str(clicked_monster.get("name", "target"))], extra_decisions), true)
			var extra_brutal := await _request_brutal_strike(active_character, weapon, has_disadvantage)
			if not extra_brutal.is_empty():
				extra_decisions["barbarian_brutal_strike_effects"] = extra_brutal
			var extra_packet := await _conjure_minor_elementals_damage_choice(active_character, clicked_monster)
			var extra_additional_damage := {"packets": [extra_packet]} if not extra_packet.is_empty() else {}
			var extra_result := await _resolve_player_weapon_attack(active_character, clicked_monster, weapon, has_advantage, has_disadvantage, extra_decisions, extra_additional_damage)
			_remember_attack_action_choice(weapon, str(extra_decisions.get(AttackProfileRules.DECISION_KEY, extra_result.get("attack_profile_damage_type", ""))))
			await _offer_divine_smite(clicked_monster, weapon, extra_result)
			await _offer_sneak_attack(clicked_monster, weapon, extra_result, active_character, has_advantage, has_disadvantage)
			if int(extra_result.get("damage", 0)) > 0:
				ClericRules.clear_turning_after_damage(clicked_monster)
			attack_results.append(extra_result)
			await _finish_fighter_attack(clicked_monster, weapon, extra_result)
			await _offer_stunning_strike(clicked_monster, weapon, extra_result)
			hud.add_log("[color=cyan]Extra Attack %d: %s[/color]" % [extra_index + 1, extra_result.get("message", "Miss!")], false)
			if int(clicked_monster.get("current_hp", 0)) <= 0:
				clicked_monster["is_alive"] = false
				hud.add_log("[color=green]%s was defeated![/color]" % clicked_monster["name"])
				tracker.remove_combatant(clicked_monster["id"])
				_trigger_enemy_defeat_features(clicked_monster, active_character)

		# The Attack action is now fully settled. Publish once, grouping Extra
		# Attack swings and every applied damage rider under the same intent.
		var campaign_id := str(GameManager.active_campaign.get("id", ""))
		var activity_draft := CombatActivityRecordModel.attack_action(active_character, clicked_monster, weapon, attack_results, campaign_id, tracker.current_round)
		if not activity_draft.is_empty():
			ActivityHistory.publish(activity_draft)

		await _offer_light_attack(clicked_monster)
		resolving_player_action = false
		_check_battle_end_conditions()
		if parent_strike:
			await child_actions.complete(self)
		elif remaining_attack_swings > 0 and not _battle_ending:
			pending_action_type = "attack"
			hud.add_log("%d attacks remain. Choose a target, move, or end your turn." % remaining_attack_swings)
			_highlight_attack_targets()
		else:
			_highlight_reachable()

	elif pending_action_type == "lay_on_hands":
		var lay_target: Character = null
		for player in player_entities:
			var candidate: Character = player.get("character")
			var can_cleanse := candidate != null and int(active_character.feature_uses.get("paladin_lay_on_hands", 0)) >= 5 and not PaladinRules.lay_on_hands_conditions(active_character, candidate).is_empty()
			if candidate != null and player.get("hex_position", Vector2i.ZERO) == coord and (candidate.current_hp < candidate.max_hp or can_cleanse):
				lay_target = candidate
				break
		if lay_target == null:
			return
		if not Targeting.is_in_range(player_pos, coord, 1):
			hud.add_log("That ally is out of touch range.")
			return
		var pool := int(active_character.feature_uses.get("paladin_lay_on_hands", 0))
		var conditions_to_remove: Array[String] = []
		var eligible_conditions := PaladinRules.lay_on_hands_conditions(active_character, lay_target)
		if not eligible_conditions.is_empty() and pool >= 5:
			conditions_to_remove = await hud.request_lay_on_hands_conditions(eligible_conditions, mini(eligible_conditions.size(), floori(pool / 5)))
		var condition_cost := conditions_to_remove.size() * 5
		var requested := mini(pool - condition_cost, maxi(0, lay_target.max_hp - lay_target.current_hp))
		var result := CombatAction.resolve_lay_on_hands(active_character, lay_target, requested, conditions_to_remove)
		hud.add_log(result.get("message", "Lay on Hands failed."))
		if result.get("success", false):
			_spend_action_cost("bonus_action")
			pending_action_type = ""
			pending_feature_data = {}
			hud.update_hud(active_character, tracker)
			_check_battle_end_conditions()
			_highlight_reachable()
	elif pending_action_type == "bardic_inspiration":
		var inspiration_target: Character = null
		for player in player_entities:
			var candidate: Character = player.get("character")
			if candidate != null and candidate != active_character and player.get("hex_position", Vector2i.ZERO) == coord:
				inspiration_target = candidate
				break
		if inspiration_target == null or not inspiration_target.is_alive:
			return
		if not Targeting.is_in_range(player_pos, coord, 12):
			hud.add_log("That ally is out of Bardic Inspiration range.")
			return
		var inspiration_result := CombatAction.resolve_bardic_inspiration(active_character, inspiration_target, HexUtils.get_distance(player_pos, coord) * 5)
		hud.add_log(inspiration_result.get("message", "Bardic Inspiration failed."))
		if inspiration_result.get("success", false):
			_spend_action_cost("bonus_action")
			pending_action_type = ""
			pending_feature_data = {}
			hud.update_hud(active_character, tracker)
			_highlight_reachable()
	elif pending_action_type == "unarmed_attack":
		var unarmed_target: Dictionary = {}
		for monster in monster_entities:
			if monster.get("is_alive", false) and monster.get("hex_position", Vector2i.ZERO) == coord:
				unarmed_target = monster
				break
		if unarmed_target.is_empty() or not Targeting.is_in_range(player_pos, coord, 1):
			return
		var feature_id := str(pending_feature_data.get("id", ""))
		var focus_cost := int(pending_feature_data.get("focus_cost", 0))
		if remaining_flurry_swings <= 0:
			if not _can_spend_action_cost("bonus_action") or active_character.get_focus_points() < focus_cost: return
			if feature_id == "monk_bonus_unarmed_strike" and not active_character.can_use_martial_arts(): return
			if not active_character.use_feature(feature_id): return
			active_character.spend_focus_points(focus_cost)
			_spend_action_cost("bonus_action")
			if active_character.has_feature("monk_fleet_step"): _grant_extra_movement_speed()
			remaining_flurry_swings = 3 if feature_id == "monk_flurry_of_blows" and active_character.has_feature("monk_heightened_focus") else 2 if feature_id == "monk_flurry_of_blows" else 1
		strike_unit_parent = "flurry"
		pending_action_type = ""
		pending_feature_data = {}
		resolving_player_action = true
		var unarmed_results: Array[Dictionary] = []
		var strike_count := 1 if _has_attack_substitutions() else remaining_flurry_swings
		for strike in strike_count:
			if int(unarmed_target.get("current_hp", 0)) <= 0:
				break
			remaining_flurry_swings -= 1
			var result := CombatAction.resolve_unarmed_attack(active_character, unarmed_target)
			await _offer_divine_smite(unarmed_target, {"id": "unarmed_strike"}, result)
			unarmed_results.append(result)
			await _offer_stunning_strike(unarmed_target, {"id": "unarmed_strike"}, result)
		for strike_index in unarmed_results.size():
			hud.add_log("%s" % unarmed_results[strike_index].get("message", "Unarmed Strike missed."))
		if int(unarmed_target.get("current_hp", 0)) <= 0:
			unarmed_target["is_alive"] = false
			hud.add_log("[color=green]%s was defeated![/color]" % unarmed_target.get("name", "Enemy"))
			tracker.remove_combatant(unarmed_target.get("id", ""))
			_trigger_enemy_defeat_features(unarmed_target, active_character)
		pending_action_type = ""
		pending_feature_data = {}
		resolving_player_action = false
		hud.update_hud(active_character, tracker)
		_check_battle_end_conditions()
		_highlight_reachable()
	elif pending_action_type == "spell":
		# Cast spell at hex
		var spell_range := _spell_target_range(pending_spell_data)
		var is_chain_lightning := str(pending_spell_data.get("id", "")) == "chain_lightning"
		if not pending_words_primary_selected and (not is_chain_lightning or pending_command_target_coords.is_empty()) and not Targeting.is_in_range(_pending_spell_origin(), coord, spell_range):
			return # out of range
		var area_point_count := int(pending_spell_data.get("area_point_count", 1))
		if area_point_count > 1:
			if not hex_grid.has_tile(coord) or coord in pending_command_target_coords:
				return
			pending_command_target_coords.append(coord)
			if pending_command_target_coords.size() < area_point_count:
				hud.add_log("Choose another distinct area center for %s (%d of %d)." % [str(pending_spell_data.get("name", "this spell")), pending_command_target_coords.size(), area_point_count])
				return
			var area_centers := pending_command_target_coords.duplicate()
			pending_command_target_coords.clear()
			await _execute_player_spell(area_centers[0], Vector2i(9999, 9999), area_centers)
			return
		if str(pending_spell_data.get("id", "")) in ["magic_missile", "scorching_ray", "eldritch_blast"]:
			if not _has_spell_creature_at(coord, pending_spell_data):
				return
			pending_command_target_coords.append(coord)
			var projectile_total := _spell_projectile_total(pending_spell_data)
			if pending_command_target_coords.size() < projectile_total:
				var projectile_name := "dart" if str(pending_spell_data.get("id", "")) == "magic_missile" else "beam" if str(pending_spell_data.get("id", "")) == "eldritch_blast" else "ray"
				hud.add_log("Choose a creature for %s %s %d of %d. You may select the same creature again." % [str(pending_spell_data.get("name", "Spell")), projectile_name, pending_command_target_coords.size() + 1, projectile_total])
				hud.show_hint("%s: %d %s(s) remaining. Click a creature; you may choose the same creature again. Esc/Cancel to back out." % [pending_spell_data.get("name", "Spell"), projectile_total - pending_command_target_coords.size(), projectile_name])
				return
			var dart_targets := pending_command_target_coords.duplicate()
			pending_command_target_coords.clear()
			await _execute_player_spell(dart_targets[0], Vector2i(9999, 9999), dart_targets)
			return
		if _spell_grants_additional_target(active_character, pending_spell_data):
			if _spell_upcast_maximum_targets(pending_spell_data) > 2:
				var maximum_targets := _spell_upcast_maximum_targets(pending_spell_data)
				if pending_command_target_coords.is_empty():
					var exclusions: Array = pending_spell_data.get("target_creature_type_exclusions", [])
					var excluded := not exclusions.is_empty() and _creature_at_coord_matches_types(coord, exclusions)
					var valid_first_target := _has_spell_target_at(coord, pending_spell_data) if is_chain_lightning else _has_spell_creature_at(coord, pending_spell_data)
					if not valid_first_target or (excluded and not is_chain_lightning):
						return
					if is_chain_lightning:
						var first_options := SpellCastTargeting.chain_target_options(_spell_cast_context(), coord)
						var first_target_id := await hud.request_chain_lightning_target_choice(first_options, str(pending_spell_data.get("_test_chain_target_id", "")))
						if first_target_id.is_empty():
							return
						pending_command_target_ids.append(first_target_id)
					pending_command_target_coords.append(coord)
				else:
					if coord in pending_command_target_coords:
						if int(pending_spell_data.get("_metamagic_twinned_extra_targets", 0)) > 0:
							return
						var chosen := pending_command_target_coords.duplicate()
						var chosen_ids := pending_command_target_ids.duplicate()
						pending_command_target_coords.clear()
						pending_command_target_ids.clear()
						await _execute_player_spell(chosen[0], Vector2i(9999, 9999), chosen, chosen_ids)
						return
					var chain_anchor: Vector2i = pending_command_target_coords[0]
					if not _valid_additional_spell_target(chain_anchor, coord, pending_spell_data, pending_command_target_coords):
						return
					if is_chain_lightning:
						var next_options := SpellCastTargeting.chain_target_options(_spell_cast_context(), coord)
						var next_target_id := await hud.request_chain_lightning_target_choice(next_options, str(pending_spell_data.get("_test_chain_target_id", "")))
						if next_target_id.is_empty():
							return
						pending_command_target_ids.append(next_target_id)
					pending_command_target_coords.append(coord)
				if pending_command_target_coords.size() < maximum_targets:
					var next_target_kind := "creature or object" if is_chain_lightning else "creature"
					hud.add_log("Select another %s for %s (%d of %d), or click a selected target again to cast." % [next_target_kind, pending_spell_data.get("name", "this spell"), pending_command_target_coords.size(), maximum_targets])
					return
				var command_targets := pending_command_target_coords.duplicate()
				var command_target_ids := pending_command_target_ids.duplicate()
				pending_command_target_coords.clear()
				pending_command_target_ids.clear()
				await _execute_player_spell(command_targets[0], Vector2i(9999, 9999), command_targets, command_target_ids)
				return
			if not pending_words_primary_selected:
				if not _has_spell_creature_at(coord, pending_spell_data):
					return
				pending_words_primary_target = coord
				pending_words_primary_selected = true
				if int(pending_spell_data.get("_metamagic_twinned_extra_targets", 0)) > 0:
					hud.add_log("Select another creature within this spell's range.")
				else:
					hud.add_log("Select a second creature within 10 feet, or click the first target again to cast on one creature.")
				return
			if coord == pending_words_primary_target:
				if int(pending_spell_data.get("_metamagic_twinned_extra_targets", 0)) > 0:
					hud.add_log("Twinned Spell requires the additional target; choose another creature in range.")
					return
				await _execute_player_spell(pending_words_primary_target)
			elif _valid_additional_spell_target(pending_words_primary_target, coord, pending_spell_data):
				await _execute_player_spell(pending_words_primary_target, coord)
			else:
				hud.add_log("Choose another creature within 10 feet of the first target.")
			return
		await _execute_player_spell(coord)
	else:
		# Regular movement click
		var reachable := _player_reachable(player_pos, remaining_speed, active_character)
		var jump_cost := _spell_jump_move_cost(player_pos, coord, reachable)
		var use_spell_jump := jump_cost >= 0.0
		if (reachable.has(coord) or use_spell_jump) and coord != player_pos:
			active_character.feature_uses.erase("find_steed_just_mounted_this_turn")
			player_moved_this_turn = true
			resolving_player_action = true
			var path: Array[Vector2i] = HexUtils.hex_line(player_pos, coord) if use_spell_jump else _player_path(player_pos, coord, active_character)
			var cost: float = jump_cost if use_spell_jump else float(reachable[coord])
			remaining_speed -= cost
			if use_spell_jump:
				active_character.feature_uses["jump_spell_used_this_turn"] = true
			
			var disengaged := active_character.has_condition("disengaging")
			if not disengaged and path.size() >= 2:
				await _check_opportunity_attacks_for_path(active_character, player_entities[current_player_idx], path, false)
			elif disengaged and path.size() >= 2:
				for path_index in range(1, path.size()):
					var movement_result := CombatAction.resolve_movement_step(player_entities[current_player_idx], path[path_index - 1], path[path_index])
					if not movement_result.get("success", false):
						break
					_publish_source_range_events()
					_sync_mounted_steed_position(active_character, path[path_index])
					if await _apply_room_fall_damage(active_character, path[path_index - 1], path[path_index]):
						break
					await _resolve_spell_zone_entries(active_character, path[path_index - 1], path[path_index])
					await _resolve_spell_zone_movement(active_character, path[path_index])
			else:
				# Teleport normally if disengaged or path too short
				CombatAction.resolve_movement_step(player_entities[current_player_idx], player_pos, coord)
				_publish_source_range_events()
				_sync_mounted_steed_position(active_character, coord)
				await _resolve_spell_zone_entries(active_character, player_pos, coord)
			
			if active_character.is_alive:
				hud.add_log("%s leapt, spending 10 feet of movement." % active_character.character_name if use_spell_jump else "%s moved." % active_character.character_name)
			if _conjure_animals_zone_source_for_caster(active_character) != "":
				active_character.feature_uses["conjure_animals_moved_this_turn"] = true
				_refresh_conjure_animals_strength_advantage(active_character)
			if _conjure_celestial_zone_source_for_caster(active_character) != "":
				active_character.feature_uses["conjure_celestial_moved_this_turn"] = true
			
			_highlight_reachable()
			resolving_player_action = false

	_update_grid_entities()
	if active_character != null:
		hud.update_hud(active_character, tracker)

	if child_move and player_entities[current_player_idx].hex_position != move_origin and child_actions.settle(self):
		await child_actions.complete(self)


func _execute_player_spell(target_coord: Vector2i, additional_target_coord: Vector2i = Vector2i(9999, 9999), extra_target_coords: Array[Vector2i] = [], chain_target_ids: Array[String] = []) -> void:
	if _cast_in_progress: return
	var parent_cast := child_actions.current("cast")
	var cast := _spell_cast_context(target_coord, additional_target_coord, extra_target_coords, chain_target_ids)
	if parent_cast: child_actions.frame["cast_invocation"] = cast.invocation_id
	var actor := active_character
	var turn := CombatAction.active_turn_serial
	var count := int(pending_spell_data.get("_attack_unit_substitution_units", 0))
	if count > 0:
		attack_unit_substitution = {"actor":actor, "spell_id":str(cast.spell.id), "units":count, "parent":strike_unit_parent, "invocation_id":cast.invocation_id, "settled":false}
		cast.action_id = strike_unit_parent
	if parent_cast:
		cast.action_invocation_id = str(child_actions.frame.invocation)
		cast.parent_source_id = str(child_actions.frame.feature.id)
		cast.action_id = str(child_actions.frame.feature.child_actions.classification)
	var payment_frame := attack_unit_substitution
	var selected_spell := cast.spell
	cast.commit_guard = func():
		if active_character != actor or CombatAction.active_turn_serial != turn or not actor.is_alive or CombatAction.is_incapacitated(actor): return false
		if parent_cast: return child_actions.valid(self) and child_actions.current("cast") and not child_actions.frame.settled
		if count > 0: return _remaining_strike_units() >= count and _attack_unit_substitution_units(selected_spell) == count
		return _can_spend_action_cost(_action_cost_for_command("cast_spell", {"spell":selected_spell}))
	var commit_guard := cast.commit_guard
	cast.can_spend = func(cost: String):
		return commit_guard.call() if cost == "magic_action" and (parent_cast or count > 0) else _can_spend_action_cost(cost)
	_cast_in_progress = true
	cast.damage_receipts.clear()
	await _execute_selected_spell(cast)
	last_spell_damage_receipts = cast.damage_receipts.duplicate(true)
	_cast_in_progress = false
	resolving_player_action = false
	if parent_cast:
		if not child_actions.frame.is_empty() and child_actions.frame.settled: await child_actions.complete(self)
		elif pending_action_type.is_empty(): await child_actions.cancel(self)
	elif not payment_frame.is_empty() and payment_frame.get("settled", false):
		attack_unit_substitution = {}
	if hud != null: hud.update_hud(active_character, tracker)

func _execute_selected_spell(cast: SpellCastContext) -> void:
	if not await SpellCastPreparation.validate_and_choose(cast):
		return
	if not await SpellCastPreparation.choose_target_options(cast):
		return
	# Batch 066: recheck the arrival after any option popups, still before payment.
	if SpellCastMovement.refuse_teleport_destination(cast):
		return
	if not SpellCastResources.commit_metamagic(cast):
		return
	if not SpellCastResources.commit_spell_resource(cast):
		return
	if await _resolve_spell_cast_movement(cast):
		SpellCastResults._publish_completed_cast(cast)
		return
	await _collect_spell_cast_reactions(cast)
	if await _resolve_spell_cast_markers(cast):
		cast.successful = true # Marker handlers return only after accepting/settling this cast.
		SpellCastResults._publish_completed_cast(cast)
		return
	await SpellCastTargeting.collect_targets(cast)
	await _prepare_spell_cast_effects(cast)
	await _resolve_spell_cast_targets(cast)
	await _create_spell_cast_areas(cast)
	await _finish_spell_cast(cast)


func _sync_changed_movement_speed() -> void:
	var current_speed := _active_movement_speed_hexes()
	if active_character != _movement_speed_owner:
		_movement_speed_owner = active_character
		_movement_speed_snapshot = current_speed
		return
	var delta := current_speed - _movement_speed_snapshot
	_movement_speed_snapshot = current_speed
	if active_character != null and active_character.has_condition("prone"):
		delta /= 2.0
	_set_remaining_movement(remaining_speed - _movement_speed_shortfall + delta)

func _set_remaining_movement(allowance: float) -> void:
	remaining_speed = maxf(0.0, allowance)
	# A later speed increase must not refund distance spent above a reduced speed.
	_movement_speed_shortfall = maxf(0.0, -allowance)

## Recheck exact source owners after a real encounter position change.
func _publish_source_range_events() -> void:
	var positions: Dictionary = {}
	var actors: Array = []
	for player in player_entities:
		var actor: Character = player.get("character")
		if actor == null: continue
		var id := SpellEffects.caster_id(actor)
		positions[id] = player.get("hex_position", Vector2i.ZERO)
		actors.append(actor)
	for monster in monster_entities:
		var id := str(monster.get("id", ""))
		if id.is_empty(): continue
		positions[id] = monster.get("hex_position", Vector2i.ZERO)
		actors.append(monster)
	for target in actors:
		var target_id := SpellEffects.caster_id(target) if target is Character else str(target.get("id", ""))
		var target_position: Vector2i = positions.get(target_id, Vector2i.ZERO)
		for source in SpellEffects.records(target).keys().duplicate():
			var record: Dictionary = SpellEffects.records(target).get(source, {})
			var caster_position: Variant = positions.get(str(record.get("caster_id", "")), null)
			if not caster_position is Vector2i: continue
			var distance_feet := HexUtils.get_distance(target_position, caster_position) * 5
			SpellEffects.publish_event(target, {"type": "range", "actor_id": target_id, "distance_feet": distance_feet, "range_source_id": str(source)})


func _spell_cast_context(target_coord: Vector2i = Vector2i.ZERO, additional_target_coord: Vector2i = Vector2i(9999, 9999), extra_target_coords: Array[Vector2i] = [], chain_target_ids: Array[String] = []) -> SpellCastContext:
	var cast := SpellCastContext.new()
	cast.action_id = str(pending_spell_data.get("_parent_action_id", "magic"))
	cast.caster = active_character
	cast.spell = pending_spell_data
	cast.target_coord = target_coord
	cast.additional_target_coord = additional_target_coord
	cast.extra_target_coords = extra_target_coords
	cast.chain_target_ids = chain_target_ids
	cast.ground_items = dropped_combat_items
	cast.players = player_entities
	cast.monsters = monster_entities
	cast.player_index = current_player_idx
	cast.grid = hex_grid
	cast.hud = hud
	cast.tracker = tracker
	cast.action_history = action_history
	cast.turn_budget = turn_budget
	cast.areas = _spell_zones()
	cast.prestidigitation_effects = prestidigitation_effects
	cast.divine_intervention = pending_divine_intervention
	cast.divine_intervention_wish = pending_divine_intervention_wish
	cast.owner_label = _owner_label_for_character(active_character) if active_character != null else ""
	cast.can_spend = _can_spend_action_cost
	cast.highlight_reachable = _highlight_reachable
	cast.reset_pending = _reset_pending_spell_cast
	cast.publish_spell = _replace_pending_cast_spell
	cast.set_resolving = _set_spell_cast_resolving
	cast.detected_creatures = _detect_evil_and_good_targets
	cast.detected_hazards = _detect_poison_and_disease_targets
	cast.effect_boundary_rounds = _spell_boundary_rounds
	cast.owner_label_for_character = _owner_label_for_character
	cast.action_cost_for_command = _action_cost_for_command
	cast.add_find_steed_entity = _add_find_steed_entity
	cast.attach_created_actors = _attach_created_actors
	cast.apply_find_steed_life_bond = _apply_find_steed_life_bond
	cast.check_battle_end_conditions = _check_battle_end_conditions
	cast.collect_attack_inspiration_decision = _collect_attack_inspiration_decision
	cast.collect_bardic_inspiration_save_decision = _collect_bardic_inspiration_save_decision
	cast.collect_countercharm_decisions = _collect_countercharm_decisions
	cast.collect_counterspell_decisions = _collect_counterspell_decisions
	cast.collect_reaction_decisions = _collect_reaction_decisions
	cast.collect_spell_shield_decision = _collect_spell_shield_decision
	cast.collect_stroke_of_luck_save_decision = _collect_stroke_of_luck_save_decision
	cast.collect_roll_token_decision = _collect_roll_token_decision
	cast.collect_projected_ward_decision = _collect_projected_ward_decision
	cast.offer_potent_spellcasting_vitality = _offer_potent_spellcasting_vitality
	cast.offer_power_word_heal_stand = _offer_power_word_heal_stand
	cast.offer_sneak_attack = _offer_sneak_attack
	cast.offer_divine_smite = _offer_divine_smite
	cast.offer_weapon_damage_riders = _offer_weapon_damage_riders
	cast.publish_true_strike_activity = _publish_true_strike_activity
	cast.spend_action_cost = _spend_action_cost.bind(cast.invocation_id)
	cast.trigger_enemy_defeat_features = _trigger_enemy_defeat_features
	cast.finish_targeting = _finish_spell_targeting
	cast.begin_targeting = _begin_spell_targeting
	cast.minor_illusion_markers = minor_illusion_markers
	cast.mage_hand_markers = mage_hand_markers
	cast.light_spell_markers = light_spell_markers
	cast.dancing_light_sets = dancing_light_sets
	cast.produce_flame_markers = produce_flame_markers
	cast.refresh_poison_senses = _refresh_detect_poison_and_disease_senses
	cast.refresh_creature_senses = _refresh_detect_evil_and_good_senses
	cast.end_concentration = _end_concentration
	cast.publish_source_range_events = _publish_source_range_events
	cast.end_resilient_sphere = _end_resilient_sphere_for_target
	cast.push_blocked_hexes = _spell_push_blocked_hexes
	cast.redraw_entities = _update_grid_entities
	cast.push_combat_target = _push_combat_target
	return cast


func _reset_pending_spell_cast(flags: int) -> void:
	if flags & SpellCastContext.CLEAR_ACTION:
		pending_action_type = ""
		attack_unit_substitution = {}
	if flags & SpellCastContext.CLEAR_SPELL:
		pending_spell_data = {}
	if flags & SpellCastContext.CLEAR_INTERVENTION:
		pending_divine_intervention = false
	if flags & SpellCastContext.CLEAR_WISH:
		pending_divine_intervention_wish = false


func _replace_pending_cast_spell(spell_data: Dictionary) -> void:
	pending_spell_data = spell_data


func _set_spell_cast_resolving(resolving: bool) -> void:
	resolving_player_action = resolving


func _resolve_spell_cast_movement(cast: SpellCastContext) -> bool:
	return await SpellCastMovement._resolve_spell_cast_movement(cast)




func _collect_spell_cast_reactions(cast: SpellCastContext) -> void:
	await SpellCastReactions._collect_spell_cast_reactions(cast)




func _resolve_spell_cast_markers(cast: SpellCastContext) -> bool:
	return await SpellCastMarkers._resolve_spell_cast_markers(cast)




func _prepare_spell_cast_effects(cast: SpellCastContext) -> void:
	await SpellCastReactions._prepare_spell_cast_effects(cast)




func _resolve_spell_cast_targets(cast: SpellCastContext) -> void:
	await SpellCastResults._resolve_spell_cast_targets(cast)




func _create_spell_cast_areas(cast: SpellCastContext) -> void:
	await SpellCastAreas._create_spell_cast_areas(cast)




func _finish_spell_cast(cast: SpellCastContext) -> void:
	await SpellCastResults._finish_spell_cast(cast)




func _resolve_ice_knife_splash(center: Vector2i, spell_data: Dictionary, slot_level: int, cast_decisions: Dictionary) -> void:
	await SpellCastResults._resolve_ice_knife_splash(_spell_cast_context(), center, spell_data, slot_level, cast_decisions)




func _spell_decisions_for_target(cast_decisions: Dictionary, first_target: bool) -> Dictionary:
	return SpellCastResults._spell_decisions_for_target(_spell_cast_context(), cast_decisions, first_target)




func _collect_spell_shield_decision(target: Character, spell_data: Dictionary, existing_decisions: Dictionary) -> Dictionary:
	if target == null or not target.reaction_available or SpellPermissionRules.payment_choices(target, "shield").is_empty():
		return {}
	for decision_key in existing_decisions:
		if str(decision_key) == "counterspell:%s" % target.character_name and bool(existing_decisions[decision_key]):
			return {}
	var spell_id := str(spell_data.get("id", ""))
	var attack_type := str(spell_data.get("attack_type", "none"))
	if spell_id == "magic_missile":
		return await _choose_shield_payment(target, await hud.request_reaction(_owner_label_for_character(target), "shield", "Magic Missile targets you. Shield prevents all its damage and adds +5 AC until your next turn."))
	if attack_type not in ["ranged_spell", "melee_spell"]:
		return {}
	var spell_name := str(spell_data.get("name", "This spell"))
	return await _choose_shield_payment(target, await hud.request_reaction(_owner_label_for_character(target), "shield", "If %s hits you, cast Shield as a Reaction? It spends only if an attack hits. The +5 AC applies against the triggering attack and later attacks until the start of your next turn." % spell_name, "Use Shield if hit?", "Use Reaction", "Shield — %s" % _owner_label_for_character(target)))

func _choose_shield_payment(target: Character, accepted: bool) -> Dictionary:
	if not accepted: return {"shield":false}
	var payment := await hud.request_spell_payment(target, "shield")
	return {"shield":not payment.is_empty(), SpellPermissionRules.reaction_key(target, "shield"):payment}


func _settle_empowered_spell(target, result: Dictionary, decisions: Dictionary) -> Dictionary:
	return await SpellCastResults._settle_empowered_spell(_spell_cast_context(), target, result, decisions)




func _apply_find_steed_life_bond(owner: Character, healing: int, owner_position: Vector2i) -> void:
	if healing <= 0 or owner == null:
		return
	for entity in player_entities:
		if not entity.get("is_steed", false) or entity.get("steed_owner") != owner:
			continue
		if not Targeting.is_in_range(owner_position, entity.get("hex_position", Vector2i.ZERO), 1):
			return
		var steed: Character = entity.get("character")
		if steed == null or not steed.is_alive:
			return
		var restored := PaladinRules.apply_life_bond(owner, steed, healing)
		if restored > 0:
			hud.add_log("Life Bond restores %d Hit Points to %s." % [restored, steed.character_name])
		return


func _area_selection_for_spell(spell_data: Dictionary) -> Dictionary:
	return SpellCastTargeting._area_selection_for_spell(_spell_cast_context(), spell_data)


func _on_hex_hovered(coord: Vector2i) -> void:
	# --- Move-path preview (P1 readability) ---
	# When no offensive action is pending, show the route to the hovered
	# reachable hex so the player commits with eyes open (no blind teleport).
	if pending_action_type == "" and active_character != null and not _battle_ending:
		_clear_path_preview()
		var player_pos: Vector2i = player_entities[current_player_idx]["hex_position"]
		if coord != player_pos and active_character.is_alive:
			var reachable := _player_reachable(player_pos, remaining_speed, active_character)
			if coord in reachable:
				var path := _player_path(player_pos, coord, active_character)
				for h in path:
					if h != player_pos:
						hex_grid.add_highlight(h, HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.PATH])
						_path_preview_hexes.append(h)
		return

	# For spell casting, overlay targeting shapes (e.g. highlight AoE sphere or cone on hover)
	if pending_action_type == "spell":
		var target_type: String = pending_spell_data.get("target", "single")
		var origin := _pending_spell_origin()
		var max_range := _spell_target_range(pending_spell_data)

		if not Targeting.is_in_range(origin, coord, max_range):
			return # Out of cast range, keep default highlights

		# Recalculate range markers
		_highlight_spell_targets()
		
		# Overlay AoE area hover highlights
		var aoe_list: Array = []
		if target_type == "area":
			var area_selection := _area_selection_for_spell(pending_spell_data)
			if not area_selection.get("success", false):
				return
			if int(pending_spell_data.get("area_point_count", 1)) > 1 and str(area_selection.get("shape", "sphere")) == "sphere":
				var preview_centers: Array[Vector2i] = pending_command_target_coords.duplicate()
				if coord not in preview_centers:
					preview_centers.append(coord)
				aoe_list = SpellCastTargeting.union_sphere_targets(preview_centers, int(area_selection.get("radius", 2)), hex_grid)
			else:
				match str(area_selection.get("shape", "sphere")):
					"line":
						if not pending_command_target_coords.is_empty():
							aoe_list = HexUtils.hex_line(pending_command_target_coords[0], coord)
					"point":
						aoe_list = [coord]
					"cube":
						aoe_list = Targeting.get_cube_targets(origin, coord, int(area_selection.get("size", 3)), hex_grid)
					"cone":
						aoe_list = Targeting.get_cone_targets(origin, coord, int(area_selection.get("size", 3)), hex_grid)
					"square":
						aoe_list = Targeting.get_square_targets(coord, int(area_selection.get("size_feet", 10)), hex_grid)
					_:
						aoe_list = Targeting.get_sphere_targets(coord, int(area_selection.get("radius", 2)), hex_grid)
		elif target_type == "cone":
			var area_selection := _area_selection_for_spell(pending_spell_data)
			if not area_selection.get("success", false):
				return
			var cone_size := int(area_selection.get("size", 3))
			aoe_list = Targeting.get_cone_targets(origin, coord, cone_size, hex_grid)

		for hex in aoe_list:
			hex_grid.add_highlight(hex, HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.SPELL])


## Chill Touch expires at the end of the caster's next turn, regardless of
## where the target falls in initiative order.
func _tick_spell_healing_suppression(caster: Character) -> void:
	SpellEncounterLifecycle._tick_spell_healing_suppression(_spell_cast_context(), caster)


func _end_active_turn() -> void:
	if _pool_recovery_pending: return
	_waiting_for_owner_rebind = false
	_rebind_wait_before_turn_setup = false
	# Resolve victory/defeat before advancing the turn order. This is the
	# chokepoint for both player and monster turns, so a monster wiping the
	# last standing player (or any death during turn-start) is caught here.
	if _check_battle_end_conditions():
		return

	if active_combatant["is_player"] and active_character != null:
		for actor_id in CreatedCommandRules.apply_defaults(self, active_character): # Batch 055 S-156: uncommanded default.
			hud.add_log("%s was not commanded and acts on its declared behaviour." % str(_entity_name_for_created(actor_id)))
	# Tick active conditions at turn end
	if active_combatant["is_player"] and active_character != null:
		await _resolve_delayed_spell_damage(active_character)
		if _check_battle_end_conditions():
			return
		_resolve_condition_spell_repeat_saves(active_character)
		await _resolve_spell_zone_end_turn(active_character, player_entities[current_player_idx].get("hex_position", Vector2i.ZERO))
		_tick_spell_effect_boundary(active_character, "end")
		SpellEffects.reconcile(_spell_casters(), _spell_effect_targets())
		for fall_message in LocalRoomCombat.reconcile_flight_altitudes(player_entities):
			hud.add_log(fall_message)
		if _check_battle_end_conditions():
			return
		active_character.tick_conditions()
		active_character.combat_command.clear()
		_tick_spell_healing_suppression(active_character)
		FighterRules.end_turn(active_character)
	elif not active_combatant["is_player"] and not active_combatant.is_empty():
		var monster: Dictionary = active_combatant["entity"]
		await _resolve_delayed_spell_damage(monster)
		if _check_battle_end_conditions():
			return
		if CombatAction.has_condition_source(monster, RogueRules.CUNNING_KNOCKOUT_SOURCE):
			var knock_out_dc := int(monster.get("rogue_cunning_knock_out_dc", 0))
			var knock_out_save := BarbarianRules.roll_monster_save(monster, "CON")
			if RogueRules.resolve_knock_out_repeat_save(monster, knock_out_save, knock_out_dc):
				hud.add_log("%s succeeds on the end-of-turn Constitution save and wakes from Knock Out (%d vs DC %d)." % [monster.get("name", "The target"), knock_out_save, knock_out_dc])
			else:
				hud.add_log("%s remains Unconscious after failing its end-of-turn Constitution save (%d vs DC %d)." % [monster.get("name", "The target"), knock_out_save, knock_out_dc])
		if CombatAction.has_condition_source(monster, "rogue_cunning_poison"):
			var poison_save := BarbarianRules.roll_monster_save(monster, "CON")
			var poison_dc := int(monster.get("rogue_cunning_poison_dc", 0))
			if poison_save >= poison_dc:
				CombatAction.remove_condition_source(monster, "rogue_cunning_poison", ["poisoned"])
				monster.erase("rogue_cunning_poison_dc")
				hud.add_log("%s succeeds on the end-of-turn Constitution save and ends the Rogue's poison." % monster.get("name", "The target"))
			else:
				hud.add_log("%s remains Poisoned after failing its end-of-turn Constitution save (%d vs DC %d)." % [monster.get("name", "The target"), poison_save, poison_dc])
		_resolve_condition_spell_repeat_saves(monster)
		await _resolve_spell_zone_end_turn(monster, monster.get("hex_position", Vector2i.ZERO))
		SpellEffects.reconcile(_spell_casters(), _spell_effect_targets())
		CombatState.tick_monster_condition_durations(monster)
		monster.erase("combat_command")
		if not CombatAction.has_condition_source(monster, "rogue_cunning_poison"):
			monster.erase("rogue_cunning_poison_dc")
		if not CombatAction.has_condition_source(monster, RogueRules.CUNNING_KNOCKOUT_SOURCE):
			monster.erase("rogue_cunning_knock_out_dc")
		monster.erase("fighter_stood_up")

	_advance_combat_turn()


func _advance_combat_turn() -> void:
	for gone_id in CreatedCommandRules.reconcile(self): # Ended sources leave before the order advances.
		hud.add_log("%s leaves the battle; its source has ended." % gone_id)
	var round_complete := tracker.next_turn()
	if round_complete:
		# Combat owns effect/light ticks; advance only the durable campaign clock here.
		GameManager.campaign_elapsed_seconds += 6
		SpellEffects.resolve_elapsed_repeat_saves(_spell_effect_targets(), int(GameManager.campaign_elapsed_seconds))
		for player in player_entities:
			CorpseRules.advance_time(player["character"], GameManager.campaign_elapsed_seconds)
		_tick_portable_light_sources()
		_tick_active_time_and_tethers()
		_tick_spell_zones()
	_start_combat_turn()


## A removed owner supplies only a clock for its creatures. Never run the
## owner's action, recovery, conditions or turn budgets here.
func _start_created_actor_interval() -> void:
	if _check_battle_end_conditions(): return
	active_combatant = tracker.get_active()
	active_character = null
	current_player_idx = -1
	pending_action_type = ""
	hex_grid.clear_highlights()
	hud.update_hud(null, tracker)
	action_history.begin_scheduled_interval(tracker.current_round)
	CombatAction.advance_combat_turn(null, tracker.current_round)
	var owner: Character = active_combatant.entity
	CreatedCommandRules.tick_sources(self, owner, "start")
	SpellEffects.reconcile(_spell_casters(), _spell_effect_targets())
	CreatedCommandRules.start_owner_turn(self, owner)
	for actor_id in CreatedCommandRules.apply_defaults(self, owner):
		hud.add_log("%s acts on its declared behaviour." % _entity_name_for_created(actor_id))
	CreatedCommandRules.tick_sources(self, owner, "end")
	SpellEffects.reconcile(_spell_casters(), _spell_effect_targets())
	if _check_battle_end_conditions(): return
	await get_tree().process_frame
	_advance_combat_turn()


## S-064 active time spends combat rounds; S-168 tethers beyond range break.
func _tick_active_time_and_tethers() -> void:
	for player in player_entities:
		var character: Character = player.get("character")
		if character == null: continue
		ActiveTimeRules.settle(character, 6, int(GameManager.campaign_elapsed_seconds))
	_enforce_tether_range()


## S-066: combat interrupts qualified work; progress follows each work's own policy.
func _interrupt_work_for_combat() -> void:
	for player in player_entities:
		var character: Character = player.get("character")
		for receipt in WorkRules.interrupt_all(character, "combat"):
			hud.add_log("[color=orange]%s's work is interrupted by combat (%d seconds kept, %d lost).[/color]" % [character.character_name, int(receipt.kept_seconds), int(receipt.lost_seconds)])


## Review 045 R1: S-168 range check against current positions (movement, teleport, forced moves).
func _enforce_tether_range() -> void:
	var captors: Array = []
	var positions := {}
	var victims := {}
	for player in player_entities:
		var character: Character = player.get("character")
		if character == null: continue
		captors.append(character)
		positions[character.character_id] = player.get("hex_position", Vector2i.ZERO)
		victims[character.character_id] = character
	for monster in monster_entities:
		positions[TetherRules.victim_id(monster)] = monster.get("hex_position", Vector2i.ZERO)
		victims[TetherRules.victim_id(monster)] = monster
	for source in TetherRules.enforce_range(captors, positions, victims):
		hud.add_log("[color=cyan]A tether stretches past its range and breaks.[/color]")


func _tick_portable_light_sources() -> void:
	for player in player_entities:
		var character: Character = player.get("character")
		if character == null or character.inventory == null:
			continue
		for record in character.inventory.owned_instances():
			if LightSourceRules.is_lit(record):
				character.inventory.update_instance(LightSourceRules.tick_record(record, 6))
	for index in dropped_combat_items.size():
		var dropped: Dictionary = dropped_combat_items[index]
		if LightSourceRules.is_lit(dropped):
			dropped_combat_items[index] = LightSourceRules.tick_record(dropped, 6)
	_update_grid_entities()


func _resolve_delayed_spell_damage(target) -> void:
	await SpellEncounterLifecycle._resolve_delayed_spell_damage(_spell_cast_context(), target)
## Tick monster conditions and restore movement after a spell slow expires.
## Kept as a stateless boundary so duration cleanup can be exercised without
## constructing a full combat scene.
static func tick_monster_condition_durations(monster: Dictionary) -> void:
	var conditions: Dictionary = monster.get("conditions", {})
	var tracked_conditions: Array = monster.get("condition_sources", {}).keys()
	var had_animal_friendship := _has_animal_friendship_condition_source(monster)
	var was_turned := CombatAction.has_condition_source(monster, "turn_undead")
	var was_abjured := CombatAction.has_condition_source(monster, "abjure_foes")
	CombatAction.tick_condition_sources(monster)
	if had_animal_friendship and not _has_animal_friendship_condition_source(monster):
		monster.erase("animal_friendship_caster_ids")
	if was_turned and not CombatAction.has_condition_source(monster, "turn_undead"):
		monster.erase("turn_undead_origin")
	if was_abjured and not CombatAction.has_condition_source(monster, "abjure_foes"):
		monster.erase(PaladinRules.ABJURE_FOES_MARKER)
		monster.erase(PaladinRules.ABJURE_FOES_CASTER_ID)
	var expired: Array[String] = []
	for cond in conditions:
		if cond in tracked_conditions:
			continue
		conditions[cond] -= 1
		if conditions[cond] <= 0:
			expired.append(cond)
	for cond in expired:
		conditions.erase(cond)
		if cond == "longstrider":
			monster["speed"] = maxi(0, int(monster.get("speed", 6)) - 2)
		if cond == "charmed" and not conditions.has("charmed"):
			monster.erase("animal_friendship_caster_ids")
		if cond == "frightened":
			monster.erase(PaladinRules.ABJURE_FOES_MARKER)
			monster.erase(PaladinRules.ABJURE_FOES_CASTER_ID)
		if cond == "incapacitated" or cond == "frightened":
			if not conditions.has("incapacitated") and not conditions.has("frightened"):
				monster.erase("turn_undead_origin")
		if cond == "speed_reduced" and monster.has("speed_before_spell_slow"):
			monster["speed"] = int(monster.get("speed_before_spell_slow", monster.get("speed", 6)))
			monster.erase("speed_before_spell_slow")


static func _has_animal_friendship_condition_source(monster: Dictionary) -> bool:
	if SpellEffects.has_spell(monster, "animal_friendship"):
		return true
	for source_id in monster.get("condition_sources", {}).get("charmed", {}):
		if str(source_id).begins_with("animal_friendship:"):
			return true
	return false


func _creature_at_coord_matches_sizes(coord: Vector2i, required_sizes: Array) -> bool:
	return SpellCastTargeting._creature_at_coord_matches_sizes(_spell_cast_context(), coord, required_sizes)


func _creature_at_coord_has_condition(coord: Vector2i, condition: String) -> bool:
	return SpellCastTargeting._creature_at_coord_has_condition(_spell_cast_context(), coord, condition)


func _check_battle_end_conditions() -> bool:
	# If a battle-end was already triggered, don't trigger it again.
	if _battle_ending:
		return true

	# Check if all monsters dead
	var monsters_alive := false
	for m in monster_entities:
		if m["is_alive"]:
			monsters_alive = true
			break

	if not monsters_alive:
		_battle_ending = true
		hud.add_log("[color=green]VICTORY! All monsters defeated.[/color]")
		# Register defeated monsters
		for m in monster_entities:
			var defeated_id := str(m.get("monster_id", ""))
			if not defeated_id.is_empty() and defeated_id not in GameManager.defeated_monsters:
				GameManager.defeated_monsters.append(defeated_id)
		_end_battle("victory")
		return true

	# Check if all players dead (TPK / party wipe)
	var players_alive := false
	for p in player_entities:
		if p.get("is_familiar", false) or p.get("is_steed", false) or p.get("is_created_creature", false) or p.get("is_created_actor", false):
			continue
		var c: Character = p.get("character")
		if c != null and (c.is_alive or (not c.disintegrated and (c.has_feature("fighter_indomitable") or c.has_feature("champion_survivor")) and c.death_save_failures < 3 and c.death_save_successes < 3)):
			players_alive = true
			break

	if not players_alive:
		_battle_ending = true
		hud.add_log("[color=red]DEFEAT! TPK - Entire party was wiped.[/color]")
		_end_battle("defeat")
		return true

	return false


func _end_battle(result: String) -> void:
	CreatedCreatureCombat.capture(self)
	_cleanup_dead_familiars()
	_sync_find_steeds()
	LocalRoomCombat.capture_spell_zones(player_entities, active_spell_zones)
	LocalRoomCombat.capture(player_entities, dropped_combat_items)
	CombatAction.active_turn_actor_id = 0
	CombatAction.reset_bounded_owner_turn_rider_locks()
	for source_id_value in active_spell_zones.keys().duplicate():
		_remove_spell_zone(str(source_id_value))
	SpellEffects.finish_encounter(_spell_casters(), _spell_effect_targets())
	_clear_monk_battle_effects()
	_clear_delayed_spell_damage()
	set_process_input(false)
	var presenter := CombatResultPresenter.new()
	var choice: String = await presenter.present(self, result, GameManager.test_mode)
	if GameManager.test_mode:
		# Headless / test: never block on a button press or replace the harness.
		# The viewport harness owns the scene tree. A real scene transition here
		# would replace that supervisor before it can publish its result marker.
		# The battle has already resolved and registered its defeated monsters.
		print("[CombatState] Test mode: skipping post-battle scene transition")
		return
	if choice == "menu":
		GameManager.return_to_menu()
	else:
		GameManager.exit_combat(result)


func _clear_monk_battle_effects() -> void:
	for player in player_entities:
		var member: Character = player.get("character")
		if member != null and member.feature_uses.has("monk_patient_dodge"):
			member.remove_condition("dodging")
			member.feature_uses.erase("monk_patient_dodge")


func _exit_tree() -> void:
	child_actions.clear()
	aura_choice_generation += 1
	temporary_hp_grants.clear()
	grant_transfers.clear()
	party_allocations.clear()
	pool_recovery.clear()
	CombatAction.reset_bounded_owner_turn_rider_locks()
	for entity in player_entities:
		var character: Character = entity.get("character")
		if character != null:
			# Combat owns these positions; range-only auras cannot outlive it.
			character.aura_source_memberships.clear()
			character.familiar_senses = null
			ProtectionRules.cancel_choice(character)
	CombatAction.active_turn_actor_id = 0
	_clear_monk_battle_effects()
	_clear_delayed_spell_damage()
	SpellDamageRolls.clear_pending_requests()


func _recover_combat_pools(actor: Character, trigger: String, occurrence: int) -> void:
	_pool_recovery_pending = true
	var receipt_start := pool_recovery.receipts.size()
	var requests := pool_recovery.begin(actor, trigger, occurrence)
	for request in requests:
		var selected := await hud.request_pool_recovery(request)
		if not is_inside_tree(): return
		var result := pool_recovery.settle(str(request.request_id), actor, selected)
		if not result.get("success", false): hud.add_log(str(result.get("message", "Recovery unavailable.")))
	for receipt in pool_recovery.receipts.slice(receipt_start):
		hud.add_log("%s regains %d pool uses (%d/%d) at %s." % [actor.character_name, int(receipt.recovered), int(receipt.current), int(receipt.capacity), trigger.replace("_", " ")])
	_pool_recovery_pending = false


func _clear_delayed_spell_damage() -> void:
	SpellEncounterLifecycle._clear_delayed_spell_damage(_spell_cast_context())


func _refresh_paladin_divine_sense(paladin: Character) -> void:
	if paladin == null or paladin.class_id != "paladin" or not paladin.feature_uses.has("paladin_divine_sense_expires_round"):
		return
	if paladin.has_condition("incapacitated") or tracker.current_round >= int(paladin.feature_uses.get("paladin_divine_sense_expires_round", 0)):
		paladin.feature_uses.erase("paladin_divine_sense_targets")
		paladin.feature_uses.erase("paladin_divine_sense_expires_round")
		return
	if current_player_idx < 0 or current_player_idx >= player_entities.size():
		return
	var origin: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
	CombatAction.resolve_divine_sense(paladin, monster_entities, origin, 12, tracker.current_round, true)


func _execute_class_feature(feature: Dictionary) -> void:
	if feature.has("temporary_hp_grant"):
		await _execute_temporary_hp_grant(feature)
		return
	if feature.has("allocation"):
		await _execute_party_allocation(feature)
		return
	if feature.has("transfer_grant"):
		await _execute_captured_grant_transfer(feature)
		return
	if str(feature.get("id", "")) == "rogue_steady_aim":
		if player_moved_this_turn or rogue_steady_aim_armed:
			hud.add_log("Steady Aim requires that you have not moved this turn.")
			return
		if not turn_budget.can_spend("bonus_action") or not active_character.use_feature("rogue_steady_aim"):
			hud.add_log("No Bonus Action remains for Steady Aim.")
			return
		_spend_action_cost("bonus_action")
		rogue_steady_aim_armed = true
		remaining_speed = 0
		hud.add_log("%s steadies their aim. Speed is 0 until the end of the turn; the next attack has Advantage." % active_character.character_name)
		hud.update_hud(active_character, tracker)
		_highlight_reachable()
		return
	if str(feature.get("resolver", "")) == "cleric_rules" and str(feature.get("id", "")) == "cleric_turn_undead":
		await _execute_cleric_turn_undead(feature)
		return
	if feature.has("executor"):
		var result := ClassFeature.execute(active_character, feature, null, turn_budget, str(feature.get("source_instance_id", "")), int(feature.get("selected_pool_quantity", 0)))
		if not result.get("success", false):
			hud.add_log(result.get("message", "Feature unavailable."))
			return
		for effect_result in result.get("results", []):
			hud.add_log(effect_result.get("message", ""))
		if str(feature.get("id", "")) == "barbarian_rage" and not result.get("rage_extended", false):
			var pounce_distance := BarbarianRules.instinctive_pounce_distance(active_character)
			if pounce_distance > 0:
				remaining_speed += pounce_distance
				hud.add_log("[color=green]Instinctive Pounce: %s can move up to %d feet.[/color]" % [active_character.character_name, pounce_distance * 5])
		if feature.get("id", "") == "fighter_second_wind" and active_character.has_feature("fighter_tactical_shift"):
			resolving_player_action = true
			await _offer_fighter_movement("Tactical Shift")
			resolving_player_action = false
		if feature.get("action_cost", "") == "bonus_action" and active_character.has_feature("monk_fleet_step"):
			_grant_extra_movement_speed()
		hud.update_hud(active_character, tracker)
		_highlight_reachable()
		return
	var f_id: String = feature.get("id", "")
	for effect in feature.get("effects", []):
		if effect is Dictionary and str(effect.get("type", "")) == "rest_slot_recovery":
			hud.add_log("%s can only be used when finishing a Short Rest." % str(feature.get("name", f_id)))
			return
	var cost_type: String = feature.get("action_cost", "action")
	if not _can_spend_action_cost(cost_type):
		hud.add_log("You have no %s available for %s." % [cost_type.replace("_", " "), feature.get("name", f_id)])
		return
	
	var monk_choice := str(feature.get("selected_action", ""))
	var focus_cost := int(feature.get("focus_cost", 0))
	if f_id in ["monk_patient_defense", "monk_step_of_the_wind"]:
		if monk_choice not in feature.get("options", []):
			return
		focus_cost = 1 if monk_choice in ["disengage_dodge", "dash_disengage"] else 0
	if focus_cost > 0 and active_character.get_focus_points() < focus_cost:
		hud.add_log("Not enough Focus.")
		return
	if not active_character.use_feature(f_id):
		hud.add_log("You have no uses of %s remaining!" % feature.get("name", f_id))
		return

	hud.add_log("[color=cyan]%s uses class feature: %s![/color]" % [active_character.character_name, feature.get("name", f_id)])

	var effects: Array = feature.get("effects", [])
	active_character.spend_focus_points(focus_cost)
	_spend_action_cost(cost_type)
	if cost_type == "bonus_action" and pending_action_type == "unarmed_attack":
		pending_action_type = ""
		pending_feature_data = {}

	for effect in effects:
		var type: String = effect.get("type", "")
		match type:
			"monk_bonus_action":
				if monk_choice.begins_with("dash"):
					_grant_extra_movement_speed()
				if "disengage" in monk_choice:
					active_character.add_condition("disengaging", 1)
				if monk_choice == "disengage_dodge":
					active_character.add_condition("dodging", 2)
					active_character.feature_uses["monk_patient_dodge"] = true
					if active_character.has_feature("monk_heightened_focus"):
						var temp_hp := Dice.parse_dice_string(active_character.get_martial_arts_die()) + Dice.parse_dice_string(active_character.get_martial_arts_die())
						active_character.temp_hp = maxi(active_character.temp_hp, temp_hp)
						hud.add_log("Heightened Focus grants %d Temporary Hit Points." % temp_hp)
				if active_character.has_feature("monk_fleet_step") and f_id == "monk_patient_defense":
					_grant_extra_movement_speed()
					hud.add_log("Fleet Step grants Step of the Wind dash movement.")
				hud.add_log("%s: %s (%d Focus remaining)." % [feature.get("name", f_id), monk_choice.replace("_", " + "), active_character.get_focus_points()])
			"grant_extra_action":
				turn_budget.grant_surge_action()
				hud.add_log("[color=green]%s gains an additional action this turn![/color]" % active_character.character_name)
			"cunning_dash":
				_grant_extra_movement_speed()
				hud.add_log("[color=green]%s uses Cunning Action: Dash! Speed doubled to %.1f.[/color]" % [active_character.character_name, remaining_speed])
			"cunning_disengage":
				active_character.add_condition("disengaging", 1)
				hud.add_log("[color=green]%s uses Cunning Action: Disengage! Opportunity attacks against them are disabled this turn.[/color]" % active_character.character_name)
			"cunning_hide":
				# Roll stealth check vs passive perception of monsters (or standard DC)
				var roll := Dice.roll(20)
				var dex_mod := active_character.ability_scores.get_ability_modifier("DEX")
				var stealth_bonus := dex_mod
				if "Stealth" in active_character.skill_proficiencies:
					stealth_bonus += active_character.proficiency_bonus
				var total := roll + stealth_bonus
				
				# Check vs typical passive perception (e.g. DC 12)
				var dc := 12
				var success := total >= dc
				if success:
					active_character.add_condition("hidden", 1)
					hud.add_log("[color=green]%s uses Cunning Action: Hide! Stealth check: %d (Roll %d + %d bonus) vs DC %d. SUCCESS! They are now hidden.[/color]" % [active_character.character_name, total, roll, stealth_bonus, dc])
				else:
					hud.add_log("[color=yellow]%s uses Cunning Action: Hide! Stealth check: %d (Roll %d + %d bonus) vs DC %d. FAILED! They failed to hide.[/color]" % [active_character.character_name, total, roll, stealth_bonus, dc])
			"cunning_action":
				var selected_action := str(feature.get("selected_action", "dash"))
				match selected_action:
					"dash":
						_grant_extra_movement_speed()
						hud.add_log("[color=green]%s uses Cunning Action: Dash! Speed doubled to %.1f.[/color]" % [active_character.character_name, remaining_speed])
					"disengage":
						active_character.add_condition("disengaging", 1)
						hud.add_log("[color=green]%s uses Cunning Action: Disengage![/color]" % active_character.character_name)
					"hide":
						var hide_roll := Dice.roll(20) + active_character.ability_scores.get_ability_modifier("DEX")
						if hide_roll >= 12:
							active_character.add_condition("hidden", 1)
							hud.add_log("[color=green]%s uses Cunning Action: Hide! Stealth check %d vs DC 12 succeeded.[/color]" % [active_character.character_name, hide_roll])
						else:
							hud.add_log("[color=yellow]%s uses Cunning Action: Hide! Stealth check %d vs DC 12 failed.[/color]" % [active_character.character_name, hide_roll])
			"step_of_the_wind":
				var step_action := str(feature.get("selected_action", "dash"))
				match step_action:
					"dash":
						_grant_extra_movement_speed()
						hud.add_log("[color=green]%s uses Step of the Wind: Dash! Speed doubled to %.1f.[/color]" % [active_character.character_name, remaining_speed])
					"disengage":
						active_character.add_condition("disengaging", 1)
						hud.add_log("[color=green]%s uses Step of the Wind: Disengage![/color]" % active_character.character_name)
			"divine_sense":
				var sense_origin: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
				var sense_result := CombatAction.resolve_divine_sense(active_character, monster_entities, sense_origin, 12, tracker.current_round)
				hud.add_log("[color=cyan]%s[/color]" % sense_result.get("message", "Divine Sense resolves."))
			"recover_spell_slots":
				_recover_wizard_spell_slots(active_character)
			"superior_defense":
				var def_res := MonkRules.activate_superior_defense(active_character)
				hud.add_log(def_res.get("message", ""))
			_:
				var res := EventResolver.apply_effects(active_character, [effect])
				for r in res:
					hud.add_log(r.get("message", ""))

	if f_id == "fighter_second_wind" and active_character.has_feature("fighter_tactical_shift"):
		resolving_player_action = true
		await _offer_fighter_movement("Tactical Shift")
		resolving_player_action = false
	hud.update_hud(active_character, tracker)
	_highlight_reachable()


func _execute_cleric_turn_undead(feature: Dictionary) -> void:
	var channel_error := ClericRules.channel_divinity_error(active_character)
	if not channel_error.is_empty():
		hud.add_log(channel_error)
		return
	if not turn_budget.can_spend("magic_action") or not active_character.has_feature("cleric_turn_undead") or int(active_character.feature_uses.get("cleric_channel_divinity", 0)) <= 0:
		hud.add_log("Turn Undead needs a Channel Divinity use and a Magic action.")
		return
	var origin: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
	var candidates: Array[Dictionary] = []
	for monster in monster_entities:
		if monster.get("is_alive", false) and str(monster.get("creature_type", "")).to_lower() == "undead" and Targeting.is_in_range(origin, monster.get("hex_position", Vector2i.ZERO), 6):
			candidates.append(monster)
	if candidates.is_empty():
		hud.add_log("No Undead are within 30 feet.")
		return
	resolving_player_action = true
	var selected := await hud.request_turn_undead_targets(candidates)
	var sear := false
	if not selected.is_empty() and active_character.has_feature("cleric_sear_undead"):
		sear = await hud.request_reaction(_owner_label_for_character(active_character), "sear_undead", "Deal Radiant damage to each selected Undead that fails its save?", "Use Sear Undead?", "Sear", "Sear Undead")
	resolving_player_action = false
	if selected.is_empty():
		return
	if not turn_budget.can_spend("magic_action") or not active_character.use_feature("cleric_turn_undead"):
		return
	_spend_action_cost("magic_action")
	var results := ClericRules.resolve_turn_undead(active_character, monster_entities, origin, selected, sear)
	for result in results:
		hud.add_log(str(result.get("message", "Turn Undead resolves.")))
		for monster in monster_entities:
			if str(monster.get("id", "")) == str(result.get("target_id", "")) and not monster.get("is_alive", false):
				tracker.remove_combatant(str(monster["id"]))
	_update_grid_entities()
	hud.update_hud(active_character, tracker)
	_check_battle_end_conditions()
	_highlight_reachable()

func _execute_item(item: Dictionary, substitution_units: int = 0) -> void:
	var item_id := str(item.get("id", ""))
	var item_data := DataLoader.get_item(item_id)
	var cost_type := str(item_data.get("action_cost", "action"))
	if substitution_units <= 0 and not _can_spend_action_cost(cost_type):
		hud.add_log("You have no %s available to use that item." % cost_type.replace("_", " "))
		return
	if substitution_units > 0 and (_remaining_strike_units() < substitution_units or CombatChildActions.units(item_data) != substitution_units): return
	var result := active_character.inventory.consume_instance(str(item.instance_id), active_character) if item.has("instance_id") else active_character.inventory.consume(item_id, active_character)
	if not result.get("success", false):
		hud.add_log("[color=orange]%s[/color]" % result.get("message", "Item could not be used."))
		return
	if substitution_units > 0: _consume_strike_units(substitution_units)
	else: _spend_action_cost(cost_type)
	for effect_result in result.get("results", []):
		hud.add_log(effect_result.get("message", ""))
	hud.update_hud(active_character, tracker)
	_highlight_reachable()


func _execute_goodberry() -> void:
	if not _can_spend_action_cost("bonus_action"):
		hud.add_log("You have no Bonus Action available to eat a Goodberry.")
		return
	if not SpellEffects.consume_goodberry_from_party(_spell_casters()):
		hud.add_log("No Goodberries remain.")
		return
	var restored := active_character.heal(1)
	_spend_action_cost("bonus_action")
	hud.add_log("%s eats a Goodberry and regains %d Hit Point%s (%d remaining in the party)." % [active_character.character_name, restored, "" if restored == 1 else "s", SpellEffects.goodberry_count_for_party(_spell_casters())])
	hud.update_hud(active_character, tracker)
	_highlight_reachable()


## Bonus movement is a separate, immediate selection, never normal movement
## or a whole-turn Disengage. Cancel forfeits only this optional movement.
func _fighter_entity(actor: Character) -> Dictionary:
	for entity in player_entities:
		if entity.get("character") == actor:
			return entity
	return {}


func _fighter_movement_choices(actor: Character, toward: Variant = null) -> Dictionary:
	var entity := _fighter_entity(actor)
	if entity.is_empty():
		return {}
	var origin: Vector2i = entity["hex_position"]
	var maximum := float(actor.get_speed()) / 2.0
	if toward != null:
		var straight_choices := {}
		var spent := 0.0
		for hex in HexUtils.hex_line(origin, toward):
			if hex == origin:
				continue
			spent += hex_grid.get_hex_cost(hex)
			if spent > maximum or not hex_grid.is_hex_passable(hex) or _fighter_hex_occupied(hex):
				break
			straight_choices[hex] = spent
		return straight_choices
	var choices := HexUtils.get_reachable(origin, maximum, func(hex: Vector2i): return hex_grid.is_hex_passable(hex) and (hex == origin or not _fighter_hex_occupied(hex)), hex_grid.get_hex_cost)
	choices.erase(origin)
	return choices


func _offer_fighter_movement(label: String, actor: Character = null, toward: Variant = null) -> void:
	if actor == null:
		actor = active_character
	var entity := _fighter_entity(actor)
	if entity.is_empty():
		return
	var choices := _fighter_movement_choices(actor, toward)
	if choices.is_empty():
		return
	var detail := "Move up to half Speed%s without Opportunity Attacks. Normal movement is preserved." % (" straight toward the target" if toward != null else "")
	if not await hud.request_reaction(_owner_label_for_character(actor), "fighter_movement", detail, "Use %s movement?" % label, "Choose Destination", label):
		return
	fighter_move_choices = choices
	fighter_move_entity = entity
	fighter_move_done = false
	fighter_move_waiting = true
	var highlights := {}
	for hex in choices:
		highlights[hex] = HexHighlight.HIGHLIGHT_COLORS[HexHighlight.HighlightType.MOVEMENT]
	hex_grid.set_highlights(highlights)
	hud.add_log("%s: choose a highlighted destination, or Cancel." % label)
	while not fighter_move_done and not _battle_ending:
		await get_tree().process_frame
	fighter_move_waiting = false
	fighter_move_choices.clear()
	fighter_move_entity = {}
	_update_grid_entities()


func _collect_attack_inspiration_decision(actor: Character) -> Dictionary:
	if not BardicInspirationRules.has_die(actor):
		return {}
	var die := str(actor.feature_uses["bardic_inspiration_die"])
	var accepted := await hud.request_reaction(_owner_label_for_character(actor), "bardic_inspiration", "If this attack fails, add %s. A successful attack keeps the die." % die, "Use Bardic Inspiration if the attack fails?", "Use Inspiration", "Bardic Inspiration — %s" % _owner_label_for_character(actor))
	return {"bardic_inspiration_attack": accepted}


func _offer_power_word_heal_stand(target, spell: Dictionary) -> void:
	if str(spell.get("id", "")) != "power_word_heal" or not CombatAction.has_condition(target, "prone") or CombatAction.is_incapacitated(target):
		return
	if target is Character:
		if target.reaction_available and await hud.request_reaction(_owner_label_for_character(target), "power_word_heal_stand", "Power Word Heal lets you spend your Reaction to stand from Prone.", "Stand up?", "Stand up", "Power Word Heal — %s" % _owner_label_for_character(target)):
			CombatAction.stand_after_power_word_heal(target)
	elif target is Dictionary:
		# NPCs accept the benefit if their Reaction is still available.
		CombatAction.stand_after_power_word_heal(target)


func _request_brutal_strike(actor: Character, weapon: Dictionary, disadvantage: bool = false) -> Array[String]:
	if not BarbarianRules.brutal_strike_eligible(actor, weapon, disadvantage):
		return []
	var detail := "Trade Advantage on this Strength attack for %s extra damage and a Brutal Strike effect." % BarbarianRules.brutal_strike_dice(actor)
	if not await hud.request_reaction(_owner_label_for_character(actor), "brutal_strike", detail, "Use Brutal Strike?", "Brutal Strike", "Brutal Strike — %s" % _owner_label_for_character(actor)):
		return []
	return await hud.request_barbarian_brutal_strike(actor)


func _finish_fighter_attack(target: Dictionary, weapon: Dictionary, result: Dictionary, actor: Character = null) -> void:
	if actor == null:
		actor = active_character
	if actor == null:
		return
	await _offer_weapon_damage_riders(actor, target, weapon, result)
	var entity := _fighter_entity(actor)
	if entity.is_empty():
		return
	var barbarian_effects: Dictionary = result.get("barbarian_brutal_strike", {})
	if result.get("hit", false) and not barbarian_effects.is_empty() and int(target.get("current_hp", 0)) > 0:
		if int(barbarian_effects.get("push_distance", 0)) > 0:
			await _push_combat_target(target, entity["hex_position"], int(barbarian_effects["push_distance"]), false)
		if bool(barbarian_effects.get("move_after_push", false)):
			await _offer_fighter_movement("Forceful Blow", actor, target["hex_position"])
	if result.get("crit", false) and actor.has_feature("champion_remarkable_athlete"):
		await _offer_fighter_movement("Remarkable Athlete", actor)
	if result.get("hit", false) and result.get("mastery", "") == "push" and int(target.get("current_hp", 0)) > 0:
		await _push_combat_target(target, entity["hex_position"])
	if result.get("hit", false) and result.get("mastery", "") == "cleave" and not actor.feature_uses.get("fighter_cleave_used", false):
		var origin: Vector2i = entity["hex_position"]
		for other in monster_entities:
			if other == target or not other.get("is_alive", false):
				continue
			if HexUtils.get_distance(target["hex_position"], other["hex_position"]) > 1 or not Targeting.is_in_range(origin, other["hex_position"], int(weapon.get("range", 1))):
				continue
			if await hud.request_reaction(_owner_label_for_character(actor), "cleave", "Make one extra attack against %s, without a positive ability damage bonus." % other["name"], "Use Cleave?", "Attack", "Cleave"):
				actor.feature_uses["fighter_cleave_used"] = true
				var cleave_weapon := weapon.duplicate(true)
				cleave_weapon["cleave_extra"] = true
				cleave_weapon["attack_distance"] = HexUtils.get_distance(origin, other["hex_position"])
				var cleave_effects := await _request_brutal_strike(actor, cleave_weapon)
				var cleave_decisions := await _collect_attack_inspiration_decision(actor)
				if not cleave_effects.is_empty():
					cleave_decisions["barbarian_brutal_strike_effects"] = cleave_effects
				var cleave_packet := await _conjure_minor_elementals_damage_choice(actor, other)
				var cleave_additional_damage := {"packets": [cleave_packet]} if not cleave_packet.is_empty() else {}
				var cleave := CombatAction.resolve_weapon_attack(actor, other, cleave_weapon, false, false, cleave_decisions, cleave_additional_damage)
				await _offer_divine_smite(other, cleave_weapon, cleave, actor)
				await _offer_weapon_damage_riders(actor, other, cleave_weapon, cleave)
				await _offer_sneak_attack(other, cleave_weapon, cleave, actor)
				hud.add_log("Cleave: %s" % cleave.get("message", ""), false)
				_publish_fighter_extra_attack(other, cleave_weapon, cleave, actor)
				await _finish_fighter_attack(other, cleave_weapon, cleave, actor)
				_mark_fighter_target_defeated(other)
				break


func _push_combat_target(target, origin: Vector2i, distance: int = 2, size_limited: bool = true) -> int:
	var entity: Dictionary = _fighter_entity(target) if target is Character else target
	if entity.is_empty(): return 0
	if size_limited and str(entity.get("size", "medium")).to_lower() in ["huge", "gargantuan", "h", "g"]: return 0
	var start: Vector2i = entity["hex_position"]
	var blocked := _spell_push_blocked_hexes(target if target is Character else null, {} if target is Character else target)
	var pushed_to := Targeting.get_pushed_position(start, origin, distance, hex_grid, blocked)
	var path := HexUtils.hex_line(start, pushed_to)
	for step in range(1, path.size()):
		var from_hex: Vector2i = path[step - 1]
		var to_hex: Vector2i = path[step]
		if _spell_zones()._antilife_shell_blocks_crossing(target, from_hex, to_hex):
			hud.add_log("Antilife Shell prevents crossing its barrier.")
			break
		# Batch 066 (S-121/S-122): forced movement stops before a step whose full
		# size-based footprint is not a legal space (PlacementRules).
		var pushed_actor = target if target is Character else entity
		var pushed_size := PhysicalFactsRules.get_size(target) if target is Character else str(entity.get("size", "medium")).to_lower()
		# A body that already overlaps something at its start (legacy placement)
		# is not trapped by that pre-existing overlap; only a legal start is held to it.
		# Review 066 R1: an illegal start still never enters terrain the footprint cannot occupy.
		if TravelPlacementRules.forced_step_blocked(self, from_hex, to_hex, pushed_size, pushed_actor):
			break
		entity["hex_position"] = to_hex
		if target is Character:
			await _apply_room_fall_damage(target, from_hex, to_hex)
		else:
			_apply_forced_movement_fall_damage(target, from_hex, to_hex)
		if (target is Character and not target.is_alive) or (target is Dictionary and not bool(target.get("is_alive", true))): break
		await _resolve_spell_zone_entries(target, from_hex, to_hex)
		await _resolve_spell_zone_movement(target, to_hex)
		if (target is Character and not target.is_alive) or (target is Dictionary and not bool(target.get("is_alive", true))): break
	_update_grid_entities()
	return HexUtils.get_distance(start, entity["hex_position"]) * 5


func _apply_forced_movement_fall_damage(target: Dictionary, from_hex: Vector2i, to_hex: Vector2i) -> void:
	var room := LocalRoomCombat.room()
	if room.is_empty():
		return
	var drop_feet := LocalRoomRules.elevation_feet(room, from_hex) - LocalRoomRules.elevation_feet(room, to_hex)
	if drop_feet < 10 or int(target.get("fly_speed_feet", 0)) > 0:
		return
	var damage := 0
	for _die in LocalRoomRules.fall_dice_for_drop(drop_feet):
		damage += Dice.roll(6)
	target["current_hp"] = maxi(0, int(target.get("current_hp", 0)) - damage)
	hud.add_log("%s is pushed %d feet down and takes %d falling damage." % [target.get("name", "The creature"), drop_feet, damage])
	if int(target["current_hp"]) <= 0 and bool(target.get("is_alive", true)):
		target["is_alive"] = false
		tracker.remove_combatant(str(target.get("id", "")))
		_trigger_enemy_defeat_features(target)
		_check_battle_end_conditions()


func _spell_push_blocked_hexes(excluded_player: Character, excluded_monster: Dictionary) -> Array[Vector2i]:
	var occupied: Array[Vector2i] = []
	for entity in player_entities:
		var character: Character = entity.get("character")
		if character != null and character != excluded_player and character.is_alive:
			occupied.append(entity.get("hex_position", Vector2i.ZERO))
	for entity in monster_entities:
		if entity != excluded_monster and entity.get("is_alive", false):
			occupied.append(entity.get("hex_position", Vector2i.ZERO))
	return occupied


func _fighter_hex_occupied(hex: Vector2i) -> bool:
	for entity in player_entities:
		if entity["hex_position"] == hex:
			return true
	for entity in monster_entities:
		if entity.get("is_alive", false) and entity["hex_position"] == hex:
			return true
	return false


func _offer_light_attack(target: Dictionary) -> void:
	if light_attack_weapon.is_empty() or active_character.feature_uses.get("fighter_light_used", false):
		return
	var offhand_id := active_character.inventory.get_equipped(Inventory.Slot.OFFHAND)
	var weapon := DataLoader.get_item(offhand_id).duplicate(true)
	if "light" not in weapon.get("properties", []):
		return
	var nick := FighterRules.mastery(active_character, weapon) == "nick"
	if not nick and not turn_budget.bonus_action_available:
		return
	var origin: Vector2i = player_entities[current_player_idx]["hex_position"]
	var candidates: Array = [target]
	for monster in monster_entities:
		if monster != target:
			candidates.append(monster)
	for candidate in candidates:
		if not candidate.get("is_alive", false) or not Targeting.is_in_range(origin, candidate["hex_position"], int(weapon.get("range", 1))):
			continue
		if not await hud.request_reaction(_owner_label_for_character(active_character), "light_attack", "Attack %s with %s (%s). Once this turn." % [candidate.get("name", "target"), weapon.get("name", offhand_id), "part of the Attack action — Nick" if nick else "Bonus Action"], "Make the extra Light attack?", "Attack", "Light Weapon"):
			continue
		active_character.feature_uses["fighter_light_used"] = true
		if not nick:
			_spend_action_cost("bonus_action")
		weapon["light_extra"] = true
		weapon["attack_distance"] = HexUtils.get_distance(origin, candidate["hex_position"])
		var light_effects := await _request_brutal_strike(active_character, weapon)
		var light_decisions := await _collect_attack_inspiration_decision(active_character)
		if not light_effects.is_empty():
			light_decisions["barbarian_brutal_strike_effects"] = light_effects
		var light_packet := await _conjure_minor_elementals_damage_choice(active_character, candidate)
		var light_additional_damage := {"packets": [light_packet]} if not light_packet.is_empty() else {}
		var result := CombatAction.resolve_weapon_attack(active_character, candidate, weapon, false, false, light_decisions, light_additional_damage)
		await _offer_divine_smite(candidate, weapon, result)
		await _offer_sneak_attack(candidate, weapon, result)
		hud.add_log(result.get("message", ""), false)
		await _finish_fighter_attack(candidate, weapon, result)
		_publish_fighter_extra_attack(candidate, weapon, result)
		_mark_fighter_target_defeated(candidate)
		hud.update_hud(active_character, tracker)
		return


func _publish_fighter_extra_attack(target: Dictionary, weapon: Dictionary, result: Dictionary, actor: Character = null) -> void:
	if actor == null:
		actor = active_character
	var draft := CombatActivityRecordModel.attack_action(actor, target, weapon, [result], str(GameManager.active_campaign.get("id", "")), tracker.current_round)
	if not draft.is_empty():
		ActivityHistory.publish(draft)


func _publish_true_strike_activity(target: Dictionary, weapon: Dictionary, result: Dictionary) -> void:
	var settled_attacks: Array[Dictionary] = [result]
	var draft := CombatActivityRecordModel.attack_action(active_character, target, weapon, settled_attacks, str(GameManager.active_campaign.get("id", "")), tracker.current_round)
	if draft.is_empty():
		return
	draft["kind"] = "spell_attack"
	draft["title"] = "True Strike — " + str(weapon.get("name", "Weapon"))
	ActivityHistory.publish(draft)


func _mark_fighter_target_defeated(target: Dictionary) -> void:
	if int(target.get("current_hp", 0)) <= 0:
		target["is_alive"] = false
		for combatant in tracker.combatants:
			if str(combatant.get("id", "")) == str(target.get("id", "")):
				tracker.remove_combatant(str(target.get("id", "")))
				hud.add_log("%s was defeated!" % target.get("name", "Target"))
				break
		_trigger_enemy_defeat_features(target, active_character)


func _trigger_enemy_defeat_features(defeated_target: Dictionary, killer_character: Character = null) -> void:
	if defeated_target.is_empty():
		return
	var target_pos: Vector2i = defeated_target.get("hex_position", Vector2i.ZERO)
	for p_entity in player_entities:
		var c: Character = p_entity.get("character")
		if c == null or not c.has_feature("fiend_dark_ones_blessing") or not c.is_alive:
			continue
		var dist_feet := HexUtils.get_distance(p_entity.get("hex_position", Vector2i.ZERO), target_pos) * 5
		if c == killer_character or dist_feet <= 10:
			var gained := WarlockRules.apply_dark_ones_blessing(c)
			if gained > 0:
				hud.add_log("[color=purple]%s gains %d temporary Hit Points from Dark One's Blessing.[/color]" % [c.character_name, gained])


func _action_cost_for_command(action_type: String, extra_data: Dictionary) -> String:
	if action_type == "use_item": return str(DataLoader.get_item(str(extra_data.get("item", {}).get("id", ""))).get("action_cost", "action"))
	if action_type == "toggle_find_steed_mount":
		return "free"
	if action_type == "activate_magic_item":
		return "magic_action"
	if action_type in ["control_mage_hand", "dismiss_mage_hand"]:
		return "magic_action"
	if action_type == "dismiss_light":
		return "action"
	if action_type == "detect_magic_inspect":
		return "magic_action"
	if action_type == "font_of_magic_create":
		return "bonus_action"
	if action_type == "move_dancing_lights":
		return "bonus_action"
	if action_type == "move_moonbeam":
		return "magic_action"
	if action_type == "move_conjure_fey":
		return "bonus_action"
	if action_type == "use_feature":
		for effect in extra_data.get("feature", {}).get("effects", []):
			if effect.get("type", "") == "resource_from_spell_slot":
				return "free"
			if effect.get("type", "") == "damage_ward_pool" and bool(effect.get("bonus_action_slot_recharge", false)):
				return "bonus_action"
		return str(extra_data.get("feature", {}).get("action_cost", "action"))
	if action_type == "cast_spell":
		var spell_cost := str(extra_data.get("spell", {}).get("casting_time", "action"))
		return "bonus_action" if spell_cost == "bonus_action" else "magic_action"
	if action_type in ["attack", "dodge"]:
		return "action"
	return "free"


## Batch 057: a mode act's declared cost can be paid now from the plain turn budget
## (not mid-cast or mid attack substitution, where _spend_action_cost means something else).
func can_pay_mode_cost(cost_type: String) -> bool:
	return child_actions.frame.is_empty() and attack_unit_substitution.is_empty() and not _cast_in_progress and _can_spend_action_cost(cost_type)


func _can_spend_action_cost(cost_type: String) -> bool:
	return turn_budget.can_spend(cost_type)


func _reset_turn_action_economy() -> void:
	child_actions.clear()
	remaining_flurry_swings = 0
	strike_unit_parent = "attack"
	attack_unit_substitution = {}
	turn_budget.reset(active_character, player_entities)
	player_moved_this_turn = false
	extra_movement_speed_hexes = 0.0
	_movement_speed_shortfall = 0.0
	_movement_speed_owner = active_character
	_movement_speed_snapshot = _active_movement_speed_hexes()
	rogue_steady_aim_armed = false
	if active_character != null:
		active_character.feature_uses.erase("conjure_animals_moved_this_turn")
		active_character.feature_uses.erase("conjure_animals_pack_moved_this_turn")
		active_character.feature_uses.erase("conjure_celestial_moved_this_turn")
		active_character.feature_uses.erase("conjure_celestial_pillar_moved_this_turn")


func _spend_action_cost(cost_type: String, invocation_id: String = "") -> bool:
	if child_actions.current("cast"):
		if cost_type != "magic_action" or invocation_id != str(child_actions.frame.get("cast_invocation", "")): return false
		return child_actions.settle(self)
	if not attack_unit_substitution.is_empty():
		if cost_type != "magic_action" or invocation_id.is_empty() or invocation_id != str(attack_unit_substitution.get("invocation_id", "")) or attack_unit_substitution.get("actor") != active_character or bool(attack_unit_substitution.get("settled", false)) or _remaining_strike_units() < int(attack_unit_substitution.get("units", 0)):
			return false
		_consume_strike_units(int(attack_unit_substitution["units"]))
		attack_unit_substitution["settled"] = true
		return true
	var spent := turn_budget.spend(cost_type)
	if spent and cost_type in ["action", "magic_action", "bonus_action"] and active_character != null:
		action_history.record_action(active_character)
	return spent


func _attack_unit_substitution_units(spell: Dictionary) -> int:
	var authoritative := DataLoader.get_spell(str(spell.get("id", "")))
	return CombatChildActions.units(authoritative) if authoritative.get("execution") == "shared" and authoritative.get("casting_time", "action") == "action" else 0

## Batch 070 (S-084/S-085): after an attack_count alternative switches or its
## source leaves mid-action, spent swings stay spent and no swing is refunded or
## added: remaining = min(remaining, new total - spent).
func reclamp_attack_units() -> void:
	if remaining_attack_swings <= 0 or attack_action_total <= 0 or active_character == null: return
	var spent := attack_action_total - remaining_attack_swings
	var total := 1 + RuleUpgradeRules.extra_attacks(active_character) if attack_action_total > 1 else 1
	remaining_attack_swings = mini(remaining_attack_swings, maxi(0, total - spent))
	attack_action_total = spent + remaining_attack_swings

func _remaining_strike_units() -> int:
	return remaining_flurry_swings if strike_unit_parent == "flurry" else remaining_attack_swings

func _consume_strike_units(count: int) -> void:
	if strike_unit_parent == "flurry": remaining_flurry_swings -= count
	else: remaining_attack_swings -= count

func _has_attack_substitutions() -> bool:
	for id in SpellPermissionRules.spell_ids(active_character):
		if _attack_unit_substitution_units(DataLoader.get_spell(id)) > 0: return true
	for feature in active_character.features:
		if CombatChildActions.units(feature) > 0: return true
	for item in active_character.inventory.backpack_instances():
		if CombatChildActions.units(DataLoader.get_item(str(item.definition_id))) > 0: return true
	return false


func _offer_divine_smite(target, weapon: Dictionary, result: Dictionary, actor: Character = null) -> void:
	if actor == null:
		actor = active_character
	if result.has("divine_smite") or actor != active_character or _battle_ending or not turn_budget.can_spend("bonus_action") or not result.get("hit", false):
		return
	var spell := DataLoader.get_spell("divine_smite")
	if not bool(result.get("can_divine_smite", false)):
		var properties: Array = weapon.get("properties", [])
		var melee := str(weapon.get("id", "")) == "unarmed_strike" or (str(weapon.get("type", "")) == "weapon" and "ranged" not in properties and "ammunition" not in properties)
		var target_hp: int = target.current_hp if target is Character else int(target.get("current_hp", 0))
		if not melee or target_hp <= 0 or not actor.has_feature("paladin_paladins_smite") or CombatAction.is_incapacitated(actor) or actor.has_condition("raging") or not DruidRules.can_cast_spell(actor, spell):
			return
		if not actor.has_free_spell_cast("divine_smite") and CombatAction.get_spell_slot_level(actor, spell) <= 0:
			return
	var target_name: String = target.character_name if target is Character else str(target.get("name", "Target"))
	var choice := await hud.request_divine_smite(actor, _owner_label_for_character(actor), target_name)
	if choice.is_empty() or actor != active_character or not turn_budget.can_spend("bonus_action") or _battle_ending:
		return
	var origin: Vector2i = player_entities[current_player_idx]["hex_position"]
	var reactions := await _collect_counterspell_decisions(actor, spell, origin, actor)
	var smite := CombatAction.resolve_divine_smite(actor, target, int(choice["slot_level"]), bool(choice["free_cast"]), bool(result.get("crit", false)), reactions.get("decisions", {}), reactions.get("observers", []))
	if smite.get("cast_committed", false):
		_spend_action_cost("bonus_action")
	if smite.get("success", false):
		var added := int(smite.get("damage", 0))
		result["damage"] = int(result.get("damage", 0)) + added
		var detail: Dictionary = result.get("activity_damage", {})
		for term in smite.get("activity_damage", {}).get("dice_terms", []):
			var labeled: Dictionary = term.duplicate(true)
			labeled["label"] = "Divine Smite — " + str(labeled.get("label", "d8"))
			detail.get("dice_terms", []).append(labeled)
		for field in ["rolled_total", "resolved_total", "applied"]:
			detail[field] = int(detail.get(field, 0)) + int(smite.get("activity_damage", {}).get(field, added))
		detail["final_total"] = detail["rolled_total"]
		detail.get_or_add("mitigation", []).append_array(smite.get("activity_damage", {}).get("mitigation", []))
		result["damage_components"].append({"label": "Divine Smite", "value": added, "type": "radiant", "formula": smite.get("damage_formula", "")})
		if added > 0:
			ClericRules.clear_turning_after_damage(target)
	result["message"] = str(result.get("message", "")) + " " + str(smite.get("message", ""))
	hud.update_hud(actor, tracker)
	_update_grid_entities()


func _offer_sneak_attack(target: Dictionary, weapon: Dictionary, result: Dictionary, actor: Character = null, has_advantage: bool = false, has_disadvantage: bool = false) -> void:
	if actor == null:
		actor = active_character
	# Use the resolver's final attack context, including conditions and cancellations.
	has_advantage = bool(result.get("activity_roll", {}).get("advantage", has_advantage))
	has_disadvantage = bool(result.get("activity_roll", {}).get("disadvantage", has_disadvantage))
	if result.get("hit", false) and _is_sneak_attack_valid(actor, target["hex_position"], has_advantage, has_disadvantage, weapon):
		actor.feature_uses["sneak_attack_used_this_turn"] = 1
		var full_sa_dice := _get_sneak_attack_dice(actor)
		var available_sa_dice := int(full_sa_dice.split("d")[0])
		var cunning_options: Array[String] = []
		if actor.level >= 5:
			cunning_options = await hud.request_rogue_cunning_strike(actor, target, available_sa_dice)
		var remaining_sa_dice := RogueRules.remaining_sneak_attack_dice(available_sa_dice, cunning_options)
		var sa_damage := 0
		var sa_dice := "%dd6" % remaining_sa_dice
		if remaining_sa_dice > 0:
			sa_damage = Dice.parse_dice_string(sa_dice)
			if result.get("crit", false):
				# Critical hits double only the Sneak Attack dice not traded away.
				sa_damage += Dice.parse_dice_string(sa_dice)
		var sa_type := str(result.get("damage_type", ""))
		var bypass := ClassProgression.has_epic_boon(actor, "irresistible_offense") and sa_type in ["bludgeoning", "piercing", "slashing"]
		var actual_sa_dealt := int(CombatAction.resolve_damage(target, sa_damage, sa_type, {}, bypass)["damage"]) if sa_damage > 0 else 0
		result["damage"] = int(result.get("damage", 0)) + actual_sa_dealt
		if actual_sa_dealt > 0:
			result.get_or_add("damage_components", []).append({"label": "Sneak Attack", "value": actual_sa_dealt, "type": sa_type, "formula": sa_dice})
		result["message"] += " [color=orange]Sneak Attack! Deals +%d damage (%s).[/color]" % [actual_sa_dealt, sa_dice]
		for cunning_option in cunning_options:
			match cunning_option:
				"poison", "trip", "daze", "knock_out", "obscure":
					var save_ability := RogueRules.cunning_strike_save_ability(cunning_option)
					var save_dc := RogueRules.saving_throw_dc(actor)
					var save_total := BarbarianRules.roll_monster_save(target, save_ability)
					var condition: String = {"poison": "poisoned", "trip": "prone", "daze": "dazed", "knock_out": "unconscious", "obscure": "blinded"}.get(cunning_option, "")
					if save_total < save_dc:
						var source := ""
						var duration := 1
						match cunning_option:
							"poison":
								source = "rogue_cunning_poison"
								duration = 10
							"daze":
								source = RogueRules.CUNNING_DAZE_SOURCE
							"knock_out":
								source = RogueRules.CUNNING_KNOCKOUT_SOURCE
								duration = 10
							"obscure":
								source = RogueRules.CUNNING_OBSCURE_SOURCE
						CombatAction.apply_condition(target, condition, duration, source)
						if cunning_option == "poison" and CombatAction.has_condition_source(target, source):
							target["rogue_cunning_poison_dc"] = save_dc
						elif cunning_option == "knock_out" and CombatAction.has_condition_source(target, source):
							target["rogue_cunning_knock_out_dc"] = save_dc
						if not condition.is_empty() and condition in target.get("condition_immunities", []):
							result["message"] += " %s is immune to Cunning Strike %s." % [target.get("name", "Target"), cunning_option.replace("_", " ").capitalize()]
						else:
							result["message"] += " [color=orange]Cunning Strike %s: %s failed %s save (DC %d).[/color]" % [cunning_option.replace("_", " ").capitalize(), target.get("name", "Target"), save_ability, save_dc]
					else:
						result["message"] += " Cunning Strike %s: target succeeds on %s save (DC %d)." % [cunning_option.replace("_", " ").capitalize(), save_ability, save_dc]
				"withdraw":
					var withdraw_distance: float = floor(float(actor.get_speed()) / 2.0)
					await _offer_fighter_movement("Cunning Strike Withdraw", actor)
					result["message"] += " [color=orange]Cunning Strike Withdraw: move up to %d feet of movement without provoking Opportunity Attacks.[/color]" % int(withdraw_distance * 5.0)
		actor.feature_uses["sneak_attack_used_this_turn"] = 1


func _is_sneak_attack_valid(attacker: Character, target_coord: Vector2i, has_advantage: bool, has_disadvantage: bool = false, weapon: Dictionary = {}) -> bool:
	var has_ally_adjacent := false
	for p in player_entities:
		var ally: Character = p["character"]
		if ally != attacker and ally.is_alive and not CombatAction.is_incapacitated(ally) and HexUtils.get_distance(p["hex_position"], target_coord) == 1:
			has_ally_adjacent = true
			break
	return RogueRules.sneak_attack_eligible(attacker, weapon if not weapon.is_empty() else DataLoader.get_item(attacker.inventory.get_weapon()), has_advantage, has_disadvantage, has_ally_adjacent)


func _get_sneak_attack_dice(attacker: Character) -> String:
	var dice := "1d6"
	for f in attacker.features:
		for eff in attacker._feature_effects(f):
			if eff.get("type", "") not in ["sneak_attack", "sneak_attack_upgrade"]:
				continue
			var progression: Dictionary = eff.get("dice_by_level", {})
			var threshold := 0
			for key in progression:
				if int(key) <= attacker.level and int(key) > threshold:
					threshold = int(key)
			dice = str(progression[str(threshold)]) if threshold > 0 else str(eff.get("dice", dice))
	return dice


func _tick_dancing_lights_duration(caster: Character) -> void:
	SpellCastMarkers._tick_dancing_lights_duration(_spell_cast_context(), caster)


func _tick_light_spell_duration(caster: Character) -> void:
	SpellCastMarkers._tick_light_spell_duration(_spell_cast_context(), caster)


func _tick_mage_hand_duration(caster: Character) -> void:
	SpellCastMarkers._tick_mage_hand_duration(_spell_cast_context(), caster)


func _tick_minor_illusion_duration(caster: Character) -> void:
	SpellCastMarkers._tick_minor_illusion_duration(_spell_cast_context(), caster)


func _tick_prestidigitation_effects(caster: Character) -> void:
	SpellCastMarkers._tick_prestidigitation_effects(_spell_cast_context(), caster)


func _tick_produce_flame_duration(caster: Character) -> void:
	SpellCastMarkers._tick_produce_flame_duration(_spell_cast_context(), caster)


func _tick_protection_from_energy_duration(caster: Character) -> void:
	SpellEncounterLifecycle._tick_protection_from_energy_duration(_spell_cast_context(), caster)


func _tick_protection_from_evil_and_good_duration(caster: Character) -> void:
	SpellEncounterLifecycle._tick_protection_from_evil_and_good_duration(_spell_cast_context(), caster)


func _tick_ray_of_enfeeblement_duration(caster: Character) -> void:
	SpellEncounterLifecycle._tick_ray_of_enfeeblement_duration(_spell_cast_context(), caster)


func _tick_resilient_sphere_duration(caster: Character) -> void:
	SpellEncounterLifecycle._tick_resilient_sphere_duration(_spell_cast_context(), caster)


func _tick_hold_monster_duration(caster: Character) -> void:
	SpellEncounterLifecycle._tick_hold_monster_duration(_spell_cast_context(), caster)


func _apply_regenerate_turn_start(target) -> void:
	SpellEncounterLifecycle._apply_regenerate_turn_start(_spell_cast_context(), target)


func _tick_spell_effect_boundary(caster: Character, phase: String) -> void:
	SpellEncounterLifecycle._tick_spell_effect_boundary(_spell_cast_context(), caster, phase)


func _identify_target_remains_touchable(caster: Character, identify_target: Dictionary) -> bool:
	return SpellEncounterPerception._identify_target_remains_touchable(_spell_cast_context(), caster, identify_target)


func _validate_identify_contacts() -> void:
	SpellEncounterPerception._validate_identify_contacts(_spell_cast_context())


func _complete_identify(caster: Character, identify_record: Dictionary) -> void:
	SpellEncounterPerception._complete_identify(_spell_cast_context(), caster, identify_record)

func _spell_effect_targets() -> Array:
	return _spell_zones()._spell_effect_targets()

func _spell_casters() -> Array:
	return player_entities.map(func(player): return player.get("character")).filter(func(caster): return caster != null)

func _resolve_condition_spell_repeat_saves(target) -> void:
	SpellEncounterLifecycle._resolve_condition_spell_repeat_saves(_spell_cast_context(), target)


func _spell_zones() -> CombatSpellZones:
	# Entity arrays can be replaced during setup; bind the current encounter views.
	_area_spells.bind_encounter(hex_grid, hud, tracker, player_entities, monster_entities)
	_area_spells.light_spell_markers = light_spell_markers
	_area_spells.produce_flame_markers = produce_flame_markers
	_area_spells.dancing_light_sets = dancing_light_sets
	_area_spells.collect_save_decisions = _collect_zone_save_decisions
	_area_spells.collect_attack_decision = _collect_attack_inspiration_decision
	_area_spells.collect_shield_decision = _collect_spell_shield_decision
	_area_spells.check_concentration = _check_concentration_save
	_area_spells.end_concentration = _end_concentration
	_area_spells.enemy_defeated = _trigger_enemy_defeat_features
	_area_spells.refresh_grid = _update_grid_entities
	_area_spells.highlight_reachable = _highlight_reachable
	return _area_spells


func _collect_zone_save_decisions(target, label: String, spell_data: Dictionary) -> Dictionary:
	var decisions: Dictionary = {}
	if target is Character:
		decisions.merge(await _collect_stroke_of_luck_save_decision(target, label), true)
		decisions.merge(await _collect_bardic_inspiration_save_decision(target, spell_data), true)
	return decisions


func _create_grease_zone(center: Vector2i) -> void:
	SpellZoneTerrain._create_grease_zone(_spell_zones(), active_character, center)


func _create_spike_growth_zone(center: Vector2i, slot_level: int) -> void:
	SpellZoneTerrain._create_spike_growth_zone(_spell_zones(), active_character, center, slot_level)


func _create_entangle_zone(center: Vector2i, source_id: String, restrained_targets: Array) -> void:
	SpellZoneTerrain._create_entangle_zone(_spell_zones(), active_character, center, source_id, restrained_targets)


func _apply_black_tentacles_restrained(target, source_id: String, restrained_targets: Array) -> void:
	SpellZoneTerrain._apply_black_tentacles_restrained(_spell_zones(), target, source_id, restrained_targets)


func _create_black_tentacles_zone(center: Vector2i, source_id: String, restrained_targets: Array, initial_targets: Array, slot_level: int) -> void:
	SpellZoneTerrain._create_black_tentacles_zone(_spell_zones(), active_character, pending_spell_data, center, source_id, restrained_targets, initial_targets, slot_level)


func _create_sleet_storm_zone(center: Vector2i, source_id: String, extended: bool) -> void:
	SpellZoneTerrain._create_sleet_storm_zone(_spell_zones(), active_character, center, source_id, extended)


func _create_plant_growth_zone(center: Vector2i) -> void:
	SpellZoneTerrain._create_plant_growth_zone(_spell_zones(), active_character, center)


func _current_spell_trigger_turn() -> String:
	return _spell_zones()._current_spell_trigger_turn()


func _spell_zone_target_id(target) -> String:
	return _spell_zones()._spell_zone_target_id(target)


func _spell_zone_target_hex(target) -> Vector2i:
	return _spell_zones()._spell_zone_target_hex(target)


func _has_spell_condition_source(target, source_id: String, condition: String = "restrained") -> bool:
	return _spell_zones()._has_spell_condition_source(target, source_id, condition)


func _spell_target_at_hex(target_hex: Vector2i):
	return _spell_zones()._spell_target_at_hex(target_hex)


func _cloud_of_daggers_zone_source_for_caster(caster: Character) -> String:
	return _spell_zones()._cloud_of_daggers_zone_source_for_caster(caster)


func _conjure_animals_zone_source_for_caster(caster: Character) -> String:
	return _spell_zones()._conjure_animals_zone_source_for_caster(caster)


func _create_conjure_animals_zone(center: Vector2i, source_id: String, slot_level: int) -> void:
	SpellZoneConjurations._create_conjure_animals_zone(_spell_zones(), active_character, center, source_id, slot_level)


func _refresh_conjure_animals_strength_advantage(caster: Character) -> void:
	_spell_zones()._refresh_conjure_animals_strength_advantage(caster)


func _highlight_conjure_animals_movement() -> void:
	var source_id := _conjure_animals_zone_source_for_caster(active_character)
	var zone: Dictionary = active_spell_zones.get(source_id, {})
	var center: Vector2i = zone.get("center", Vector2i.ZERO)
	var highlights := {}
	for candidate in hex_grid.tiles.keys():
		if Targeting.is_in_range(center, candidate, 6) and not _is_occupied_hex(candidate):
			highlights[candidate] = Color(0.52, 0.82, 0.62, 0.72)
	hex_grid.set_highlights(highlights)


func _conjure_celestial_zone_source_for_caster(caster: Character) -> String:
	return _spell_zones()._conjure_celestial_zone_source_for_caster(caster)


func _create_conjure_celestial_zone(center: Vector2i, source_id: String, slot_level: int, initial_targets: Dictionary) -> void:
	SpellZoneConjurations._create_conjure_celestial_zone(_spell_zones(), active_character, center, source_id, slot_level, initial_targets)


func _highlight_conjure_celestial_movement() -> void:
	var source_id := _conjure_celestial_zone_source_for_caster(active_character)
	var zone: Dictionary = active_spell_zones.get(source_id, {})
	var center: Vector2i = zone.get("center", Vector2i.ZERO)
	var highlights := {}
	for candidate in hex_grid.tiles.keys():
		if Targeting.is_in_range(center, candidate, 6):
			highlights[candidate] = Color(1.0, 0.9, 0.52, 0.74)
	hex_grid.set_highlights(highlights)


func _apply_conjure_celestial_healing(target, caster: Character, slot_level: int) -> int:
	return SpellZoneConjurations._apply_conjure_celestial_healing(_spell_zones(), target, caster, slot_level)


func _resolve_conjure_celestial_zone_trigger(target, zone: Dictionary) -> Dictionary:
	return await SpellZoneConjurations._resolve_conjure_celestial_zone_trigger(_spell_zones(), target, zone)


func _resolve_conjure_celestial_area_movement(zone: Dictionary, old_coords: Array, new_coords: Array) -> Array[Dictionary]:
	return await _spell_zones()._resolve_conjure_celestial_area_movement(zone, old_coords, new_coords)


func _conjure_elemental_zone_source_for_caster(caster: Character) -> String:
	return _spell_zones()._conjure_elemental_zone_source_for_caster(caster)


func _create_conjure_elemental_zone(center: Vector2i, source_id: String, slot_level: int, element: String, damage_type: String) -> void:
	SpellZoneConjurations._create_conjure_elemental_zone(_spell_zones(), active_character, center, source_id, slot_level, element, damage_type)


func _conjure_elemental_has_restrained_target(zone: Dictionary) -> bool:
	return SpellZoneConjurations._conjure_elemental_has_restrained_target(_spell_zones(), zone)


func _resolve_conjure_elemental_save(target, zone: Dictionary, repeat_save: bool = false) -> Dictionary:
	return await SpellZoneConjurations._resolve_conjure_elemental_save(_spell_zones(), target, zone, repeat_save)


func _is_unoccupied_conjure_fey_space(center: Vector2i) -> bool:
	return _spell_zones()._is_unoccupied_conjure_fey_space(center)


func _conjure_fey_zone_source_for_caster(caster: Character) -> String:
	return _spell_zones()._conjure_fey_zone_source_for_caster(caster)


func _create_conjure_fey_zone(center: Vector2i, source_id: String, slot_level: int) -> String:
	return SpellZoneConjurations._create_conjure_fey_zone(_spell_zones(), active_character, center, source_id, slot_level)


func _create_conjure_minor_elementals_zone(source_id: String, slot_level: int) -> String:
	return SpellZoneConjurations._create_conjure_minor_elementals_zone(_spell_zones(), active_character, source_id, slot_level)


func _conjure_minor_elementals_zone_source_for_caster(caster: Character) -> String:
	return _spell_zones()._conjure_minor_elementals_zone_source_for_caster(caster)


func _conjure_woodland_beings_zone_source_for_caster(caster: Character) -> String:
	return _spell_zones()._conjure_woodland_beings_zone_source_for_caster(caster)


func _create_conjure_woodland_beings_zone(source_id: String, slot_level: int) -> String:
	return SpellZoneConjurations._create_conjure_woodland_beings_zone(_spell_zones(), active_character, source_id, slot_level)


func _character_combat_hex(character: Character) -> Vector2i:
	return _spell_zones()._character_combat_hex(character)


func _spirit_guardians_zone_source_for_caster(caster: Character) -> String:
	return _spell_zones()._spirit_guardians_zone_source_for_caster(caster)


func _aura_of_life_zone_source_for_caster(caster: Character) -> String:
	return _spell_zones()._aura_of_life_zone_source_for_caster(caster)


func _create_aura_of_life_zone(source_id: String) -> String:
	return SpellZoneConjurations._create_aura_of_life_zone(_spell_zones(), active_character, source_id)


func _refresh_aura_of_life_protection() -> void:
	_spell_zones()._refresh_aura_of_life_protection()


func _aura_of_life_allows_hp_maximum(target: Character) -> bool:
	return _spell_zones()._aura_of_life_allows_hp_maximum(target)


func _create_spirit_guardians_zone(source_id: String, slot_level: int) -> String:
	return SpellZoneConjurations._create_spirit_guardians_zone(_spell_zones(), active_character, pending_spell_data, source_id, slot_level)


func _spirit_guardians_zone_affects_target(zone: Dictionary, target_id: String) -> bool:
	return SpellZoneConjurations._spirit_guardians_zone_affects_target(_spell_zones(), zone, target_id)


func _spirit_guardians_movement_slowed(target, coord: Vector2i) -> bool:
	return _spell_zones()._spirit_guardians_movement_slowed(target, coord)


func _resolve_spirit_guardians_zone_save(target, zone: Dictionary) -> Dictionary:
	return await SpellZoneConjurations._resolve_spirit_guardians_zone_save(_spell_zones(), target, zone)


func _resolve_spirit_guardians_area_movement(zone: Dictionary, old_center: Vector2i, new_center: Vector2i) -> Array[Dictionary]:
	return await _spell_zones()._resolve_spirit_guardians_area_movement(zone, old_center, new_center)


func _conjure_minor_elementals_applies_to_target(caster: Character, target) -> bool:
	return _spell_zones()._conjure_minor_elementals_applies_to_target(caster, target)


func _conjure_minor_elementals_damage_choice(caster: Character, target) -> Dictionary:
	return await SpellZoneConjurations._conjure_minor_elementals_damage_choice(_spell_zones(), caster, target)


func _conjure_minor_elementals_spell_attack_choices(caster: Character, target, spell_data: Dictionary) -> Array[Dictionary]:
	return await SpellZoneConjurations._conjure_minor_elementals_spell_attack_choices(_spell_zones(), caster, target, spell_data)


func _player_movement_cost(coord: Vector2i, character: Character) -> float:
	var ignores_difficult_terrain := (character != null and SpellEffects.has_spell(character, "freedom_of_movement")) or (active_movement_mode == "fly")
	var cost := hex_grid.get_hex_cost(coord, ignores_difficult_terrain)
	var room := LocalRoomCombat.room()
	var surface := _movement_surface_at(coord)
	if active_movement_mode == "fly":
		cost = 1.0
	elif LocalRoomRules.requires_surface_traversal(surface):
		cost = 1.0 + (1.0 if not ignores_difficult_terrain and hex_grid.is_difficult_terrain(coord) else 0.0)
	if not room.is_empty():
		if LocalRoomRules.has_wall(room, coord) and active_movement_mode == "climb":
			cost += float(LocalRoomRules.wall_height_feet(room, coord)) / 5.0
	if active_movement_mode == "climb" and character != null and character.movement_speed_feet("climb") <= 0 and not SpellEffects.has_spell(character, "spider_climb"):
		cost += 1.0
	if active_movement_mode == "swim" and character != null and character.movement_speed_feet("swim") <= 0 and not (character != null and SpellEffects.has_spell(character, "freedom_of_movement")):
		cost += 1.0
	if not ignores_difficult_terrain and _spirit_guardians_movement_slowed(character, coord):
		cost *= 2.0
	return cost


func _movement_surface_at(coord: Vector2i) -> String:
	var room := LocalRoomCombat.room()
	if not room.is_empty(): return LocalRoomRules.surface_at(room, coord)
	if hex_grid != null and hex_grid.has_tile(coord) and hex_grid.tiles[coord].terrain == HexTile.TerrainType.WATER: return "water"
	return "ground"


func _player_step_movement_cost(from_hex: Vector2i, to_hex: Vector2i, character: Character) -> float:
	if _spell_zones()._antilife_shell_blocks_crossing(character, from_hex, to_hex):
		return 9999.0
	var cost := _player_movement_cost(to_hex, character)
	var room := LocalRoomCombat.room()
	if not room.is_empty() and active_movement_mode == "walk":
		var rise_feet := LocalRoomRules.elevation_feet(room, to_hex) - LocalRoomRules.elevation_feet(room, from_hex)
		if rise_feet > 0:
			cost += float(rise_feet) / 5.0
	return cost


func _apply_room_fall_damage(target, from_hex: Vector2i, to_hex: Vector2i) -> bool:
	var room := LocalRoomCombat.room()
	if room.is_empty():
		return false
	var height_change := LocalRoomRules.elevation_feet(room, to_hex) - LocalRoomRules.elevation_feet(room, from_hex)
	if height_change > -10:
		return false
	var can_fly := active_movement_mode == "fly" if target is Character and target == active_character else int(target.get("fly_speed_feet", 0)) > 0 if target is Dictionary else false
	if can_fly:
		return false
	var dice_count := LocalRoomRules.fall_dice_for_drop(-height_change)
	var damage := 0
	for _die in dice_count:
		damage += Dice.roll(6, target if target is Character else null)
	if target is Character:
		target.take_damage(damage)
		hud.add_log("%s falls %d feet and takes %d damage." % [target.character_name, -height_change, damage])
		if damage > 0 and target.is_alive:
			await _check_concentration_save(target, damage)
		if not target.is_alive:
			_end_concentration(target)
			_check_battle_end_conditions()
			return true
	elif target is Dictionary:
		target["current_hp"] = maxi(0, int(target.get("current_hp", 0)) - damage)
		hud.add_log("%s falls %d feet and takes %d damage." % [target.get("name", "The creature"), -height_change, damage])
		if int(target["current_hp"]) <= 0 and bool(target.get("is_alive", true)):
			target["is_alive"] = false
			tracker.remove_combatant(str(target.get("id", "")))
			_trigger_enemy_defeat_features(target)
			_check_battle_end_conditions()
			return true
	return false


func _player_can_enter(coord: Vector2i, character: Character) -> bool:
	if hex_grid == null or not hex_grid.has_tile(coord): return false
	for player in player_entities:
		var occupant: Character = player.get("character")
		if player.get("hex_position") == coord and occupant != null and occupant != character and occupant.is_alive and not (bool(player.get("is_steed", false)) and player.get("steed_owner") == character): return false
	for monster in monster_entities:
		if monster.get("hex_position") == coord and monster.get("is_alive", false): return false
	for object in CombatObjectRules.all_at(hex_grid, coord):
		if object.get("fixed", false) or object.get("blocks_movement", false): return false
	var room := LocalRoomCombat.room()
	var surface := _movement_surface_at(coord)
	if character != null:
		var req := PhysicalFactsRules.check_surface_and_hand_requirements(character, active_movement_mode, surface)
		if not req.allowed:
			return false
	if room.is_empty():
		if bool(hex_grid.tiles[coord].custom_properties.get("blocks_movement", false)): return false
		if surface == "water": return active_movement_mode in ["fly", "swim"] or SpellEffects.has_spell(character, "water_walk") or character.has_condition("water_walk")
		return hex_grid.is_hex_passable(coord)
	var current_position: Vector2i = player_entities[current_player_idx].get("hex_position", Vector2i.ZERO)
	var current_altitude := int(player_entities[current_player_idx].get("altitude_feet", LocalRoomRules.elevation_feet(room, current_position)))
	if active_movement_mode != "fly" and current_altitude > LocalRoomRules.elevation_feet(room, current_position):
		return false
	if LocalRoomRules.requires_surface_traversal(surface):
		var can_surface_traverse := active_movement_mode == "fly" or (surface == "water" and active_movement_mode == "swim") or SpellEffects.has_spell(character, "water_walk")
		if not can_surface_traverse: return false
	if LocalRoomRules.has_wall(room, coord):
		if active_movement_mode == "fly":
			var wall_altitude := int(player_entities[current_player_idx].get("altitude_feet", LocalRoomRules.elevation_feet(room, coord)))
			return wall_altitude >= LocalRoomRules.elevation_feet(room, coord) + LocalRoomRules.wall_height_feet(room, coord) and wall_altitude + 5 <= LocalRoomRules.ceiling_feet(room, coord)
		if active_movement_mode == "climb":
			return LocalRoomRules.wall_height_feet(room, coord) <= _movement_speed_feet("climb", character)
		return false
	if active_movement_mode == "fly":
		var flight_altitude := int(player_entities[current_player_idx].get("altitude_feet", 0))
		if flight_altitude < LocalRoomRules.elevation_feet(room, coord) or flight_altitude + 5 > LocalRoomRules.ceiling_feet(room, coord): return false
	return hex_grid.is_hex_passable(coord)


func _player_reachable(origin: Vector2i, movement_budget: float, character: Character) -> Dictionary:
	return HexUtils.get_reachable(origin, movement_budget, func(coord: Vector2i): return _player_can_enter(coord, character), func(coord: Vector2i) -> float: return _player_movement_cost(coord, character), func(from_hex: Vector2i, to_hex: Vector2i): return _player_step_movement_cost(from_hex, to_hex, character))


func _player_path(origin: Vector2i, destination: Vector2i, character: Character) -> Array[Vector2i]:
	return HexUtils.find_path(origin, destination, func(coord: Vector2i): return _player_can_enter(coord, character), func(coord: Vector2i) -> float: return _player_movement_cost(coord, character), 100, func(from_hex: Vector2i, to_hex: Vector2i): return _player_step_movement_cost(from_hex, to_hex, character))


func _enemy_movement_cost(coord: Vector2i, mover_id: String = "") -> float:
	return _spell_zones()._enemy_movement_cost(coord, mover_id)


func _enemy_step_movement_cost(from_hex: Vector2i, to_hex: Vector2i, mover: Dictionary) -> float:
	if _spell_zones()._antilife_shell_blocks_crossing(mover, from_hex, to_hex):
		return 9999.0
	var cost := _enemy_movement_cost(to_hex, str(mover.get("id", "")))
	var room := LocalRoomCombat.room()
	if not room.is_empty() and int(mover.get("fly_speed_feet", 0)) <= 0:
		var rise_feet := LocalRoomRules.elevation_feet(room, to_hex) - LocalRoomRules.elevation_feet(room, from_hex)
		if rise_feet > 0:
			cost += float(rise_feet) / 5.0
	return cost



func _enemy_reachable(origin: Vector2i, movement_budget: float, mover: Dictionary = {}) -> Dictionary:
	var mover_id := str(mover.get("id", ""))
	return HexUtils.get_reachable(origin, movement_budget, hex_grid.is_hex_passable, func(coord: Vector2i) -> float: return _enemy_movement_cost(coord, mover_id), func(from_hex: Vector2i, to_hex: Vector2i): return _enemy_step_movement_cost(from_hex, to_hex, mover))


func _enemy_path(origin: Vector2i, destination: Vector2i, mover: Dictionary) -> Array[Vector2i]:
	var mover_id := str(mover.get("id", ""))
	return HexUtils.find_path(origin, destination, hex_grid.is_hex_passable, func(coord: Vector2i) -> float: return _enemy_movement_cost(coord, mover_id), 100, func(from_hex: Vector2i, to_hex: Vector2i): return _enemy_step_movement_cost(from_hex, to_hex, mover))


func _conjure_fey_targets_within(center: Vector2i) -> Array[Dictionary]:
	return _spell_zones()._conjure_fey_targets_within(center)


func _conjure_fey_target_by_id(target_id: String):
	return _spell_zones()._conjure_fey_target_by_id(target_id)


func _resolve_conjure_fey_attack(zone: Dictionary, target) -> Dictionary:
	return await SpellZoneConjurations._resolve_conjure_fey_attack(_spell_zones(), zone, target)


func _expire_conjure_fey_frightened(caster: Character) -> void:
	_spell_zones()._expire_conjure_fey_frightened(caster)


func _highlight_conjure_fey_movement() -> void:
	var source_id := _conjure_fey_zone_source_for_caster(active_character)
	var zone: Dictionary = active_spell_zones.get(source_id, {})
	var center: Vector2i = zone.get("center", Vector2i.ZERO)
	var highlights := {}
	for candidate in hex_grid.tiles.keys():
		if Targeting.is_in_range(center, candidate, 6) and candidate != center and _is_unoccupied_conjure_fey_space(candidate):
			highlights[candidate] = Color(0.84, 0.63, 0.97, 0.76)
	hex_grid.set_highlights(highlights)


func _resolve_conjure_animals_zone_save(target, zone: Dictionary) -> Dictionary:
	return await SpellZoneConjurations._resolve_conjure_animals_zone_save(_spell_zones(), target, zone)


func _resolve_conjure_woodland_beings_zone_save(target, zone: Dictionary) -> Dictionary:
	return await SpellZoneConjurations._resolve_conjure_woodland_beings_zone_save(_spell_zones(), target, zone)


func _resolve_conjure_woodland_beings_area_movement(zone: Dictionary, old_center: Vector2i, new_center: Vector2i) -> Array[Dictionary]:
	return await _spell_zones()._resolve_conjure_woodland_beings_area_movement(zone, old_center, new_center)


func _resolve_conjure_animals_area_movement(zone: Dictionary, old_coords: Array, new_coords: Array) -> Array[Dictionary]:
	return await _spell_zones()._resolve_conjure_animals_area_movement(zone, old_coords, new_coords)


func _create_fog_cloud_zone(center: Vector2i, slot_level: int, extended: bool) -> void:
	SpellZoneTerrain._create_fog_cloud_zone(_spell_zones(), active_character, center, slot_level, extended)


func _refresh_fog_cloud_conditions() -> void:
	_spell_zones()._refresh_fog_cloud_conditions()


func _create_darkness_zone(center: Vector2i, extended: bool) -> void:
	SpellZoneTerrain._create_darkness_zone(_spell_zones(), active_character, center, extended)


func _refresh_darkness_conditions() -> void:
	_spell_zones()._refresh_darkness_conditions()


func _create_cloudkill_zone(center: Vector2i, source_id: String, slot_level: int, extended: bool) -> void:
	SpellZoneTerrain._create_cloudkill_zone(_spell_zones(), active_character, center, source_id, slot_level, extended)


func _advance_cloudkill_zones_for_caster(caster: Character) -> void:
	await _spell_zones()._advance_cloudkill_zones_for_caster(caster)


func _cloud_of_daggers_can_move(zone: Dictionary) -> bool:
	return _spell_zones()._cloud_of_daggers_can_move(zone)


func _create_cloud_of_daggers_zone(center: Vector2i, slot_level: int, extended: bool) -> void:
	SpellZoneTerrain._create_cloud_of_daggers_zone(_spell_zones(), active_character, center, slot_level, extended)


func _highlight_cloud_of_daggers_movement() -> void:
	var source_id := _cloud_of_daggers_zone_source_for_caster(active_character)
	var zone: Dictionary = active_spell_zones.get(source_id, {})
	var center: Vector2i = zone.get("center", Vector2i.ZERO)
	var highlights := {}
	for candidate in hex_grid.tiles.keys():
		if Targeting.is_in_range(center, candidate, 6):
			highlights[candidate] = Color(0.72, 0.82, 1.0, 0.72)
	hex_grid.set_highlights(highlights)


func _moonbeam_zone_source_for_caster(caster: Character) -> String:
	return _spell_zones()._moonbeam_zone_source_for_caster(caster)


func _moonbeam_can_move(zone: Dictionary) -> bool:
	return _spell_zones()._moonbeam_can_move(zone)


func _create_moonbeam_zone(center: Vector2i, slot_level: int, initial_targets: Array, source_id: String, shape_locked_targets: Array) -> void:
	SpellZoneTerrain._create_moonbeam_zone(_spell_zones(), active_character, center, slot_level, initial_targets, source_id, shape_locked_targets)


func _highlight_moonbeam_movement() -> void:
	var source_id := _moonbeam_zone_source_for_caster(active_character)
	var zone: Dictionary = active_spell_zones.get(source_id, {})
	if zone.is_empty():
		return
	var center: Vector2i = zone.get("center", Vector2i.ZERO)
	var highlights: Dictionary = {}
	for candidate in hex_grid.tiles.keys():
		if Targeting.is_in_range(center, candidate, 12):
			highlights[candidate] = Color(0.72, 0.82, 1.0, 0.72)
	hex_grid.set_highlights(highlights)


func _resolve_moonbeam_zone_save(target, zone: Dictionary) -> Dictionary:
	return await SpellZoneTerrain._resolve_moonbeam_zone_save(_spell_zones(), target, zone)


func _apply_moonbeam_shape_change(target: Character, source_id: String, locked_targets: Array, was_shape_shifted: bool = false) -> bool:
	return SpellZoneTerrain._apply_moonbeam_shape_change(_spell_zones(), target, source_id, locked_targets, was_shape_shifted)


func _release_moonbeam_shape_lock(target, source_id: String, zone: Dictionary) -> void:
	_spell_zones()._release_moonbeam_shape_lock(target, source_id, zone)


func _resolve_moonbeam_area_movement(zone: Dictionary, old_coords: Array, new_coords: Array) -> void:
	await _spell_zones()._resolve_moonbeam_area_movement(zone, old_coords, new_coords)


func _position_for_spell_target(target) -> Vector2i:
	return _spell_zones()._position_for_spell_target(target)


func _remove_spell_zone(source_id: String) -> void:
	_spell_zones()._remove_spell_zone(source_id)


func _tick_spell_zones() -> void:
	_spell_zones()._tick_spell_zones()


func _resolve_spell_zone_save(target, zone: Dictionary) -> Dictionary:
	return await SpellZoneTerrain._resolve_spell_zone_save(_spell_zones(), target, zone)


func _resolve_black_tentacles_zone_save(target, zone: Dictionary) -> Dictionary:
	return await SpellZoneTerrain._resolve_black_tentacles_zone_save(_spell_zones(), target, zone)


func _resolve_sleet_storm_zone_save(target, zone: Dictionary) -> Dictionary:
	return await SpellZoneTerrain._resolve_sleet_storm_zone_save(_spell_zones(), target, zone)


func _resolve_cloud_of_daggers_damage(target, zone: Dictionary) -> Dictionary:
	return await SpellZoneTerrain._resolve_cloud_of_daggers_damage(_spell_zones(), target, zone)


func _resolve_cloud_of_daggers_area_movement(zone: Dictionary, old_coords: Array, new_coords: Array) -> Array[Dictionary]:
	return await _spell_zones()._resolve_cloud_of_daggers_area_movement(zone, old_coords, new_coords)


func _resolve_cloudkill_zone_save(target, zone: Dictionary) -> Dictionary:
	return await SpellZoneTerrain._resolve_cloudkill_zone_save(_spell_zones(), target, zone)


func _resolve_cloudkill_area_movement(zone: Dictionary, old_coords: Array, new_coords: Array) -> Array[Dictionary]:
	return await _spell_zones()._resolve_cloudkill_area_movement(zone, old_coords, new_coords)


func _spell_zone_caster(zone: Dictionary) -> Character:
	return _spell_zones()._spell_zone_caster(zone)


func _resolve_spell_zone_entries(target, from_hex: Vector2i, to_hex: Vector2i) -> Array[Dictionary]:
	return await _spell_zones()._resolve_spell_zone_entries(target, from_hex, to_hex)


func _resolve_spell_zone_movement(target, to_hex: Vector2i) -> Array[Dictionary]:
	return await _spell_zones()._resolve_spell_zone_movement(target, to_hex)


func _resolve_spell_zone_path(target, path: Array) -> Array[Dictionary]:
	return await _spell_zones()._resolve_spell_zone_path(target, path)


func _resolve_spell_zone_end_turn(target, coord: Vector2i) -> Array[Dictionary]:
	return await _spell_zones()._resolve_spell_zone_end_turn(target, coord)


func _resolve_spell_zone_start_turn(target, coord: Vector2i) -> Array[Dictionary]:
	return await _spell_zones()._resolve_spell_zone_start_turn(target, coord)


func _try_escape_restrained_zone(character: Character) -> bool:
	if character == null or not _can_spend_action_cost("action"):
		return false
	for source_id_value in character.condition_sources.get("restrained", {}).keys():
		var source_id := str(source_id_value)
		if not (source_id.begins_with("entangle:") or source_id.begins_with("black_tentacles:")):
			continue
		var zone: Dictionary = active_spell_zones.get(source_id, {})
		if zone.is_empty():
			CombatAction.remove_condition_source(character, source_id, ["restrained"])
			continue
		var result := EventResolver.resolve_skill_check(character, {"ability": "STR", "skill": "Athletics", "dc": int(zone.get("save_dc", 10)), "use_primal_knowledge": false})
		_spend_action_cost("action")
		if bool(result.get("success", false)):
			CombatAction.remove_condition_source(character, source_id, ["restrained"])
			var restrained_targets: Array = zone.get("restrained_targets", [])
			restrained_targets.erase(character)
			zone["restrained_targets"] = restrained_targets
			hud.add_log("[color=green]%s breaks free of %s with Strength (Athletics) (%d vs DC %d).[/color]" % [character.character_name, str(zone.get("spell_id", "the restraint")).capitalize().replace("_", " "), int(result.get("total", 0)), int(result.get("dc", 0))])
		else:
			hud.add_log("[color=orange]%s fails the Strength (Athletics) check to escape %s (%d vs DC %d).[/color]" % [character.character_name, str(zone.get("spell_id", "the restraint")).capitalize().replace("_", " "), int(result.get("total", 0)), int(result.get("dc", 0))])
		hud.update_hud(active_character, tracker)
		_highlight_reachable()
		return true
	return false


func _try_freedom_of_movement_escape(character: Character) -> bool:
	if character == null or not SpellEffects.has_spell(character, "freedom_of_movement"):
		return false
	if CombatAction.nonmagical_restraint_sources(character).is_empty():
		return false
	var total_speed := float(character.movement_speed_feet(active_movement_mode, true)) / 5.0
	var available_speed := minf(total_speed, remaining_speed) if player_moved_this_turn else total_speed
	if available_speed < 1.0:
		hud.add_log("You need 5 feet of movement available to escape the restraint.")
		return true
	if not CombatAction.escape_nonmagical_restraint(character):
		return false
	remaining_speed = available_speed - 1.0
	player_moved_this_turn = true
	hud.add_log("%s spends 5 feet of movement and escapes the nonmagical restraint." % character.character_name)
	hud.update_hud(active_character, tracker)
	_highlight_reachable()
	return true


func _try_shake_sleeping_creature(coord: Vector2i, player_pos: Vector2i) -> bool:
	return SpellEncounterLifecycle._try_shake_sleeping_creature(_spell_cast_context(), coord, player_pos)



func _resolve_ray_of_enfeeblement_repeat_save(target) -> void:
	SpellEncounterLifecycle._resolve_ray_of_enfeeblement_repeat_save(_spell_cast_context(), target)




func _resolve_hold_monster_repeat_save(target) -> void:
	SpellEncounterLifecycle._resolve_hold_monster_repeat_save(_spell_cast_context(), target)




func _end_concentration(caster: Character) -> void:
	SpellEncounterLifecycle._end_concentration(_spell_cast_context(), caster)
	_highlight_reachable()


func _end_resilient_sphere_for_target(target) -> void:
	SpellEncounterLifecycle._end_resilient_sphere_for_target(_spell_cast_context(), target)


func _check_concentration_save(character: Character, damage_taken: int) -> void:
	await SpellEncounterLifecycle._check_concentration_save(_spell_cast_context(), character, damage_taken)


func _handle_spell_effects(p_target: Character = null, m_target: Dictionary = {}, spell_data: Dictionary = {}, origin: Vector2i = Vector2i.ZERO, target_coord: Vector2i = Vector2i.ZERO, resolution: Dictionary = {}) -> void:
	await SpellEffectApplication.apply(_spell_cast_context(), p_target, m_target, spell_data, origin, target_coord, resolution)




func _recover_wizard_spell_slots(character: Character) -> void:
	if character == null or character.class_id == "wizard":
		return
	var max_recovery_levels := int(ceil(float(character.level) / 2.0))
	var recovered_slots: Array[String] = []
	
	var class_data := DataLoader.get_character_class(character.class_id)
	var slot_table: Dictionary = class_data.get("spell_slots_by_character_level", {})
	var level_key := str(character.level)
	if not level_key in slot_table:
		return
		
	var max_slots: Array = slot_table[level_key]
	
	var remaining_recovery_levels := max_recovery_levels
	for slot_lvl in range(max_slots.size(), 0, -1):
		if slot_lvl > 5: continue
		
		var max_qty: int = int(max_slots[slot_lvl - 1]) if slot_lvl <= max_slots.size() else 0
		var slot_lvl_str := str(slot_lvl)
		var current_qty: int = character.spell_slots.get(slot_lvl_str, 0)
		var expended := max_qty - current_qty
		
		while expended > 0 and remaining_recovery_levels >= slot_lvl:
			character.spell_slots[slot_lvl_str] = character.spell_slots.get(slot_lvl_str, 0) + 1
			remaining_recovery_levels -= slot_lvl
			expended -= 1
			recovered_slots.append("Level %d" % slot_lvl)
	
	if recovered_slots.is_empty():
		hud.add_log("No spell slots needed recovery.")
	else:
		hud.add_log("[color=green]%s recovered spell slots: %s[/color]" % [character.character_name, ", ".join(recovered_slots)])


func _lowest_available_spell_slot(character: Character, max_level: int) -> int:
	for level in range(1, max_level + 1):
		if int(character.spell_slots.get(str(level), 0)) > 0:
			return level
	return 0


func _check_opportunity_attacks_for_path(entity, entity_dict: Dictionary, path: Array, is_entity_monster: bool):
	if path.size() < 2: return []
	var zone_entry_results: Array[Dictionary] = []
	
	for k in range(path.size() - 1):
		var from_hex: Vector2i = path[k]
		var to_hex: Vector2i = path[k+1]
		
		# Move through the shared action boundary before checking reactions.
		var movement_result := CombatAction.resolve_movement_step(entity_dict, from_hex, to_hex)
		if not movement_result.get("success", false):
			return
		_publish_source_range_events()
		if not is_entity_monster:
			_sync_mounted_steed_position(entity, to_hex)
		
		if is_entity_monster:
			# Monster is moving. Check players who can make opportunity attacks.
			for p in player_entities:
				var char_data: Character = p["character"]
				if char_data == null or not char_data.is_alive: continue
				if not p.get("reaction_available", true): continue
				if char_data.has_condition("stunned") or CombatAction.blocks_opportunity_attack(char_data): continue
				
				# Check if player was adjacent at from_hex and is no longer adjacent at to_hex
				var weapon := DataLoader.get_item(char_data.inventory.get_weapon()).duplicate(true)
				if "ranged" in weapon.get("properties", []) or weapon.is_empty():
					weapon = {"id": "unarmed", "type": "weapon", "damage": "1+STR", "ability": "STR", "range": 1, "damage_type": "bludgeoning"}
				if _spell_zones()._antilife_shell_blocks_melee(char_data, p.get("hex_position", Vector2i.ZERO), from_hex, weapon):
					continue
				var reach := 2 if "reach" in weapon.get("properties", []) else 1
				var dist_from := HexUtils.get_distance(p["hex_position"], from_hex)
				var dist_to := HexUtils.get_distance(p["hex_position"], to_hex)
				if dist_from <= reach and dist_to > reach:
					var owner_label := _owner_label_for_character(char_data)
					var accepted := await hud.request_reaction(owner_label, "opportunity_attack", "Make a weapon attack against %s before it leaves your reach." % entity_dict["name"])
					if not accepted:
						hud.add_log("[color=gray]%s declines the opportunity attack.[/color]" % owner_label)
						continue
					p["reaction_available"] = false
					char_data.reaction_available = false
					hud.add_log("[color=yellow]%s makes an Opportunity Attack against %s![/color]" % [char_data.character_name, entity_dict["name"]])
					
					# Resolve before leaving reach. A positional mastery can interrupt
					# the proposed path, so do not overwrite its settled destination.
					entity_dict["hex_position"] = from_hex
					weapon["attack_distance"] = dist_from
					weapon["opportunity_attack"] = true
					var opportunity_effects := await _request_brutal_strike(char_data, weapon)
					var opportunity_decisions := await _collect_attack_inspiration_decision(char_data)
					opportunity_decisions.merge(await _collect_roll_token_decision(char_data, "attack", "%s Opportunity Attack roll against %s" % [char_data.character_name, str(entity_dict.get("name", "target"))], opportunity_decisions), true)
					if not opportunity_effects.is_empty():
						opportunity_decisions["barbarian_brutal_strike_effects"] = opportunity_effects
					var opportunity_packet := await _conjure_minor_elementals_damage_choice(char_data, entity_dict)
					var opportunity_additional_damage := {"packets": [opportunity_packet]} if not opportunity_packet.is_empty() else {}
					var result := CombatAction.resolve_weapon_attack(char_data, entity_dict, weapon, false, false, opportunity_decisions, opportunity_additional_damage)
					await _offer_sneak_attack(entity_dict, weapon, result, char_data)
					await _offer_stunning_strike(entity_dict, weapon, result, char_data)
					await _finish_fighter_attack(entity_dict, weapon, result, char_data)
					hud.add_log(result.get("message", "Miss!"))
					_publish_fighter_extra_attack(entity_dict, weapon, result, char_data)
					
					if int(entity_dict.get("current_hp", 0)) <= 0:
						entity_dict["is_alive"] = false
						hud.add_log("[color=green]%s was defeated by opportunity attack![/color]" % entity_dict["name"])
						tracker.remove_combatant(entity_dict["id"])
						_trigger_enemy_defeat_features(entity_dict, char_data)
						entity_dict["hex_position"] = from_hex # Stops at from_hex
						return
					if entity_dict["hex_position"] != from_hex:
						return
					entity_dict["hex_position"] = to_hex
		else:
			# Player is moving. Check monsters who can make opportunity attacks.
			for m in monster_entities:
				if entity is Character and (entity.has_feature("agile") or (entity.has_feature("flyby") and active_movement_mode == "fly")): continue
				if not m["is_alive"]: continue
				if not m.get("reaction_available", true): continue
				if m.get("conditions", {}).has("stunned") or CombatAction.blocks_opportunity_attack(m) or m.get("stunning_strike_stunned", false) or m.has("barbarian_no_opportunity_owner"): continue
				
				# Check if monster was adjacent at from_hex and is no longer adjacent at to_hex
				var dist_from := HexUtils.get_distance(m["hex_position"], from_hex)
				var dist_to := HexUtils.get_distance(m["hex_position"], to_hex)
				if dist_from == 1 and dist_to > 1:
					var attack_data: Dictionary = m.get("attacks", [{}])[0]
					if _spell_zones()._antilife_shell_blocks_melee(m, m["hex_position"], from_hex, attack_data):
						continue
					m["reaction_available"] = false
					hud.add_log("[color=red]%s makes an Opportunity Attack against %s![/color]" % [m["name"], entity.character_name])
					var reaction_decisions := await _collect_reaction_decisions(entity)
					var monster_attacker := _make_temp_monster_character(m)
					reaction_decisions.merge(await _collect_roll_token_decision(monster_attacker, "attack", "%s Opportunity Attack roll against %s" % [str(m.get("name", "Monster")), entity.character_name], reaction_decisions), true)
					var result := CombatAction.resolve_weapon_attack(monster_attacker, entity, attack_data, false, false, reaction_decisions)
					if result.has("attack_roll"):
						SpellEffects.consume_spell(m, "invisibility")
					_sync_consumed_monster_attack_conditions(m, monster_attacker)
					if result.get("deflected", false):
						await _offer_deflect_redirect(entity, from_hex, attack_data, result)
					hud.add_log(result.get("message", "Miss!"))
					
					if not entity.is_alive:
						hud.add_log("[color=red]%s was knocked out by opportunity attack![/color]" % entity.character_name)
						entity_dict["hex_position"] = from_hex # Stops at from_hex
						_end_concentration(entity)
						return
		var actual_hex: Vector2i = entity_dict.get("hex_position", from_hex)
		if actual_hex != from_hex and await _apply_room_fall_damage(entity, from_hex, actual_hex):
			return zone_entry_results
		zone_entry_results.append_array(await _resolve_spell_zone_entries(entity, from_hex, actual_hex))
		zone_entry_results.append_array(await _resolve_spell_zone_movement(entity, actual_hex))
	return zone_entry_results


func _owner_label_for_character(character: Character) -> String:
	if character == null:
		return "Unknown seat"
	for player_entity in player_entities:
		if player_entity.get("character") != character:
			continue
		var owner_index := int(player_entity.get("owner_player_index", -1))
		return "Seat %d - %s" % [owner_index + 1, character.character_name] if owner_index >= 0 else character.character_name
	return character.character_name


func _begin_spell_targeting() -> void:
	pending_action_type = "spell"
	pending_command_target_coords.clear()
	pending_command_target_ids.clear()


func _finish_spell_targeting() -> void:
	pending_words_primary_selected = false
	pending_command_target_coords.clear()
	pending_command_target_ids.clear()


var grant_transfers := CapturedGrantRules.new()
var temporary_hp_grants := TemporaryHPRules.new()
var aura_choice_generation := 0
var last_temporary_hp_grant: Dictionary = {}

func _execute_temporary_hp_grant(feature: Dictionary) -> void:
	var supplier := active_character
	var original_feature := supplier.get_feature(str(feature.id)).duplicate(true)
	var original_source := str(feature.get("source_instance_id", ""))
	var original_pool: Dictionary = supplier.numeric_resource_pools.get(original_source, {})
	var original_quantity := original_pool.duplicate(true)
	var original_budget := turn_budget
	var original_turn := CombatAction.active_turn_serial
	var original_clock := int(GameManager.campaign_elapsed_seconds)
	var original_generation := temporary_hp_grants.generation
	var recipients := _gift_recipients().filter(func(actor): return TemporaryHPRules.eligible(actor))
	var options: Array[String] = []
	var labels := {}
	for recipient in recipients:
		options.append(recipient.character_id)
		labels[recipient.character_id] = recipient.character_name
	if options.is_empty(): return
	resolving_player_action = true
	var id: String = await hud._request_popup_choice("Temporary HP recipient", options, labels)
	if not _temporary_hp_actor_current(supplier) or temporary_hp_grants.generation != original_generation or original_budget != turn_budget or original_turn != CombatAction.active_turn_serial or original_clock != int(GameManager.campaign_elapsed_seconds) or supplier.get_feature(str(feature.id)) != original_feature or not is_same(supplier.numeric_resource_pools.get(original_source), original_pool) or supplier.numeric_resource_pools.get(original_source) != original_quantity:
		resolving_player_action = false
		return
	var recipient: Character
	for candidate in recipients:
		if candidate.character_id == id: recipient = candidate
	if recipient == null or recipient not in _gift_recipients():
		resolving_player_action = false
		return
	var request := temporary_hp_grants.begin(supplier, str(feature.id), str(feature.get("source_instance_id", "")), turn_budget, recipient)
	if request.is_empty():
		resolving_player_action = false
		return
	var replace := true
	if int(request.current) > 0:
		var answer: String = await hud._request_popup_choice("Temporary HP: keep or replace", ["keep", "replace"], {"keep":"Keep %d Temporary HP and its original source/deadline" % int(request.current), "replace":"Replace with %d Temporary HP" % int(request.incoming)})
		if not _temporary_hp_actor_current(supplier) or temporary_hp_grants.pending.get("budget") != turn_budget or answer not in ["keep", "replace"]:
			temporary_hp_grants.clear()
			resolving_player_action = false
			return
		replace = answer == "replace"
	last_temporary_hp_grant = temporary_hp_grants.settle(request, replace, _gift_recipients())
	resolving_player_action = false
	if last_temporary_hp_grant.get("success", false) and not last_temporary_hp_grant.get("declined", false):
		if feature.action_cost != "free": action_history.record_action(supplier)
		hud.add_log("%s replaces Temporary HP from %s." % [recipient.character_name, supplier.character_name])
	else: hud.add_log("Temporary HP kept, canceled or no longer available.")
	hud.update_hud(active_character, tracker)

func _temporary_hp_actor_current(actor: Character) -> bool:
	return is_inside_tree() and actor == active_character and hud.active_character == actor and actor in _gift_recipients()

func _choose_aura_protection(group: String) -> void:
	var actor := active_character
	var snapshot := AuraProtectionRules.offers(actor, group)
	var options: Array[String] = []
	var labels := {}
	for key in snapshot:
		options.append(key)
		var duration := "while in range" if snapshot[key].effect.entry_policy == "membership" else "%d seconds" % (int(snapshot[key].expires_at_seconds)-int(GameManager.campaign_elapsed_seconds))
		labels[key] = "%s: AC +%d, saves +%d (%s)" % [snapshot[key].source_owner_id, int(snapshot[key].effect.benefits.ac_bonus), int(snapshot[key].effect.benefits.save_bonus), duration]
	aura_choice_generation += 1
	var generation := aura_choice_generation
	var turn := CombatAction.active_turn_serial
	resolving_player_action = true
	var answer: String = await hud._request_popup_choice("Choose aura protection: " + group, options, labels)
	resolving_player_action = false
	if generation != aura_choice_generation or turn != CombatAction.active_turn_serial or not _temporary_hp_actor_current(actor): return
	if not AuraProtectionRules.choose(actor, snapshot, answer): hud.add_log("Aura choice canceled or no longer available.")
	hud.update_hud(active_character, tracker)
var party_allocations := PartyAllocationRules.new()
var last_party_allocation: Dictionary = {}

func _execute_party_allocation(feature: Dictionary) -> void:
	var actor := active_character
	var request := party_allocations.begin(actor, str(feature.id), str(feature.get("source_instance_id", "")), turn_budget, _gift_recipients())
	if request.is_empty():
		hud.add_log("No eligible recipient or available allocation source.")
		return
	resolving_player_action = true
	var spec: Dictionary = request.spec
	if spec.mode == "rolled_total" and feature.action_cost != "free": action_history.record_action(actor)
	var rows: Array = []
	var used := 0
	var canceled := false
	while used < int(request.total):
		var ids: Array[String] = []
		var labels := {}
		for id in request.recipient_ids:
			var existing := -1
			for index in rows.size():
				if rows[index].recipient_id == id: existing = index
			if existing < 0 and rows.size() >= int(spec.max_recipients): continue
			var allocated: int = 0 if existing < 0 else (rows[existing].dice_ids.size() if spec.mode == "captured_dice" else int(rows[existing].amount))
			if allocated >= int(spec.per_target_cap): continue
			ids.append(str(id))
			for recipient in _gift_recipients():
				if recipient.character_id == id: labels[id] = "%s (%d allocated)" % [recipient.character_name, allocated]
		if not rows.is_empty():
			ids.append("__done")
			labels["__done"] = "Confirm allocation (%d of %d)" % [used, int(request.total)]
		if ids.is_empty(): break
		var answer: String = await hud._request_popup_choice("Allocate: %d remaining%s" % [int(request.total)-used, " — use already spent; cancel forfeits" if spec.mode == "rolled_total" else ""], ids, labels)
		if not _allocation_actor_current(actor):
			party_allocations.clear()
			resolving_player_action = false
			return
		if answer == "__done": break
		if answer not in request.recipient_ids:
			canceled = true
			break
		var index := -1
		for i in rows.size():
			if rows[i].recipient_id == answer: index = i
		var allocated: int = 0 if index < 0 else (rows[index].dice_ids.size() if spec.mode == "captured_dice" else int(rows[index].amount))
		var choices: Array[String] = []
		labels = {}
		if spec.mode == "captured_dice":
			for die in request.dice:
				if rows.any(func(row): return die.die_id in row.dice_ids): continue
				choices.append(str(die.die_id))
				labels[die.die_id] = "d%d: %d [%s]" % [int(die.die_size), int(die.face), die.die_id]
		else:
			for amount in range(1, mini(int(spec.per_target_cap)-allocated, int(request.total)-used)+1):
				choices.append(str(amount))
				labels[str(amount)] = str(amount)
		var quantity: String = await hud._request_popup_choice("Choose a retained die" if spec.mode == "captured_dice" else "Choose amount", choices, labels)
		if not _allocation_actor_current(actor):
			party_allocations.clear()
			resolving_player_action = false
			return
		if quantity not in choices:
			canceled = true
			break
		if index < 0:
			rows.append({"recipient_id":answer, "dice_ids":[]} if spec.mode == "captured_dice" else {"recipient_id":answer, "amount":0})
			index = rows.size()-1
		if spec.mode == "captured_dice": rows[index].dice_ids.append(quantity)
		else: rows[index].amount += int(quantity)
		used += 1 if spec.mode == "captured_dice" else int(quantity)
	last_party_allocation = party_allocations.settle(str(request.request_id), actor, [] if canceled else rows, _gift_recipients())
	resolving_player_action = false
	if last_party_allocation.get("success", false) and not last_party_allocation.get("declined", false):
		if spec.mode != "rolled_total" and feature.action_cost != "free": action_history.record_action(actor)
		hud.add_log("Allocation completed.")
	else:
		hud.add_log("Allocation canceled or no longer available.%s" % [" Revealed roll is forfeited." if spec.mode == "rolled_total" else ""])
	print("PARTY ALLOCATION: " + JSON.stringify(last_party_allocation))
	hud.update_hud(active_character, tracker)
	_highlight_reachable()

func _allocation_actor_current(actor: Character) -> bool:
	return is_inside_tree() and active_character == actor and hud.active_character == actor and party_allocations._pending.get("budget") == turn_budget and player_entities.any(func(entry): return entry.get("character") == actor)

func _gift_recipients() -> Array:
	var recipients: Array = []
	for entry in player_entities:
		var recipient: Character = entry.get("character")
		if recipient != null and recipient not in recipients: recipients.append(recipient)
	return recipients

func _execute_captured_grant_transfer(feature: Dictionary) -> void:
	var giver := active_character
	var request := grant_transfers.begin(giver, str(feature.id), str(feature.get("source_instance_id", "")), turn_budget, _gift_recipients())
	if request.is_empty():
		hud.add_log("No eligible willing recipient or available transfer source.")
		return
	resolving_player_action = true
	var selected: Array = []
	var options: Array[String] = []
	var labels := {}
	for id in request.recipient_ids:
		options.append(str(id))
		for recipient in _gift_recipients():
			if recipient.character_id == id: labels[id] = recipient.character_name
	while selected.size() < int(request.max_recipients) and not options.is_empty():
		var offered: Array[String] = options.duplicate()
		if not selected.is_empty():
			offered.append("__done")
			labels["__done"] = "Give to selected recipients"
		var answer: String = await hud._request_popup_choice("Give captured gift", offered, labels)
		if active_character != giver or hud.active_character != giver or not is_inside_tree():
			grant_transfers.clear()
			resolving_player_action = false
			return
		if answer == "__done": break
		if answer not in options:
			selected.clear()
			break
		selected.append(answer)
		options.erase(answer)
	var result := grant_transfers.settle(str(request.request_id), giver, selected, _gift_recipients())
	resolving_player_action = false
	if result.get("success", false) and not result.get("declined", false):
		if feature.action_cost != "free": action_history.record_action(giver)
		hud.add_log(str(result.message))
		print("CAPTURED GIFT TRANSFER: " + JSON.stringify(result))
	else:
		hud.add_log("Gift canceled or no longer available.")
	hud.update_hud(active_character, tracker)
	_highlight_reachable()


## Batch 053 S-122: created actors enter at their confirmed legal destinations.
func _attach_created_actors(owner: Character, picks: Array) -> Array:
	var origin := Vector2i.ZERO
	for entity in player_entities:
		if entity.get("character") == owner: origin = entity.get("hex_position", Vector2i.ZERO)
	return CreatedActorRules.attach(self, owner, origin, picks)


func _entity_name_for_created(actor_id: String) -> String:
	for e in player_entities:
		if str(e.get("combat_id", "")) == actor_id: return str(e.get("name", actor_id))
	return actor_id
