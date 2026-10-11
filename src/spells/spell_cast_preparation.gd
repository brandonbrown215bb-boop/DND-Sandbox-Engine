## Spell eligibility and spell-specific choices at their existing cast boundaries.
class_name SpellCastPreparation
extends RefCounted

static func validate_and_choose(cast: SpellCastContext) -> bool:
	if not SpellCastValidation.validate_host(cast):
		return false
	if not SpellCastValidation.validate_actor(cast):
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
	return true


static func choose_target_options(cast: SpellCastContext) -> bool:
	return await SpellCastChoices.choose_target_options(cast)
