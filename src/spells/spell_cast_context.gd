## One transient cast request and its stage results. Never serialized.
## Explicit callbacks synchronize pending selections, input locks and redraws.
class_name SpellCastContext
extends RefCounted

static var _next_invocation_serial := 1

const CLEAR_ACTION := 1
const CLEAR_SPELL := 2
const CLEAR_INTERVENTION := 4
const CLEAR_WISH := 8

var caster: Character
var invocation_id := ""
var action_id := ""
var action_invocation_id := ""
var parent_source_id := ""
var component_copy_validated := false
## Exploration ritual completion; elapsed before creating the new effect.
var ritual_seconds := 0
var spell: Dictionary = {}
var formula_inputs: Dictionary = {}
var ordered_result: Dictionary = {}
var players: Array[Dictionary] = []
var monsters: Array[Dictionary] = []
var player_index := -1
var detected_creatures: Dictionary = {}
var detected_hazards: Dictionary = {}
var effect_boundary_rounds: Dictionary = {}
var grid: HexGrid
var hud: CombatHUD
var tracker: InitiativeTracker
## Encounter-only action history. Never serialized with the transient cast.
var action_history: CombatActionHistory
var turn_budget: CombatTurnBudget
var areas: CombatSpellZones
var prestidigitation_effects: Dictionary = {}
var divine_intervention := false
var divine_intervention_wish := false
var owner_label := ""
var target_coord := Vector2i.ZERO
var additional_target_coord := Vector2i(9999, 9999)
var extra_target_coords: Array[Vector2i] = []

var commit_guard: Callable
var can_spend: Callable
var highlight_reachable: Callable
var reset_pending: Callable
var publish_spell: Callable
var set_resolving: Callable
var owner_label_for_character: Callable
var action_cost_for_command: Callable
var add_find_steed_entity: Callable
var apply_find_steed_life_bond: Callable
var check_battle_end_conditions: Callable
var collect_attack_inspiration_decision: Callable
var collect_bardic_inspiration_save_decision: Callable
var collect_countercharm_decisions: Callable
var collect_counterspell_decisions: Callable
var collect_reaction_decisions: Callable
var collect_spell_shield_decision: Callable
var collect_stroke_of_luck_save_decision: Callable
var collect_roll_token_decision: Callable
var collect_projected_ward_decision: Callable
var offer_potent_spellcasting_vitality: Callable
var offer_power_word_heal_stand: Callable
var offer_sneak_attack: Callable
var offer_divine_smite: Callable
var offer_weapon_damage_riders: Callable
var publish_true_strike_activity: Callable
var spend_action_cost: Callable
var trigger_enemy_defeat_features: Callable
var finish_targeting: Callable
var begin_targeting: Callable
var minor_illusion_markers: Dictionary = {}
var mage_hand_markers: Dictionary = {}
var light_spell_markers: Dictionary = {}
var dancing_light_sets: Dictionary = {}
var produce_flame_markers: Dictionary = {}
var refresh_poison_senses: Callable
var refresh_creature_senses: Callable
var end_concentration: Callable
var publish_source_range_events: Callable
var end_resilient_sphere: Callable
var push_blocked_hexes: Callable
var redraw_entities: Callable
var push_combat_target: Callable

var spell_origin := Vector2i.ZERO
var delivery_character: Character
var target_type := "single"
var command_selection: Array[Vector2i] = []
var chain_target_ids: Array[String] = []
var area_selection: Dictionary = {}
var component_item_id := ""
var component_instance_id := ""
var spell_level := 0
var slot_level_used := 0
var payment_receipt: Dictionary = {}
var incoming_slot_spent := false
var incoming_slot_pool_id := "ordinary"
var result_recovery_queued := false
var reaction_decisions: Dictionary = {}
## Canonical transient exemption choice; caller decisions are never its authority.
var recipient_exemption_selection: Dictionary = {}
var spell_attack_available := false
var apotheosis_available := false
var apotheosis_assigned := false
var quickened_selected := false
var twinned_selected := false
var targets: Array = []
var counterspell_observers: Array = []
var counterspell_decisions: Dictionary = {}
var counterspell_pending := true
var successful := false
var interrupted := false
var damage_dealt := 0
## Transient receipts for every original and linked damage recipient in this cast.
var damage_receipts: Array[Dictionary] = []
## Published only after the cast and its area effects have settled.
var completed_cast_facts: Dictionary = {}
var area_source_id := ""
var restrained_targets: Array = []
var initial_targets: Dictionary = {}
var shape_locked_targets: Array = []

func _init() -> void:
	invocation_id = "spell-invocation:%d" % _next_invocation_serial
	_next_invocation_serial += 1
	action_invocation_id = "action-invocation:%d" % _next_invocation_serial
	_next_invocation_serial += 1

func clear_pending(flags: int) -> void:
	if flags & CLEAR_SPELL:
		spell = {}
	if flags & CLEAR_INTERVENTION:
		divine_intervention = false
	if flags & CLEAR_WISH:
		divine_intervention_wish = false
	if reset_pending != null and reset_pending.is_valid():
		reset_pending.call(flags)


func replace_spell(value: Dictionary) -> void:
	spell = value
	if publish_spell != null and publish_spell.is_valid():
		publish_spell.call(value)
