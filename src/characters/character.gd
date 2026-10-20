## Character
## Core character data class for player characters and NPCs.
## Integrates ability scores, class features, inventory, and combat stats.
class_name Character
extends RefCounted

static func saved_campaign_modifier_error(data: Dictionary, campaign_seconds: int) -> String:
	var modifiers: Variant = data.get("modifiers", [])
	if not modifiers is Array:
		return "Character modifier state is not an array."
	var cooldowns: Variant = data.get("campaign_modifier_cooldowns", [])
	if not cooldowns is Array:
		return "Campaign modifier cooldown state is not an array."
	var owner_id := str(data.get("character_id", ""))
	var pools: Variant = data.get("numeric_resource_pools", {})
	if not pools is Dictionary:
		return "Timed modifier source pools are invalid."
	var saved_serial: Variant = data.get("timed_modifier_grant_serial", 0)
	if not (saved_serial is int or saved_serial is float) or not is_finite(float(saved_serial)) or float(saved_serial) != floor(float(saved_serial)) or int(saved_serial) < 0:
		return "Timed modifier grant serial is invalid."
	var seen_grants: Dictionary = {}
	var active_sources: Dictionary = {}
	var cooldown_sources: Dictionary = {}
	var maximum_grant_serial := 0
	for modifier in modifiers:
		if not modifier is Dictionary:
			continue
		var has_timed_identity: bool = modifier.has("owner_id") or modifier.has("source_instance_id") or modifier.has("grant_instance_id") or modifier.has("cooldown_seconds") or modifier.has("used_rider_options")
		if not modifier.has("expires_at_seconds"):
			if has_timed_identity:
				return "Tagged timed modifier is missing its campaign deadline."
			continue
		var expiry: Variant = modifier.get("expires_at_seconds", null)
		var amount: Variant = modifier.get("amount", null)
		var source_id := str(modifier.get("source_instance_id", ""))
		var grant_id := str(modifier.get("grant_instance_id", ""))
		if str(modifier.get("owner_id", "")) != owner_id or owner_id.is_empty() or source_id.is_empty() or grant_id.is_empty():
			return "Timed modifier owner/source/grant identity is invalid."
		var source_pool: Variant = pools.get(source_id, null)
		if not source_pool is Dictionary or str(source_pool.get("owner_id", "")) != owner_id or str(source_pool.get("source_instance_id", "")) != source_id:
			return "Timed modifier source does not own a saved numeric resource pool."
		if str(modifier.get("kind", "")) != "stat" or str(modifier.get("key", "")) != "AC":
			return "Timed modifier contains an unsupported stat."
		var grant_prefix := "%s:%s:" % [owner_id, source_id]
		var grant_serial_text := grant_id.get_slice(":", grant_id.get_slice_count(":") - 1)
		if not grant_id.begins_with(grant_prefix) or not grant_serial_text.is_valid_int() or int(grant_serial_text) < 1:
			return "Timed modifier grant identity does not match its owner/source."
		maximum_grant_serial = maxi(maximum_grant_serial, int(grant_serial_text))
		if not (expiry is int or expiry is float) or not is_finite(float(expiry)) or float(expiry) != floor(float(expiry)) or float(expiry) < 1:
			return "Timed modifier campaign deadline is invalid."
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floor(float(amount)) or int(amount) == 0 or abs(int(amount)) > 100:
			return "Timed modifier amount is invalid."
		var cooldown_seconds: Variant = modifier.get("cooldown_seconds", 0)
		if not _saved_integer(cooldown_seconds, 0, 86400):
			return "Timed modifier cooldown duration is invalid."
		var used_options: Variant = modifier.get("used_rider_options", [])
		if not used_options is Array or used_options.size() > 100:
			return "Timed modifier rider locks must be a bounded option list."
		var seen_options: Dictionary = {}
		for option in used_options:
			if not option is String or not str(option).is_valid_identifier() or seen_options.has(option):
				return "Timed modifier rider lock has an invalid or duplicate option."
			seen_options[option] = true
		if seen_grants.has(grant_id):
			return "Timed modifier grant identity is duplicated."
		seen_grants[grant_id] = true
		if int(expiry) > campaign_seconds:
			if active_sources.has(source_id):
				return "A source has more than one active timed modifier grant."
			active_sources[source_id] = true
	for cooldown in cooldowns:
		if not cooldown is Dictionary:
			return "Campaign modifier cooldown must be an object."
		var source_id := str(cooldown.get("source_instance_id", ""))
		var grant_id := str(cooldown.get("grant_instance_id", ""))
		var started_at: Variant = cooldown.get("started_at_seconds", null)
		var ready_at: Variant = cooldown.get("ready_at_seconds", null)
		var cooldown_seconds: Variant = cooldown.get("cooldown_seconds", null)
		if owner_id.is_empty() or str(cooldown.get("owner_id", "")) != owner_id or source_id.is_empty() or grant_id.is_empty():
			return "Campaign modifier cooldown owner/source/grant identity is invalid."
		var source_pool: Variant = pools.get(source_id, null)
		if not source_pool is Dictionary or str(source_pool.get("owner_id", "")) != owner_id or str(source_pool.get("source_instance_id", "")) != source_id:
			return "Campaign modifier cooldown source does not own a saved numeric resource pool."
		var grant_prefix := "%s:%s:" % [owner_id, source_id]
		var grant_serial_text := grant_id.get_slice(":", grant_id.get_slice_count(":") - 1)
		if not grant_id.begins_with(grant_prefix) or not grant_serial_text.is_valid_int() or int(grant_serial_text) < 1:
			return "Campaign modifier cooldown grant identity does not match its owner/source."
		maximum_grant_serial = maxi(maximum_grant_serial, int(grant_serial_text))
		if str(cooldown.get("end_reason", "")) not in ["expired", "dismissed"]:
			return "Campaign modifier cooldown end reason is unsupported."
		if not _saved_integer(started_at, 0, 2147483647) or not _saved_integer(cooldown_seconds, 1, 86400) or not _saved_integer(ready_at, 1, 2147483647) or int(ready_at) != int(started_at) + int(cooldown_seconds):
			return "Campaign modifier cooldown deadline is invalid."
		if seen_grants.has(grant_id):
			return "Campaign modifier grant identity is active and cooling down at once."
		seen_grants[grant_id] = true
		if int(ready_at) > campaign_seconds:
			if cooldown_sources.has(source_id) or active_sources.has(source_id):
				return "A source has overlapping active timed grants or cooldowns."
			cooldown_sources[source_id] = true
	if int(saved_serial) < maximum_grant_serial:
		return "Timed modifier grant serial would reuse a saved identity."
	return ""


static func saved_willingness_error(data: Dictionary) -> String:
	if not data.has("willingness"):
		return ""
	if not data["willingness"] is String or str(data["willingness"]) not in ["unknown", "willing", "unwilling"]:
		return "Character willingness must be unknown, willing, or unwilling."
	return ""


static func saved_damage_history_error(data: Dictionary, campaign_seconds: int) -> String:
	if not data.has("recent_damage_history"):
		return ""
	var entries: Variant = data.get("recent_damage_history")
	if not entries is Array or entries.size() > 128:
		return "Recent damage history must be an array of at most 128 entries."
	var owner_id := str(data.get("character_id", ""))
	for entry in entries:
		if not entry is Dictionary or entry.size() != 9:
			return "Recent damage history entry is malformed."
		for key in entry:
			if key not in ["target_actor_id", "source_actor_id", "source_instance_id", "at_seconds", "raw", "prevented", "absorbed", "resolved", "hp_loss"]:
				return "Recent damage history entry contains an unsupported field."
		var target_id: Variant = entry.get("target_actor_id", null)
		var source_id: Variant = entry.get("source_actor_id", null)
		var source_instance_id: Variant = entry.get("source_instance_id", null)
		var at: Variant = entry.get("at_seconds", null)
		if owner_id.is_empty() or not target_id is String or str(target_id) != owner_id or not source_id is String or str(source_id).is_empty() or not source_instance_id is String or str(source_instance_id).is_empty() or not _saved_integer(at, 0, campaign_seconds):
			return "Recent damage history source or campaign timestamp is invalid."
		for measure in ["raw", "prevented", "absorbed", "resolved", "hp_loss"]:
			if not _saved_integer(entry.get(measure, null), 0, 2000000):
				return "Recent damage history measure '%s' is invalid." % measure
	return ""


static func _saved_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return not value is bool and (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and int(value) >= minimum and int(value) <= maximum


func record_recent_damage(source_actor_id: String, source_instance_id: String, raw: int, prevented: int, absorbed: int, resolved: int, hp_loss: int, at_seconds: int) -> void:
	if character_id.is_empty() or source_actor_id.is_empty() or source_instance_id.is_empty() or at_seconds < 0:
		return
	_prune_recent_damage_history(at_seconds)
	var measures := {"raw": maxi(0, raw), "prevented": maxi(0, prevented), "absorbed": maxi(0, absorbed), "resolved": maxi(0, resolved), "hp_loss": maxi(0, hp_loss)}
	for entry in recent_damage_history:
		if str(entry.get("target_actor_id", "")) == character_id and str(entry.get("source_actor_id", "")) == source_actor_id and str(entry.get("source_instance_id", "")) == source_instance_id and int(entry.get("at_seconds", -1)) == at_seconds:
			for measure in measures:
				entry[measure] = int(entry.get(measure, 0)) + int(measures[measure])
			return
	recent_damage_history.append({"target_actor_id": character_id, "source_actor_id": source_actor_id, "source_instance_id": source_instance_id, "at_seconds": at_seconds}.merged(measures))
	while recent_damage_history.size() > 128:
		recent_damage_history.pop_front()


func recent_damage_measure(source_actor_id: String, source_instance_id: String, measure: String, now_seconds: int) -> Dictionary:
	if character_id.is_empty() or source_actor_id.is_empty() or source_instance_id.is_empty() or measure not in ["raw", "prevented", "absorbed", "resolved", "hp_loss"] or now_seconds < 0:
		return {"available": false}
	var total := 0
	for entry in recent_damage_history:
		var at := int(entry.get("at_seconds", -1))
		if str(entry.get("target_actor_id", "")) == character_id and str(entry.get("source_actor_id", "")) == source_actor_id and str(entry.get("source_instance_id", "")) == source_instance_id and at <= now_seconds and now_seconds - at < 60:
			total += int(entry.get(measure, 0))
	return {"available": true, "value": total}


func _prune_recent_damage_history(now_seconds: int) -> void:
	var retained: Array[Dictionary] = []
	for entry in recent_damage_history:
		var at := int(entry.get("at_seconds", -1))
		if at >= 0 and at <= now_seconds and now_seconds - at < 60:
			retained.append(entry)
	recent_damage_history = retained


static func saved_next_weapon_hit_grants_error(data: Dictionary, campaign_seconds: int) -> String:
	var grants: Variant = data.get("next_weapon_hit_grants", [])
	if not grants is Array:
		return "Next weapon-hit grant state is not an array."
	var owner_id := str(data.get("character_id", ""))
	var saved_serial: Variant = data.get("next_weapon_hit_grant_serial", 0)
	if not (saved_serial is int or saved_serial is float) or not is_finite(float(saved_serial)) or float(saved_serial) != floor(float(saved_serial)) or int(saved_serial) < 0:
		return "Next weapon-hit grant serial is invalid."
	var pools: Variant = data.get("numeric_resource_pools", {})
	if not pools is Dictionary:
		return "Next weapon-hit grant pools are invalid."
	var seen_grants: Dictionary = {}
	var seen_orders: Dictionary = {}
	var active_sources: Dictionary = {}
	var maximum_order := 0
	for grant in grants:
		if not grant is Dictionary:
			return "Next weapon-hit grant is not an object."
		var source_id := str(grant.get("source_instance_id", ""))
		var grant_id := str(grant.get("grant_instance_id", ""))
		var order: Variant = grant.get("acquisition_order", null)
		var expiry: Variant = grant.get("expires_at_seconds", null)
		var amount: Variant = grant.get("amount", null)
		if owner_id.is_empty() or str(grant.get("owner_id", "")) != owner_id or source_id.is_empty() or not pools.has(source_id):
			return "Next weapon-hit grant owner/source identity is invalid."
		if not (order is int or order is float) or not is_finite(float(order)) or float(order) != floor(float(order)) or int(order) < 1:
			return "Next weapon-hit acquisition order is invalid."
		if seen_orders.has(int(order)):
			return "Next weapon-hit acquisition order is duplicated."
		seen_orders[int(order)] = true
		if grant_id != "next-hit:%s:%s:%d" % [owner_id, source_id, int(order)]:
			return "Next weapon-hit grant identity does not match its owner/source/order."
		var damage_type := str(grant.get("damage_type", ""))
		if str(grant.get("matcher", "")) != "melee_weapon_hit" or damage_type not in DataLoader.VALID_DAMAGE_TYPES or damage_type == "none":
			return "Next weapon-hit grant contains an unsupported matcher or damage type."
		if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) != floor(float(amount)) or int(amount) < 1 or int(amount) > 100:
			return "Next weapon-hit grant amount is invalid."
		if not (expiry is int or expiry is float) or not is_finite(float(expiry)) or float(expiry) != floor(float(expiry)) or int(expiry) < 1:
			return "Next weapon-hit grant deadline is invalid."
		if seen_grants.has(grant_id):
			return "Next weapon-hit grant identity is duplicated."
		seen_grants[grant_id] = true
		maximum_order = maxi(maximum_order, int(order))
		if int(expiry) > campaign_seconds:
			if active_sources.has(source_id):
				return "A source has more than one active next weapon-hit grant."
			active_sources[source_id] = true
	if int(saved_serial) < maximum_order:
		return "Next weapon-hit grant serial would reuse a saved acquisition order."
	return ""


static func saved_timed_temporary_hp_error(data: Dictionary, campaign_seconds: int) -> String:
	var carries_new_state := data.has("timed_temporary_hp_grant_serial") or data.has("timed_temporary_hp_grants") or data.has("timed_temporary_hp_current_grant_id")
	if carries_new_state and (not data.has("timed_temporary_hp_grant_serial") or not data.has("timed_temporary_hp_grants") or not data.has("timed_temporary_hp_current_grant_id")):
		return "Timed Temporary HP checkpoint state is missing a required field."
	var grants: Variant = data.get("timed_temporary_hp_grants", [])
	if not grants is Array:
		return "Timed Temporary HP grant state is not an array."
	var pools: Variant = data.get("numeric_resource_pools", {})
	if not pools is Dictionary:
		return "Timed Temporary HP source pools are invalid."
	var owner_id := str(data.get("character_id", ""))
	var saved_serial: Variant = data.get("timed_temporary_hp_grant_serial", 0)
	if not _saved_integer(saved_serial, 0, 2147483647):
		return "Timed Temporary HP grant serial is invalid."
	var current_grant_id: Variant = data.get("timed_temporary_hp_current_grant_id", "")
	if not current_grant_id is String:
		return "Timed Temporary HP current grant identity is invalid."
	var current_temp_hp: Variant = data.get("temp_hp", 0)
	if not _saved_integer(current_temp_hp, 0, 100000):
		return "Temporary HP amount is invalid."
	var seen_sources: Dictionary = {}
	var seen_grants: Dictionary = {}
	var maximum_serial := 0
	var current_id_found := str(current_grant_id).is_empty()
	for grant in grants:
		if not grant is Dictionary:
			return "Timed Temporary HP grant must be an object."
		var source_id := str(grant.get("source_instance_id", ""))
		var grant_id := str(grant.get("grant_instance_id", ""))
		var amount: Variant = grant.get("amount", null)
		var expiry: Variant = grant.get("expires_at_seconds", null)
		if owner_id.is_empty() or str(grant.get("owner_id", "")) != owner_id or source_id.is_empty() or grant_id.is_empty():
			return "Timed Temporary HP owner/source/grant identity is invalid."
		var source_pool: Variant = pools.get(source_id, null)
		if not source_pool is Dictionary or str(source_pool.get("owner_id", "")) != owner_id or str(source_pool.get("source_instance_id", "")) != source_id:
			return "Timed Temporary HP source does not own a saved numeric resource pool."
		var prefix := "%s:%s:" % [owner_id, source_id]
		var serial_text := grant_id.get_slice(":", grant_id.get_slice_count(":") - 1)
		if not grant_id.begins_with(prefix) or not serial_text.is_valid_int() or int(serial_text) < 1:
			return "Timed Temporary HP grant identity does not match its owner/source."
		maximum_serial = maxi(maximum_serial, int(serial_text))
		if not _saved_integer(amount, 1, 100000) or not _saved_integer(expiry, 1, 2147483647):
			return "Timed Temporary HP amount or campaign deadline is invalid."
		for field in grant:
			if field not in ["owner_id", "source_instance_id", "grant_instance_id", "amount", "expires_at_seconds"]:
				return "Timed Temporary HP grant contains an unsupported field."
		if seen_sources.has(source_id) or seen_grants.has(grant_id):
			return "Timed Temporary HP source or grant identity is duplicated."
		seen_sources[source_id] = true
		seen_grants[grant_id] = true
		if str(current_grant_id) == grant_id:
			current_id_found = true
			if int(expiry) <= campaign_seconds:
				return "Current timed Temporary HP is past its campaign deadline."
			if int(current_temp_hp) <= 0 or int(current_temp_hp) > int(amount):
				return "Current timed Temporary HP amount does not match its grant."
	if int(saved_serial) < maximum_serial:
		return "Timed Temporary HP serial would reuse a saved identity."
	if not current_id_found or (not str(current_grant_id).is_empty() and int(current_temp_hp) <= 0):
		return "Current Temporary HP grant does not own a positive saved amount."
	return ""

