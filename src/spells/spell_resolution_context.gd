## Transient shared resolver inputs/results for one target. Never serialized.
class_name SpellResolutionContext
extends RefCounted

var caster: Character
var target: Variant
var spell: Dictionary = {}
var decisions: Dictionary = {}
var observers: Array = []
var slot_level := 0
var distance_feet := -1
var effect_cast: Dictionary = {}
var incoming_slot_spent := false
var incoming_slot_key := ""
var has_damage_payload := false
