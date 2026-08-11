## Builds player-facing combat activity drafts from settled resolver results.
## This module never rolls dice or recomputes combat outcomes.
class_name CombatActivityRecord
extends RefCounted


static func attack_action(attacker: Character, target: Dictionary, weapon: Dictionary, results: Array[Dictionary], campaign_id: String = "", round_number: int = 0) -> Dictionary:
	if attacker == null or target.is_empty() or results.is_empty():
		return {}
	var first_result: Dictionary = results[0]
	var payload: Dictionary = first_result.get("activity_roll", {}).duplicate(true)
	if payload.is_empty():
		return {}

	var attack_sections: Array[Dictionary] = []
	var hit_count := 0
	var total_damage := 0
	var any_critical := false
	for index in results.size():
		var result: Dictionary = results[index]
		var hit := bool(result.get("hit", false))
		var critical := bool(result.get("crit", false))
		var damage := int(result.get("damage", 0))
		if hit:
			hit_count += 1
		if critical:
			any_critical = true
		total_damage += damage
		attack_sections.append({
			"index": index + 1,
			"outcome": "critical_hit" if critical else ("hit" if hit else "miss"),
			"roll": result.get("activity_roll", {}).duplicate(true),
			"damage": result.get("activity_damage", {}).duplicate(true),
			"damage_components": result.get("damage_components", []).duplicate(true),
			"applied_damage": damage,
		})
	payload["sections"] = {"attacks": attack_sections, "total_damage": total_damage}

	var outcome_code := "critical_hit" if any_critical else ("hit" if hit_count > 0 else "miss")
	var outcome_label := "Critical Hit" if any_critical else ("Hit" if hit_count > 0 else "Miss")
	var summary := _attack_summary(results, hit_count, total_damage, outcome_label)
	var draft := {
		"category": "roll",
		"kind": "attack",
		"actor": {"id": attacker.character_id, "name": attacker.character_name},
		"targets": [{"id": str(target.get("id", target.get("monster_id", ""))), "name": str(target.get("name", "Target"))}],
		"title": str(weapon.get("name", "Weapon Attack")),
		"summary": summary,
		"outcome": {"code": outcome_code, "label": outcome_label},
		"visibility": "public",
		"payload": payload,
		"scene_context": {"scene": "combat"},
	}
	if round_number > 0:
		draft["campaign_time"] = {"round": round_number}
	if not campaign_id.is_empty():
		draft["scene_context"]["campaign_id"] = campaign_id
	return draft


static func _attack_summary(results: Array[Dictionary], hit_count: int, total_damage: int, outcome_label: String) -> String:
	if results.size() > 1:
		return "%d attacks - %d hit; %d damage" % [results.size(), hit_count, total_damage]
	var result: Dictionary = results[0]
	var roll := int(result.get("attack_roll", 0))
	var target_ac := int(result.get("target_ac", 0))
	if not bool(result.get("hit", false)):
		return "%d vs AC %d - %s" % [roll, target_ac, outcome_label]
	return "%d vs AC %d - %s; %d %s damage" % [roll, target_ac, outcome_label, total_damage, str(result.get("damage_type", ""))]