## Character identity.
var character_id: String = ""
var character_name: String = ""
var race_id: String = ""
var class_id: String = ""
## Explicit represented allocation. Empty retains existing single-class state.
var class_levels: Dictionary = {}
var subclass_id: String = ""
## Stable improvement entitlements; saved totals are never replayed on reload.
var feature_choices: Dictionary = {}
## Owner's preselected policy, editable on the sheet even during combat.
var zero_hp_history: Dictionary = {}
var zero_hp_attempt_serial: int = 0
## S-130 source-owned maximum-HP entries keyed by exact source instance.
var max_hp_sources: Dictionary = {}
var barbarian_relentless_rage_enabled: bool = true
## Temporary Beast statistics plus the Druid statistics needed to revert safely.
var wild_shape_state: Dictionary = {}
## Encounter-only borrowed senses; never written to a character checkpoint.
var familiar_senses: Character
var familiar_senses_position := Vector2i.ZERO

## Level and experience.
var level: int = 1
var xp: int = 0

## Ability scores.
var ability_scores: AbilityScores = AbilityScores.new():
	get:
		ability_scores.projection_owner=weakref(self)
		return ability_scores
	set(value):
		ability_scores=value
		ability_scores.projection_owner=weakref(self)

var protection_grants: Array[Dictionary] = []
var protection_selections: Dictionary = {}
var protection_serial: int = 0
var protection_choice_generation: int = 0
var pending_protection_choice: Dictionary = {}

## Hit points.
var max_hp: int = 10
var current_hp: int = 10
var _temp_hp_value: int = 0
var temp_hp: int:
	set(value):
		var next_value := maxi(0, value)
		if next_value <= 0 or next_value != _temp_hp_value:
			timed_temporary_hp_current_grant_id = ""
			linked_temporary_hp = {}
		_temp_hp_value = next_value
	get:
		return _temp_hp_value
var temporary_hp_supply_serial: int = 0
var linked_temporary_hp: Dictionary = {}
var aura_entry_receipts: Dictionary = {}
var aura_protection_selections: Dictionary = {}
var timed_temporary_hp_grant_serial: int = 0
var timed_temporary_hp_grants: Array[Dictionary] = []
var timed_temporary_hp_current_grant_id: String = ""
## Combat-only spell effects that temporarily prevent Hit Point recovery.
var healing_suppression_sources: Dictionary = {}
## Transient combat-only command imposed by the Command spell.
var combat_command: Dictionary = {}
## Skill selected for the transient Guidance spell effect.
var guidance_skill: String = ""
var resistance_damage_type: String = ""
var resistance_last_turn_serial: int = -1
var protection_from_energy_type: String = ""
var protection_from_evil_and_good_sources: Dictionary = {}
var creature_type: String = "humanoid"
var shillelagh_weapon_id: String = ""

## Armor class (calculated from equipment + DEX).
var base_ac: int = 10

## Movement speed in hex tiles per turn.
var speed: int = 6
## Extra movement speeds in feet; ordinary walking continues to use `speed` tiles.
var movement_speeds_feet: Dictionary = {"climb": 0, "swim": 0, "fly": 0}

## Proficiency bonus (scales with level).
var proficiency_bonus: int = 2

## Proficiencies.
var saving_throw_proficiencies: Array[String] = []
var skill_proficiencies: Array[String] = []
var tool_proficiencies: Array[String] = []
var creation_choices: Dictionary = {}
## Ordered acquired classes, pending milestone levels and once-only permanent receipts.
var permanent_progression: Dictionary = {}
var weapon_proficiencies: Array[String] = []
var armor_proficiencies: Array[String] = []

## Racial traits defined in race JSON.
var traits: Array[Dictionary] = []
var darkvision: bool = false
var darkvision_feet: int = 0

## Unlocked class features (list of feature dictionaries from class JSON).
var features: Array[Dictionary] = []

## Spell slots: level -> remaining uses. (e.g., {1: 2, 2: 1})
var spell_slots: Dictionary = {}
## Pact Magic remains its own recoverable pool alongside ordinary slots.
var pact_spell_slots: Dictionary = {}

## Currently concentrating spell info: {"spell_id": String, "targets": Array}
var concentrating_on: Dictionary = {}

## Reaction tracking: available or spent this round.
var reaction_available: bool = true

## Known spells: array of spell IDs.
var known_spells: Array[String] = []
## Campaign-clock deadlines for the first tracked food and water supply units.
var nourishment_until_seconds: int = 0
var hydration_until_seconds: int = 0
## Food and water consumed during the current campaign day, in pounds/gallons.
var food_eaten_today_pounds: float = 0.0
var water_drank_today_gallons: float = 0.0
## Current 2024 Exhaustion condition level and hazard causes that still block
## Long Rest removal until the character consumes a full daily portion.
var exhaustion_level: int = 0
var exhaustion_recovery_blockers: Array[String] = []
var days_without_food: int = 0
## A spellcasting choice is offered at creation and after each class level gain.
var spell_choices_pending: bool = false
var spell_repertoire_state: Dictionary = {}
## Wizard spellbook knowledge is independent from currently prepared spells.
var wizard_spellbook: Array[String] = []
var wizard_spellbook_pending: int = 0
var cleric_spells_trained: bool = false
var cleric_preparation_free_change: bool = false
var cleric_cantrip_replacement_available: bool = false
var wizard_preparation_free_change: bool = false
var wizard_memorize_spell_pending: bool = false
var wizard_mastery_replacement_available: bool = false
var wizard_spell_mastery: Dictionary = {}
var wizard_signature_spells: Array[String] = []
var sorcerer_metamagic_choices: Array[String] = []
var sorcerer_metamagic_pending: int = 0
var sorcerer_metamagic_replacement_available: bool = false
var warlock_invocations: Array[String] = []
var warlock_invocation_pending: int = 0
var warlock_invocation_replacement_available: bool = false
var warlock_mystic_arcanum: Dictionary = {}
var warlock_arcanum_pending_levels: Array[int] = []
var warlock_arcanum_uses: Dictionary = {}
var warlock_arcanum_replacement_available: bool = false
var roll_tokens: Dictionary = {}
var roll_token_generation_serial: int = 0
var damage_wards: Dictionary = {}

## Active conditions (e.g., "blessed", "poisoned"): condition_name -> remaining_turns.
var conditions: Dictionary = {}
## Independent grants; ordinary conditions remain compatible with older saves.
var condition_sources: Dictionary = {}
var spell_effects: Dictionary = {}
var spell_cast_serial: int = 0
## One-shot spell damage queued for the target's next end of turn. Combat only.
var delayed_spell_damage: Array[Dictionary] = []

## Timed numeric modifiers: [{"kind": "stat"/"roll", "key": String,
## "amount": int, "remaining_turns": int}].
var modifiers: Array[Dictionary] = []
## Monotonic identity for durable source-owned campaign-time modifier grants.
var timed_modifier_grant_serial: int = 0
## Cooldowns created when a timed campaign modifier expires or is dismissed.
var campaign_modifier_cooldowns: Array[Dictionary] = []
## Bounded, source-attributed finalized damage from the last 60 campaign seconds.
var recent_damage_history: Array[Dictionary] = []
## Unspent next-melee-hit grants; ordering survives allowed campaign checkpoints.
var next_weapon_hit_grants: Array[Dictionary] = []
var next_weapon_hit_grant_serial: int = 0

## Inventory.
var inventory: Inventory = Inventory.new()

func _init() -> void:
	inventory.owner_character_ref = weakref(self)

## Per-combat/per-rest resource tracking for features.
## feature_id -> remaining uses
var feature_uses: Dictionary = {}
## Source-instance ID -> validated mutable numeric pool DTO.
var numeric_resource_pools: Dictionary = {}
## Recipient-owned captured gifts; giver serial is independent of pool reacquisition.
var captured_grants: Array[Dictionary] = []
var grant_transfer_serial: int = 0
## High-water marks prevent transferred die identities being regenerated after source removal.
var transferred_die_serials: Dictionary = {}

## Whether this character is alive.
var is_alive: bool = true
## Set when Disintegrate reduces this character to 0 HP; only True Resurrection or Wish can restore it.
var disintegrated: bool = false
var corpse_state: Dictionary = {}
var body_death_serial: int = 0
var revival_willing: bool = true
## Explicit character-level permission preference. Unknown never grants eligibility.
var willingness := "unknown"
var body_missing_parts: Array[String] = []
var stable_recovery_at_seconds: int = 0

## Critical hit range (normally 20, Fighter's Improved Critical lowers to 19).
var crit_range: int = 20

## Extra attacks per Attack action (normally 0, Extra Attack gives 1).
var extra_attacks: int = 0

## Saved Fighter choices and preferences; combat target markers are transient.
var fighter_training: Dictionary = {}
## Weapon types with mastery properties trained across eligible classes.
var weapon_masteries: Array[String] = []
var heroic_inspiration: bool = false
var fighter_studied_targets: Array[String] = []
var fighter_studied_previous: Array[String] = []
var death_save_successes: int = 0
var death_save_failures: int = 0
var is_stable: bool = false
var last_save_note: String = ""
## Live combat-only aura sources; positions and owners are rebuilt by CombatState.
var aura_source_memberships: Array[Dictionary] = []
## Live CombatState-owned sources that grant Aura of Life while the character is in range.
var aura_of_life_sources: Array[String] = []
var fiendish_resilience_type: String = ""
var pact_weapon_damage_type: String = ""


## Effective movement speed after timed modifiers.
func get_speed(ignore_restrained: bool = false) -> int:
	if has_condition("resilient_sphere") or has_condition("paralyzed") or (has_condition("restrained") and not ignore_restrained) or has_condition("stunned") or has_condition("power_word_stun_speed_zero"):
		return 0
	if DruidRules.is_shaped(self):
		var form := DruidRules.current_form(self)
		if not form.is_empty():
			return maxi(0, int(floor(float(form.get("speed_feet", 5)) / 5.0)) - exhaustion_level)
	var movement_bonus := 0
	if has_condition("longstrider"):
		movement_bonus += 2
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") != "speed_bonus":
				continue
			if bool(effect.get("requires_unarmored", false)) and not is_unarmored():
				continue
			if bool(effect.get("requires_no_heavy_armor", false)) and _is_wearing_heavy_armor():
				continue
			var table: Dictionary = effect.get("bonus_by_level", {})
			var threshold := 0
			for key in table:
				if int(key) <= level and int(key) > threshold:
					threshold = int(key)
			movement_bonus += int(table[str(threshold)]) if threshold > 0 else int(effect.get("bonus", 0))
	return maxi(0, speed + movement_bonus + SourceBenefitRules.total(self, "speed") + get_modifier("stat", "speed") - exhaustion_level)


func movement_speed_feet(mode: String = "walk", ignore_restrained: bool = false) -> int:
	if mode == "walk": return get_speed(ignore_restrained) * 5
	if mode not in ["climb", "swim", "fly"]: return 0
	if get_speed(ignore_restrained) <= 0: return 0
	if mode == "fly" and SpellEffects.has_spell(self, "fly"): return 60
	if mode == "climb" and SpellEffects.has_spell(self, "spider_climb"): return movement_speed_feet("walk", ignore_restrained)
	if mode == "swim" and SpellEffects.has_spell(self, "freedom_of_movement"): return movement_speed_feet("walk", ignore_restrained)
	return maxi(0, int(movement_speeds_feet.get(mode, 0)) - exhaustion_level * 5)


func set_movement_speed_feet(mode: String, feet: int) -> void:
	if mode in ["climb", "swim", "fly"] and feet >= 0 and feet % 5 == 0:
		movement_speeds_feet[mode] = feet


func _is_wearing_heavy_armor() -> bool:
	var armor_id := inventory.get_armor()
	return not armor_id.is_empty() and str(DataLoader.get_item(armor_id).get("armor_type", "")) == "heavy"


func get_feature_effect(effect_type: String) -> Dictionary:
	for feature in features:
		for effect in _feature_effects(feature):
			if str(effect.get("type", "")) == effect_type:
				return effect
	return {}


func has_feature_effect(effect_type: String) -> bool:
	return not get_feature_effect(effect_type).is_empty()


func get_weapon_mastery_capacity() -> int:
	var effect := get_feature_effect("weapon_mastery")
	var capacities: Dictionary = effect.get("capacity_by_level", {})
	var threshold := 0
	for key in capacities:
		if int(key) <= level and int(key) > threshold:
			threshold = int(key)
	return int(capacities.get(str(threshold), 0)) if threshold > 0 else 0


## Return a spellcasting limit declared by an owned spellcasting feature.
func get_spellcasting_capacity(kind: String) -> int:
	if kind not in ["cantrips", "prepared_spells"]:
		return 0
	var effect := get_feature_effect("spellcasting")
	var capacities: Dictionary = effect.get("capacity_by_level", {})
	var threshold := 0
	for key in capacities:
		if int(key) <= get_class_level() and int(key) > threshold:
			threshold = int(key)
	if threshold == 0:
		return 0
	var capacity := int(capacities.get(str(threshold), {}).get(kind, 0))
	for option_effect in ClassProgression.selected_feature_effects(self):
		if option_effect.get("type", "") == "spellcasting_capacity_bonus" and option_effect.get("kind", "") == kind:
			capacity += int(option_effect.get("amount", 0))
	return capacity


## Return the feature granting an available once-per-rest free casting.
func free_spell_cast_feature(spell_id: String, preferred_source_id: String = "") -> Dictionary:
	if spell_id.is_empty():
		return {}
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") != "spell_free_cast" or spell_id not in effect.get("spells", []):
				continue
			var feature_id := str(feature.get("id", ""))
			if not preferred_source_id.is_empty() and feature_id != preferred_source_id:
				continue
			var resource_id := _free_spell_cast_resource_id(feature_id)
			var maximum := _spell_free_cast_maximum(effect)
			if maximum > 0 and int(feature_uses.get(resource_id, maximum)) > 0:
				return {"feature_id": feature_id, "resource_id": resource_id, "effect": effect}
	for effect in ClassProgression.selected_feature_effects(self):
		if effect.get("type", "") != "spell_free_cast" or spell_id not in effect.get("spells", []) or not bool(effect.get("at_will", false)):
			continue
		var invocation_id := str(effect.get("invocation_selection", "warlock_invocation"))
		if preferred_source_id.is_empty() or invocation_id == preferred_source_id:
			return {"feature_id": invocation_id, "resource_id": "", "effect": effect}
	if class_id == "wizard":
		var mastery_spell_level := int(DataLoader.get_spell(spell_id).get("level", 0))
		if (preferred_source_id.is_empty() or preferred_source_id == "wizard_spell_mastery") and has_feature("wizard_spell_mastery") and str(wizard_spell_mastery.get(str(mastery_spell_level), "")) == spell_id and mastery_spell_level in [1, 2]:
			return {"feature_id": "wizard_spell_mastery", "resource_id": "", "effect": {"at_will": true, "lowest_level_only": true}}
		if has_feature("wizard_signature_spells") and spell_id in wizard_signature_spells:
			var signature_resource := "wizard_signature_spell:%s" % spell_id
			if (preferred_source_id.is_empty() or preferred_source_id == "wizard_signature_spells") and int(feature_uses.get(signature_resource, 1)) > 0:
				return {"feature_id": "wizard_signature_spells", "resource_id": signature_resource, "effect": {"uses": 1, "uses_per": "short_or_long_rest"}}
	return {}


func _spell_free_cast_maximum(effect: Dictionary, at_level: int = -1) -> int:
	var resolved_level := level if at_level < 0 else at_level
	var maximum := int(effect.get("uses", 1))
	var uses_by_level: Dictionary = effect.get("uses_by_level", {})
	var threshold := 0
	for key in uses_by_level:
		if int(key) <= resolved_level and int(key) > threshold:
			threshold = int(key)
	if threshold > 0:
		maximum = int(uses_by_level[str(threshold)])
	return maximum


func has_free_spell_cast(spell_id: String) -> bool:
	return not free_spell_cast_feature(spell_id).is_empty()


func spend_free_spell_cast(spell_id: String, preferred_source_id: String = "") -> bool:
	var available := free_spell_cast_feature(spell_id, preferred_source_id)
	if available.is_empty():
		return false
	if bool(available.get("effect", {}).get("at_will", false)):
		return true
	var resource_id := str(available.get("resource_id", ""))
	feature_uses[resource_id] = int(feature_uses.get(resource_id, int(available.get("effect", {}).get("uses", 1)))) - 1
	return true


func restore_free_spell_cast(spell_id: String, preferred_source_id: String = "") -> bool:
	if spell_id.is_empty():
		return false
	if class_id == "wizard" and (preferred_source_id.is_empty() or preferred_source_id == "wizard_signature_spells") and has_feature("wizard_signature_spells") and spell_id in wizard_signature_spells:
		var signature_resource := "wizard_signature_spell:%s" % spell_id
		feature_uses[signature_resource] = 1
		return true
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") != "spell_free_cast" or spell_id not in effect.get("spells", []):
				continue
			var feature_id := str(feature.get("id", ""))
			if not preferred_source_id.is_empty() and feature_id != preferred_source_id:
				continue
			var resource_id := _free_spell_cast_resource_id(feature_id)
			var maximum := _spell_free_cast_maximum(effect)
			feature_uses[resource_id] = mini(maximum, int(feature_uses.get(resource_id, 0)) + 1)
			return true
	return false


static func _free_spell_cast_resource_id(feature_id: String) -> String:
	return "free_spell_cast:%s" % feature_id


func get_spellcasting_feature_id() -> String:
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") == "spellcasting":
				return str(feature.get("id", ""))
	return ""


func get_spell_list_ids(for_cantrips: bool = false) -> Array:
	var list_ids: Array = []
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") not in ["spellcasting", "spell_list_expansion"]:
				continue
			if for_cantrips and bool(effect.get("level_1_plus_only", false)):
				continue
			for list_id in effect.get("spell_lists", []):
				if list_id not in list_ids:
					list_ids.append(list_id)
	for effect in ClassProgression.selected_feature_effects(self):
		if effect.get("type", "") != "spell_list_expansion":
			continue
		if for_cantrips and bool(effect.get("level_1_plus_only", false)):
			continue
		for list_id in effect.get("spell_lists", []):
			if list_id not in list_ids:
				list_ids.append(list_id)
	return list_ids


