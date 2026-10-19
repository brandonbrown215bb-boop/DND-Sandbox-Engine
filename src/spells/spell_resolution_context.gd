## Transient shared resolver inputs/results for one target. Never serialized.
class_name SpellResolutionContext
extends RefCounted

var caster: Character
var target: Variant
var spell: Dictionary = {}
var decisions: Dictionary = {}
## Live combat/room owner for location facts; never serialized or copied as a snapshot.
var spatial_host: SpellCastContext
var observers: Array = []
var slot_level := 0
var distance_feet := -1
var effect_cast: Dictionary = {}
## Runtime invocation identity and optional exact item copy captured by the cast host.
var invocation_id := ""
var spell_definition_id := ""
var action_id := ""
var action_invocation_id := ""
var parent_source_id := ""
var item_definition_id := ""
var item_instance_id := ""
var item_copy_validated := false
var source_definition_id := ""
var source_instance_id := ""
var source_owner_id := ""
## Exact ordered step that owns this save, when resolution is inside a shared spell.
var originating_step_id := ""
var incoming_slot_spent := false
var incoming_slot_key := ""
var incoming_slot_pool_id := "ordinary"
var interrupted := false
var canceled := false
var has_damage_payload := false
## One transient attack occurrence and the window receipts emitted by its owner.
## This is shared with existing pending choices but is never saved.
var resolution_window_context: Dictionary = {}
var resolution_window: Dictionary = {}
## Exact recipient for the current receipt; another target cannot inherit it.
var resolution_window_target: Variant = null
