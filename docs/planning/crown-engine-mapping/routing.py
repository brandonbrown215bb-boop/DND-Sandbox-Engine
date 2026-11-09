"""Authored routes from written clauses to shared requirements (not opcodes).

The upstream authoring groups are leads. The explicit candidate/feature routes
below refine them; full sequences retain every qualifier at the source pointer.
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
GROUPS = {}


def groups(name, body):
    GROUPS[name] = {row.split(":")[0]: row.split(":")[1].split()
                    for row in body.strip().splitlines()}


groups("crown-spells", """
attack_interception:ILLUSION REACTION
attack_riders:RIDER
attitude_scopes:KNOWLEDGE BENEFIT
auras:ZONE BENEFIT
barriers:BARRIER
benefit_only_rest:REST
benefit_recipients:BENEFIT LIFETIME
breathing:BREATH
cast_failure:BUDGET
communication:LANGUAGE KNOWLEDGE
compelled_actions:GRANTED_MOVE BUDGET
containment:CONTAIN
created_actors:ACTOR COMMAND
created_objects:CREATION
curse_damage_routes:RIDER
curses_and_attunement:ITEM_MAGIC
damage_copy:DAMAGE_COPY
damage_repeat_saves:REPEAT
damage_to_healing:DAMAGE_HEAL
death_and_remains:REMAINS
detection:DETECT
detection_masking:DETECT LIFETIME
dispelling:DISPEL
divination:KNOWLEDGE
falling:FALL
flight:MOVE FALL
forced_movement:GRANTED_MOVE
forms:FORM
granted_actions:CREATION BUDGET
granted_movement:MOVE
heard_targeting:LIGHT
illusions:ILLUSION
item_benefits:ITEM_MAGIC
light_and_darkness:LIGHT DISPEL
liquid_surfaces:MOVE BREATH
long_cast:WORK
long_lifetimes:LIFETIME
object_ignition:OBJECT HAZARD
object_repair:REPAIR
object_targets:OBJECT
objects:OBJECT
phasing:PHASE
post_hit_casts:POSTHIT
quantities:QUANTITY SUPPLY CREATION
reaction_routes:REACTION
remote_senses:REMOTE
restricted_budgets:BUDGET
retained_conversion_limit:BASE
retargeting:RIDER
roll_hosts:ROLL BENEFIT
stored_spells:STORAGE
teleportation:PHASE
terrain:MOVE ZONE
tethers:GRAPPLE ZONE
travel:TRAVEL
utility_world:CREATION OBJECT KNOWLEDGE
wards_and_triggers:WARD
world_outcomes:KNOWLEDGE
zones:ZONE
""")
groups("crown-characters", """
progression:ACQUIRE MULTI BACKGROUND SPECIES
choices:CHOICE
casting:CAST
resources:POOL
rolls:ROLL DICE
attacks:WEAPON RIDER
stats:ARMOR BENEFIT
source_lifetimes:LIFETIME
conditions:BASE GRAPPLE
movement:MOVE GRANTED_MOVE
forms:FORM ACTOR COMMAND
reactions:REACTION DEFLECT
falling:FALL
actions:BUDGET
languages:LANGUAGE
world:KNOWLEDGE DETECT
items:PACK COMPONENT ITEM_MAGIC
allocation:BENEFIT POOL
initiative:INIT
""")
groups("crown-equipment", """
ordinary_items:PACK OBJECT
weapons:WEAPON
armor:ARMOR
ammunition:AMMO
packs:PACK CARRY
containers:CARRY QUANTITY
environment:SUPPLY
hazards:HAZARD
context_benefits:TOOL KNOWLEDGE
bindings:GRAPPLE
light_fuel:LIGHT QUANTITY
oil:ITEM_ATTACK HAZARD QUANTITY
healing:ITEM_ATTACK QUANTITY
attack_items:ITEM_ATTACK
tools:TOOL
crafting:CRAFT
focuses:COMPONENT
choices:PACK CHOICE
spellbooks:BOOK
""")
groups("crown-reachable-items", """
weapons:WEAPON
armor:ARMOR
ammunition:AMMO
net:ITEM_ATTACK GRAPPLE
potions:ITEM_ATTACK QUANTITY
components:COMPONENT
currency_rewards:CLEAR_REWARD EVENT_REWARD MONSTER_REWARD
quest_items:WARD CLEAR_REWARD
campaign_custom:ITEM_ATTACK
created_items:CREATION QUANTITY SUPPLY
created_books:BOOK
character_creations:CREATION ITEM_MAGIC
legacy_components:COMPONENT
""")
groups("crown-creatures", """
map_statistics:ACTOR
map_attacks:ACTOR WEAPON RIDER
map_conditions:BASE GRAPPLE LIFETIME
map_movement:MOVE GRANTED_MOVE FALL PHASE
map_senses:LIGHT REMOTE LANGUAGE DETECT
map_resources:POOL COMMAND
map_forms:FORM ACTOR COMMAND
map_aftermath:REMAINS
map_items:REPAIR ITEM_MAGIC
map_party:COMPANION
map_containment:CONTAIN
map_casting:CAST
map_rolls:ROLL
""")
groups("crown-world", """
travel:TRAVEL
discovery:TOOL KNOWLEDGE TRAP
locks_traps:WARD TRAP
objects:OBJECT CARRY REPAIR
supplies:SUPPLY QUANTITY
hazards:HAZARD FALL BREATH
senses:LIGHT REMOTE
areas_wards:ZONE WARD STORAGE DISPEL
knowledge_social:LANGUAGE KNOWLEDGE ILLUSION
bodies_actors:REMAINS ACTOR COMMAND
access_movement:MOVE PHASE CONTAIN BARRIER
rest_time:WORK REST LIFETIME
objectives_rewards:CLEAR_REWARD EVENT_REWARD MONSTER_REWARD EVENT
""")

FEATURES = {}


def feature(ids, caps):
    for key in ids.split():
        assert key not in FEATURES, key
        FEATURES[key] = caps.split()


feature("barbarian_weapon_mastery fighter_weapon_mastery paladin_weapon_mastery ranger_weapon_mastery rogue_weapon_mastery", "WEAPON CHOICE")
feature("barbarian_extra_attack fighter_extra_attack monk_extra_attack paladin_extra_attack ranger_extra_attack", "WEAPON BUDGET")
feature("barbarian_ability_score_improvement bard_ability_score_improvement cleric_ability_score_improvement druid_ability_score_improvement fighter_ability_score_improvement monk_ability_score_improvement paladin_ability_score_improvement ranger_ability_score_improvement rogue_ability_score_improvement sorcerer_ability_score_improvement warlock_ability_score_improvement wizard_ability_score_improvement", "CHOICE ACQUIRE")
feature("barbarian_barbarian_subclass bard_bard_subclass cleric_cleric_subclass druid_druid_subclass fighter_fighter_subclass monk_monk_subclass paladin_paladin_subclass ranger_ranger_subclass rogue_rogue_subclass sorcerer_sorcerer_subclass warlock_warlock_subclass wizard_wizard_subclass", "ACQUIRE CHOICE")
feature("bard_spellcasting cleric_spellcasting druid_spellcasting paladin_spellcasting ranger_spellcasting sorcerer_spellcasting warlock_pact_magic", "CAST ACQUIRE")
feature("wizard_spellcasting", "CAST BOOK ACQUIRE")
feature("cleric_life_domain_spells circle_of_the_land_circle_of_the_land_spells paladin_oath_of_devotion_spells sorcerer_draconic_spells warlock_fiend_spells", "CAST CHOICE ACQUIRE")
feature("barbarian_rage", "POOL BENEFIT RIDER LIFETIME BUDGET")
feature("barbarian_unarmored_defense monk_unarmored_defense", "ARMOR BENEFIT")
feature("barbarian_danger_sense", "ROLL")
feature("barbarian_reckless_attack", "RIDER ROLL LIFETIME")
feature("barbarian_primal_knowledge", "CHOICE ROLL")
feature("barbarian_fast_movement monk_unarmored_movement", "BENEFIT ARMOR MOVE")
feature("path_of_the_berserker_frenzy", "RIDER DICE")
feature("bard_bardic_inspiration", "ROLL POOL LIFETIME")
feature("bard_expertise rogue_expertise wizard_scholar college_of_lore_bonus_proficiencies", "CHOICE ACQUIRE ROLL")
feature("bard_jack_of_all_trades", "ROLL")
feature("bard_font_of_inspiration", "POOL ROLL")
feature("college_of_lore_cutting_words", "ROLL REACTION POOL")
feature("cleric_divine_order druid_primal_order", "CHOICE CAST ROLL ACQUIRE")
feature("cleric_channel_divinity", "POOL BENEFIT GRANTED_MOVE BASE")
feature("cleric_sear_undead", "BASE POOL ZONE")
feature("life_domain_disciple_of_life", "BENEFIT CAST LIFETIME")
feature("life_domain_preserve_life", "BENEFIT POOL")
feature("druid_druidic", "LANGUAGE KNOWLEDGE CAST")
feature("druid_wild_shape", "FORM ACTOR CHOICE POOL")
feature("druid_wild_companion", "CAST COMPONENT ACTOR COMMAND LIFETIME")
feature("druid_wild_resurgence", "POOL")
feature("circle_of_the_land_land_s_aid", "BASE ZONE BENEFIT POOL")
feature("fighter_fighting_style paladin_fighting_style ranger_fighting_style", "CHOICE CAST WEAPON")
feature("fighter_second_wind", "POOL BASE")
feature("fighter_action_surge", "BUDGET POOL")
feature("fighter_tactical_mind", "ROLL POOL")
feature("fighter_tactical_shift", "GRANTED_MOVE POOL")
feature("champion_improved_critical", "DICE")
feature("champion_remarkable_athlete", "ROLL GRANTED_MOVE")
feature("monk_martial_arts", "WEAPON DICE GRAPPLE BUDGET")
feature("monk_monks_focus", "POOL BUDGET MOVE WEAPON")
feature("monk_uncanny_metabolism", "POOL BASE")
feature("monk_deflect_attacks", "DEFLECT")
feature("monk_slow_fall", "FALL REACTION")
feature("monk_stunning_strike", "POSTHIT RIDER BASE POOL")
feature("monk_open_hand_technique", "BASE GRANTED_MOVE")
feature("paladin_lay_on_hands", "BENEFIT POOL BASE")
feature("paladin_paladins_smite", "CAST POSTHIT POOL")
feature("paladin_channel_divinity", "DETECT POOL LIFETIME")
feature("paladin_faithful_steed", "CAST ACTOR COMMAND")
feature("oath_of_devotion_sacred_weapon", "ITEM_MAGIC WEAPON LIGHT LIFETIME")
feature("ranger_favored_enemy", "CAST RIDER DETECT")
feature("ranger_deft_explorer", "CHOICE LANGUAGE ACQUIRE")
feature("hunter_hunter_s_lore", "DETECT")
feature("hunter_hunter_s_prey", "RIDER BUDGET CHOICE")
feature("rogue_sneak_attack", "RIDER DICE")
feature("rogue_thieves_cant", "LANGUAGE KNOWLEDGE")
feature("rogue_cunning_action", "BUDGET BASE")
feature("rogue_steady_aim", "RIDER MOVE LIFETIME")
feature("rogue_cunning_strike", "POSTHIT DICE BASE GRANTED_MOVE TOOL")
feature("rogue_uncanny_dodge", "REACTION DEFLECT")
feature("thief_fast_hands", "TOOL BUDGET WARD TRAP ITEM_ATTACK")
feature("thief_second_story_work", "MOVE")
feature("sorcerer_innate_sorcery", "CAST ROLL POOL LIFETIME")
feature("sorcerer_font_of_magic sorcerer_sorcerous_restoration warlock_magical_cunning wizard_arcane_recovery", "POOL REST WORK")
feature("sorcerer_metamagic", "CHOICE CAST")
feature("draconic_sorcery_draconic_resilience", "BENEFIT ARMOR ACQUIRE")
feature("warlock_eldritch_invocations", "CHOICE ACQUIRE")
feature("fiend_dark_ones_blessing", "RIDER BENEFIT")
feature("wizard_ritual_adept wizard_memorize_spell evoker_evocation_savant", "BOOK CAST WORK")
feature("evoker_potent_cantrip", "DICE BASE")

CANDIDATES = {}


def candidate(set_name, ids, caps, operations=None, rules=None):
    for key in ids.split():
        value = {"default": caps.split()}
        if operations:
            value["operations"] = {str(i): v.split() for i, v in enumerate(operations)}
        if rules:
            value["rules"] = {k: v.split() for k, v in rules.items()}
        CANDIDATES[set_name + ":" + key] = value


def character(ids, caps, operations=None):
    candidate("crown-characters", ids, caps, operations)


character("agonizing_blast", "RIDER CAST CHOICE")
character("armor_of_shadows ascendant_step mask_of_many_faces master_of_myriad_forms misty_visions one_with_shadows otherworldly_leap", "CAST CHOICE")
character("devils_sight", "LIGHT")
character("eldritch_mind", "ROLL")
character("eldritch_smite", "POSTHIT POOL")
character("eldritch_spear", "CAST")
character("fiendish_vigor", "CAST DICE")
character("gaze_of_two_minds", "REMOTE LIFETIME")
character("gift_of_the_depths", "CAST BREATH MOVE")
character("investment_of_the_chain_master", "COMMAND FORM REACTION")
character("lessons_of_the_first_ones", "CHOICE ACQUIRE")
character("pact_of_the_blade", "ITEM_MAGIC CREATION WEAPON")
character("pact_of_the_chain", "COMMAND ACTOR CAST COMPONENT")
character("pact_of_the_tome", "BOOK CAST CREATION")
character("repelling_blast", "GRANTED_MOVE RIDER")
character("thirsting_blade", "WEAPON BUDGET")
character("careful_spell distant_spell extended_spell heightened_spell quickened_spell subtle_spell transmuted_spell twinned_spell", "CAST POOL")
character("empowered_spell seeking_spell", "CAST DICE POOL")
character("dragonborn", "SPECIES", ["SPECIES LANGUAGE LIGHT", "BENEFIT", "BASE WEAPON BUDGET POOL", "FALL MOVE POOL LIFETIME"])
character("dwarf", "SPECIES", ["SPECIES LANGUAGE LIGHT", "BENEFIT ROLL", "ACQUIRE BENEFIT", "LIGHT POOL LIFETIME"])
character("elf", "SPECIES", ["SPECIES LANGUAGE LIGHT", "ROLL", "CHOICE", "REST BASE", "CAST ACQUIRE"])
character("gnome", "SPECIES", ["SPECIES LANGUAGE LIGHT", "ROLL", "CAST", "CREATION WORK"])
character("goliath", "SPECIES", ["SPECIES LANGUAGE", "POSTHIT DEFLECT PHASE POOL", "FORM BENEFIT", "GRAPPLE CARRY ROLL"])
character("halfling", "SPECIES", ["SPECIES LANGUAGE", "ROLL", "MOVE", "ROLL", "BASE LIGHT"])
character("human", "SPECIES", ["SPECIES LANGUAGE", "ROLL REST", "CHOICE", "CHOICE ACQUIRE"])
character("orc", "SPECIES", ["SPECIES LANGUAGE LIGHT", "BUDGET BENEFIT POOL", "BASE REMAINS"])
character("tiefling", "SPECIES", ["SPECIES LANGUAGE LIGHT", "BENEFIT CAST ACQUIRE", "CAST", "CAST ACQUIRE"])
character("alert", "CHOICE INIT ROLL", ["ROLL", "INIT"])
character("magic_initiate", "CAST CHOICE ACQUIRE")
character("savage_attacker great_weapon_fighting", "DICE WEAPON")
character("skilled ability_score_improvement", "CHOICE ACQUIRE")
character("grappler", "GRAPPLE CHOICE ACQUIRE")
character("archery two_weapon_fighting", "WEAPON")
character("defense", "ARMOR BENEFIT")
character("acolyte criminal sage soldier", "BACKGROUND PACK CHOICE ACQUIRE")
character("crown_multiclass", "MULTI CAST ACQUIRE")
FEATURES["wizard_arcane_recovery"].append("BOOK")

# Exact spell clauses refine operation-wide source associations. Headings and
# upgrade units remain retained; the full rule always outranks these facets.
candidate("crown-spells", "aid", "BENEFIT LIFETIME", rules={"r001": "BASE BENEFIT", "r002": "BENEFIT LIFETIME", "r003": "BENEFIT", "r004": "BENEFIT"})
candidate("crown-spells", "fireball burning_hands fire_bolt", "BASE OBJECT HAZARD")
candidate("crown-spells", "chromatic_orb", "BASE COMPONENT")
candidate("crown-spells", "true_strike", "BASE WEAPON COMPONENT")
candidate("crown-spells", "shatter thunderwave", "BASE OBJECT")
candidate("crown-spells", "bestow_curse", "RIDER LIFETIME BUDGET ROLL")
candidate("crown-spells", "tashas_hideous_laughter", "REPEAT BASE LIFETIME")
candidate("crown-spells", "slow", "BUDGET BENEFIT")
candidate("crown-spells", "hex hunters_mark", "RIDER LIFETIME DETECT")
candidate("crown-spells", "warding_bond", "DAMAGE_COPY BENEFIT COMPONENT LIFETIME")
candidate("crown-spells", "prayer_of_healing", "REST WORK")
candidate("crown-spells", "animate_dead", "ACTOR COMMAND REMAINS WORK LIFETIME")
candidate("crown-spells", "find_familiar", "ACTOR COMMAND REMOTE WORK COMPONENT")
candidate("crown-spells", "find_steed", "ACTOR COMMAND FORM")
candidate("crown-spells", "phantom_steed", "ACTOR COMMAND TRAVEL LIFETIME")
candidate("crown-spells", "tensers_floating_disk", "CREATION CONTAIN TRAVEL")
candidate("crown-spells", "rope_trick", "CONTAIN PHASE BARRIER")
candidate("crown-spells", "sacred_flame", "BASE")
candidate("crown-spells", "lesser_restoration", "BASE")
candidate("crown-spells", "resistance", "BENEFIT DEFLECT")
candidate("crown-world", "sequential_dungeon", "EVENT ACTOR CLEAR_REWARD TRAVEL")
candidate("crown-world", "quest_board_bounty", "EVENT_REWARD")
candidate("crown-world", "ruins_of_ashvale_clear caverns_of_gloom_clear tower_of_the_lich_clear", "CLEAR_REWARD")
candidate("crown-world", "town_events__quest_board", "EVENT KNOWLEDGE EVENT_REWARD", operations=["EVENT_REWARD ACTOR", "EVENT_REWARD", "EVENT KNOWLEDGE"])

# Exact behavior names identify clauses in these written sources, not dispatch
# registration in the game. Keep their resulting per-index routes explicit.
BEHAVIORS = {
    "Swallow": "CONTAIN BASE",
    "Corrosive Form": "REPAIR AMMO",
    "Pseudopod": "ACTOR REPAIR",
    "Undead Fortitude": "BASE REMAINS ROLL",
    "Life Drain": "ACTOR REMAINS BENEFIT",
    "Pack Tactics": "RIDER ROLL", "Bloodied Fury": "RIDER ROLL",
    "Sunlight Sensitivity": "LIGHT ROLL",
    "Amphibious": "BREATH", "Water Breathing": "BREATH", "Hold Breath": "BREATH",
    "Amorphous": "PHASE", "Compression": "PHASE",
    "Jumper": "MOVE", "Standing Leap": "MOVE", "Spider Climb": "MOVE",
    "Flyby": "GRANTED_MOVE", "Agile": "GRANTED_MOVE", "Bubble Dash": "GRANTED_MOVE",
    "Illumination": "LIGHT", "Mimicry": "LANGUAGE KNOWLEDGE",
    "Web Walker": "MOVE DETECT", "Beast of Burden": "CARRY",
    "Heart Sight": "DETECT", "Burst of Ingenuity (2/Day)": "ROLL REACTION POOL",
    "Ink Cloud (1/Day)": "ZONE REACTION GRANTED_MOVE POOL",
    "Scare (1/Day)": "ACTOR BASE POOL", "Multiattack": "ACTOR WEAPON",
    "Shape-Shift": "FORM", "Invisibility": "CAST LIFETIME",
    "Magic Resistance": "ROLL", "Swarm": "ACTOR BENEFIT MOVE",
}
creatures = ROOT / "docs/planning/preparation/crown-creatures"
for row in json.loads((creatures / "index.json").read_text(encoding="utf-8"))["candidates"]:
    d = json.loads((creatures / row["path"]).read_text(encoding="utf-8"))
    for i, op in enumerate(d["authored_operations"]):
        if op.get("name") in BEHAVIORS:
            key = "crown-creatures:" + d["id"]
            CANDIDATES.setdefault(key, {}) .setdefault("operations", {})[str(i)] = BEHAVIORS[op["name"]].split()
for name in ["crown-equipment", "crown-reachable-items"]:
    folder = ROOT / "docs/planning/preparation" / name
    for row in json.loads((folder / "index.json").read_text(encoding="utf-8"))["candidates"]:
        path = folder / row["path"]
        if ".." in row["path"]:
            continue
        d = json.loads(path.read_text(encoding="utf-8"))
        if d.get("kind") == "potion":
            value = CANDIDATES.setdefault(name + ":" + d["id"], {})
            value["default"] = ["ITEM_ATTACK", "MIX", "QUANTITY"]
            for i, op in enumerate(d["authored_operations"]):
                if isinstance(op, str) and ("mixing" in op or "miscibility" in op):
                    value.setdefault("operations", {})[str(i)] = ["MIX"]

SUPPLEMENTS = {
    "packages.json": ["PACK", "CHOICE"], "languages.json": ["LANGUAGE"],
    "dependency-map.json": ["ACTOR", "COMMAND", "OBJECT", "KNOWLEDGE", "CAST"],
    "acquisition-links.json": ["PACK", "ACTOR", "CLEAR_REWARD", "EVENT_REWARD", "MONSTER_REWARD"],
    "consumer-trace.json": ["EVENT", "CLEAR_REWARD", "EVENT_REWARD", "MONSTER_REWARD"],
    "selection-links.json": ["ACTOR", "FORM", "COMMAND", "COMPANION"],
    "reachability.json": ["PACK", "COMPONENT", "CLEAR_REWARD", "EVENT_REWARD", "MONSTER_REWARD"],
    "spell-materials.json": ["COMPONENT"], "created-item-boundaries.json": ["CREATION", "CRAFT"],
    "animal-source-inventory.json": ["ACTOR", "FORM"]}


def write():
    (HERE / "routes.json").write_text(json.dumps({"schema": "crown-clause-routes/1", "groups": GROUPS,
        "features": FEATURES, "candidates": CANDIDATES, "supplements": SUPPLEMENTS}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    write()
    print(f"Wrote {len(FEATURES)} exact feature routes and {len(CANDIDATES)} candidate refinements.")
