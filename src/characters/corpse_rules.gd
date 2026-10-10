## Party remains belong to the original character; revival never creates a new actor.
class_name CorpseRules
extends RefCounted

const REMAINS := ["intact", "partial", "bones", "dust", "destroyed"]
const RESTRICTIONS := ["old_age", "soul_unavailable", "vital_parts_missing", "transformed_undead"]

static func is_dead(character: Character) -> bool:
	return character != null and (not character.corpse_state.is_empty() or character.disintegrated or character.death_save_failures >= 3 or character.exhaustion_level >= 6 or character.max_hp <= 0)

static func mark_dead(character: Character, cause: String, remains: String = "intact", death_time: int = -2) -> void:
	if character == null: return
	if character.corpse_state.is_empty():
		character.body_death_serial += 1
		character.corpse_state = {
			"corpse_id": "corpse:%s:%d" % [character.character_id, character.body_death_serial],
			"character_id": character.character_id,
			"death_at_seconds": int(GameManager.campaign_elapsed_seconds) if death_time == -2 else death_time,
			"cause": cause, "remains": remains, "missing_parts": character.body_missing_parts.duplicate(), "recovery_restrictions": [],
			"preserved_seconds": 0, "preservation_started_at": -1, "preservation_until": -1,
		}
	else:
		# A later disintegration changes the remains, never the original death time.
		if remains in ["dust", "destroyed"]: character.corpse_state["remains"] = remains
	if cause == "old_age" and "old_age" not in character.corpse_state["recovery_restrictions"]:
		character.corpse_state["recovery_restrictions"].append("old_age")
	character.current_hp = 0
	character.temp_hp = 0
	character.is_alive = false
	character.death_save_failures = 3
	character.is_stable = false
	character.stable_recovery_at_seconds = 0
	character.end_rage()
	DruidRules.revert_for_incapacitation(character)
	SpellEffects.end_concentration(character, character.concentrating_on.get("targets", []))
	character.concentrating_on.clear()
	for record in character.inventory.owned_instances():
		if str(record.get("state", {}).get("attuned_to", "")) == character.character_id:
			character.inventory.unattune_instance(str(record["instance_id"]), character.character_id, true)

static func restore(character: Character, data: Dictionary) -> void:
	character.body_death_serial = int(data.get("body_death_serial", 0))
	character.revival_willing = bool(data.get("revival_willing", true))
	character.body_missing_parts.clear()
	for part in data.get("body_missing_parts", []): character.body_missing_parts.append(str(part))
	character.corpse_state = data.get("corpse_state", {}).duplicate(true)
	character.stable_recovery_at_seconds = int(data.get("stable_recovery_at_seconds", 0)) if character.is_stable else 0
	if is_dead(character):
		# Earlier schema-2 saves cannot establish a recent death. Never reset that clock.
		mark_dead(character, "unknown", "dust" if character.disintegrated else "intact", -1)

static func effective_age(character: Character, now: int) -> int:
	var body := character.corpse_state
	if body.is_empty() or int(body.get("death_at_seconds", -1)) < 0: return -1
	var protected := int(body.get("preserved_seconds", 0))
	var started := int(body.get("preservation_started_at", -1))
	if started >= 0:
		protected += maxi(0, mini(now, int(body["preservation_until"])) - started)
	return maxi(0, now - int(body["death_at_seconds"]) - protected)

static func target_error(character: Character, spell_id: String, now: int) -> String:
	if character == null or character.class_id in ["familiar", "steed"]:
		return "Choose a party member's remains."
	if not is_dead(character): return "That party member is unconscious or alive, not dead."
	if character.corpse_state.is_empty(): return "This death has no recorded time; recent revival cannot be established."
	var body := character.corpse_state
	if str(body.get("remains", "destroyed")) == "destroyed": return "No remains are available to touch."
	if spell_id == "gentle_repose": return ""
	if spell_id != "revivify": return "This recovery spell is unsupported."
	if not character.revival_willing: return "The spirit refuses this revival."
	if character.disintegrated or str(body.get("remains", "")) in ["dust", "bones"]:
		return "Revivify cannot restore these remains."
	var restrictions: Array = body.get("recovery_restrictions", [])
	if not restrictions.is_empty(): return "Revivify is blocked: %s." % ", ".join(restrictions)
	if character.max_hp <= 0: return "The creature's Hit Point maximum must first be restored."
	var age := effective_age(character, now)
	if age < 0: return "The time of death is unknown; Revivify's one-minute limit cannot be established."
	if age > 60: return "Revivify's one-minute limit has expired."
	return ""

static func preserve(character: Character, now: int) -> void:
	var body := character.corpse_state
	var started := int(body.get("preservation_started_at", -1))
	if started >= 0:
		body["preserved_seconds"] = int(body.get("preserved_seconds", 0)) + maxi(0, mini(now, int(body["preservation_until"])) - started)
	body["preservation_started_at"] = now
	body["preservation_until"] = now + 864000

static func protected_from_undeath(character: Character, now: int) -> bool:
	return not character.corpse_state.is_empty() and int(character.corpse_state.get("preservation_until", -1)) > now

