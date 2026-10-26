## NON-SHIPPING audit tool (Progression/Acquisition audit). Not referenced by src/ or any shipping scene.
## Exports what the production DataLoader registered that bears on acquisition and advancement:
## classes (proficiencies, multiclass, subclass level, spell access), subclasses, species, feats.
## Run: godot --headless --path . res://tools/progression_audit/progression_inventory_export.tscn
extends Node

func _ready() -> void:
	var loader := get_node_or_null("/root/DataLoader")
	if loader == null:
		push_error("DataLoader autoload missing"); get_tree().quit(1); return
	var classes: Array = []
	for c in loader.get_all_classes():
		var d: Dictionary = c.duplicate(true)
		var feats_by_level: Variant = d.get("features_by_level", {})
		var counts := {}
		if feats_by_level is Dictionary:
			for lvl in feats_by_level:
				counts[str(lvl)] = (feats_by_level[lvl] as Array).size() if feats_by_level[lvl] is Array else 1
		d.erase("features_by_level")
		d["_feature_count_by_level"] = counts
		d["_keys"] = c.keys()
		d["_subclass_ids"] = loader.get_subclasses_for_class(str(c.get("id", ""))).map(func(s): return str(s.get("id", "")))
		classes.append(d)
	var subclasses: Array = []
	for id in loader.subclasses:
		var s: Dictionary = loader.subclasses[id]
		var lv := []
		var fbl: Variant = s.get("features_by_level", {})
		if fbl is Dictionary:
			lv = fbl.keys()
		subclasses.append({"id": id, "class_id": s.get("class_id", ""), "keys": s.keys(), "feature_levels": lv,
			"always_prepared_spells": s.get("always_prepared_spells", null), "rules_status": s.get("rules_status", null)})
	var registry_json: String = loader.get_registry_hash()
	var feats_json := JSON.stringify(loader.feats)
	var payload := {
		"schema_version": 1,
		"registry_hash_sha256": registry_json.sha256_text(),
		"feats_registry_sha256": feats_json.sha256_text(),
		"content_layers": loader.get_content_layers(),
		"content_pack_ids": loader.get_content_pack_ids(),
		"load_errors": loader.get_load_errors(),
		"validation_warnings": loader.get_validation_warnings(),
		"counts": {"class": loader.classes.size(), "subclass": loader.subclasses.size(), "race": loader.races.size(), "feat": loader.feats.size(), "spell": loader.spells.size()},
		"classes": classes,
		"subclasses": subclasses,
		"species": loader.get_all_races(),
		"feats": loader.feats.values(),
	}
	var dest := "res://.artifacts/progression-acquisition/inventory.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest).get_base_dir())
	var f := FileAccess.open(dest, FileAccess.WRITE)
	f.store_string(JSON.stringify(payload, "\t", true)); f.close()
	print("PROGRESSION INVENTORY: ", JSON.stringify(payload.counts), " hash=", payload.registry_hash_sha256)
	get_tree().quit(0)