func get_spell_option_ids(cantrips: bool) -> Array[String]:
	var options: Array[String] = []
	var maximum_spell_level := get_max_spell_slot_level()
	if class_id == "wizard" and not cantrips:
		for spell_id in wizard_spellbook:
			var book_spell := DataLoader.get_spell(spell_id)
			var spell_level := int(book_spell.get("level", -1))
			if spell_level >= 1 and spell_level <= maximum_spell_level and (SpellSupport.is_available(book_spell) or spell_id in known_spells):
				options.append(spell_id)
		return options
	for spell in DataLoader.get_spell_list_options(get_spell_list_ids(cantrips)):
		if not SpellSupport.is_available(spell) and str(spell.get("id", "")) not in known_spells:
			continue
		var spell_level := int(spell.get("level", -1))
		if cantrips and spell_level != 0:
			continue
		if not cantrips and (spell_level < 1 or spell_level > maximum_spell_level):
			continue
		options.append(str(spell.get("id", "")))
	return options


func get_spell_permissions(spell_id: String) -> Array[Dictionary]:
	return SpellPermissionRules.for_spell(self, DataLoader.get_spell(spell_id))


func get_max_spell_slot_level() -> int:
	var class_data := DataLoader.get_character_class(class_id)
	var source_level := get_class_level()
	var pact_table: Dictionary = class_data.get("pact_magic_by_level", {})
	if pact_table.has(str(source_level)):
		return int(pact_table[str(source_level)].get("slot_level", 0))
	var table: Dictionary = class_data.get("spell_slots_by_character_level", {})
	if table.has(str(source_level)):
		var slots: Array = table[str(source_level)]
		for index in range(slots.size() - 1, -1, -1):
			if int(slots[index]) > 0:
				return index + 1
	return 0


func refresh_spell_selection_from_choices() -> void:
	SpellRepertoireRules.prune_removed(self)
	var spellcasting_id := get_spellcasting_feature_id()
	if spellcasting_id.is_empty() or not feature_choices.has(spellcasting_id):
		_append_warlock_arcanum_spells()
		_append_separate_repertoires()
		return
	known_spells.clear()
	for spell_id in feature_choices[spellcasting_id]:
		var id := str(spell_id)
		if class_id == "wizard" and int(DataLoader.get_spell(id).get("level", 0)) > 0 and id not in wizard_spellbook:
			continue
		if id not in known_spells:
			known_spells.append(id)
	_append_always_prepared_spells()
	_append_warlock_arcanum_spells()
	_append_separate_repertoires()

func _append_separate_repertoires() -> void:
	for source in SpellRepertoireRules.sources(self):
		for id in feature_choices.get(source.id, []):
			if str(id) not in known_spells and not SpellRepertoireRules.permissions(self, DataLoader.get_spell(str(id))).is_empty(): known_spells.append(str(id))


func _append_warlock_arcanum_spells() -> void:
	if class_id != "warlock":
		return
	var spell_ids: Array = warlock_mystic_arcanum.values()
	for effect in WarlockRules.selected_invocation_effects(self):
		if effect.get("type", "") == "spell_free_cast":
			spell_ids.append_array(effect.get("spells", []))
	for spell_id in spell_ids:
		var id := str(spell_id)
		if not id.is_empty() and not DataLoader.get_spell(id).is_empty() and id not in known_spells:
			known_spells.append(id)


func _append_always_prepared_spells() -> void:
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") != "always_prepared_spells":
				continue
			for spell_id in effect.get("spells", []):
				var id := str(spell_id)
				if not DataLoader.get_spell(id).is_empty() and id not in known_spells:
					known_spells.append(id)
	if class_id == "wizard":
		if has_feature("wizard_spell_mastery"):
			for spell_id in wizard_spell_mastery.values():
				if not DataLoader.get_spell(str(spell_id)).is_empty() and str(spell_id) not in known_spells:
					known_spells.append(str(spell_id))
		if has_feature("wizard_signature_spells"):
			for spell_id in wizard_signature_spells:
				if not DataLoader.get_spell(spell_id).is_empty() and spell_id not in known_spells:
					known_spells.append(spell_id)


func _restore_wizard_signature_spells() -> void:
	if class_id != "wizard" or not has_feature("wizard_signature_spells"):
		return
	for spell_id in wizard_signature_spells:
		feature_uses["wizard_signature_spell:%s" % spell_id] = 1


func _feature_effects(feature: Dictionary) -> Array:
	var effects: Array = feature.get("effects", []).duplicate()
	effects.append_array(feature.get("passive_effects", []))
	return effects


func get_skill_check_ability(default_ability: String, skill: String, use_primal_knowledge: bool = true) -> String:
	for feature in features:
		if str(feature.get("id", "")) == "barbarian_primal_knowledge" and not use_primal_knowledge:
			continue
		for effect in _feature_effects(feature):
			if effect.get("type", "") != "ability_check_override" or skill not in effect.get("skills", []):
				continue
			var condition := str(effect.get("condition", ""))
			var excluded := str(effect.get("unless_condition", ""))
			if (condition.is_empty() or has_condition(condition)) and (excluded.is_empty() or not has_condition(excluded)):
				return str(effect.get("ability", default_ability))
	return default_ability


func get_skill_proficiency_bonus(skill: String) -> int:
	if skill.is_empty():
		return 0
	var multiplier := 1 if skill in skill_proficiencies or (class_id == "warlock" and WarlockRules.has_invocation(self, "beguiling_influence") and skill in ["Deception", "Persuasion"]) else 0
	for feature_id in ClassProgression.skill_expertise_choice_ids(self):
		var choice: Variant = feature_choices.get(feature_id, [])
		if skill in choice:
			multiplier = 2
	if PermanentProgressionRules.expertise(self, skill): multiplier = 2
	if multiplier == 0 and has_feature_effect("jack_of_all_trades"):
		return int(floor(float(proficiency_bonus) / 2.0))
	return proficiency_bonus * multiplier


func get_skill_check_modifier(skill: String, ability: String) -> int:
	var modifier := ability_scores.get_ability_modifier(ability)
	modifier += get_skill_proficiency_bonus(skill)
	modifier += get_ability_check_bonus(skill, ability)
	if class_id == "familiar":
		var creature_skills: Dictionary = feature_uses.get("creature_skills", {})
		if creature_skills.has(skill):
			modifier = int(creature_skills[skill])
	if class_id == "druid" and DruidRules.is_shaped(self):
		var form := DruidRules.current_form(self)
		var form_skills: Dictionary = form.get("skills", {})
		if form_skills.has(skill):
			modifier = maxi(modifier, int(form_skills[skill]))
	return modifier - exhaustion_level * 2


func get_creature_type() -> String:
	if class_id == "familiar": return str(feature_uses.get("creature_type", "fey"))
	if DruidRules.is_shaped(self): return "beast"
	if not creature_type.is_empty() and creature_type != "humanoid": return creature_type
	return str(DataLoader.get_race(race_id).get("creature_type", "humanoid"))


func get_creature_size() -> String:
	if class_id == "created_creature": return str(feature_uses.get("creature_size", "medium"))
	if class_id == "familiar": return str(feature_uses.get("creature_size", "large" if has_feature("find_steed_slam") else "tiny")).to_lower()
	if DruidRules.is_shaped(self): return str(DruidRules.current_form(self).get("size", "medium")).to_lower()
	return str(DataLoader.get_race(race_id).get("size", "medium")).to_lower()


func get_ability_check_bonus(skill: String, check_ability: String = "") -> int:
	var bonus := 0
	for effect in ClassProgression.selected_feature_effects(self):
		if effect.get("type", "") != "ability_check_bonus" or skill not in effect.get("skills", []):
			continue
		if not check_ability.is_empty() and effect.has("check_ability") and str(effect["check_ability"]) != check_ability:
			continue
		bonus += maxi(int(effect.get("minimum_bonus", 0)), ability_scores.get_ability_modifier(str(effect.get("ability", "INT"))))
	return bonus


func has_ability_check_advantage(ability: String) -> bool:
	if SpellEffects.has_enhance_ability_advantage(self, ability):
		return true
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") != "ability_check_advantage" or str(effect.get("ability", "")).to_upper() != ability.to_upper():
				continue
			var condition := str(effect.get("condition", ""))
			var excluded := str(effect.get("unless_condition", ""))
			if (condition.is_empty() or has_condition(condition)) and (excluded.is_empty() or not has_condition(excluded)):
				return true
	return false


func has_darkvision() -> bool:
	return darkvision or darkvision_feet > 0 or SpellEffects.has_spell(self, "darkvision")


func has_trait(trait_id: String) -> bool:
	for trait_data in traits:
		if str(trait_data.get("id", "")) == trait_id:
			return true
	return false


func add_nourishment(days: int = 1) -> void:
	var now := int(GameManager.campaign_elapsed_seconds)
	var food_days := maxi(1, days)
	food_eaten_today_pounds += SurvivalRules.food_need_for_character(self) * float(food_days)
	nourishment_until_seconds = maxi(nourishment_until_seconds, now) + food_days * 86400
	days_without_food = 0
	remove_exhaustion_recovery_blocker("malnutrition")


func record_food_intake(pounds: float) -> void:
	if pounds <= 0.0:
		return
	food_eaten_today_pounds += pounds
	days_without_food = 0
	if food_eaten_today_pounds >= SurvivalRules.food_need_for_character(self):
		var now := int(GameManager.campaign_elapsed_seconds)
		nourishment_until_seconds = maxi(nourishment_until_seconds, now + 86400)
		remove_exhaustion_recovery_blocker("malnutrition")


func add_hydration(days: int = 1) -> void:
	var now := int(GameManager.campaign_elapsed_seconds)
	var water_days := maxi(1, days)
	water_drank_today_gallons += SurvivalRules.water_need_for_character(self) * float(water_days)
	hydration_until_seconds = maxi(hydration_until_seconds, now) + water_days * 86400
	remove_exhaustion_recovery_blocker("dehydration")


func record_water_intake(gallons: float) -> void:
	if gallons <= 0.0:
		return
	water_drank_today_gallons += gallons
	if water_drank_today_gallons >= SurvivalRules.water_need_for_character(self):
		var now := int(GameManager.campaign_elapsed_seconds)
		hydration_until_seconds = maxi(hydration_until_seconds, now + 86400)
		remove_exhaustion_recovery_blocker("dehydration")


func gain_exhaustion(source: String) -> void:
	if exhaustion_level >= 6:
		return
	exhaustion_level += 1
	conditions["exhaustion"] = exhaustion_level
	if source in ["malnutrition", "dehydration"] and source not in exhaustion_recovery_blockers:
		exhaustion_recovery_blockers.append(source)
	if exhaustion_level >= 6:
		CorpseRules.mark_dead(self, "exhaustion")


func remove_exhaustion_recovery_blocker(source: String) -> void:
	exhaustion_recovery_blockers.erase(source)


func apply_feature_check_floor(total: int, ability: String, check_type: String) -> int:
	var result := total
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") != "ability_check_floor" or str(effect.get("ability", "")).to_upper() != ability.to_upper() or check_type not in effect.get("applies_to", []):
				continue
			if effect.has("minimum_roll"):
				continue
			var condition := str(effect.get("condition", ""))
			var excluded := str(effect.get("unless_condition", ""))
			if (condition.is_empty() or has_condition(condition)) and (excluded.is_empty() or not has_condition(excluded)):
				result = maxi(result, ability_scores.get_score(ability))
	return result


func apply_skill_check_roll_floor(roll: int, skill: String) -> int:
	var result := roll
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") != "ability_check_floor" or "ability_check" not in effect.get("applies_to", []) or not effect.has("minimum_roll"):
				continue
			if bool(effect.get("requires_proficiency", false)) and get_skill_proficiency_bonus(skill) <= 0:
				continue
			var condition := str(effect.get("condition", ""))
			var excluded := str(effect.get("unless_condition", ""))
			if (condition.is_empty() or has_condition(condition)) and (excluded.is_empty() or not has_condition(excluded)):
				result = maxi(result, int(effect.get("minimum_roll", 1)))
	return result


func is_unarmored() -> bool:
	return inventory.get_armor().is_empty() and inventory.get_equipped(Inventory.Slot.SHIELD).is_empty()


func is_monk_weapon(weapon: Dictionary) -> bool:
	var properties: Array = weapon.get("properties", [])
	return str(weapon.get("type", "")) == "weapon" and "ranged" not in properties and (str(weapon.get("weapon_type", "")) == "simple" or "light" in properties)


func can_use_martial_arts() -> bool:
	if not has_feature("monk_martial_arts") or not is_unarmored():
		return false
	var weapon_id := inventory.get_weapon()
	return weapon_id.is_empty() or is_monk_weapon(DataLoader.get_item(weapon_id))


func get_martial_arts_die() -> String:
	return MonkRules.get_martial_arts_die(level)


func get_max_focus_points() -> int:
	return level if class_id == "monk" and has_feature("monk_monk's_focus") and level >= 2 else 0


func get_focus_points() -> int:
	return clampi(int(feature_uses.get("focus_points", 0)), 0, get_max_focus_points())


func spend_focus_points(amount: int) -> bool:
	if amount < 0 or amount > get_focus_points():
		return false
	feature_uses["focus_points"] = get_focus_points() - amount
	return true


func _sync_focus_points(previous_maximum: int = 0) -> void:
	var maximum := get_max_focus_points()
	if maximum > 0:
		feature_uses["focus_points"] = mini(maximum, int(feature_uses.get("focus_points", 0)) + maxi(0, maximum - previous_maximum))


func use_uncanny_metabolism() -> Dictionary:
	if not has_feature("monk_uncanny_metabolism") or int(feature_uses.get("uncanny_metabolism_used", 0)) > 0:
		return {"success": false}
	feature_uses["uncanny_metabolism_used"] = 1
	feature_uses["focus_points"] = get_max_focus_points()
	var healing := mini(max_hp - current_hp, level + Dice.parse_dice_string(get_martial_arts_die()))
	healing = heal(healing)
	return {"success": true, "healing": healing, "message": "%s recovers all Focus and %d HP with Uncanny Metabolism." % [character_name, healing]}


## Initialize a character from race and class data.
func initialize(p_name: String, p_race_id: String, p_class_id: String, scores: AbilityScores, starting_equipment_choice: String = "equipment", selected_creation_choices: Dictionary = {}) -> void:
	if not permanent_progression.is_empty(): return # Creation is not a repeatable acquisition.
	var managed := PermanentProgressionRules.enabled(p_class_id)
	if managed:
		var definition := DataLoader.get_character_class(p_class_id)
		if not PermanentProgressionRules.definition_error(definition).is_empty(): return
		var initial := PermanentProgressionRules.expected_receipts([p_class_id])
		if not PermanentProgressionRules.can_fit(self, initial): return
	var choices := selected_creation_choices.duplicate(true)
	if not managed and p_class_id in ["bard", "cleric"]:
		if choices.is_empty():
			choices = ClassProgression.default_creation_choices(p_class_id, p_race_id)
		choices["equipment"] = starting_equipment_choice
		if not ClassProgression.creation_choices_error(p_class_id, p_race_id, choices).is_empty():
			return # Validate before changing character or granting inventory.
	spell_repertoire_state.clear()
	character_name = p_name
	race_id = p_race_id
	class_id = p_class_id
	ability_scores = scores
	level = 1

	var race_data := DataLoader.get_race(race_id)
	var class_data := DataLoader.get_character_class(class_id)
	weapon_proficiencies.assign([] if managed else class_data.get("weapon_proficiencies", []))
	armor_proficiencies.assign([] if managed else class_data.get("armor_proficiencies", []))

	# Apply racial bonuses
	ability_scores.apply_racial_bonuses(race_data)

	# Apply racial traits
	speed = int(race_data.get("speed", 6))
	var racial_proficiencies: Array = race_data.get("proficiencies", [])
	for prof in racial_proficiencies:
		if prof not in skill_proficiencies:
			skill_proficiencies.append(str(prof))
	traits.clear()
	var raw_traits: Array = race_data.get("traits", [])
	for trait_val in raw_traits:
		if trait_val is Dictionary:
			traits.append(trait_val.duplicate(true))
	darkvision = bool(race_data.get("darkvision", false))
	darkvision_feet = int(race_data.get("darkvision_feet", 0))
	if darkvision and darkvision_feet == 0:
		darkvision_feet = 60
	for trait_data in traits:
		var trait_id := str(trait_data.get("id", "")).to_lower()
		var trait_name := str(trait_data.get("name", "")).to_lower()
		if "darkvision" in trait_id or "darkvision" in trait_name:
			darkvision = true
			if darkvision_feet == 0:
				var desc := str(trait_data.get("description", ""))
				darkvision_feet = 120 if "120" in desc else 60
		for effect in trait_data.get("effects", []):
			var effect_type := str(effect.get("type", ""))
			if effect_type == "vision_bonus":
				darkvision = true
				if darkvision_feet == 0:
					darkvision_feet = 60
			elif effect_type == "weapon_proficiency":
				for weapon_id in effect.get("weapons", []):
					if str(weapon_id) not in weapon_proficiencies:
						weapon_proficiencies.append(str(weapon_id))
			elif effect_type == "armor_proficiency":
				for armor_id in effect.get("armor", []):
					if str(armor_id) not in armor_proficiencies:
						armor_proficiencies.append(str(armor_id))

	# Apply class base stats
	saving_throw_proficiencies.assign([] if managed else class_data.get("saving_throw_proficiencies", []))
	creation_choices = choices
	if not choices.is_empty():
		for skill in choices.get("skills", []):
			if str(skill) not in skill_proficiencies:
				skill_proficiencies.append(str(skill))
		tool_proficiencies.assign(choices.get("tools", []))

	# Starting equipment
	var starting_equipment: Array = [] if managed else class_data.get("starting_equipment", []).duplicate()
	if not managed and class_id == "bard":
		starting_equipment.append(str(choices.get("instrument", "lute")))
	if not managed and class_id == "barbarian" and starting_equipment_choice == "gold":
		inventory.gold = 75
	elif not managed and class_id in ["bard", "cleric"] and starting_equipment_choice == "gold":
		inventory.gold = int(class_data.get("starting_gold_alternative", 90))
	else:
		inventory.add_starting_equipment(starting_equipment)
		inventory.gold = 0 if managed else int(class_data.get("starting_gold", 0))

	# Calculate initial HP: hit die max + CON modifier
	var hit_die_sides := _parse_hit_die(class_data.get("hit_die", "d8"))
	max_hp = hit_die_sides + AbilityScores.get_modifier(ability_scores.get_permanent_score("CON"))
	max_hp = maxi(max_hp, 1)
	current_hp = max_hp
	disintegrated = false
	corpse_state.clear()
	body_death_serial = 0
	revival_willing = true
	willingness = "unknown"
	body_missing_parts.clear()

	if managed: PermanentProgressionRules.initialize(self)
	if not managed: FighterRules.initialize_training(self)
	if not managed and class_id == "fighter":
		FighterRules.choose_skills(self, "Athletics", "Perception")
	# Unlock level 1 features
	_unlock_features_for_level(1)
	weapon_masteries.clear()
	if not managed and class_id == "fighter":
		for mastery_id in fighter_training.get("masteries", []):
			weapon_masteries.append(str(mastery_id))
	_initialize_spell_access()
	_update_spell_slots()
	_sync_sorcery_points()
	_sync_focus_points()

	# Calculate AC
	_recalculate_ac()


