## Eligibility for spoken exchanges between represented local actors.
class_name CommunicationRules
extends RefCounted

const DEFAULT_RANGE_FEET := 30
const SPOKEN_SOUND := {"volume":"whisper", "range_feet":DEFAULT_RANGE_FEET}


static func known_languages(actor: Variant) -> Array:
	if actor is Character:
		return actor.known_languages
	if actor is Dictionary:
		var declared: Variant = actor.get("languages", [])
		return declared if declared is Array else []
	return []


static func saved_languages_error(data: Dictionary) -> String:
	if not data.has("known_languages"):
		return ""
	var languages: Variant = data.get("known_languages")
	if not languages is Array or languages.size() > 64:
		return "Known languages must be an array of at most 64 entries."
	var seen: Dictionary = {}
	for language in languages:
		if not language is String or str(language).strip_edges().is_empty() or str(language).length() > 80 or seen.has(language):
			return "Known language entries must be unique, nonempty strings."
		seen[language] = true
	return ""


static func definition_languages_error(data: Dictionary) -> String:
	if not data.has("languages"):
		return ""
	var languages: Variant = data.get("languages")
	if not languages is Array or languages.size() > 64:
		return "Declared creature languages must be an array of at most 64 entries."
	var seen: Dictionary = {}
	for language in languages:
		if not language is String or str(language).strip_edges().is_empty() or str(language).length() > 80 or seen.has(language):
			return "Declared creature languages must be unique, nonempty strings."
		seen[language] = true
	return ""


static func shared_language(speaker: Variant, listener: Variant) -> String:
	var listener_languages: Array = known_languages(listener)
	for language in known_languages(speaker):
		if language in listener_languages:
			return str(language)
	return ""


static func speaker_error(speaker: Variant) -> String:
	if speaker == null or not _alive(speaker) or _incapacitated(speaker):
		return "The speaker cannot speak now."
	if _condition(speaker, "silenced"):
		return "The speaker cannot make a sound."
	if known_languages(speaker).is_empty():
		return "The speaker has no declared spoken language."
	return ""


static func eligibility_error(speaker: Variant, listener: Variant, speaker_position: Vector2i, listener_position: Vector2i, grid: HexGrid, spatial_context: Dictionary, range_feet: int = DEFAULT_RANGE_FEET) -> String:
	var reason: String = speaker_error(speaker)
	if not reason.is_empty():
		return reason
	if listener == null or not _alive(listener) or _incapacitated(listener) or _condition(listener, "deafened") or _condition(listener, "silenced"):
		return "The listener cannot hear speech."
	if range_feet < 1 or range_feet > DEFAULT_RANGE_FEET:
		return "The communication range is invalid."
	var language: String = shared_language(speaker, listener)
	if language.is_empty():
		return "The listener does not understand a language the speaker knows."
	if PhysicalFactsRules.get_plane(speaker, spatial_context) != PhysicalFactsRules.get_plane(listener, spatial_context):
		return "The actors are on different planes."
	if grid == null or not grid.has_tile(speaker_position) or not grid.has_tile(listener_position):
		return "Speech has no represented sound route."
	if not CombatNoiseRules.can_hear(listener, listener_position, speaker_position, grid, {"volume":"whisper", "range_feet":range_feet}, speaker, spatial_context):
		return "The listener cannot hear the speaker across this distance or obstruction."
	return ""


static func can_communicate(speaker: Variant, listener: Variant, speaker_position: Vector2i, listener_position: Vector2i, grid: HexGrid, spatial_context: Dictionary, range_feet: int = DEFAULT_RANGE_FEET) -> bool:
	return eligibility_error(speaker, listener, speaker_position, listener_position, grid, spatial_context, range_feet).is_empty()


static func _alive(actor: Variant) -> bool:
	return bool(actor.get("is_alive", true)) and int(actor.get("current_hp", 1)) > 0 if actor is Dictionary else actor.is_alive if actor is Character else false


static func _incapacitated(actor: Variant) -> bool:
	return CombatAction.is_incapacitated(actor)


static func _condition(actor: Variant, condition: String) -> bool:
	return CombatPerception._has_condition(actor, condition)
