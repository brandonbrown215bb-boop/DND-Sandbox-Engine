## Core rules batch 2 runtime probe (audit tooling only; changes no gameplay).
## Monster-AI condition handling and non-EventResolver check/save hosts.
## Output: .artifacts/core-rules-2/runtime.json
## Run: godot --headless --path . res://tools/core_rules_2_audit/core_rules_2_probe.tscn
extends Node

const SCORES := {"STR": 14, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 10}
const TRIALS := 400

func _actor(n: String) -> Character:
	var s := AbilityScores.new(); s.from_dict(SCORES)
	var c := Character.new(); c.initialize(n, "human", "fighter", s)
	return c

func _monster(conds: Array, pos := Vector2i(1, 0)) -> Dictionary:
	var m: Dictionary = DataLoader.get_monster("goblin")
	var d := {"id": "probe_m", "name": "probe", "monster_id": "goblin", "max_hp": 50, "current_hp": 50, "armor_class": 12, "speed": 6, "ability_scores": m.get("ability_scores", {}), "attacks": m.get("attacks", []), "hex_position": pos, "is_alive": true, "conditions": {}, "condition_sources": {}}
	for c in conds: d["conditions"][c] = 10
	return d

func _ai(conds: Array, players: Array, grid: HexGrid, extra := {}) -> Dictionary:
	var m := _monster(conds, Vector2i(0, 0)); m.merge(extra, true)
	return AIController.get_monster_action(m, Vector2i(0, 0), grid, players)

func _monster_save_rate(conds: Array, ability: String, dc: int) -> float:
	var ok := 0
	for i in TRIALS:
		if BarbarianRules.roll_monster_save(_monster(conds), ability) >= dc: ok += 1
	return float(ok) / TRIALS

func _char_save_rate(cond: String, ability: String, dc: int) -> float:
	var ok := 0
	for i in TRIALS:
		var c := _actor("s")
		if cond == "exhaustion": c.gain_exhaustion("probe")
		elif cond != "": c.add_condition(cond, 10)
		if bool(c.saving_throw_test_to_dc(ability, dc).get("success", false)): ok += 1
	return float(ok) / TRIALS

func _check_mode(cond: String) -> Dictionary:
	var c := _actor("k")
	if cond == "exhaustion": c.gain_exhaustion("probe")
	elif cond != "": c.add_condition(cond, 10)
	var r := EventResolver.resolve_skill_check(c, {"ability": "DEX", "skill": "Stealth", "dc": 10})
	return {"roll_mode": str(r.get("roll_mode", r.get("mode", "?"))), "rolls": r.get("rolls", []).size() if r.get("rolls", []) is Array else -1, "modifier": int(r.get("modifier", 0)), "keys_have_mode": r.has("roll_mode")}

func _ready() -> void:
	var out := {}
	var commit := []
	OS.execute("git", ["rev-parse", "HEAD"], commit)
	out["commit"] = str(commit[0]).strip_edges() if commit.size() > 0 else "?"
	out["registry_hash_sha256"] = str(DataLoader.get_registry_hash()).sha256_text()
	var grid := HexGrid.new()
	var near := _actor("Near"); var far := _actor("Far")
	var players := [{"character": near, "hex_position": Vector2i(1, 0)}, {"character": far, "hex_position": Vector2i(3, 0)}]
	var ai := {}
	for cond in ["", "petrified", "incapacitated", "unconscious", "stunned", "paralyzed", "frightened", "charmed", "blinded", "restrained", "grappled", "prone", "poisoned"]:
		ai["monster_" + (cond if cond != "" else "none")] = _ai([cond] if cond != "" else [], players, grid)
	# charmed by Near via a non-spell source record: does AI still target Near?
	ai["monster_charmed_source_near"] = _ai(["charmed"], players, grid, {"condition_sources": {"charmed": [{"source_id": "probe", "caster_id": near.character_id}]}})
	near.add_condition("invisible", 10)
	ai["target_near_invisible"] = _ai([], players, grid)
	near.remove_condition("invisible") if near.has_method("remove_condition") else null
	near.add_condition("hidden", 10)
	ai["target_near_hidden"] = _ai([], players, grid)
	out["ai"] = ai
	var spd := {}
	for cond in ["", "restrained", "grappled", "unconscious", "petrified", "paralyzed", "stunned", "prone"]:
		spd[cond if cond != "" else "none"] = FighterRules.monster_speed(_monster([cond] if cond != "" else []))
	out["monster_speed_hexes"] = spd
	var ms := {}
	for cond in ["", "paralyzed", "stunned", "unconscious", "petrified", "restrained"]:
		ms[(cond if cond != "" else "none") + "_DEX_dc2"] = _monster_save_rate([cond] if cond != "" else [], "DEX", 2)
		ms[(cond if cond != "" else "none") + "_STR_dc2"] = _monster_save_rate([cond] if cond != "" else [], "STR", 2)
	ms["none_DEX_dc12"] = _monster_save_rate([], "DEX", 12)
	ms["restrained_DEX_dc12"] = _monster_save_rate(["restrained"], "DEX", 12)
	out["monster_generic_save_success_rate"] = ms
	var cs := {}
	for cond in ["", "paralyzed", "stunned", "unconscious", "petrified"]:
		cs[(cond if cond != "" else "none") + "_DEX_dc2"] = _char_save_rate(cond, "DEX", 2)
	cs["none_DEX_dc14"] = _char_save_rate("", "DEX", 14)
	cs["restrained_DEX_dc14"] = _char_save_rate("restrained", "DEX", 14)
	cs["exhaustion1_DEX_dc14"] = _char_save_rate("exhaustion", "DEX", 14)
	out["character_generic_save_success_rate"] = cs
	var ck := {}
	for cond in ["", "poisoned", "frightened", "exhaustion", "blinded"]:
		ck[cond if cond != "" else "none"] = _check_mode(cond)
	out["event_resolver_check"] = ck
	var st := _actor("Sneak")
	if "Stealth" not in st.skill_proficiencies: st.skill_proficiencies.append("Stealth")
	out["overworld_stealth_casing"] = {"skill_proficiencies": st.skill_proficiencies, "matches_STEALTH_literal": "STEALTH" in st.skill_proficiencies, "engine_skill_modifier": st.get_skill_check_modifier("Stealth", "DEX"), "dex_mod": st.ability_scores.get_ability_modifier("DEX"), "proficiency_bonus": st.proficiency_bonus}
	grid.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.artifacts/core-rules-2"))
	var f := FileAccess.open("res://.artifacts/core-rules-2/runtime.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "  ", true)); f.close()
	print("CORE_RULES_2_PROBE_DONE ", out["commit"], " ", out["registry_hash_sha256"])
	get_tree().quit(0)