## Level up this character (milestone-based).
func level_up() -> void:
	if PermanentProgressionRules.enabled(class_id):
		PermanentProgressionRules.request_level(self)
		return
	if not class_levels.is_empty():
		push_warning("Explicit class allocations require an authored level update; native leveling is unavailable.")
		return
	var previous_focus_maximum := get_max_focus_points()
	if level >= 20:
		return
	var previous_maxima := {}
	for feature in features:
		if feature.get("type", "") in ["active", "triggered", "resource"]:
			var pool := str(feature.get("resource_id", feature["id"]))
			previous_maxima[pool] = maxi(0, get_feature_max_uses(pool))
		for effect in _feature_effects(feature):
			if effect.get("type", "") == "spell_free_cast":
				var free_cast_pool := _free_spell_cast_resource_id(str(feature.get("id", "")))
				previous_maxima[free_cast_pool] = _spell_free_cast_maximum(effect)
	level += 1
	if class_id == "cleric":
		cleric_cantrip_replacement_available = true
	proficiency_bonus = 2 + int(floor(float(level - 1) / 4.0))

	var class_data := DataLoader.get_character_class(class_id)
	var hit_die_sides := _parse_hit_die(class_data.get("hit_die", "d8"))

	# HP increase: roll hit die (or average) + CON modifier
	var hp_roll := Dice.roll(hit_die_sides, self)
	var con_mod := AbilityScores.get_modifier(ability_scores.get_permanent_score("CON"))
	var hp_gain := maxi(hp_roll + con_mod, 1)
	max_hp += hp_gain
	if is_alive and not is_dead(): current_hp = max_hp  # Living characters retain the existing level-up heal.

	# Unlock new features
	_unlock_features_for_level(level)
	if class_id == "wizard":
		wizard_spellbook_pending += 2
	if class_id == "sorcerer" and level == 2:
		sorcerer_metamagic_pending += 2
	if class_id == "sorcerer":
		sorcerer_metamagic_replacement_available = true
		if level in [10, 17]:
			sorcerer_metamagic_pending += 2
	if class_id == "warlock":
		warlock_invocation_replacement_available = true
		warlock_arcanum_replacement_available = true
		warlock_invocation_pending = maxi(0, WarlockRules.invocation_capacity(level) - warlock_invocations.size())
		if level in [11, 13, 15, 17]:
			var arcanum_level := int((level + 1) / 2)
			if str(arcanum_level) not in warlock_mystic_arcanum:
				warlock_arcanum_pending_levels.append(arcanum_level)
	_add_spells_for_level(level)
	_append_always_prepared_spells()
	spell_choices_pending = not get_spellcasting_feature_id().is_empty()

	# Update spell slots if caster
	_update_spell_slots()
	_sync_sorcery_points(true)
	_sync_focus_points(previous_focus_maximum)
	for id in previous_maxima:
		if str(id).begins_with("free_spell_cast:"):
			for feature in features:
				if _free_spell_cast_resource_id(str(feature.get("id", ""))) != str(id):
					continue
				for effect in _feature_effects(feature):
					if effect.get("type", "") == "spell_free_cast":
						var free_maximum := _spell_free_cast_maximum(effect)
						feature_uses[id] = clampi(int(feature_uses.get(id, 0)) + maxi(0, free_maximum - int(previous_maxima[id])), 0, free_maximum)
						break
				break
			continue
		if has_feature(id):
			var maximum := get_feature_max_uses(id)
			# Newly unlocked pools were initialized by feature acquisition.
			feature_uses[id] = clampi(int(feature_uses.get(id, 0)) + maxi(0, maximum - int(previous_maxima[id])), 0, maximum)
	if class_id == "fighter":
		fighter_training["style_swap"] = true
	WardRules.sync_pools_on_level_up(self)

	print("[Character] %s leveled up to %d! (+%d HP, now %d)" % [character_name, level, hp_gain, max_hp])


## Unlock class features for a specific level.
func _unlock_features_for_level(lvl: int, acquiring: bool = true) -> void:
	var class_data := DataLoader.get_character_class(class_id)
	if acquiring and subclass_id.is_empty() and lvl >= int(class_data.get("subclass_level", 3)):
		var available := DataLoader.get_subclasses_for_class(class_id)
		if available.size() == 1:
			subclass_id = str(available[0]["id"])
	var gained: Array[Dictionary] = []
	for source in [class_data, DataLoader.get_subclass(subclass_id)]:
		for feature in source.get("features_by_level", {}).get(str(lvl), []):
			if not has_feature(str(feature["id"])):
				var granted: Dictionary = feature.duplicate(true) if feature.get("type") == "zero_hp_replacement" else feature
				features.append(granted)
				gained.append(granted)
	for feature in gained:
		_apply_passive_feature(feature, acquiring)
		if acquiring and feature.get("type", "") == "passive" and feature.has("resource_pool"):
			var carries_save_bonus := false
			for effect in feature.get("passive_effects", []):
				if effect is Dictionary and str(effect.get("type", "")) in ["failed_save_numeric_bonus", "ability_check_numeric_bonus"]:
					carries_save_bonus = true
					break
			if carries_save_bonus:
				var source_id := str(feature.get("source_instance_id", feature.get("id", "")))
				var acquired := ResourcePoolRules.acquire(self, feature, source_id)
				if not acquired.get("success", false):
					push_warning("[Character] Could not acquire passive save-bonus pool '%s': %s" % [source_id, str(acquired.get("message", "unknown error"))])
		if acquiring and feature.get("type", "") in ["active", "triggered", "resource"]:
			var pool := str(feature.get("resource_id", feature["id"]))
			if not feature_uses.has(pool):
				feature_uses[pool] = get_feature_max_uses(pool)
	if acquiring and not gained.is_empty():
		RollTokenRules.sync_pools_on_acquire(self)
		WardRules.sync_pools_on_acquire(self)


## Apply effects of passive features.
func _apply_passive_feature(feature: Dictionary, acquiring: bool = true) -> void:
	if feature.get("type", "") != "passive":
		return

	var effects: Array = _feature_effects(feature)
	for effect in effects:
		var effect_type: String = effect.get("type", "")
		match effect_type:
			"spell_free_cast":
				if acquiring:
					feature_uses[_free_spell_cast_resource_id(str(feature.get("id", "")))] = _spell_free_cast_maximum(effect)
			"modify_crit_range":
				crit_range = int(effect.get("value", 20))
			"extra_attack":
				extra_attacks += int(effect.get("count", 1))
			"ability_score_increase":
				if acquiring:
					ClassProgression.apply_fixed_score_increase(self, effect)


static func saved_class_levels_error(data: Dictionary) -> String:
	var allocation: Variant = data.get("class_levels", {})
	if not allocation is Dictionary or allocation.size() > 12: return "Class levels must be a bounded allocation."
	if allocation.is_empty(): return ""
	var total := 0
	for key in allocation:
		if not key is String or DataLoader.get_character_class(key).is_empty() or not ResourcePoolRules._integer(allocation[key], 1, 20): return "Class allocation contains an unknown class or invalid level."
		total += int(allocation[key])
	if not allocation.has(str(data.get("class_id", ""))) or not ResourcePoolRules._integer(data.get("level"), 1, 20) or total != int(data.level): return "Class allocation must include the primary class and sum to character level."
	return ""


static func saved_pact_spell_slots_error(data: Dictionary) -> String:
	if not data.has("pact_spell_slots"): return ""
	var saved: Variant = data.get("pact_spell_slots")
	if not saved is Dictionary: return "Pact spell slots are not an object"
	var allocation: Dictionary = data.get("class_levels", {}).duplicate(true)
	if allocation.is_empty(): allocation[str(data.get("class_id", ""))] = int(data.get("level", 0))
	var maximum := {}
	for class_id in allocation:
		var class_data := DataLoader.get_character_class(str(class_id))
		var table: Dictionary = class_data.get("pact_magic_by_level", {})
		var row: Dictionary = table.get(str(int(allocation[class_id])), {})
		if not row.is_empty():
			maximum = {str(int(row.get("slot_level", 1))):int(row.get("slots", 0))}
			break
	if not saved.is_empty() and maximum.is_empty(): return "Pact slots have no acquired Pact Magic source"
	for key in saved:
		if not str(key).is_valid_int() or int(key) < 1 or int(key) > 9 or not saved[key] is int or int(saved[key]) < 0 or int(saved[key]) > int(maximum.get(str(key), 0)):
			return "Pact spell slot count is invalid"
	return ""


## Explicit allocations never borrow character level for a missing class.
func get_class_level(target_class_id: String = "") -> int:
	var normalized := target_class_id.strip_edges()
	if not class_levels.is_empty():
		if not saved_class_levels_error({"class_levels":class_levels,"class_id":class_id,"level":level}).is_empty(): return -1
		return int(class_levels.get(class_id if normalized.is_empty() or normalized == "self" else normalized, 0))
	if normalized.is_empty() or normalized == "self" or normalized == class_id:
		return maxi(0, level)
	return 0


## Return the maximum spell slots dictionary for this character's current class and level.
func get_max_spell_slots() -> Dictionary:
	var class_data := DataLoader.get_character_class(class_id)
	var combined := SpellSlotRules.ordinary_maximum(self)
	if not combined.is_empty():
		return combined
	var pact_table: Dictionary = class_data.get("pact_magic_by_level", {})
	if not pact_table.is_empty():
		var pact_entry: Dictionary = pact_table.get(str(get_class_level(class_id)), {})
		if not pact_entry.is_empty():
			return {str(int(pact_entry.get("slot_level", 1))): int(pact_entry.get("slots", 0))}
	var progression: Dictionary = class_data.get("spell_slots_by_character_level", {})
	if progression.has(str(level)):
		var out := {}
		var counts: Array = progression[str(level)]
		for index in counts.size():
			var count := int(counts[index])
			if count > 0:
				out[str(index + 1)] = count
		return out
	var slot_table: Dictionary = class_data.get("spell_slots_by_level", {})
	var fallback := {}
	for lvl_key in slot_table:
		var lvl_data = slot_table[lvl_key]
		# Data format: { "1": [2], "2": [3], ... } — first element is the slot count.
		var count: int = lvl_data[0] if (typeof(lvl_data) == TYPE_ARRAY and lvl_data.size() > 0) else int(lvl_data)
		fallback[str(lvl_key)] = count
	return fallback


## Update spell slots based on class and level.
func _update_spell_slots() -> void:
	spell_slots = get_max_spell_slots()
	var pact_maximum := SpellSlotRules.pact_maximum(self)
	var ordinary_maximum := SpellSlotRules.ordinary_maximum(self)
	if not pact_maximum.is_empty() and (not ordinary_maximum.is_empty() or class_id != "warlock"):
		pact_spell_slots = pact_maximum
	else:
		pact_spell_slots = {}


## Seed known spells from the production class record. DataLoader supplies the
## curated Crown access table when imported records do not contain mappings.
func _initialize_spell_access() -> void:
	known_spells.clear()
	var spellcasting_id := get_spellcasting_feature_id()
	if not spellcasting_id.is_empty():
		var effect := get_feature_effect("spellcasting")
		var defaults: Array = effect.get("default_cantrips", []).duplicate()
		if class_id == "wizard":
			wizard_spellbook.clear()
			wizard_spellbook_pending = 6
		else:
			defaults.append_array(effect.get("default_prepared_spells", []))
		defaults = defaults.filter(func(id): return SpellSupport.is_available(DataLoader.get_spell(str(id))))
		feature_choices[spellcasting_id] = defaults
		for spell_id in defaults:
			if DataLoader.get_spell(str(spell_id)).is_empty():
				continue
			known_spells.append(str(spell_id))
		if class_id == "warlock":
			warlock_invocation_pending = WarlockRules.invocation_capacity(level)
		_append_always_prepared_spells()
		spell_choices_pending = true
		return
	var class_data := DataLoader.get_character_class(class_id)
	for spell_id in class_data.get("cantrips_known", []):
		if str(spell_id) not in known_spells and not DataLoader.get_spell(str(spell_id)).is_empty():
			known_spells.append(str(spell_id))
	_add_spells_for_level(level)


func _add_spells_for_level(lvl: int) -> void:
	if not get_spellcasting_feature_id().is_empty():
		return
	var class_data := DataLoader.get_character_class(class_id)
	var known_by_level: Dictionary = class_data.get("spells_known_by_level", {})
	for level_key in known_by_level:
		if int(level_key) > lvl:
			continue
		for spell_id in known_by_level[level_key]:
			var id := str(spell_id)
			if id not in known_spells and not DataLoader.get_spell(id).is_empty():
				known_spells.append(id)


## Parse a hit die string like "d10" into the number of sides.
func _parse_hit_die(hit_die: String) -> int:
	if hit_die.begins_with("d") or hit_die.begins_with("D"):
		return hit_die.substr(1).to_int()
	return 8  # Default to d8


## Recalculate armor class from equipment and DEX.
func _equipment_base_ac() -> int:
	var computed_base := 10
	var dex_mod := ability_scores.get_ability_modifier("DEX")
	var armor_id := inventory.get_armor()
	var shield_id := inventory.get_equipped(Inventory.Slot.SHIELD)

	if armor_id.is_empty():
		var unarmored_defense := get_feature_effect("unarmored_defense")
		if not unarmored_defense.is_empty() and (bool(unarmored_defense.get("allows_shield", false)) or shield_id.is_empty()):
			var secondary_ability := str(unarmored_defense.get("ability", "WIS"))
			computed_base = 10 + dex_mod + ability_scores.get_ability_modifier(secondary_ability)
		else:
			# No armor: AC = 10 + DEX
			computed_base = 10 + dex_mod
	else:
		var armor_data := DataLoader.get_item(armor_id)
		var armor_type: String = armor_data.get("armor_type", "light")
		var armor_ac: int = int(armor_data.get("ac", 10))

		match armor_type:
			"light":
				computed_base = armor_ac + dex_mod
			"medium":
				computed_base = armor_ac + mini(dex_mod, 2)
			"heavy":
				computed_base = armor_ac  # No DEX bonus

	# Shield bonus
	var shield_ac: int = 0
	if not shield_id.is_empty():
		var shield_data := DataLoader.get_item(shield_id)
		shield_ac = int(shield_data.get("ac_bonus", 2))

	computed_base += shield_ac

	return computed_base


func _recalculate_ac() -> void:
	if not inventory.get_armor().is_empty() and has_condition("mage_armor"):
		SpellEffects.end_mage_armor_if_armored(self)
	base_ac = _equipment_base_ac()

## Get effective AC (base + conditions/buffs).
func get_ac() -> int:
	if DruidRules.is_shaped(self):
		var form_ac := DruidRules.armor_class(self)
		if form_ac >= 0:
			return form_ac
	var ac := _equipment_base_ac() if not protection_grants.is_empty() else base_ac
	var protection := ProtectionRules.ac(self,ac)
	ac = int(protection.base)
	var armor_id := inventory.get_armor()
	
	# Mage Armor offers the 13 + DEX calculation; retain any better unarmored base.
	if has_condition("mage_armor"):
		if armor_id.is_empty():
			var dex_mod := ability_scores.get_ability_modifier("DEX")
			var shield_ac: int = 0
			var shield_id := inventory.get_equipped(Inventory.Slot.SHIELD)
			if not shield_id.is_empty():
				var shield_data := DataLoader.get_item(shield_id)
				shield_ac = int(shield_data.get("ac_bonus", 2))
			ac = maxi(ac, 13 + dex_mod + shield_ac)

	ac += int(protection.addition)
	# Shield spell grants +5 AC
	if has_condition("shield"):
		ac += 5
	if has_condition("shield_of_faith"):
		ac += 2
	ac += get_modifier("stat", "AC")

	# Defense Fighting Style applies only while armor is worn.
	if FighterRules.has_style(self, "defense") and not armor_id.is_empty():
		ac += 1
	ac += inventory.magic_item_saving_bonus(character_id)
	return SpellEffects.effective_ac(self, ac) + SourceBenefitRules.total(self, "AC")


