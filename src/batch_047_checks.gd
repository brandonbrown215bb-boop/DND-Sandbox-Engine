class_name Batch047Checks
extends RefCounted

const CHANGELING := "fixture:b047_changeling"

static func load_fixtures() -> void:
	Batch046Checks.load_fixtures()
	if not DataLoader.get_spell(CHANGELING).is_empty(): return
	DataLoader._load_json_file("res://data/fixtures/batch_047/spells/changeling.json", "spell")

static func run(check: Callable) -> void:
	load_fixtures()
	check.call(DataLoader.get_load_errors().is_empty() and SharedSpell.content_error(DataLoader.get_spell(CHANGELING)).is_empty(), "047 neutral two-form two-policy projection loads: %s" % str(DataLoader.get_load_errors()))
	var o := SpellCastChoices.projection_options(DataLoader.get_spell(CHANGELING))
	check.call(o.forms.map(func(f): return f.id) == ["b047_hare", "b047_boar"] and o.equipment.map(func(e): return e.id) == ["merged", "worn"] and str(o.forms[0].label).begins_with("Hare"), "047 chooser lists exactly the declared forms and legal equipment policies in order")
	var shift := SpellCastChoices.projection_options(DataLoader.get_spell(Batch040Checks.SHIFT))
	var guise := SpellCastChoices.projection_options(DataLoader.get_spell(Batch041Checks.GUISE))
	var mantle := SpellCastChoices.projection_options(DataLoader.get_spell(Batch040Checks.MANTLE))
	check.call(shift.forms.size() == 2 and shift.equipment.is_empty() and guise.forms.size() == 1 and guise.equipment.size() == 3 and mantle.forms.size() == 1 and mantle.equipment.is_empty() and SpellCastChoices.projection_options(DataLoader.get_spell("magic_missile")).is_empty(), "047 forms-only, equipment-only, single-option and non-projection spells expose only their own choices")
	# Without a HUD a multi-option cast cannot be answered: it refuses before cost; single-option needs no popup.
	var a := Batch031Checks._character("b047_logic", 40)
	var multi := SpellCastContext.new()
	multi.caster = a
	multi.spell = DataLoader.get_spell(CHANGELING).duplicate(true)
	var single := SpellCastContext.new()
	single.caster = a
	single.spell = DataLoader.get_spell(Batch040Checks.MANTLE).duplicate(true)
	var multi_ok: bool = await SpellCastChoices.choose_projection_options(multi)
	var single_ok: bool = await SpellCastChoices.choose_projection_options(single)
	check.call(not multi_ok and single_ok and not single.spell.has("_projection_form_id") and ActorProjectionRules.cast_error(a, single.spell).is_empty(), "047 headless multi-option refuses; a single-option projection needs no popup and stays castable")
	var chosen := DataLoader.get_spell(CHANGELING).duplicate(true)
	chosen["_projection_form_id"] = "b047_boar"
	chosen["_projection_equipment"] = "worn"
	var wrong := chosen.duplicate(true)
	wrong["_projection_equipment"] = "dropped"
	check.call(not ActorProjectionRules.cast_error(a, DataLoader.get_spell(CHANGELING)).is_empty() and ActorProjectionRules.cast_error(a, chosen).is_empty() and not ActorProjectionRules.cast_error(a, wrong).is_empty() and not DataLoader.get_spell(CHANGELING).has("_projection_form_id"), "047 the chooser's picks satisfy the pre-cost check; an undeclared policy still refuses; shared content is not mutated")
