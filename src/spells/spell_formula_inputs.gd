## Transient formula inputs owned by one real cast; never accepted from decisions.
class_name SpellFormulaInputs
extends RefCounted

static func content_error(spell: Dictionary) -> String:
	var inputs: Variant = spell.get("formula_inputs", {})
	if not inputs is Dictionary or inputs.size() > 8: return "formula_inputs must contain at most eight declarations."
	for id in inputs:
		if not id is String or not id.is_valid_identifier(): return "Formula input IDs must be identifiers."
		var spec: Variant = inputs[id]
		if not spec is Dictionary: return "Formula inputs require declarations."
		if spec.get("kind") == "number_choice":
			if spec.size() != 4 or spec.get("policy") != "captured" or not SharedStepExecutor._integer(spec.get("minimum"), 0, 99) or not SharedStepExecutor._integer(spec.get("maximum"), 0, 99) or int(spec.minimum) > int(spec.maximum) or int(spec.maximum)-int(spec.minimum)>20: return "Number choices require bounded integer minimum/maximum and captured policy."
		elif spec.get("kind") == "parameter":
			if spec.size() != 3 or spec.get("policy") not in ["captured", "live"]: return "Parameters require formula and captured/live policy."
			var error := SharedStepExecutor.formula_content_error(spec.get("formula"))
			if not error.is_empty() or not ResourcePoolRules._actor_formula_error(spec.get("formula")).is_empty(): return "Parameters require deterministic actor-only formulas."
		else: return "Unknown formula input kind."
	for id in referenced_inputs(spell.get("steps", [])):
		if not inputs.has(id): return "Formula input '%s' is undeclared." % id
	return ""


static func referenced_inputs(value: Variant) -> Array:
	var ids: Array = []
	if value is Dictionary:
		if value.has("input_value"): ids.append(value.input_value)
		for child in value.values(): ids.append_array(referenced_inputs(child))
	elif value is Array:
		for child in value: ids.append_array(referenced_inputs(child))
	return ids


static func capture(host: SpellCastContext, id: String, value: Variant) -> bool:
	var spec: Dictionary = host.spell.get("formula_inputs", {}).get(id, {})
	if spec.get("kind") != "number_choice" or not SharedStepExecutor._integer(value, int(spec.minimum), int(spec.maximum)): return false
	if host.formula_inputs.has(id): return false
	host.formula_inputs[id] = {"value":int(value), "spec":spec.duplicate(true), "owner":host.caster, "invocation":host.invocation_id, "spell":str(host.spell.get("id", ""))}
	return true


static func choose(host: SpellCastContext) -> bool:
	var error := content_error(host.spell)
	if not error.is_empty(): return false
	for id in host.spell.get("formula_inputs", {}):
		var spec: Dictionary = host.spell.formula_inputs[id]
		if spec.kind == "number_choice":
			var selected: Variant = await host.hud.request_formula_number(id, int(spec.minimum), int(spec.maximum))
			if not is_instance_valid(host.hud) or host.hud.active_character != host.caster or not capture(host, id, selected): return false
	# Check every parameter before costs; only captured parameters retain this value.
	# Live parameters must already be available, then reevaluate at consumption.
	for id in host.spell.get("formula_inputs", {}):
		var spec: Dictionary = host.spell.formula_inputs[id]
		if spec.kind == "parameter":
			var value := SharedStepExecutor.evaluate_actor_formula(spec.formula, host.caster)
			if not value.get("success", false): return false
			if spec.policy == "captured":
				host.formula_inputs[id] = {"value":int(value.value), "spec":spec.duplicate(true), "owner":host.caster, "invocation":host.invocation_id, "spell":str(host.spell.get("id", ""))}
	return true


static func read(cast: SpellResolutionContext, id: String) -> Dictionary:
	if cast == null or cast.spatial_host == null: return {"success":false,"value":0}
	var host := cast.spatial_host
	var spec: Dictionary = cast.spell.get("formula_inputs", {}).get(id, {})
	if spec.is_empty() or host.caster != cast.caster or host.invocation_id != cast.invocation_id: return {"success":false,"value":0}
	if spec.get("kind") == "parameter" and spec.get("policy") == "live":
		return SharedStepExecutor.evaluate_actor_formula(spec.formula, cast.caster)
	var receipt: Dictionary = host.formula_inputs.get(id, {})
	if receipt.get("owner") != cast.caster or receipt.get("invocation") != cast.invocation_id or receipt.get("spell") != cast.spell_definition_id or receipt.get("spec") != spec: return {"success":false,"value":0}
	return {"success":true,"value":int(receipt.value),"input_id":id,"policy":spec.policy}


static func source_die(selector: Dictionary, cast: SpellResolutionContext, target, results: Array) -> Dictionary:
	var unavailable := {"success":false,"value":0}
	if cast == null: return unavailable
	var subject = target if selector.target == "same" else cast.target
	var selected: Dictionary = {}
	for row in results:
		if row.get("step_id") != selector.step: continue
		if not selected.is_empty() or row.get("complete") != true: return unavailable
		selected = row
	if selected.is_empty(): return unavailable
	var receipt: Dictionary = {}
	for child in selected.get("target_outcomes", []):
		if not is_same(child.get("target"), subject): continue
		if not receipt.is_empty() or child.get("skipped", false): return unavailable
		receipt = child.get("result", {}).get("formula_source_die", {})
	if receipt.get("pool_definition_id") != selector.pool_id or not SharedStepExecutor._integer(receipt.get("face"), 1, int(receipt.get("sides",0))) or int(receipt.get("sides",0)) not in ResourcePoolRules.SUPPORTED_DIE_SIZES: return unavailable
	var owner: Character = cast.caster if selected.get("type") == "attack" else (subject if subject is Character else null)
	if owner == null or receipt.get("owner_id") != owner.character_id: return unavailable
	if selector.policy == "revalidate":
		var pool: Dictionary = owner.numeric_resource_pools.get(str(receipt.get("source_instance_id", "")), {})
		if pool.get("owner_id") != owner.character_id or pool.get("definition_id") != selector.pool_id: return unavailable
	return {"success":true,"value":int(receipt.face),"source":receipt.duplicate(true),"policy":selector.policy}
