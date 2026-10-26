## Core rules/conditions runtime probe (audit tooling only; changes no gameplay).
## Builds throwaway actors after production autoloads initialize, applies each
## SRD 5.2.1 condition through the shipped owners and records what the engine
## actually does. Output: .artifacts/core-rules/runtime.json
## Run: godot --headless --path . res://scenes/core_rules_inventory_export.tscn
extends Node

const SRD_CONDITIONS := ["blinded", "charmed", "deafened", "exhaustion", "frightened", "grappled", "incapacitated", "invisible", "paralyzed", "petrified", "poisoned", "prone", "restrained", "stunned", "unconscious"]
const SCORES := {"STR": 14, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10}

func _actor(name: String) -> Character:
	var s := AbilityScores.new()
	s.from_dict(SCORES)
	var c := Character.new()
	c.initialize(name, "human", "fighter", s)
	return c

func _monster(conds: Array) -> Dictionary:
	var m: Dictionary = DataLoader.get_monster("goblin")
	var d := {"name": "probe", "monster_id": "goblin", "max_hp": 50, "current_hp": 50, "armor_class": 1, "speed": 6, "ability_scores": m.get("ability_scores", {}), "attacks": m.get("attacks", []), "condition_immunities": [], "damage_immunities": [], "hex_position": Vector2i(1, 0), "is_alive": true, "conditions": {}, "creature_type": str(m.get("creature_type", "humanoid"))}
	for c in conds:
		d["conditions"][c] = 10
	return d

func _mode(r: Dictionary) -> String:
	var a := bool(r.get("advantage", false)); var d := bool(r.get("disadvantage", false))
	return "advantage" if a and not d else ("disadvantage" if d and not a else "normal")

func _weapon() -> Dictionary:
	var w = DataLoader.get_item("longsword")
	return w if w is Dictionary and not w.is_empty() else {"id": "longsword", "name": "Longsword", "damage": "1d8", "damage_type": "slashing", "properties": [], "range": 1}

const TRIALS := 300

func _hit_rate(cond: String, character_target: bool) -> float:
	var hits := 0
	var attacker := _actor("probe_attacker")
	for i in TRIALS:
		var target
		if character_target:
			target = _actor("target")
			target.max_hp = 500; target.current_hp = 500
			if cond == "exhaustion": target.gain_exhaustion("probe")
			elif cond != "": target.add_condition(cond, 10)
		else:
			target = _monster([] if cond in ["", "exhaustion"] else [cond])
			target["armor_class"] = 14; target["max_hp"] = 500; target["current_hp"] = 500
		if bool(CombatAction.resolve_weapon_attack(attacker, target, _weapon()).get("hit", false)):
			hits += 1
	return float(hits) / TRIALS

func _probe(cond: String) -> Dictionary:
	var row := {"condition": cond}
	var c := _actor("probe_" + cond)
	if cond == "exhaustion":
		c.gain_exhaustion("probe")
	else:
		c.add_condition(cond, 10)
	row["has_condition_after_add"] = c.has_condition(cond) if cond != "exhaustion" else c.exhaustion_level == 1
	row["speed_feet"] = int(round(c.get_speed() * 5))
	row["is_incapacitated"] = CombatAction.is_incapacitated(c)
	row["own_attack_mode"] = _mode(c.make_attack_roll("STR"))
	var str_save := c.saving_throw_test_to_dc("STR", -100)
	var dex_save := c.saving_throw_test_to_dc("DEX", -100)
	row["generic_str_save_vs_dc_-100_succeeds"] = bool(str_save.get("success", false))
	row["generic_dex_save_vs_dc_-100_succeeds"] = bool(dex_save.get("success", false))
	row["generic_dex_save_mode"] = _mode(dex_save)
	row["ability_check_mode"] = str(EventResolver.ability_check_roll_mode(c, "DEX", "Stealth", {}).get("effective_mode", ""))
	# Attacks against a target bearing the condition. resolve_weapon_attack does
	# not return its roll mode, so the probe measures hit rate over fresh
	# targets against the unconditioned baseline (see rate_mode()).
	row["player_attack_vs_character_hit_rate"] = _hit_rate(cond, true)
	row["player_attack_vs_monster_hit_rate"] = _hit_rate(cond, false)
	return row

func _ready() -> void:
	var loader := get_node_or_null("/root/DataLoader")
	if loader == null or not loader.get_load_errors().is_empty():
		push_error("Core rules inventory requires a valid production DataLoader registry.")
		get_tree().quit(1)
		return
	var out := {"schema_version": 1, "registry_snapshot_sha256": str(loader.get_registry_hash()).sha256_text(), "engine": Engine.get_version_info().get("string", ""), "os": OS.get_name(), "conditions": [], "exhaustion": [], "rests": {}, "death": {}}
	var baseline := _actor("baseline")
	out["baseline"] = {"speed_feet": int(round(baseline.get_speed() * 5)), "own_attack_mode": _mode(baseline.make_attack_roll("STR"))}
	out["baseline"]["player_attack_vs_character_hit_rate"] = _hit_rate("", true)
	out["baseline"]["player_attack_vs_monster_hit_rate"] = _hit_rate("", false)
	for cond in SRD_CONDITIONS:
		out["conditions"].append(_probe(cond))
	# exhaustion ladder
	var e := _actor("exhaust")
	for level in range(1, 7):
		e.gain_exhaustion("probe")
		out["exhaustion"].append({"level": e.exhaustion_level, "speed_feet": int(round(e.get_speed() * 5)), "alive": e.is_alive})
	var e2 := _actor("exhaust_rest"); e2.gain_exhaustion("probe"); e2.gain_exhaustion("probe"); e2.long_rest()
	out["exhaustion_after_long_rest_from_2"] = e2.exhaustion_level
	# rests
	var r := _actor("rest"); r.take_damage(5); var before := r.current_hp; r.short_rest()
	out["rests"]["short_rest_hp_gain_with_no_choice"] = r.current_hp - before
	out["rests"]["character_has_hit_point_dice_pool"] = "hit_dice_remaining" in r or "hit_point_dice" in r
	r.take_damage(5); r.long_rest(); out["rests"]["long_rest_restores_full_hp"] = r.current_hp == r.max_hp
	# death / zero HP
	var d := _actor("dying"); d.take_damage(d.current_hp)
	out["death"]["at_zero_unconscious"] = d.has_condition("unconscious")
	out["death"]["at_zero_prone"] = d.has_condition("prone")
	d.take_damage(1); out["death"]["damage_at_zero_failures"] = d.death_save_failures
	d.take_damage(1, false, true); out["death"]["crit_at_zero_failures"] = d.death_save_failures
	var m := _actor("massive"); m.take_damage(m.current_hp + m.max_hp)
	out["death"]["massive_damage_dead"] = not m.is_alive
	var dest := "res://.artifacts/core-rules/runtime.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest).get_base_dir())
	var f := FileAccess.open(dest, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t", true)); f.close()
	print("CORE RULES INVENTORY EXPORTED: %d conditions, registry %s" % [out["conditions"].size(), out["registry_snapshot_sha256"]])
	get_tree().quit(0)