## Take damage. Returns actual damage dealt after temp HP absorption.
func take_damage(amount: int, accepted_relentless_rage_inspiration: bool = false, critical_hit: bool = false, damage_facts: Dictionary = {}) -> int:
	if amount <= 0 or is_dead():
		return 0

	TemporaryHPRules.prune(self, int(GameManager.campaign_elapsed_seconds))
	var incoming_damage := amount
	var absorbed := mini(amount, maxi(0, temp_hp))
	absorb_temporary_hp(absorbed)
	var hp_damage := amount - absorbed

	if current_hp <= 0:
		# Downed actor taking damage:
		# SRD 5.2.1 p. 18 & Sage Advice Compendium (lines 732-735):
		# Temporary HP absorbs damage but taking damage at 0 HP still inflicts a death
		# saving throw failure (2 on critical hit) or instant death if damage >= max_hp.
		# Full temporary-HP absorption is not immunity or a ward.
		is_stable = false
		stable_recovery_at_seconds = 0
		death_save_successes = 0
		if incoming_damage >= max_hp:
			CorpseRules.mark_dead(self, "massive_damage")
			return hp_damage
		death_save_failures = mini(3, death_save_failures + (2 if critical_hit else 1))
		if death_save_failures >= 3:
			CorpseRules.mark_dead(self, "death_saves")
		return hp_damage

	# Living actor (current_hp > 0):
	if hp_damage <= 0:
		return 0

	var hp_before_damage := current_hp
	current_hp -= hp_damage
	if current_hp <= 0:
		var damage_amount: int = int(damage_facts.get("damage", incoming_damage))
		var dmg_type: String = str(damage_facts.get("damage_type", "untyped"))
		var is_crit: bool = bool(damage_facts.get("critical", critical_hit))
		current_hp = 0
		var damage_decisions: Dictionary = damage_facts.get("decisions", {}) if damage_facts.get("decisions") is Dictionary else {}
		damage_decisions["zero_hp_outright_death"] = hp_damage >= hp_before_damage + max_hp
		var replaced := SharedStepExecutor.resolve_zero_hp_replacement(self, hp_before_damage, damage_amount, dmg_type, is_crit, damage_decisions)
		if replaced:
			damage_facts["zero_hp_replacement_saved"] = true
			damage_facts["replacement_hp"] = current_hp
			return hp_damage
		if class_id == "created_creature":
			is_alive = false
			death_save_failures = 3
			return hp_damage
		if hp_damage < hp_before_damage + max_hp and not ZeroHpAftermathRules.precedes_replacement(self, damage_decisions):
			var relentless := BarbarianRules.attempt_relentless_rage(self, accepted_relentless_rage_inspiration, damage_decisions)
			if relentless.get("success", false):
				return hp_damage
		end_rage()
		is_alive = false
		DruidRules.revert_for_incapacitation(self)
		if hp_damage >= hp_before_damage + max_hp or death_save_failures >= 3:
			CorpseRules.mark_dead(self, "massive_damage" if hp_damage >= hp_before_damage + max_hp else "death_saves")

	return hp_damage


## Apply one resistance halving after the caller has resolved damage reduction.
## Multiple resistance sources don't multiply against one another.
func resist_damage(amount: int, damage_type: String) -> int:
	if amount <= 0:
		return 0
	var raging_resistance := has_condition("raging") and damage_type in ["bludgeoning", "piercing", "slashing"]
	var superior_resistance := has_condition("superior_defense") and damage_type != "force"
	var fiend_resistance := has_feature("fiend_fiendish_resilience") and damage_type != "force" and (fiendish_resilience_type == damage_type or (fiendish_resilience_type.is_empty() and damage_type == "fire"))
	var spell_resistance := protection_from_energy_type == damage_type
	var poison_spell_resistance := has_condition("protection_from_poison") and damage_type == "poison"
	var aura_of_life_resistance := damage_type == "necrotic" and not aura_of_life_sources.is_empty()
	var custom_resistance: bool = (feature_uses.get("damage_resistances", []) is Array) and (damage_type in (feature_uses.get("damage_resistances", []) as Array))
	return int(floor(float(amount) / 2.0)) if raging_resistance or superior_resistance or fiend_resistance or spell_resistance or poison_spell_resistance or aura_of_life_resistance or custom_resistance else amount


## Heal HP.
func heal(amount: int) -> int:
	if amount <= 0 or is_dead() or not healing_suppression_sources.is_empty():
		return 0
	var actual := mini(amount, max_hp - current_hp)
	current_hp += actual
	if current_hp > 0:
		is_alive = true
	if current_hp > 0:
		death_save_successes = 0
		death_save_failures = 0
		is_stable = false
		stable_recovery_at_seconds = 0
	return actual


## Check if this character has proficiency in a saving throw.
func is_proficient_in_save(ability: String) -> bool:
	if has_feature("monk_disciplined_survivor"):
		return true
	if ability.to_upper() in saving_throw_proficiencies:
		return true
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") == "saving_throw_proficiency" and ability.to_upper() in effect.get("abilities", []):
				return true
	return false


## Weapon proficiency can come from a category, a named weapon, or a species feature.
func is_proficient_with_weapon(weapon: Dictionary) -> bool:
	if weapon.is_empty():
		return false
	var weapon_id := str(weapon.get("id", ""))
	var weapon_category := str(weapon.get("weapon_type", ""))
	if weapon_category in weapon_proficiencies or weapon_id in weapon_proficiencies:
		return true
	var owned_features: Array = features.duplicate()
	owned_features.append_array(DataLoader.get_race(race_id).get("features", []))
	for feature in owned_features:
		var effects: Array = feature.get("effects", []) + feature.get("passive_effects", [])
		for effect in effects:
			if str(effect.get("type", "")) == "weapon_proficiency" and weapon_id in effect.get("weapons", []):
				return true
	return false


## Make a saving throw. Returns the total roll.
func make_saving_throw(ability: String, advantage: bool = false, disadvantage: bool = false, decisions: Dictionary = {}) -> int:
	return int(make_saving_throw_result(ability, advantage, disadvantage, decisions).get("total", 0))


## Return the d20 and non-d20 modifiers so a failed D20 Test can be replaced
## without losing proficiency, bonuses, or feature floors.
func make_saving_throw_result(ability: String, advantage: bool = false, disadvantage: bool = false, decisions: Dictionary = {}) -> Dictionary:
	advantage = advantage or _has_saving_throw_advantage(ability)
	if ability.to_upper() == "STR" and has_condition("ray_of_enfeeblement"):
		disadvantage = true
	if ability.to_upper() == "CON" and not concentrating_on.is_empty() and WarlockRules.has_invocation(self, "eldritch_mind"):
		advantage = true
	var d20_details: Dictionary = RollTokenRules.resolve_d20_test(self, "save", advantage, disadvantage, decisions)
	var roll := int(d20_details.get("total", 1))

	var mod := ability_scores.get_ability_modifier(ability)
	if is_proficient_in_save(ability):
		mod += proficiency_bonus
	mod += AuraRules.saving_throw_bonus(self)
	mod += TemporaryHPRules.bonus(self, "save_bonus") + AuraProtectionRules.bonus(self, "save_bonus")
	mod += inventory.magic_item_saving_bonus(character_id)
	var captured_bonus_dice: Array[Dictionary] = []
	if has_condition("blessed"):
		var bless_details := Dice.roll_single_details(4, self)
		var bless_value := int(bless_details.get("total", 0))
		mod += bless_value
		captured_bonus_dice.append({"source": "bless", "sides": 4, "value": bless_value, "sign": 1, "included_in_modifier": false, "applied_before_total_floor": false, "roll": bless_details.duplicate(true)})
	var bane_details := Dice.roll_single_details(4, self) if has_condition("baned") else {}
	var bane_penalty := int(bane_details.get("total", 0)) if not bane_details.is_empty() else 0
	if bane_penalty > 0:
		captured_bonus_dice.append({"source": "bane", "sides": 4, "value": bane_penalty, "sign": -1, "included_in_modifier": false, "applied_before_total_floor": false, "roll": bane_details.duplicate(true)})
	mod -= bane_penalty
	mod += get_modifier("roll", "save")
	mod += get_modifier("roll", "save:%s" % ability.to_upper())
	mod -= exhaustion_level * 2
	var captured_bonus_modifier := 0
	for bonus_die in captured_bonus_dice:
		captured_bonus_modifier += int(bonus_die.get("value", 0)) * int(bonus_die.get("sign", 1))
	var raw_total := roll + mod
	var total := apply_feature_check_floor(raw_total, ability, "saving_throw")
	var out := {
		"natural": roll,
		"natural_roll": roll,
		"rolls": d20_details.get("rolls", [roll]),
		"kept": d20_details.get("kept", [true]),
		"roll_mode": "advantage" if advantage and not disadvantage else ("disadvantage" if disadvantage and not advantage else "normal"),
		"roll_details": d20_details.duplicate(true),
		"modifier": mod,
		"base_modifier": mod - captured_bonus_modifier,
		"check_bonus_dice": captured_bonus_dice,
		"bane_penalty": bane_penalty,
		"raw_total": raw_total,
		"total": total,
		"success": false,
		"ability": ability.to_upper(),
		"floor_applied": total != raw_total,
		"roll_token_replaced": bool(d20_details.get("replaced", false)),
		"replaced_by_roll_token": bool(d20_details.get("replaced", false)),
	}
	if bool(d20_details.get("replaced", false)):
		out["roll_token_id"] = str(d20_details.get("roll_token_id", ""))
		out["roll_token_value"] = int(d20_details.get("roll_token_value", roll))
		out["roll_token_pool_id"] = str(d20_details.get("roll_token_pool_id", ""))
		out["roll_token_owner_id"] = str(d20_details.get("roll_token_owner_id", ""))
	if d20_details.has("roll_token_error"):
		out["roll_token_error"] = str(d20_details["roll_token_error"])
	return out


func _has_saving_throw_advantage(ability: String) -> bool:
	if ability.to_upper() == "WIS" and SpellEffects.has_spell(self, "beacon_of_hope"):
		return true
	if ability.to_upper() == "STR" and bool(feature_uses.get("conjure_animals_strength_advantage", false)):
		return true
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") != "saving_throw_advantage" or str(effect.get("ability", "")).to_upper() != ability.to_upper():
				continue
			var condition := str(effect.get("condition", ""))
			var excluded := str(effect.get("unless_condition", ""))
			var excluded_active := CombatAction.is_incapacitated(self) if excluded == "incapacitated" else has_condition(excluded)
			if (condition.is_empty() or has_condition(condition)) and not excluded_active:
				return true
	return false


## Return the current spell save DC for this character's class.
func get_spellcasting_ability() -> String:
	var ability := str(get_feature_effect("spellcasting").get("ability", "")).to_upper()
	if ability in AbilityScores.ABILITIES:
		return ability
	# Older records and synthetic monster casters may not declare spellcasting.
	return str(DataLoader.get_character_class(class_id).get("primary_ability", "INT"))


func get_spell_save_dc() -> int:
	var spell_stat := get_spellcasting_ability()
	var dc := 8 + ability_scores.get_ability_modifier(spell_stat) + proficiency_bonus
	if has_condition("innate_sorcery"):
		dc += 1
	return dc


## Return the passive attack-style bonus for a weapon.
func get_attack_style_bonus(weapon_data: Dictionary = {}) -> int:
	if FighterRules.has_style(self, "archery") and "ranged" in weapon_data.get("properties", []):
		return 2
	return 0


## Make an attack roll. Returns {"roll": int, "is_crit": bool, "is_miss": bool}.
func make_attack_roll(ability: String = "STR", advantage: bool = false, disadvantage: bool = false, weapon_data: Dictionary = {}, decisions: Dictionary = {}) -> Dictionary:
	if has_condition("blinded") or has_condition("poisoned") or (ability.to_upper() == "STR" and has_condition("ray_of_enfeeblement")):
		disadvantage = true
	var mockery_disadvantage := has_condition("vicious_mockery_disadvantage")
	if mockery_disadvantage:
		disadvantage = true

	var d20_details := RollTokenRules.resolve_d20_test(self, "attack", advantage, disadvantage, decisions)
	var natural_roll := int(d20_details.get("total", 0))
	var roll_results: Array = d20_details.get("rolls", [natural_roll]).duplicate()
	var roll_kept: Array = d20_details.get("kept", [true]).duplicate()
	if mockery_disadvantage:
		remove_condition("vicious_mockery_disadvantage")

	var ability_modifier := ability_scores.get_ability_modifier(ability)
	var mod := int(weapon_data.get("attack_bonus_override", ability_modifier + proficiency_bonus))
	mod -= exhaustion_level * 2
	var is_crit := natural_roll >= (crit_range if not weapon_data.is_empty() else 20)
	var is_miss := natural_roll == 1

	var total := natural_roll + mod
	var style_bonus := get_attack_style_bonus(weapon_data)
	total += style_bonus
	var bonus_dice_terms: Array[Dictionary] = []
	if has_condition("blessed"):
		var bless_roll := Dice.roll(4, self)
		total += bless_roll
		bonus_dice_terms.append({"count": 1, "sides": 4, "results": [bless_roll], "kept": [true], "label": "Bless", "subtotal": bless_roll})
	var bane_penalty := Dice.roll(4, self) if has_condition("baned") else 0
	if bane_penalty > 0:
		total -= bane_penalty
		bonus_dice_terms.append({"count": 1, "sides": 4, "results": [bane_penalty], "kept": [true], "label": "Bane", "subtotal": -bane_penalty})
	var global_attack_modifier := get_modifier("roll", "attack")
	var ability_attack_modifier := get_modifier("roll", "attack:%s" % ability.to_upper())
	total += global_attack_modifier
	total += ability_attack_modifier
	var activity_modifiers: Array[Dictionary] = [
		{"label": ability.to_upper(), "value": ability_modifier},
		{"label": "Proficiency", "value": proficiency_bonus},
	]
	if style_bonus != 0:
		activity_modifiers.append({"label": "Fighting Style", "value": style_bonus})
	if global_attack_modifier != 0:
		activity_modifiers.append({"label": "Attack modifier", "value": global_attack_modifier})
	if ability_attack_modifier != 0:
		activity_modifiers.append({"label": "%s attack modifier" % ability.to_upper(), "value": ability_attack_modifier})
	if bane_penalty > 0:
		activity_modifiers.append({"label": "Bane", "value": -bane_penalty})

	var out := {
		"natural": natural_roll,
		"total": total,
		"modifier": mod + style_bonus,
		"feature_bonus": style_bonus,
		"advantage": advantage and not disadvantage,
		"disadvantage": disadvantage and not advantage,
		"roll_results": roll_results,
		"roll_kept": roll_kept,
		"bonus_dice_terms": bonus_dice_terms,
		"activity_modifiers": activity_modifiers,
		"is_crit": is_crit,
		"is_miss": is_miss,
		"roll_token_replaced": bool(d20_details.get("replaced", false)),
	}
	if bool(d20_details.get("replaced", false)):
		out["roll_token_id"] = str(d20_details.get("roll_token_id", ""))
		out["roll_token_value"] = int(d20_details.get("roll_token_value", natural_roll))
		out["roll_token_pool_id"] = str(d20_details.get("roll_token_pool_id", ""))
		out["roll_token_owner_id"] = str(d20_details.get("roll_token_owner_id", ""))
	if d20_details.has("roll_token_error"):
		out["roll_token_error"] = str(d20_details["roll_token_error"])
	return out


## Use a class feature. Returns false if no uses remaining.
func use_feature(feature_id: String) -> bool:
	if feature_id == "fighter_action_surge" and feature_uses.get("fighter_action_surge_used", false):
		return false
	var feature := get_feature(feature_id)
	if feature.is_empty():
		return false
	var pool := str(feature.get("resource_id", feature_id))
	var cost := int(feature.get("resource_cost", 1))
	if cost < 1 or int(feature_uses.get(pool, 0)) < cost:
		return false
	feature_uses[pool] -= cost
	if feature_id == "fighter_action_surge":
		feature_uses["fighter_action_surge_used"] = true
	return true


## Return the maximum uses for a feature, including level-scaled resources.
func get_feature_max_uses(feature_id: String, feature_override: Dictionary = {}) -> int:
	if feature_id == "sorcery_points":
		return get_max_sorcery_points()
	var feature_data := feature_override
	if feature_data.is_empty():
		for feature in features:
			if str(feature.get("id", "")) == feature_id:
				feature_data = feature
				break
	if feature_data.is_empty():
		return -1
	if feature_data.has("resource_id"):
		return get_feature_max_uses(str(feature_data["resource_id"]))
	if str(feature_data.get("resource_formula", "")) == "level*5":
		return level * 5
	if feature_data.has("uses_ability"):
		return maxi(int(feature_data.get("minimum_uses", 1)), ability_scores.get_ability_modifier(str(feature_data["uses_ability"])))
	var uses_by_level: Dictionary = feature_data.get("uses_by_level", {})
	var threshold := -1
	for key in uses_by_level:
		if int(key) <= level and int(key) > threshold:
			threshold = int(key)
	if threshold >= 0:
		return int(uses_by_level[str(threshold)])
	return int(feature_data.get("uses", 1))


## Reset per-combat feature uses.
func reset_combat_features() -> void:
	feature_uses.erase("fighter_action_surge_used")
	if class_id == "fighter":
		fighter_training["creation"] = false
		fighter_training["mastery_swaps"] = 0
		fighter_training["style_swap"] = false
	fighter_studied_targets.clear()
	fighter_studied_previous.clear()
	for feature in features:
		if feature.get("uses_per", "") == "combat":
			feature_uses[feature["id"]] = get_feature_max_uses(str(feature["id"]), feature)


## Restore features whose recharge cadence is a short rest.
func short_rest() -> void:
	if is_dead() or current_hp <= 0: return
	BardicInspirationRules.advance_time(self, 3600)
	_restore_wizard_signature_spells()
	if class_id == "wizard" and has_feature("wizard_memorize_spell"):
		wizard_memorize_spell_pending = true
		spell_choices_pending = true
	feature_uses.erase("fighter_action_surge_used")
	feature_uses.erase("barbarian_relentless_rage_attempts")
	_restore_features_for_cadences(["short_rest", "rest"])
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") != "short_rest_recharge":
				continue
			var resource_id := str(effect.get("resource_id", ""))
			if resource_id.is_empty() or not feature_uses.has(resource_id):
				continue
			var cooldown_key := "short_rest_recharge_used:%s" % str(feature.get("id", ""))
			if bool(effect.get("once_per_long_rest", false)) and int(feature_uses.get(cooldown_key, 0)) > 0:
				continue
			var amount := get_feature_max_uses(resource_id)
			if effect.has("amount_by_level"):
				var amount_table: Dictionary = effect["amount_by_level"]
				var threshold := 0
				for key in amount_table:
					if int(key) <= level and int(key) > threshold:
						threshold = int(key)
				if threshold > 0:
					amount = int(amount_table[str(threshold)])
			var previous_amount := int(feature_uses.get(resource_id, 0))
			feature_uses[resource_id] = mini(get_feature_max_uses(resource_id), previous_amount + amount)
			if bool(effect.get("once_per_long_rest", false)) and feature_uses[resource_id] > previous_amount:
				feature_uses[cooldown_key] = 1
	for feature in features:
		if feature.has("short_rest_recovery"):
			var id := str(feature["id"])
			feature_uses[id] = clampi(int(feature_uses.get(id, 0)) + int(feature["short_rest_recovery"]), 0, get_feature_max_uses(id))
	_restore_pact_magic_slots()
	if get_max_focus_points() > 0:
		feature_uses["focus_points"] = get_max_focus_points()
	RollTokenRules.generate_for_rest(self, "short_rest")