static func revive(character: Character, now: int) -> Dictionary:
	var error := target_error(character, "revivify", now)
	if not error.is_empty(): return {"success": false, "message": error}
	character.body_missing_parts.clear()
	for part in character.corpse_state.get("missing_parts", []): character.body_missing_parts.append(str(part))
	character.corpse_state.clear()
	character.disintegrated = false
	character.death_save_failures = 0
	character.death_save_successes = 0
	character.is_stable = false
	character.stable_recovery_at_seconds = 0
	character.current_hp = 1
	character.is_alive = true
	character.exhaustion_level = maxi(0, character.exhaustion_level - 1)
	if character.exhaustion_level == 0: character.conditions.erase("exhaustion")
	else: character.conditions["exhaustion"] = character.exhaustion_level
	return {"success": true, "hit": true, "revived": true, "healing": 1, "message": "%s returns to life with 1 Hit Point." % character.character_name}

static func status(character: Character, now: int) -> String:
	if not is_dead(character):
		return "Unconscious (Stable)" if character.current_hp == 0 and character.is_stable else "Unconscious" if character.current_hp == 0 else "Alive"
	var age := effective_age(character, now)
	return "Dead · %s · %s%s" % [str(character.corpse_state.get("remains", "unrecorded remains")), "death time unknown" if age < 0 else "%d seconds toward revival limit" % age, " · preserved" if protected_from_undeath(character, now) else ""]

static func saved_error(data: Dictionary) -> String:
	if data.has("revival_willing") and not data["revival_willing"] is bool: return "revival willingness is invalid"
	if not _integer(data.get("body_death_serial", 0), 0): return "body death serial is invalid"
	if not _integer(data.get("stable_recovery_at_seconds", 0), 0): return "stable recovery clock is invalid"
	if int(data.get("stable_recovery_at_seconds", 0)) > 0 and (not bool(data.get("is_stable", false)) or int(data.get("current_hp", 0)) != 0): return "stable recovery contradicts character life state"
	var parts: Variant = data.get("body_missing_parts", [])
	if not parts is Array or parts.size() > 25: return "body missing parts are invalid"
	var seen_parts: Array[String] = []
	for part in parts:
		if not part is String or part.is_empty() or part.length() > 80 or part in seen_parts: return "body missing parts are invalid"
		seen_parts.append(part)
	var body: Variant = data.get("corpse_state", {})
	if not body is Dictionary: return "corpse DTO is not an object"
	if body.is_empty(): return ""
	var serial := int(data.get("body_death_serial", 0))
	if serial < 1 or str(body.get("character_id", "")) != str(data.get("character_id", "")) or str(body.get("corpse_id", "")) != "corpse:%s:%d" % [str(data.get("character_id", "")), serial]: return "corpse identity does not match its character"
	if int(data.get("current_hp", 0)) != 0 or bool(data.get("is_alive", true)) or int(data.get("death_save_failures", 0)) < 3 or bool(data.get("is_stable", false)): return "corpse contradicts character life state"
	if body.get("remains", "") not in REMAINS or not body.get("cause", null) is String or str(body["cause"]).is_empty(): return "corpse remains or cause is invalid"
	for key in ["death_at_seconds", "preservation_started_at", "preservation_until"]:
		if not _integer(body.get(key, null), -1): return "corpse clock is invalid"
	if not _integer(body.get("preserved_seconds", null), 0): return "corpse preservation clock is invalid"
	var started := int(body["preservation_started_at"])
	var until := int(body["preservation_until"])
	if (started == -1) != (until == -1) or (started >= 0 and (until - started != 864000 or (int(body["death_at_seconds"]) >= 0 and started < int(body["death_at_seconds"])))): return "corpse preservation interval is invalid"
	for key in ["missing_parts", "recovery_restrictions"]:
		if not body.get(key, null) is Array or body[key].size() > 25: return "corpse restrictions are invalid"
		var seen: Array[String] = []
		for value in body[key]:
			if not value is String or value.is_empty() or value.length() > 80 or value in seen or (key == "recovery_restrictions" and value not in RESTRICTIONS): return "corpse restrictions are invalid"
			seen.append(value)
	if bool(data.get("disintegrated", false)) and body["remains"] != "dust": return "disintegrated corpse has incompatible remains"
	return ""

static func saved_clock_error(data: Dictionary, now: int) -> String:
	if int(data.get("stable_recovery_at_seconds", 0)) > now + 14400: return "stable recovery clock exceeds four hours"
	var body: Dictionary = data.get("corpse_state", {})
	if body.is_empty(): return ""
	var death := int(body.get("death_at_seconds", -1))
	var start := int(body.get("preservation_started_at", -1))
	var protected := int(body.get("preserved_seconds", 0))
	if death > now or start > now: return "corpse clock is ahead of campaign time"
	if start < 0 and protected != 0: return "corpse preservation has no interval"
	if death >= 0 and protected > maxi(0, start - death): return "corpse preservation exceeds time since death"
	return ""

static func advance_time(character: Character, now: int) -> void:
	if character.is_stable and character.is_downed() and character.stable_recovery_at_seconds > 0 and now >= character.stable_recovery_at_seconds:
		character.heal(1)

static func _integer(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= 9007199254740991.0
