## Spell eligibility and spell-specific choices at their existing cast boundaries.
class_name SpellCastPreparation
extends RefCounted

static func validate_and_choose(cast: SpellCastContext) -> bool:
	if not SpellCastValidation.validate_host(cast):
		return false
	if not await SpellCastChoices.choose_projection_options(cast): # Card 7e2c: pick form/equipment before any cost.
		return false
	if not SpellCastValidation.validate_actor(cast):
		return false
	if not await SpellFormulaInputs.choose(cast):
		return false
	var damage_policy_error := SharedSpell.damage_policy_availability_error(cast.spell, cast.caster)
	if not damage_policy_error.is_empty():
		cast.hud.add_log(damage_policy_error)
		return false
	if not await SpellCastChoices.choose_identify(cast):
		return false
	if not SpellCastValidation.validate_weapon_and_steed(cast):
		return false
	if not await SpellCastChoices.choose_dancing_lights(cast):
		return false
	if not SpellCastValidation.validate_self_target(cast):
		return false
	if not await SpellCastChoices.choose_spirit_guardians(cast):
		return false
	if not SpellCastValidation.validate_creatures_and_components(cast):
		return false
	if not await SpellCastChoices.choose_utility_options(cast):
		return false
	if not SpellCastValidation.validate_area(cast):
		return false
	if not await SpellCastChoices.choose_orders_and_types(cast):
		return false
	if not await SpellCastChoices.choose_placement(cast): # Batch 053: legal destinations before any cost.
		return false
	return true


static func choose_target_options(cast: SpellCastContext) -> bool:
	return await SpellCastChoices.choose_target_options(cast)