## Restore long-rest resources and the character's normal between-encounter state.
func long_rest() -> void:
	if is_dead() or current_hp <= 0: return
	SpellRepertoireRules.long_rest(self)
	BardicInspirationRules.advance_time(self, 28800)
	if exhaustion_level > 0 and exhaustion_recovery_blockers.is_empty():
		exhaustion_level -= 1
		if exhaustion_level == 0:
			conditions.erase("exhaustion")
		else:
			conditions["exhaustion"] = exhaustion_level
	end_rage()
	_restore_wizard_signature_spells()
	if class_id == "cleric":
		cleric_preparation_free_change = true
		spell_choices_pending = true
	if class_id == "wizard":
		wizard_preparation_free_change = true
		wizard_mastery_replacement_available = has_feature("wizard_spell_mastery")
		wizard_memorize_spell_pending = false
		spell_choices_pending = true
	if class_id == "warlock":
		for spell_level in warlock_mystic_arcanum:
			warlock_arcanum_uses[str(spell_level)] = 1
	# Wild Shape lasts no more than half a Druid's level in hours, so an
	# eight-hour Long Rest always ends an active form.
	DruidRules.revert(self)
	feature_uses.erase("fighter_action_surge_used")
	feature_uses.erase("barbarian_persistent_rage_recovered")
	feature_uses.erase("barbarian_relentless_rage_attempts")
	_restore_features_for_cadences(["short_rest", "long_rest", "rest"])
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") == "short_rest_recharge" and bool(effect.get("once_per_long_rest", false)):
				feature_uses.erase("short_rest_recharge_used:%s" % str(feature.get("id", "")))
	for feature in features:
		for effect in _feature_effects(feature):
			if effect.get("type", "") == "spell_free_cast" and effect.get("uses_per", "long_rest") == "long_rest":
				feature_uses[_free_spell_cast_resource_id(str(feature.get("id", "")))] = _spell_free_cast_maximum(effect)
	if class_id == "druid" and has_feature("druid_wild_shape") and not DruidRules.known_form_ids(self).is_empty():
		feature_uses[DruidRules.FORM_REPLACEMENT_RESOURCE_ID] = 1
	feature_uses.erase("druid_wild_resurgence_long_rest_used")
	FamiliarRules.finish_owner_long_rest(self)
	if has_feature("cleric_greater_divine_intervention") and feature_uses.has("cleric_divine_intervention_recovery_rests"):
		var rests_left := maxi(0, int(feature_uses.get("cleric_divine_intervention_recovery_rests", 0)) - 1)
		feature_uses["cleric_divine_intervention_recovery_rests"] = rests_left
		feature_uses["cleric_divine_intervention"] = 0 if rests_left > 0 else get_feature_max_uses("cleric_divine_intervention")
	if has_feature_effect("weapon_mastery"):
		feature_uses["weapon_mastery_swaps"] = 1
	_update_spell_slots()
	_sync_sorcery_points()
	if get_max_focus_points() > 0:
		feature_uses["focus_points"] = get_max_focus_points()
	feature_uses.erase("uncanny_metabolism_used")
	RollTokenRules.generate_for_rest(self, "long_rest")
	WardRules.clear_for_long_rest(self)
	if class_id == "paladin":
		PaladinRules.restore_find_steed_ability(self)
	if class_id == "fighter":
		fighter_training["mastery_swaps"] = 1
	death_save_successes = 0
	death_save_failures = 0
	is_stable = false
	current_hp = max_hp
	is_alive = true
	temp_hp = 0
	modifiers.clear()


## Backward-compatible alias for callers that mean a full rest.
func reset_rest_features() -> void:
	long_rest()


func _restore_features_for_cadences(cadences: Array[String]) -> void:
	for feature in features:
		var resets_on: String = feature.get("uses_per", "")
		if resets_on in cadences:
			feature_uses[feature["id"]] = get_feature_max_uses(str(feature["id"]), feature)


func _restore_pact_magic_slots() -> void:
	var maximum := SpellSlotRules.pact_maximum(self)
	if maximum.is_empty(): return
	if pact_spell_slots.is_empty():
		# Existing single-class Warlock saves store Pact Magic in spell_slots.
		if class_id == "warlock" and get_max_spell_slots() == maximum:
			spell_slots = maximum
		return
	pact_spell_slots = maximum


## Recover up to a fraction of the Warlock's maximum Pact Magic slots.
func recover_pact_magic_slots(fraction: float = 0.5) -> int:
	var maxima := SpellSlotRules.pact_maximum(self)
	if maxima.is_empty(): return 0
	var pact_is_separate := not pact_spell_slots.is_empty()
	var slot_level := str(maxima.keys()[0])
	var maximum := int(maxima[slot_level])
	var current := int((pact_spell_slots if pact_is_separate else spell_slots).get(slot_level, 0))
	var recovery := maxi(1, int(ceil(float(maximum) * clampf(fraction, 0.0, 1.0))))
	var restored := mini(maximum, current + recovery) - current
	if pact_is_separate: pact_spell_slots[slot_level] = current + restored
	else: spell_slots[slot_level] = current + restored
	return restored


func get_max_sorcery_points() -> int:
	if class_id != "sorcerer" or not has_feature("sorcerer_sorcery_points"):
		return 0
	return level


func get_sorcery_points() -> int:
	return int(feature_uses.get("sorcery_points", 0))


func spend_sorcery_points(amount: int = 1) -> bool:
	var bounded_amount := maxi(0, amount)
	if bounded_amount > get_sorcery_points():
		return false
	feature_uses["sorcery_points"] = get_sorcery_points() - bounded_amount
	return true


func _sync_sorcery_points(level_up_resource: bool = false) -> void:
	var maximum := get_max_sorcery_points()
	if maximum <= 0:
		return
	if not feature_uses.has("sorcery_points"):
		feature_uses["sorcery_points"] = maximum
	elif level_up_resource:
		feature_uses["sorcery_points"] = mini(maximum, get_sorcery_points() + 1)
	else:
		feature_uses["sorcery_points"] = maximum


## Add a condition with a duration (in turns).
func add_condition(condition_name: String, duration: int, source: String = "") -> void:
	if CombatAction.is_immune_to_condition(self, condition_name):
		return
	if condition_name == "frightened" and SpellEffects.has_spell(self, "heroism"):
		return
	if condition_name.is_empty():
		return
	var requested_duration := maxi(1, duration)
	var remaining_duration := int(conditions.get(condition_name, 0))
	# Reapplying an effect must not make an existing condition expire sooner.
	conditions[condition_name] = maxi(remaining_duration, requested_duration)
	if not source.is_empty() or condition_sources.has(condition_name):
		var grants: Dictionary = condition_sources.get(condition_name, {})
		if grants.is_empty() and remaining_duration > 0:
			grants["ordinary"] = remaining_duration
		var source_id := source if not source.is_empty() else "ordinary"
		grants[source_id] = maxi(int(grants.get(source_id, 0)), requested_duration)
		condition_sources[condition_name] = grants
		conditions[condition_name] = int(grants.values().max())
	if condition_name in ["incapacitated", "unconscious", "paralyzed", "petrified", "stunned"]:
		DruidRules.revert_for_incapacitation(self)
		if has_condition("raging") and (not has_feature("barbarian_persistent_rage") or condition_name == "unconscious"):
			end_rage()


## Remove a condition.
func remove_condition(condition_name: String) -> void:
	if condition_name == "exhaustion":
		return
	var had_condition := conditions.has(condition_name)
	conditions.erase(condition_name)
	condition_sources.erase(condition_name)
	if had_condition:
		SpellEffects.publish_event(self, {"type": "status", "actor_id": SpellEffects.caster_id(self), "status": condition_name, "state": "removed"})


## Tick conditions at end of turn (reduce durations, remove expired).
func tick_conditions() -> void:
	if has_condition("raging"):
		var ended_by_status := CombatAction.is_unconscious(self) if has_feature("barbarian_persistent_rage") else CombatAction.is_incapacitated(self)
		if _is_wearing_heavy_armor() or ended_by_status:
			end_rage()
	var expired: Array[String] = []
	var tracked: Array = condition_sources.keys()
	CombatAction.tick_condition_sources(self)
	for condition in conditions:
		if condition in tracked or condition in ["raging", "exhaustion"]:
			continue
		conditions[condition] -= 1
		if conditions[condition] <= 0:
			expired.append(condition)
	for condition in expired:
		conditions.erase(condition)
		if condition == "shillelagh":
			shillelagh_weapon_id = ""
	if has_feature("monk_self_restoration"):
		MonkRules.apply_self_restoration(self)
	tick_modifiers()
	BarbarianRules.advance_rage_time(self, 6)
	BardicInspirationRules.advance_time(self, 6)


func end_rage() -> void:
	remove_condition("raging")
	feature_uses.erase("barbarian_rage_seconds_remaining")
	feature_uses.erase("barbarian_rage_upkeep_seconds_remaining")
	var kept: Array[Dictionary] = []
	for modifier in modifiers:
		if str(modifier.get("kind", "")) != "stat" or str(modifier.get("key", "")) != "damage:rage":
			kept.append(modifier)
	modifiers = kept


## Add a timed numeric modifier. Multiple modifiers stack and expire independently.
func add_modifier(kind: String, key: String, amount: int, duration: int) -> void:
	if kind.is_empty() or key.is_empty() or amount == 0:
		return
	modifiers.append({
		"kind": kind,
		"key": key,
		"amount": amount,
		"remaining_turns": maxi(1, duration),
	})


## Add a source-owned numeric modifier that expires on the campaign clock.
func add_campaign_modifier(kind: String, key: String, amount: int, duration_seconds: int, cooldown_seconds: int, source_instance_id: String) -> Dictionary:
	if kind.is_empty() or key.is_empty() or amount == 0 or duration_seconds < 1 or duration_seconds > 86400 or cooldown_seconds < 0 or cooldown_seconds > 86400 or source_instance_id.strip_edges().is_empty() or character_id.is_empty():
		return {"success": false, "message": "Campaign modifier parameters are invalid."}
	expire_campaign_modifiers(int(GameManager.campaign_elapsed_seconds))
	if has_campaign_modifier_source(source_instance_id):
		return {"success": false, "message": "This source already has an active grant."}
	if campaign_modifier_cooldown_for_source(source_instance_id, int(GameManager.campaign_elapsed_seconds)) > 0:
		return {"success": false, "message": "This source is still cooling down."}
	timed_modifier_grant_serial += 1
	var grant_id := "%s:%s:%d" % [character_id, source_instance_id, timed_modifier_grant_serial]
	var expires_at := int(GameManager.campaign_elapsed_seconds) + duration_seconds
	modifiers.append({
		"kind": kind,
		"key": key,
		"amount": amount,
		"owner_id": character_id,
		"source_instance_id": source_instance_id,
		"grant_instance_id": grant_id,
		"expires_at_seconds": expires_at,
		"cooldown_seconds": cooldown_seconds,
	})
	return {"success": true, "grant_instance_id": grant_id, "expires_at_seconds": expires_at, "cooldown_seconds": cooldown_seconds}


func has_campaign_modifier_source(source_instance_id: String) -> bool:
	for modifier in modifiers:
		if modifier.has("expires_at_seconds") and str(modifier.get("owner_id", "")) == character_id and str(modifier.get("source_instance_id", "")) == source_instance_id and int(modifier.get("expires_at_seconds", 0)) > int(GameManager.campaign_elapsed_seconds):
			return true
	return false


func campaign_modifier_source_is_cooling_down(source_instance_id: String, now_seconds: int) -> bool:
	return campaign_modifier_cooldown_for_source(source_instance_id, now_seconds) > 0


func campaign_modifier_cooldown_for_source(source_instance_id: String, now_seconds: int) -> int:
	for cooldown in campaign_modifier_cooldowns:
		if str(cooldown.get("owner_id", "")) == character_id and str(cooldown.get("source_instance_id", "")) == source_instance_id and int(cooldown.get("ready_at_seconds", 0)) > now_seconds:
			return int(cooldown["ready_at_seconds"])
	return 0


func has_timed_temporary_hp_grant_source(source_instance_id: String, now_seconds: int) -> bool:
	expire_timed_temporary_hp_grants(now_seconds)
	for grant in timed_temporary_hp_grants:
		if str(grant.get("owner_id", "")) == character_id and str(grant.get("source_instance_id", "")) == source_instance_id:
			return true
	return false


func offer_timed_temporary_hp(amount: int, duration_seconds: int, source_instance_id: String) -> Dictionary:
	if amount < 1 or amount > 100000 or duration_seconds < 1 or duration_seconds > 86400 or source_instance_id.strip_edges().is_empty() or character_id.is_empty():
		return {"success": false, "message": "Timed Temporary HP parameters are invalid."}
	var owned_pool: Variant = numeric_resource_pools.get(source_instance_id, null)
	if not owned_pool is Dictionary or str(owned_pool.get("owner_id", "")) != character_id or str(owned_pool.get("source_instance_id", "")) != source_instance_id:
		return {"success": false, "message": "Timed Temporary HP requires its exact owned resource pool."}
	var now_seconds := int(GameManager.campaign_elapsed_seconds)
	var deadline := now_seconds + duration_seconds
	if now_seconds < 0 or deadline > 2147483647:
		return {"success": false, "message": "Timed Temporary HP deadline exceeds the campaign clock limit."}
	expire_timed_temporary_hp_grants(now_seconds)
	if has_timed_temporary_hp_grant_source(source_instance_id, now_seconds):
		return {"success": false, "message": "This source already has a pending timed Temporary HP grant."}
	if amount <= temp_hp:
		return {"success": true, "accepted": false, "amount": temp_hp, "message": "%s keeps their existing temporary HP." % character_name}
	if timed_temporary_hp_grant_serial >= 2147483647:
		return {"success": false, "message": "This Temporary HP source has reached its grant limit."}
	timed_temporary_hp_grant_serial += 1
	var grant_id := "%s:%s:%d" % [character_id, source_instance_id, timed_temporary_hp_grant_serial]
	var grant := {
		"owner_id": character_id,
		"source_instance_id": source_instance_id,
		"grant_instance_id": grant_id,
		"amount": amount,
		"expires_at_seconds": deadline,
	}
	timed_temporary_hp_grants.append(grant)
	temp_hp = amount
	timed_temporary_hp_current_grant_id = grant_id
	return {"success": true, "accepted": true, "grant": grant.duplicate(true), "message": "%s gains %d Temporary HP for %d campaign seconds." % [character_name, amount, duration_seconds]}


func absorb_temporary_hp(amount: int) -> int:
	if amount <= 0 or _temp_hp_value <= 0:
		return 0
	var absorbed := mini(amount, _temp_hp_value)
	_temp_hp_value -= absorbed
	if _temp_hp_value <= 0:
		_temp_hp_value = 0
		timed_temporary_hp_current_grant_id = ""
		linked_temporary_hp = {}
	return absorbed


func expire_timed_temporary_hp_grants(now_seconds: int) -> void:
	var kept: Array[Dictionary] = []
	for grant in timed_temporary_hp_grants:
		if int(grant.get("expires_at_seconds", 0)) > now_seconds:
			kept.append(grant)
		elif str(grant.get("grant_instance_id", "")) == timed_temporary_hp_current_grant_id:
			temp_hp = 0
	timed_temporary_hp_grants = kept
	if not timed_temporary_hp_current_grant_id.is_empty() and not kept.any(func(g): return str(g.get("grant_instance_id", "")) == timed_temporary_hp_current_grant_id):
		timed_temporary_hp_current_grant_id = ""


func remove_timed_temporary_hp_grants_from_source(source_instance_id: String) -> void:
	var kept: Array[Dictionary] = []
	for grant in timed_temporary_hp_grants:
		if str(grant.get("source_instance_id", "")) != source_instance_id:
			kept.append(grant)
		elif str(grant.get("grant_instance_id", "")) == timed_temporary_hp_current_grant_id:
			temp_hp = 0
	timed_temporary_hp_grants = kept
	if not timed_temporary_hp_current_grant_id.is_empty() and not kept.any(func(g): return str(g.get("grant_instance_id", "")) == timed_temporary_hp_current_grant_id):
		timed_temporary_hp_current_grant_id = ""


func active_campaign_modifier_grants() -> Array[Dictionary]:
	var grants: Array[Dictionary] = []
	for modifier in modifiers:
		if modifier.has("grant_instance_id") and str(modifier.get("owner_id", "")) == character_id and int(modifier.get("expires_at_seconds", 0)) > int(GameManager.campaign_elapsed_seconds):
			grants.append(modifier.duplicate(true))
	return grants


func has_campaign_modifier_grant(source_instance_id: String, grant_instance_id: String, now_seconds: int) -> bool:
	for modifier in modifiers:
		if modifier.has("grant_instance_id") and str(modifier.get("owner_id", "")) == character_id and str(modifier.get("source_instance_id", "")) == source_instance_id and str(modifier.get("grant_instance_id", "")) == grant_instance_id and int(modifier.get("expires_at_seconds", 0)) > now_seconds:
			return true
	return false


func dismiss_campaign_modifier(source_instance_id: String, grant_instance_id: String, now_seconds: int) -> Dictionary:
	expire_campaign_modifiers(now_seconds)
	for index in range(modifiers.size()):
		var modifier: Dictionary = modifiers[index]
		if not has_campaign_modifier_grant(source_instance_id, grant_instance_id, now_seconds):
			continue
		if str(modifier.get("grant_instance_id", "")) != grant_instance_id:
			continue
		var cooldown_seconds := int(modifier.get("cooldown_seconds", 0))
		_record_campaign_modifier_cooldown(modifier, "dismissed", now_seconds)
		modifiers.remove_at(index)
		return {"success": true, "cooldown_seconds": cooldown_seconds, "ready_at_seconds": now_seconds + cooldown_seconds}
	return {"success": false, "message": "That exact timed grant is no longer active."}


func remove_campaign_modifiers_from_source(source_instance_id: String) -> void:
	var kept: Array[Dictionary] = []
	for modifier in modifiers:
		if not modifier.has("expires_at_seconds") or str(modifier.get("source_instance_id", "")) != source_instance_id:
			kept.append(modifier)
	modifiers = kept


func remove_campaign_modifier_cooldowns_from_source(source_instance_id: String) -> void:
	var kept: Array[Dictionary] = []
	for cooldown in campaign_modifier_cooldowns:
		if str(cooldown.get("source_instance_id", "")) != source_instance_id:
			kept.append(cooldown)
	campaign_modifier_cooldowns = kept


func expire_campaign_modifiers(now_seconds: int) -> void:
	var kept: Array[Dictionary] = []
	for modifier in modifiers:
		if not modifier.has("expires_at_seconds") or int(modifier.get("expires_at_seconds", 0)) > now_seconds:
			kept.append(modifier)
		elif modifier.has("grant_instance_id") and str(modifier.get("owner_id", "")) == character_id:
			_record_campaign_modifier_cooldown(modifier, "expired", int(modifier["expires_at_seconds"]))
	modifiers = kept
	var active_cooldowns: Array[Dictionary] = []
	for cooldown in campaign_modifier_cooldowns:
		if int(cooldown.get("ready_at_seconds", 0)) > now_seconds:
			active_cooldowns.append(cooldown)
	campaign_modifier_cooldowns = active_cooldowns
	expire_next_weapon_hit_grants(now_seconds)
	expire_timed_temporary_hp_grants(now_seconds)
	TemporaryHPRules.prune(self, now_seconds)


func _record_campaign_modifier_cooldown(modifier: Dictionary, end_reason: String, started_at_seconds: int) -> void:
	var grant_id := str(modifier.get("grant_instance_id", ""))
	var source_id := str(modifier.get("source_instance_id", ""))
	var cooldown_seconds := int(modifier.get("cooldown_seconds", 0))
	if grant_id.is_empty() or source_id.is_empty() or str(modifier.get("owner_id", "")) != character_id or cooldown_seconds < 1 or cooldown_seconds > 86400:
		return
	for existing in campaign_modifier_cooldowns:
		if str(existing.get("grant_instance_id", "")) == grant_id:
			return
	campaign_modifier_cooldowns.append({
		"owner_id": character_id,
		"source_instance_id": source_id,
		"grant_instance_id": grant_id,
		"end_reason": end_reason,
		"started_at_seconds": started_at_seconds,
		"cooldown_seconds": cooldown_seconds,
		"ready_at_seconds": started_at_seconds + cooldown_seconds,
	})


func add_next_melee_hit_grant(amount: int, damage_type: String, duration_seconds: int, source_instance_id: String) -> Dictionary:
	if amount < 1 or amount > 100 or damage_type not in DataLoader.VALID_DAMAGE_TYPES or damage_type == "none" or duration_seconds < 1 or duration_seconds > 86400 or source_instance_id.strip_edges().is_empty() or character_id.is_empty():
		return {"success": false, "message": "Next melee-hit grant parameters are invalid."}
	if has_next_melee_hit_grant_source(source_instance_id):
		return {"success": false, "message": "This source already has an unspent next melee-hit grant."}
	next_weapon_hit_grant_serial += 1
	var expires_at := int(GameManager.campaign_elapsed_seconds) + duration_seconds
	var grant_id := "next-hit:%s:%s:%d" % [character_id, source_instance_id, next_weapon_hit_grant_serial]
	var grant := {
		"owner_id": character_id,
		"source_instance_id": source_instance_id,
		"grant_instance_id": grant_id,
		"acquisition_order": next_weapon_hit_grant_serial,
		"matcher": "melee_weapon_hit",
		"amount": amount,
		"damage_type": damage_type,
		"expires_at_seconds": expires_at,
	}
	next_weapon_hit_grants.append(grant)
	return {"success": true, "grant": grant.duplicate(true), "grant_instance_id": grant_id, "expires_at_seconds": expires_at}


func has_next_melee_hit_grant_source(source_instance_id: String) -> bool:
	for grant in next_weapon_hit_grants:
		if str(grant.get("owner_id", "")) == character_id and str(grant.get("source_instance_id", "")) == source_instance_id and int(grant.get("expires_at_seconds", 0)) > int(GameManager.campaign_elapsed_seconds):
			return true
	return false


func take_oldest_next_melee_hit_grant(now_seconds: int) -> Dictionary:
	expire_next_weapon_hit_grants(now_seconds)
	if next_weapon_hit_grants.is_empty():
		return {}
	next_weapon_hit_grants.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("acquisition_order", 0)) < int(b.get("acquisition_order", 0)))
	var grant: Dictionary = next_weapon_hit_grants.pop_front()
	return grant.duplicate(true)


func remove_next_melee_hit_grants_from_source(source_instance_id: String) -> void:
	var kept: Array[Dictionary] = []
	for grant in next_weapon_hit_grants:
		if str(grant.get("source_instance_id", "")) != source_instance_id:
			kept.append(grant)
	next_weapon_hit_grants = kept


func expire_next_weapon_hit_grants(now_seconds: int) -> void:
	var kept: Array[Dictionary] = []
	for grant in next_weapon_hit_grants:
		if int(grant.get("expires_at_seconds", 0)) > now_seconds:
			kept.append(grant)
	next_weapon_hit_grants = kept


## Refresh matching timed effects without creating duplicate stacked modifiers.
func refresh_modifier(kind: String, key: String, duration: int) -> void:
	for modifier in modifiers:
		if str(modifier.get("kind", "")) == kind and str(modifier.get("key", "")) == key:
			modifier["remaining_turns"] = maxi(1, duration)


## Sum active modifiers for a named stat or roll surface.
func get_modifier(kind: String, key: String) -> int:
	var total := 0
	for modifier in modifiers:
		if str(modifier.get("kind", "")) == kind and str(modifier.get("key", "")) == key and (not modifier.has("expires_at_seconds") or int(modifier.get("expires_at_seconds", 0)) > int(GameManager.campaign_elapsed_seconds)):
			total += int(modifier.get("amount", 0))
	return total


## Reduce timed numeric modifiers by one turn and remove expired entries.
func tick_modifiers() -> void:
	var remaining: Array[Dictionary] = []
	for modifier in modifiers:
		var next := modifier.duplicate(true)
		if next.has("expires_at_seconds"):
			if int(next.get("expires_at_seconds", 0)) > int(GameManager.campaign_elapsed_seconds):
				remaining.append(next)
			continue
		next["remaining_turns"] = int(next.get("remaining_turns", 1)) - 1
		if int(next["remaining_turns"]) > 0:
			remaining.append(next)
	modifiers = remaining


## Check if a condition is active.
func is_dead() -> bool:
	return CorpseRules.is_dead(self)


func is_downed() -> bool:
	return current_hp <= 0 and not is_dead()


func has_condition(condition_name: String) -> bool:
	if condition_name == "incapacitated" and current_hp <= 0: return true
	if condition_name == "unconscious" and is_downed(): return true
	if condition_name == "exhaustion":
		return exhaustion_level > 0 and not AuraRules.suppresses_condition(self, condition_name)
	return condition_name in conditions and not AuraRules.suppresses_condition(self, condition_name)


## Check if the character has a feature by ID.
func has_feature(feature_id: String) -> bool:
	for feature in features:
		if feature.get("id", "") == feature_id:
			return true
	return false


## Return the production feature record for a character-owned feature.
func get_feature(feature_id: String) -> Dictionary:
	for feature in features:
		if str(feature.get("id", "")) == feature_id:
			return feature
	return {}


## Get IDs of all active features.
func _get_active_feature_ids() -> Array[String]:
	var ids: Array[String] = []
	for feature in features:
		ids.append(feature.get("id", ""))
	return ids


## Serialize character to dictionary.
func to_dict() -> Dictionary:
	SpellEffects.prune(self)
	TemporaryHPRules.prune(self, int(GameManager.campaign_elapsed_seconds))
	ProtectionRules.prune(self,int(GameManager.campaign_elapsed_seconds))
	_prune_recent_damage_history(int(GameManager.campaign_elapsed_seconds))
	return {
		"character_id": character_id,
		"name": character_name,
		"race_id": race_id,
		"class_id": class_id,
		"class_levels": class_levels.duplicate(true),
		"permanent_progression": permanent_progression.duplicate(true),
		"subclass_id": subclass_id,
		"feature_choices": feature_choices.duplicate(true),
		"zero_hp_history": zero_hp_history.duplicate(true),
		"zero_hp_attempt_serial": zero_hp_attempt_serial,
		"max_hp_sources": max_hp_sources.duplicate(true),
		"barbarian_relentless_rage_enabled": barbarian_relentless_rage_enabled,
		"level": level,
		"xp": xp,
		"ability_scores": ability_scores.to_dict(),
		"protection_grants": protection_grants.duplicate(true),
		"protection_selections": protection_selections.duplicate(true),
		"protection_serial": protection_serial,
		"max_hp": max_hp,
		"current_hp": current_hp,
		"temp_hp": temp_hp,
		"temporary_hp_supply_serial": temporary_hp_supply_serial,
		"linked_temporary_hp": linked_temporary_hp.duplicate(true),
		"aura_entry_receipts": aura_entry_receipts.duplicate(true),
		"aura_protection_selections": aura_protection_selections.duplicate(true),
		"timed_temporary_hp_grant_serial": timed_temporary_hp_grant_serial,
		"timed_temporary_hp_grants": timed_temporary_hp_grants.duplicate(true),
		"timed_temporary_hp_current_grant_id": timed_temporary_hp_current_grant_id,
		"base_ac": base_ac,
		"speed": speed,
		"movement_speeds_feet": movement_speeds_feet.duplicate(true),
		"proficiency_bonus": proficiency_bonus,
		"saving_throw_proficiencies": saving_throw_proficiencies,
		"skill_proficiencies": skill_proficiencies,
		"tool_proficiencies": tool_proficiencies.duplicate(),
		"creation_choices": creation_choices.duplicate(true),
		"weapon_proficiencies": weapon_proficiencies,
		"armor_proficiencies": armor_proficiencies,
		"traits": traits.duplicate(true),
		"darkvision": darkvision,
		"darkvision_feet": darkvision_feet,
		"known_spells": known_spells,
		"nourishment_until_seconds": nourishment_until_seconds,
		"hydration_until_seconds": hydration_until_seconds,
		"food_eaten_today_pounds": food_eaten_today_pounds,
		"water_drank_today_gallons": water_drank_today_gallons,
		"exhaustion_level": exhaustion_level,
		"exhaustion_recovery_blockers": exhaustion_recovery_blockers.duplicate(),
		"days_without_food": days_without_food,
		"spell_choices_pending": spell_choices_pending,
		"spell_repertoire_state": spell_repertoire_state.duplicate(true),
		"wizard_spellbook": wizard_spellbook.duplicate(),
		"wizard_spellbook_pending": wizard_spellbook_pending,
		"cleric_spells_trained": cleric_spells_trained,
		"cleric_preparation_free_change": cleric_preparation_free_change,
		"cleric_cantrip_replacement_available": cleric_cantrip_replacement_available,
		"wizard_preparation_free_change": wizard_preparation_free_change,
		"wizard_memorize_spell_pending": wizard_memorize_spell_pending,
		"wizard_mastery_replacement_available": wizard_mastery_replacement_available,
		"wizard_spell_mastery": wizard_spell_mastery.duplicate(true),
		"wizard_signature_spells": wizard_signature_spells.duplicate(),
		"sorcerer_metamagic_choices": sorcerer_metamagic_choices.duplicate(),
		"sorcerer_metamagic_pending": sorcerer_metamagic_pending,
		"sorcerer_metamagic_replacement_available": sorcerer_metamagic_replacement_available,
		"warlock_invocations": warlock_invocations.duplicate(),
		"warlock_invocation_pending": warlock_invocation_pending,
		"warlock_invocation_replacement_available": warlock_invocation_replacement_available,
		"warlock_mystic_arcanum": warlock_mystic_arcanum.duplicate(true),
		"warlock_arcanum_pending_levels": warlock_arcanum_pending_levels.duplicate(),
		"warlock_arcanum_uses": warlock_arcanum_uses.duplicate(),
		"warlock_arcanum_replacement_available": warlock_arcanum_replacement_available,
		"spell_slots": spell_slots.duplicate(),
		"pact_spell_slots": pact_spell_slots.duplicate(),
		"conditions": conditions.duplicate(),
		"condition_sources": condition_sources.duplicate(true),
		"spell_effects": spell_effects.duplicate(true),
		"spell_cast_serial": spell_cast_serial,
		"spell_concentration": SpellEffects.saved_concentration(self),
		"modifiers": modifiers.duplicate(true),
		"timed_modifier_grant_serial": timed_modifier_grant_serial,
		"campaign_modifier_cooldowns": campaign_modifier_cooldowns.duplicate(true),
		"recent_damage_history": recent_damage_history.duplicate(true),
		"next_weapon_hit_grants": next_weapon_hit_grants.duplicate(true),
		"next_weapon_hit_grant_serial": next_weapon_hit_grant_serial,
		"inventory": inventory.to_dict(),
		"feature_uses": feature_uses.duplicate(),
		"numeric_resource_pools": numeric_resource_pools.duplicate(true),
		"captured_grants": captured_grants.duplicate(true),
		"grant_transfer_serial": grant_transfer_serial,
		"transferred_die_serials": transferred_die_serials.duplicate(),
		"is_alive": is_alive,
		"disintegrated": disintegrated,
		"corpse_state": corpse_state.duplicate(true),
		"body_death_serial": body_death_serial,
		"revival_willing": revival_willing,
		"willingness": willingness,
		"body_missing_parts": body_missing_parts.duplicate(),
		"crit_range": crit_range,
		"extra_attacks": extra_attacks,
		"fighter_training": fighter_training.duplicate(true),
		"weapon_masteries": weapon_masteries.duplicate(),
		"heroic_inspiration": heroic_inspiration,
		"death_save_successes": death_save_successes,
		"death_save_failures": death_save_failures,
		"is_stable": is_stable,
		"stable_recovery_at_seconds": stable_recovery_at_seconds,
		"wild_shape_state": wild_shape_state.duplicate(true),
		"fiendish_resilience_type": fiendish_resilience_type,
		"pact_weapon_damage_type": pact_weapon_damage_type,
		"roll_tokens": RollTokenRules.serialize_tokens(roll_tokens),
		"roll_token_generation_serial": roll_token_generation_serial,
		"damage_wards": WardRules.serialize_wards(damage_wards),
	}


## Deserialize character from dictionary.
func from_dict(data: Dictionary) -> void:
	familiar_senses = null
	protection_grants.clear()
	protection_selections.clear()
	pending_protection_choice.clear()
	protection_choice_generation+=1
	character_id = str(data.get("character_id", ""))
	recent_damage_history.clear()
	for damage_entry in data.get("recent_damage_history", []):
		if damage_entry is Dictionary:
			recent_damage_history.append(damage_entry.duplicate(true))
	willingness = str(data.get("willingness", "unknown")) if str(data.get("willingness", "unknown")) in ["unknown", "willing", "unwilling"] else "unknown"
	character_name = data.get("name", "")
	race_id = data.get("race_id", "")
	class_id = data.get("class_id", "")
	permanent_progression = data.get("permanent_progression", {}).duplicate(true)
	class_levels = data.get("class_levels", {}).duplicate(true) if data.get("class_levels", {}) is Dictionary else {"_invalid": -1}
	level = clampi(int(data.get("level", 1)), 1, 20)
	subclass_id = str(data.get("subclass_id", DataLoader.get_character_class(class_id).get("legacy_subclass", "") if level >= int(DataLoader.get_character_class(class_id).get("subclass_level", 3)) else ""))
	feature_choices = data.get("feature_choices", {}).duplicate(true)
	xp = int(data.get("xp", 0))
	
	ability_scores = AbilityScores.new()
	ability_scores.from_dict(data.get("ability_scores", {}))
	
	max_hp = int(data.get("max_hp", 10))
	current_hp = int(data.get("current_hp", 10))
	disintegrated = bool(data.get("disintegrated", false))
	temp_hp = int(data.get("temp_hp", 0))
	base_ac = int(data.get("base_ac", 10))
	speed = int(data.get("speed", 6))
	movement_speeds_feet = {"climb": 0, "swim": 0, "fly": 0}
	var saved_movement_speeds: Variant = data.get("movement_speeds_feet", {})
	if saved_movement_speeds is Dictionary:
		for mode in ["climb", "swim", "fly"]:
			var feet: Variant = saved_movement_speeds.get(mode, 0)
			if (feet is int or feet is float) and is_finite(float(feet)) and float(feet) == floor(float(feet)) and int(feet) >= 0 and int(feet) <= 1000 and int(feet) % 5 == 0:
				movement_speeds_feet[mode] = int(feet)
	proficiency_bonus = int(data.get("proficiency_bonus", 2))
	is_alive = bool(data.get("is_alive", true))
	crit_range = int(data.get("crit_range", 20))
	extra_attacks = int(data.get("extra_attacks", 0))
	fiendish_resilience_type = str(data.get("fiendish_resilience_type", ""))
	pact_weapon_damage_type = str(data.get("pact_weapon_damage_type", ""))

	# Clear and rebuild arrays
	saving_throw_proficiencies.clear()
	for val in data.get("saving_throw_proficiencies", []):
		saving_throw_proficiencies.append(str(val))

	skill_proficiencies.clear()
	tool_proficiencies.assign(data.get("tool_proficiencies", []))
	creation_choices = data.get("creation_choices", {}).duplicate(true)
	for val in data.get("skill_proficiencies", []):
		skill_proficiencies.append(str(val))

	weapon_proficiencies.clear()
	for val in data.get("weapon_proficiencies", []):
		weapon_proficiencies.append(str(val))

	armor_proficiencies.clear()
	for val in data.get("armor_proficiencies", []):
		armor_proficiencies.append(str(val))

	traits.clear()
	for val in data.get("traits", []):
		if val is Dictionary:
			traits.append(val.duplicate(true))
	if traits.is_empty() and not race_id.is_empty():
		var race_info := DataLoader.get_race(race_id)
		for trait_val in race_info.get("traits", []):
			if trait_val is Dictionary:
				traits.append(trait_val.duplicate(true))
	var race_data := DataLoader.get_race(race_id)
	darkvision = bool(data.get("darkvision", race_data.get("darkvision", false)))
	darkvision_feet = int(data.get("darkvision_feet", race_data.get("darkvision_feet", 60 if darkvision else 0)))

	known_spells.clear()
	for val in data.get("known_spells", []):
		known_spells.append(str(val))
	nourishment_until_seconds = maxi(0, int(data.get("nourishment_until_seconds", 0)))
	hydration_until_seconds = maxi(0, int(data.get("hydration_until_seconds", 0)))
	food_eaten_today_pounds = maxf(0.0, float(data.get("food_eaten_today_pounds", 0.0)))
	water_drank_today_gallons = maxf(0.0, float(data.get("water_drank_today_gallons", 0.0)))
	exhaustion_level = clampi(int(data.get("exhaustion_level", data.get("conditions", {}).get("exhaustion", 0))), 0, 6)
	exhaustion_recovery_blockers.clear()
	for blocker in data.get("exhaustion_recovery_blockers", []):
		if str(blocker) in ["malnutrition", "dehydration"] and str(blocker) not in exhaustion_recovery_blockers:
			exhaustion_recovery_blockers.append(str(blocker))
	days_without_food = maxi(0, int(data.get("days_without_food", 0)))
	spell_choices_pending = bool(data.get("spell_choices_pending", false))
	spell_repertoire_state = data.get("spell_repertoire_state", {}).duplicate(true)
	for receipt in spell_repertoire_state.values(): receipt["level"] = int(receipt.get("level", 0))
	wizard_spellbook.clear()
	for val in data.get("wizard_spellbook", []):
		var spell_id := str(val)
		if spell_id not in wizard_spellbook:
			wizard_spellbook.append(spell_id)
	wizard_spellbook_pending = maxi(0, int(data.get("wizard_spellbook_pending", 0)))
	cleric_spells_trained = bool(data.get("cleric_spells_trained", false))
	cleric_preparation_free_change = bool(data.get("cleric_preparation_free_change", false))
	cleric_cantrip_replacement_available = bool(data.get("cleric_cantrip_replacement_available", false))
	wizard_preparation_free_change = bool(data.get("wizard_preparation_free_change", false))
	wizard_memorize_spell_pending = bool(data.get("wizard_memorize_spell_pending", false))
	wizard_mastery_replacement_available = bool(data.get("wizard_mastery_replacement_available", false))
	wizard_spell_mastery = data.get("wizard_spell_mastery", {}).duplicate(true)
	wizard_signature_spells.clear()
	for spell_id in data.get("wizard_signature_spells", []):
		if str(spell_id) not in wizard_signature_spells:
			wizard_signature_spells.append(str(spell_id))
	sorcerer_metamagic_choices.clear()
	for value in data.get("sorcerer_metamagic_choices", []):
		var option_id := str(value)
		if option_id not in sorcerer_metamagic_choices:
			sorcerer_metamagic_choices.append(option_id)
	if class_id == "sorcerer" and not data.has("sorcerer_metamagic_choices") and level >= 2:
		sorcerer_metamagic_choices.append("empowered_spell")
	var metamagic_total := SorcererRules.metamagic_capacity(level) if class_id == "sorcerer" else 0
	sorcerer_metamagic_pending = maxi(0, int(data.get("sorcerer_metamagic_pending", metamagic_total - sorcerer_metamagic_choices.size())))
	sorcerer_metamagic_replacement_available = bool(data.get("sorcerer_metamagic_replacement_available", false))
	warlock_invocations.clear()
	for value in data.get("warlock_invocations", []):
		warlock_invocations.append(str(value))
	warlock_mystic_arcanum = data.get("warlock_mystic_arcanum", {}).duplicate(true)
	warlock_arcanum_pending_levels.clear()
	for value in data.get("warlock_arcanum_pending_levels", []):
		warlock_arcanum_pending_levels.append(int(value))
	warlock_arcanum_uses = data.get("warlock_arcanum_uses", {}).duplicate(true)
	if class_id == "warlock":
		warlock_invocation_pending = maxi(0, int(data.get("warlock_invocation_pending", WarlockRules.invocation_capacity(level) - warlock_invocations.size())))
		warlock_invocation_replacement_available = bool(data.get("warlock_invocation_replacement_available", false))
		warlock_arcanum_replacement_available = bool(data.get("warlock_arcanum_replacement_available", false))
		for arcanum_level in [6, 7, 8, 9]:
			if arcanum_level * 2 - 1 <= level and not warlock_mystic_arcanum.has(str(arcanum_level)) and arcanum_level not in warlock_arcanum_pending_levels:
				warlock_arcanum_pending_levels.append(arcanum_level)
		_append_warlock_arcanum_spells()
	if class_id == "wizard" and not data.has("wizard_spellbook"):
		for spell_id in feature_choices.get(get_spellcasting_feature_id(), data.get("known_spells", [])):
			if int(DataLoader.get_spell(str(spell_id)).get("level", 0)) > 0 and str(spell_id) not in wizard_spellbook:
				wizard_spellbook.append(str(spell_id))
		wizard_spellbook_pending = maxi(0, 6 + 2 * (level - 1) - wizard_spellbook.size())

	fighter_training = data.get("fighter_training", {}).duplicate(true)
	if fighter_training.has("asi_spent"):
		fighter_training["asi_spent"] = int(fighter_training["asi_spent"])
	if fighter_training.has("mastery_swaps"):
		fighter_training["mastery_swaps"] = int(fighter_training["mastery_swaps"])
	FighterRules.initialize_training(self)
	weapon_masteries.clear()
	for mastery_id in data.get("weapon_masteries", fighter_training.get("masteries", [])):
		if mastery_id is String:
			weapon_masteries.append(mastery_id)
	heroic_inspiration = bool(data.get("heroic_inspiration", false))
	death_save_successes = clampi(int(data.get("death_save_successes", 0)), 0, 3)
	death_save_failures = clampi(int(data.get("death_save_failures", 0)), 0, 3)
	is_stable = bool(data.get("is_stable", false)) and current_hp == 0 and death_save_failures < 3
	fighter_studied_targets.clear()
	fighter_studied_previous.clear()
	crit_range = 20
	# Clear and rebuild features
	features.clear()
	extra_attacks = 0
	for l in range(1, maxi(0, get_class_level()) + 1):
		_unlock_features_for_level(l, false)
	ClassProgression.apply_feature_choice_grants(self)
	if weapon_masteries.is_empty() and class_id == "fighter":
		for mastery_id in fighter_training.get("masteries", []):
			weapon_masteries.append(str(mastery_id))
	ClassProgression.restore_legacy_choices(self, data)
	refresh_spell_selection_from_choices()
	if not get_spellcasting_feature_id().is_empty() and not feature_choices.has(get_spellcasting_feature_id()):
		spell_choices_pending = true

	# Overwrite conditions and feature uses with saved state
	conditions = data.get("conditions", {}).duplicate()
	if exhaustion_level > 0:
		conditions["exhaustion"] = exhaustion_level
	else:
		conditions.erase("exhaustion")
	condition_sources = data.get("condition_sources", {}).duplicate(true)
	spell_effects = data.get("spell_effects", {}).duplicate(true)
	spell_cast_serial = maxi(0, int(data.get("spell_cast_serial", 0)))
	concentrating_on = data.get("spell_concentration", {}).duplicate(true)
	if not concentrating_on.is_empty():
		concentrating_on["targets"] = []
		aura_source_memberships.clear()
	modifiers.clear()
	for modifier in data.get("modifiers", []):
		if modifier is Dictionary:
			modifiers.append(modifier.duplicate(true))
	timed_modifier_grant_serial = maxi(0, int(data.get("timed_modifier_grant_serial", 0)))
	campaign_modifier_cooldowns.clear()
	for cooldown in data.get("campaign_modifier_cooldowns", []):
		if cooldown is Dictionary:
			campaign_modifier_cooldowns.append(cooldown.duplicate(true))
	next_weapon_hit_grants.clear()
	for grant in data.get("next_weapon_hit_grants", []):
		if grant is Dictionary:
			next_weapon_hit_grants.append(grant.duplicate(true))
	next_weapon_hit_grant_serial = maxi(0, int(data.get("next_weapon_hit_grant_serial", 0)))
	temporary_hp_supply_serial = int(data.get("temporary_hp_supply_serial", 0))
	linked_temporary_hp = data.get("linked_temporary_hp", {}).duplicate(true)
	aura_entry_receipts = data.get("aura_entry_receipts", {}).duplicate(true)
	aura_protection_selections = data.get("aura_protection_selections", {}).duplicate(true)
	timed_temporary_hp_grant_serial = maxi(0, int(data.get("timed_temporary_hp_grant_serial", 0)))
	timed_temporary_hp_grants.clear()
	for grant in data.get("timed_temporary_hp_grants", []):
		if grant is Dictionary:
			timed_temporary_hp_grants.append(grant.duplicate(true))
	timed_temporary_hp_current_grant_id = str(data.get("timed_temporary_hp_current_grant_id", ""))
	feature_uses = data.get("feature_uses", {}).duplicate()
	numeric_resource_pools = data.get("numeric_resource_pools", {}).duplicate(true)
	captured_grants.assign(data.get("captured_grants", []).duplicate(true))
	grant_transfer_serial = int(data.get("grant_transfer_serial", 0))
	transferred_die_serials = data.get("transferred_die_serials", {}).duplicate()
	roll_tokens = RollTokenRules.deserialize_tokens(data.get("roll_tokens", {}))
	roll_token_generation_serial = maxi(0, int(data.get("roll_token_generation_serial", 0)))
	damage_wards = WardRules.deserialize_wards(data.get("damage_wards", {}))
	WardRules.sync_pools_on_acquire(self)
	FamiliarRules.restore_legacy(self)
	BardicInspirationRules.advance_time(self, 0)
	zero_hp_history = data.get("zero_hp_history", {}).duplicate(true)
	zero_hp_attempt_serial = int(data.get("zero_hp_attempt_serial", 0))
	MaxHpSourceRules.restore(self, data)
	barbarian_relentless_rage_enabled = bool(data.get("barbarian_relentless_rage_enabled", true))
	for feature in features:
		if feature.get("type", "") in ["active", "triggered", "resource"]:
			var pool := str(feature.get("resource_id", feature["id"]))
			feature_uses[pool] = clampi(int(feature_uses.get(pool, 0)), 0, get_feature_max_uses(pool))
	if get_max_focus_points() > 0:
		feature_uses["focus_points"] = get_focus_points()
	# Rebuild the level-appropriate default first for older saves, then restore
	# the persisted remaining slots when the save carries them.
	_update_spell_slots()
	if data.has("spell_slots") and data.get("spell_slots") is Dictionary:
		spell_slots.clear()
		var raw_slots: Dictionary = data.get("spell_slots", {})
		for slot_key in raw_slots:
			spell_slots[str(slot_key)] = int(raw_slots[slot_key])
	if data.has("pact_spell_slots") and data.get("pact_spell_slots") is Dictionary:
		pact_spell_slots.clear()
		var raw_pact_slots: Dictionary = data.get("pact_spell_slots", {})
		for slot_key in raw_pact_slots:
			pact_spell_slots[str(slot_key)] = int(raw_pact_slots[slot_key])
	
	protection_grants.assign(data.get("protection_grants",[]).duplicate(true))
	protection_selections=data.get("protection_selections",{}).duplicate(true)
	protection_serial=int(data.get("protection_serial",0))
	ProtectionRules.prune(self,int(GameManager.campaign_elapsed_seconds))

	# Restore inventory
	inventory = Inventory.new()
	inventory.owner_character_ref = weakref(self)
	inventory.from_dict(data.get("inventory", {}))
	if class_id == "wizard" and not inventory.has_item("spellbook"):
		inventory.add_item("spellbook")
	DruidRules.restore_saved_form(self, data.get("wild_shape_state", {}))
	CorpseRules.restore(self, data)
	expire_timed_temporary_hp_grants(int(GameManager.campaign_elapsed_seconds))


## Resolve a known-DC saving throw. The sheet exposes automatic resource choices.
func saving_throw_to_dc(ability: String, dc: int, advantage: bool = false, disadvantage: bool = false, decisions: Dictionary = {}) -> int:
	return int(saving_throw_test_to_dc(ability, dc, advantage, disadvantage, decisions).get("total", 0))


func saving_throw_test_to_dc(ability: String, dc: int, advantage: bool = false, disadvantage: bool = false, decisions: Dictionary = {}) -> Dictionary:
	last_save_note = ""
	var result := make_saving_throw_result(ability, advantage, disadvantage, decisions)
	var total := int(result.get("total", 0))
	if total < dc and has_feature("fighter_indomitable") and fighter_training.get("auto_indomitable", true) and use_feature("fighter_indomitable"):
		var initial_replaced := bool(result.get("roll_token_replaced", false))
		var initial_token_id := str(result.get("roll_token_id", ""))
		result = make_saving_throw_result(ability, advantage, disadvantage)
		result["modifier"] = int(result.get("modifier", 0)) + level
		result["total"] = int(result.get("total", 0)) + level
		result["raw_total"] = int(result.get("raw_total", 0)) + level
		result["indomitable_used"] = true
		if initial_replaced:
			result["initial_roll_token_replaced"] = true
			result["initial_roll_token_id"] = initial_token_id
		total = int(result["total"])
		last_save_note = "Indomitable reroll +%d: %d vs DC %d." % [level, total, dc]
	if total < dc and has_feature("monk_disciplined_survivor") and spend_focus_points(1):
		var initial_replaced := bool(result.get("roll_token_replaced", false))
		var initial_token_id := str(result.get("roll_token_id", ""))
		result = make_saving_throw_result(ability, advantage, disadvantage)
		total = int(result.get("total", 0))
		result["disciplined_survivor_used"] = true
		if initial_replaced:
			result["initial_roll_token_replaced"] = true
			result["initial_roll_token_id"] = initial_token_id
	result["total"] = total
	result["dc"] = dc
	result["success"] = total >= dc
	return result


## Survivor's death saves use this same production method on the live turn.
func make_death_save(accepted_bardic_inspiration: bool = false, accepted_stroke_of_luck: bool = false, decisions: Dictionary = {}) -> Dictionary:
	if current_hp > 0 or is_stable or is_dead() or death_save_successes >= 3:
		return {"rolled": false}
	var automatic_rule := ZeroHpAftermathRules.pending_death_save_rule(self)
	if not automatic_rule.is_empty():
		return ZeroHpAftermathRules.resolve_automatic_death_save(self, automatic_rule)
	var has_death_save_advantage := has_feature("champion_survivor") or SpellEffects.has_spell(self, "beacon_of_hope")
	var d20_details := RollTokenRules.resolve_d20_test(self, "death_save", has_death_save_advantage, false, decisions)
	var natural := int(d20_details.get("total", 1))
	var bane_penalty := Dice.roll(4, self) if has_condition("baned") else 0
	var total := natural - bane_penalty - exhaustion_level * 2
	if natural < 10 and has_feature("fighter_indomitable") and fighter_training.get("auto_indomitable", true) and use_feature("fighter_indomitable"):
		natural = Dice.roll_with_advantage(20, self) if has_death_save_advantage else Dice.roll(20, self)
		bane_penalty = Dice.roll(4, self) if has_condition("baned") else 0
		total = natural + level - bane_penalty - exhaustion_level * 2
	var stroke_used := false
	if total < 10 and accepted_stroke_of_luck:
		var stroke := RogueRules.apply_stroke_of_luck(self, {"natural_roll": natural, "modifier": total - natural, "total": total, "dc": 10, "success": false}, true)
		if stroke.get("used", false):
			total = int(stroke.get("result", {}).get("total", total))
			natural = int(stroke.get("result", {}).get("natural_roll", natural))
			stroke_used = true
	var inspiration_used := false
	var inspiration_bonus := 0
	# A natural 1 retains its special two-failure result; the die remains held.
	if natural > 1 and total < 10 and accepted_bardic_inspiration:
		var inspiration := BardicInspirationRules.apply_to_test(self, total, 10, true)
		if inspiration.get("used", false):
			total = int(inspiration["total"])
			inspiration_bonus = int(inspiration.get("bonus", 0))
			inspiration_used = true
	if natural >= (18 if has_feature("champion_survivor") else 20):
		heal(1)
	elif natural == 1:
		death_save_failures = mini(3, death_save_failures + 2)
	elif total < 10:
		death_save_failures += 1
	else:
		death_save_successes += 1
		if death_save_successes >= 3:
			stabilize()
	if death_save_failures >= 3: CorpseRules.mark_dead(self, "death_saves")
	var out := {"rolled": true, "natural": natural, "rolls": d20_details.get("rolls", [natural]), "kept": d20_details.get("kept", [true]), "total": total, "bane_penalty": bane_penalty, "stroke_of_luck_used": stroke_used, "bardic_inspiration_used": inspiration_used, "bardic_inspiration_bonus": inspiration_bonus, "revived": current_hp > 0, "successes": death_save_successes, "failures": death_save_failures, "roll_token_replaced": bool(d20_details.get("replaced", false)), "replaced_by_roll_token": bool(d20_details.get("replaced", false))}
	if bool(d20_details.get("replaced", false)):
		out["roll_token_id"] = str(d20_details.get("roll_token_id", ""))
		out["roll_token_value"] = int(d20_details.get("roll_token_value", natural))
	return out


func stabilize() -> bool:
	if not is_downed(): return false
	is_stable = true
	death_save_successes = 0
	death_save_failures = 0
	stable_recovery_at_seconds = int(GameManager.campaign_elapsed_seconds) + Dice.roll(4, self) * 3600
	return true
