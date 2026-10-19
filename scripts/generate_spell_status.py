"""Reconcile production spell IDs and generate the owner's delivery register.

Input: actual DataLoader export, not a Python imitation of the game loader.
Only the dated evidence reviewed below grants recorded-slice status. Neither
damage fields, class access, nor a passing suite total certify a complete spell.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import Counter
from pathlib import Path
from spell_dependencies import CAPABILITIES, assign as assign_dependencies, validate as validate_dependencies

ROOT = Path(__file__).resolve().parents[1]
REGISTER = ROOT / "docs/mechanics/spell_status.json"
REPORT = ROOT / "docs/mechanics/spell-status.md"

# Planning families, not promises that the current executor supports every member.
# A spell can have secondary needs; primary assignment makes counts non-overlapping.
FAMILIES = {
    "timed_effects": ("Timed effects, repeat saves and source tracking", "The seven-spell source-owned batch, including the rays and Hold spells, is delivered as bounded slices. Reuse SpellEffects and SpellEncounterLifecycle for remaining spells; audit individual expiry, repeat-save and campaign-persistence gaps.", "aid armor_of_agathys aura_of_life bane barkskin beacon_of_hope blade_ward bless blur crusaders_mantle death_ward divine_favor elemental_weapon enhance_ability enlarge/reduce expeditious_retreat false_life fire_shield foresight glibness guidance haste heroes_feast heroism hex holy_aura hunters_mark longstrider mage_armor magic_weapon mind_blank mirror_image protection_from_energy protection_from_evil_and_good protection_from_poison ray_of_enfeeblement ray_of_sickness regenerate resistance sanctuary shield shield_of_faith shillelagh stoneskin warding_bond"),
    "control": ("Conditions, control and forced movement", "Share eligible-target saves, condition consequences on both sides, repeat saves, damage breaks and constrained movement. Keep exceptional orders narrow.", "animal_friendship antipathy_sympathy bestow_curse blindness/deafness calm_emotions charm_monster charm_person color_spray command compelled_duel compulsion confusion contagion crown_of_madness dissonant_whispers dominate_beast dominate_monster dominate_person entangle enthrall eyebite fear flesh_to_stone friends geas grease hold_monster hold_person hypnotic_pattern irresistible_dance mass_suggestion power_word_stun sleep slow stinking_cloud suggestion tashas_hideous_laughter telekinesis thorn_whip vicious_mockery web"),
    "persistent_areas": ("Persistent areas, walls and triggered damage", "The encounter-local zone lifetime, movement/turn triggers, trigger caps, terrain costs and concentration cleanup are delivered. Reuse CombatSpellZones, SpellZoneTerrain and SpellZoneConjurations; audit each remaining spell's geometry, triggers and lifetime before enabling it.", "antilife_shell antimagic_field aura_of_vitality black_tentacles blade_barrier call_lightning cloud_of_daggers cloudkill conjure_animals conjure_celestial conjure_elemental conjure_fey conjure_minor_elementals conjure_woodland_beings control_water cordon_of_arrows delayed_blast_fireball earthquake flaming_sphere forbiddance glyph_of_warding guardian_of_faith guards_and_wards gust_of_wind hallow hunger_of_hadar incendiary_cloud insect_plague magic_circle moonbeam plant_growth prismatic_wall sleet_storm spike_growth spirit_guardians storm_of_vengeance sunbeam symbol tsunami wall_of_fire wall_of_force wall_of_ice wall_of_stone wall_of_thorns wind_wall"),
    "summons": ("Summons, companions and created combat entities", "Find Familiar and Animate Dead have verified bounded Crown room/encounter slices. Created Undead retain existence after control expiry. Find Steed retains existing checks awaiting full audit. Animated objects and other created creatures remain open. Modern Conjure records remain in the area family.", "animate_dead animate_objects arcane_hand arcane_sword awaken create_undead faithful_hound find_familiar find_steed giant_insect phantom_steed planar_ally planar_binding simulacrum spiritual_weapon summon_dragon unseen_servant"),
    "visibility": ("Light, visibility and detection", "Obscuration, Invisibility, sense and detection slices now affect gameplay. Reuse their source-owned effects and SpellEncounterPerception; audit terrain line of sight, object visibility, missing sense outcomes and individual spell gaps. Light markers alone remain partial.", "arcane_eye beast_sense clairvoyance continual_flame dancing_lights darkness darkvision daylight detect_evil_and_good detect_magic detect_poison_and_disease faerie_fire find_traps fog_cloud greater_invisibility invisibility light locate_animals_or_plants locate_creature locate_object mislead nondetection pass_without_trace produce_flame scrying see_invisibility true_seeing"),
    "objects": ("Objects, inventory and environmental changes", "Wave 1 ordinary rooms/objects/copies are the first implementation card. Finish their acceptance and campaign-time/exploration-casting foundations before separate Arcane Lock, Knock, Mage Hand and Mending integrations. Identify and Goodberry retain their recorded limits.", "alarm arcane_lock create_food_and_water create_or_destroy_water creation druidcraft elementalism fabricate goodberry heat_metal identify illusory_script instant_summons knock mage_hand magic_mouth mending move_earth nystuls_magic_aura passwall prestidigitation purify_food_and_drink secret_chest stone_shape tensers_floating_disk thaumaturgy"),
    "social_illusions": ("Dialogue, illusions and belief", "Reuse recipient/creature interaction, language, perception and explicit illusion outcomes. Store markers separately from actual belief or interaction effects.", "disguise_self dream hallucinatory_terrain major_image minor_illusion mirage_arcane modify_memory phantasmal_force phantasmal_killer programmed_illusion project_image seeming silent_image speak_with_animals speak_with_dead speak_with_plants weird zone_of_truth"),
    "campaign_information": ("Campaign information and communication", "Reuse the campaign clock and delivery ledger where suitable; add explicit information/recipient outcomes rather than success-only casts.", "animal_messenger augury commune commune_with_nature comprehend_languages contact_other_plane detect_thoughts divination find_the_path legend_lore message sending telepathic_bond tongues"),
    "movement_travel": ("Movement, terrain, travel and other spaces", "Share movement modes and restrictions locally; keep campaign destinations, route validation and inter-plane travel separate from a combat teleport.", "astral_projection banishment blink demiplane dimension_door etherealness feather_fall fly freedom_of_movement gaseous_form gate jump leomunds_tiny_hut levitate magnificent_mansion maze meld_into_stone misty_step plane_shift private_sanctum reverse_gravity rope_trick spider_climb teleport teleportation_circle transport_via_plants tree_stride water_breathing water_walk wind_walk word_of_recall"),
    "body_death": ("Death, bodies and transformations", "Party corpse identity/time, willingness, preservation and bounded Revivify/Gentle Repose now have production paths. Other bodies, created-undeath integration and reversible forms remain open; retain original character identity.", "alter_self animal_shapes clone feign_death gentle_repose imprisonment magic_jar polymorph raise_dead reincarnate resurrection revivify sequester shapechange true_polymorph true_resurrection"),
    "wards_removal": ("Wards, dispelling and restoring state", "Share effect identity/source, eligible removal, immunity, spell-level checks and item attunement where modeled; distinguish condition removal from full curse resolution.", "counterspell dispel_evil_and_good dispel_magic globe_of_invulnerability greater_restoration lesser_restoration remove_curse resilient_sphere silence"),
    "weapon_riders": ("Weapon-triggered and repeated attacks", "Reuse confirmed-hit riders, action/reaction timing, slot scaling and condition cleanup; avoid casting a weapon buff as an immediate ordinary damage spell.", "blinding_smite branding_smite dragons_breath divine_smite ensnaring_strike flame_blade hail_of_thorns lightning_arrow searing_smite shining_smite thunderous_smite true_strike vampiric_touch witch_bolt wrathful_smite"),
    "exceptional": ("Exceptional world or action rules", "Keep explicit supported modes for these unusual spells. Do not build a universal rule engine as a prerequisite for ordinary combat spells.", "befuddlement contingency control_weather forcecage time_stop wish"),
    "direct_resolution": ("Immediate attacks, saves, healing and area selection", "Audit complete target sets, shapes, split damage, extra effects, thresholds and upcasting using existing resolution blocks. A positive damage roll alone is insufficient.", ""),
}

# Historical slices reviewed against current.md, test_runner and encounter source.
EVIDENCE_BATCHES = {
    "longstrider-upcast-integration-verified": "longstrider",
    "animal-friendship-final-integration": "animal_friendship",
    "animal-messenger-integration-final": "animal_messenger",
    "per-caster-light-spells-integration": "dancing_lights light mage_hand",
    "command-integration-verified": "command",
    "blade-ward-integration-final": "blade_ward",
    "color-spray-integration": "acid_splash color_spray vicious_mockery",
    "chill-touch-integration-final": "chill_touch",
    "sacred-flame-integration": "sacred_flame",
    "poison-spray-integration": "poison_spray",
    "srd-spells-integration-final": "shocking_grasp inflict_wounds cure_wounds healing_word",
    "false-life-integration": "false_life",
    "shield-of-faith-integration": "shield_of_faith",
    "guiding-bolt-integration2": "guiding_bolt",
    "sorcerous-burst-final-integration": "sorcerous_burst",
    "disintegrate-integration": "fire_bolt ray_of_frost starry_wisp blight heal ice_knife melfs_acid_arrow disintegrate",
    "pfeg-integration-verified": "protection_from_evil_and_good",
    "protection-poison-integration": "protection_from_poison",
    "ray-sickness-integration-final": "ray_of_sickness",
    "ray-enfeeblement-integration-final": "ray_of_enfeeblement",
    "regenerate-integration": "regenerate",
    "remove-curse-integration": "remove_curse",
    "resilient-sphere-integration-final": "resilient_sphere",
    "detect-magic-live-integration": "detect_magic",
    "blur-live-integration": "blur",
    "detect-evil-good-live": "detect_evil_and_good",
    "detect-poison-disease-live": "detect_poison_and_disease",
    "identify-live": "identify",
    "goodberry-live": "goodberry",
    "sunburst-live-integration": "sunburst",
}

# These boundaries come from the repository's checkpoint/ADRs, not invented
# completion percentages or an exhaustive fresh SRD audit.
LIMITS = {
    "revivify": "Verified bounded party recovery: recorded recent death, spirit willingness and remains restrictions, one original Character restored with 1 HP, one diamond/slot/action, and safe corpse checkpoint continuity. Old unknown death times and expired/ineligible bodies refuse before cost. Arbitrary world/NPC corpses, full injury consequences and complete general death/spell audit remain open.",
    "gentle_repose": "Verified bounded party preservation: original corpse time/identity, consumed two-coin packet, ten-day saved interval, accumulated protected time, recast/expiry eligibility and safe checkpoint continuity. Normal room ritual after reload is verified: 606 seconds, consumed component, no slot. Cast interruptions remain open. Undeath protection exposes a shared check; created-undead integration and automatic decay remain open.",
    "find_familiar": "Verified bounded slice: four curated forms, hour/ritual room casting with consumed incense, form/type replacement, distinct ordinary/Wild Companion lifetime, pocket controls, borrowed combat sight, supported Touch delivery and authored skill Help; safe disk reload and next encounter verified. Other forms, equipment/conditions, special jumping/ceiling/web clauses, local scouting/audio and long-cast interruption remain open. See docs/mechanics/find-familiar-2024.md; full rules completeness remains uncertified.",
    "power_word_heal": "Bard live acceptance verifies two chosen creatures, a downed ally, full HP recovery, optional Reaction standing and one slot/action cost. Dead/disintegrated party targets are refused; sight handles Invisible only, without terrain occlusion. Full clause audit remains open.",
    "power_word_kill": "Bard live acceptance verifies two chosen creatures at the HP threshold and one slot/action cost; focused checks verify outright party death, bypassing death saves. Above-threshold damage uses the existing resolver. Full clause/visibility audit remains open.",
    "eldritch_blast": "Available gameplay slice: beams scale to 2/3/4 at character levels 5/11/17, each has an independent attack roll, and the player may assign each beam to a creature. Agonizing Blast damage applies per hit. Shield can be used when a beam hits and its AC applies to later beams. Visibility/line of sight and the full clause audit remain open.",
    "chain_lightning": "Available bounded combat path: select a visible first creature or object within 150 feet, then distinct secondary targets within 30 feet of that first target; level 7 allows five total targets. Exact identities distinguish creatures, authored room objects, and carried or dropped copies. Unscored objects fail Dexterity saves and damage settles against object HP. Secondary-effect previews, additional target combinations, non-hex geometry, cover and full clause audit remain open.",
    "counterspell": "Available gameplay slice: visible eligible V/S/M spell casts within 60 feet prompt a party Counterspell user with a Reaction and a level-3+ slot or free cast. The caster makes a Constitution save against the counterspeller's DC; a failure dissipates the spell and refunds its spell slot, while the counterspell's resource and Reaction remain spent. Blinded and Invisible checks apply, but terrain occlusion and enemy Counterspell reactions are not modeled; full clause audit remains open.",
    "sleep": "Available gameplay slice: each chosen creature in the 5-foot Sphere makes a Wisdom save; a failed save imposes Incapacitated until the target's next turn, then a repeat save can impose Unconscious on a second failure. Damage or an adjacent party-controlled creature's action to shake ends the effect. Creature immunity and hex area handling use curated game data; monster AI does not choose the wake-up action, and terrain occlusion/full clause audit remain open.",
    "scorching_ray": "The player assigns each base or upcast ray to a creature, including repeat targets; per-target attacks are resolved separately. Shield can be used when a ray hits and its AC applies to later rays. The full clause audit remains open.",
    "shatter": "Available creature gameplay slice: a 10-foot Sphere applies Constitution saves, Thunder damage, half damage on a save, Construct save Disadvantage, and the SRD's 1d8-per-slot upcast. Nonmagical unattended objects are not modeled as damageable combat targets; visibility/line of sight and the full clause audit remain open.",
    "burning_hands": "Available creature gameplay slice: the self-originating 15-foot Cone resolves Dexterity saves, Fire damage, half damage on a save, and +1d6 damage per slot. Ignition of flammable unattended objects, cover/visibility and full clause audit remain open.",
    "cone_of_cold": "Available creature gameplay slice: the self-originating 60-foot Cone resolves Constitution saves, Cold damage, half damage on a save, and +1d8 damage per slot. Cover/visibility and full clause audit remain open.",
    "fire_bolt": "120-foot range (24 five-foot hexes) is corrected. Object ignition, line of sight and full clause audit remain open.",
    "ray_of_frost": "60-foot range (12 five-foot hexes) is corrected. Visibility and full clause audit remain open.",
    "detect_magic": "The live slice senses tracked creature spell effects and positioned spell areas within 30 feet, then spends a separate Magic action to reveal their schools. There is no terrain sight/material barrier model, and unattached objects or magic-item auras are not represented. Full clause audit remains open.",
    "blur": "Live combat verifies Disadvantage against the caster, with immunity for Blindsight and Truesight within range, plus one-minute Concentration cleanup. Combat terrain has no line-of-sight model; the full clause audit remains open.",
    "detect_evil_and_good": "Live combat maintains a 30-foot sense for tracked Aberrations, Celestials, Elementals, Fey, Fiends, and Undead, plus modeled Hallow zones, for up to 10 minutes with Concentration. Creature type and location update as tracked entities move. Material barriers and untracked creatures or Hallow areas are not represented; full clause audit remains open.",
    "detect_poison_and_disease": "Live combat reports tracked Poisoned conditions and poisonous or venomous monsters identified from their poison-damage attacks or poison effects within 30 feet, updating their locations during movement; the effect lasts up to 10 minutes with Concentration and is ritual-eligible. Loose poison sources, disease state, magical contagions, material barriers and yew-leaf inventory enforcement are not modeled. The full clause audit remains open.",
    "identify": "Live combat spends a minute maintaining contact with a carried item or adjacent living creature, then reports the item's catalog description/structured properties or tracked ongoing spells on the creature. The pearl is nonconsumed. Item data has no general structured attunement, charge, ongoing-spell or spell-creator fields; item catalog text is included. Ritual casting is recorded but not offered in the current combat flow. Losing contact or Concentration interrupts the cast. The full clause audit remains open.",
    "goodberry": "Live combat creates a saved pool of ten Goodberries that expire after 24 hours. A party member can take a Bonus Action to eat one and regain 1 Hit Point; the earliest-expiring berry is spent first. Nourishment and berry transfer are not modeled, and ordinary nonpriced Material-component ownership (mistletoe) is not enforced by the shared inventory rules. The full clause audit remains open.",
    "sunburst": "Live combat resolves its 60-foot Sphere, radiant damage with Constitution save for half, source-owned Blinded for one minute on a failed save, and end-of-turn Constitution saves that end only that cast's condition. It removes overlapping magical Darkness and preserves zones outside the Sphere. The hex map approximates Sphere geometry; cover, material-component inventory and the full clause audit remain open.",
    "meteor_swarm": "Four distinct visible 40-foot Sphere centers select correctly, overlap hexes deduplicate, and each creature makes one Dexterity save whose Fire/Bludgeoning packets settle separately. Authored unattended room objects take separately mitigated damage and flammable objects gain a saved burning flag. Dropped combat gear and other object records are not enumerated, so casting remains gated before costs.",
    "circle_of_death": "Available creature gameplay slice: the 60-foot Sphere applies Constitution saves, Necrotic damage, half damage on a save, a 2d8-per-slot upcast and requires the carried 500 GP black-pearl powder without consuming it. Object effects, cover/visibility and full clause audit remain open.",
    "thunderwave": "Available creature gameplay slice: the 15-foot Cube points away from the caster, failed Constitution saves take Thunder damage and are pushed 10 feet, successful saves take half damage only, and upcasting adds 1d8 per slot. Hex-grid cube geometry approximates a three-by-three footprint. Unsecured object movement and the 300-foot audible boom are not modeled; full clause audit remains open.",
    "finger_of_death": "Unavailable: the resolver applies damage but cannot create and own the Zombie that appears when this spell kills a Humanoid. The SRD Zombie outcome is recorded; casting is refused before costs until created creatures and their orders are supported.",
    "contact_other_plane": "Unavailable: the spell can prompt for or resolve the save, but does not let the caster ask up to five questions or receive answers. Question-limit metadata is recorded; casting is refused before costs until the question and answer flow exists.",
    "power_word_stun": "Available creature gameplay slice: targets at 150 HP or fewer are Stunned without an initial save and repeat Constitution saves at the end of their turns until they succeed; targets above 150 HP have Speed 0 until the caster's next turn. Cover/visibility beyond Invisible checks and full clause audit remain open.",
    "true_strike": "Available gameplay slice: uses a proficient equipped weapon, spellcasting ability for its attack and damage, and the level 5/11/17 Radiant dice. The caster chooses weapon or Radiant damage type; shared attack reactions and eligible weapon riders apply. Weapon range comes from game equipment data; targets must be combat creatures, monster AI reactions and the full clause audit remain open.",
    "mass_cure_wounds": "Available gameplay slice: selects a point within 60 feet, then allows up to six chosen creatures in the 30-foot-radius Sphere to regain 5d8 plus the spellcasting modifier, with +1d8 per slot level above five. The hex Sphere approximates table geometry; targets must be combat creatures and the full clause audit remains open.",
    "mass_healing_word": "Available gameplay slice: lets the caster choose up to six visible creatures within 60 feet; each regains 2d4 plus the spellcasting modifier, with +1d4 per slot level above three. Character and monster healing use the shared combat effect path; targets must be creatures present in combat and the full clause audit remains open.",
    "blindness/deafness": "Available gameplay slice: the caster chooses Blinded or Deafened; a failed Constitution save applies the selected condition with a source-owned one-minute effect, and a successful Constitution save at the end of a target's turn ends only that target's effect. A level-3 live cast verifies two targets, captured save DC and one slot/Magic-action cost. Combat creatures and hex range are required; terrain visibility and the full clause audit remain open.",
    "grease": "Available gameplay slice: Grease applies Dexterity saves to creatures in a point-targeted 10-foot area, makes affected hexes Difficult Terrain, and triggers new saves on entry and at the end of turns spent there. The zone lasts 10 combat rounds and captured save DC is retained. The seven-hex square approximation handles normal movement, spell teleport landings and spell-driven pushes; other forced-movement sources and true square geometry remain outside the slice.",
    "spike_growth": "Available gameplay slice: Spike Growth creates a concentration-linked, source-keyed 20-foot Sphere that adds Difficult Terrain and deals 2d4 Piercing damage for each five-foot hex a creature travels inside it. The live movement flow verifies teleport landings do not count as travel and ending concentration removes the zone. Map edges clip areas to existing hexes; camouflage recognition and some non-path forced movement remain outside the slice.",
    "entangle": "Available gameplay slice: Entangle creates a concentration-linked 20-foot square (approximated by a radius-two hex area), adds Difficult Terrain, and applies source-keyed Restrained on failed initial Strength saves. Restrained creatures have Speed 0 and can spend an Action on Strength (Athletics) to escape; monsters make the escape check on their turn. Map edges clip the area to existing hexes; exact square geometry remains outside the slice.",
    "black_tentacles": "Available gameplay slice: Black Tentacles creates a 20-foot square (approximated by a radius-two hex area), adds Difficult Terrain, and applies source-owned Restrained on failed initial or repeated Strength saves. Entry and end-of-turn triggers allow one save per creature per turn; party creatures can spend an Action on Strength (Athletics) to escape and monsters attempt the check on their turn. Levels 5-6 last 8 hours without Concentration, levels 7-8 last 24 hours, and level 9 lasts until dispelled. These long-duration zones exist only in the current encounter, area geometry and terrain visibility are approximated, the material component is not enforced, and the full clause audit remains open.",
    "sleet_storm": "Available gameplay slice: a 20-foot-radius, 40-foot-high Cylinder creates a Difficult Terrain zone. Creatures make one Dexterity save per turn on first entry or at turn start; failed saves cause Prone and end that creature's Concentration. The zone lasts 1 minute, or 2 minutes with Extended Spell, and ends with the caster's Concentration. The current hex projection is a 20-foot-radius ground disk; obscured vision, flame extinguishing, vertical targeting, monster spell Concentration and terrain visibility are not enforced, and the full clause audit remains open.",
    "wall_of_fire": "Bounded gameplay slice verified 2026-10-08: the production record selects two in-range endpoints up to 60 feet apart and resolves initial Dexterity-save damage. Its slot-scaled zone and saved Concentration owner survive combat-to-room transfer and character/room reload. First entry into the wall and ending a turn in its danger footprint deal full Fire damage with separate trigger ledgers and no further save. The danger side is one adjacent five-foot caster-facing strip. Choosing either side, the full ten-foot strip, ring form, opaque wall, exact 20-foot height, 1-foot thickness, vertical targeting and non-hex geometry remain open. Material component ownership and a full clause audit remain open.",
    "cloud_of_daggers": "Gameplay implementation slice: casting damages creatures in the selected 5-foot hex; entering, ending a turn there, or teleporting the Cube over a creature can damage it once per turn. On later turns the caster can spend a Magic action to teleport the Cube up to 30 feet. The 5-foot Cube is approximated as one hex, vertical placement is unavailable, concentration removes the caster-owned zone, and the full clause audit and gameplay verification remain open.",
    "cloudkill": "Gameplay implementation slice: the 20-foot-radius Sphere damages creatures when it appears, moves over them, when they enter, or when they end a turn inside; one Constitution save per creature per turn is shared by all triggers. It drifts 10 feet away from the caster at the start of later turns and ends with the caster's Concentration. The area is projected onto a flat hex map; Heavily Obscured vision and strong-wind dispersal are not enforced, and the full clause audit remains open.",
    "conjure_animals": "Gameplay implementation slice: the selected Large spectral pack lasts up to 10 minutes, damages creatures when it moves within 10 feet, when they enter that area, or end a turn there, and shares a once-per-turn Dexterity save cap. It can move up to 30 feet for free after the caster moves once per turn; the caster has Strength-save Advantage within 5 feet. Hexes approximate the Large pack and 10-foot boundary, and the combat map has no creature sight check; the full clause audit remains open.",
    "conjure_celestial": "Gameplay implementation slice: a 10-foot-radius, 40-foot-high Bright Light cylinder lasts up to 10 minutes with Concentration. Visible creatures can receive Healing Light (4d12 + spellcasting modifier) or Searing Light (6d12 Radiant, Dexterity save for half); movement, entry and end-turn triggers share a once-per-turn target cap, and the caster can move the cylinder up to 30 feet after moving. The hex map flattens the cylinder, visibility is not modeled, and the full clause audit remains open.",
    "conjure_elemental": "Gameplay implementation slice: the caster chooses Air (Lightning), Earth (Thunder), Fire, or Water (Cold) and summons a Large intangible spirit in a clear space for up to 10 minutes with Concentration. When a creature enters its space or starts its turn within 5 feet while it has no creature Restrained, it makes a Dexterity save; failure deals 8d8 damage and applies source-owned Restrained. A Restrained target repeats the save at the start of its turns; failure deals 4d8 and success ends this spirit's Restrained effect. Under SRD 5.2.1, higher slots add 1d8 per level to both damage amounts. The Large space is approximated by seven hexes, creature visibility is not modeled, and the full clause audit remains open.",
    "conjure_fey": "Gameplay implementation slice: a Medium spirit lasts up to 10 minutes with Concentration, attacks when it appears and after a later-turn Bonus Action teleport up to 30 feet, and a hit deals Psychic damage plus the spellcasting modifier. Under SRD 5.2.1, higher slots add 1d12; a hit applies Frightened through the caster's next turn. Visible-space and line-of-sight checks are not modeled, the Medium spirit uses one hex, and the full clause audit remains open.",
    "conjure_minor_elementals": "Gameplay implementation slice: a 15-foot Emanation follows the caster for up to 10 minutes with Concentration. Each attack that hits a creature inside adds 2d8 Acid, Cold, Fire, or Lightning (chosen for that attack); higher slots add 1d8 per level above four. Enemy movement inside costs an extra 5 feet. The Emanation is projected as a three-hex radius, and the full clause audit remains open.",
    "conjure_woodland_beings": "Gameplay implementation slice: a 10-foot Emanation follows the caster for up to 10 minutes with Concentration. Entering its area, its movement over a creature, and ending a turn inside can trigger one Wisdom save per target per turn; the save deals 5d8 Force on failure or half on success, with +1d8 per slot above four. The caster can take Disengage as a Bonus Action. The Emanation is projected as two hexes, and creature visibility/choice plus the full clause audit remain open.",
    "spirit_guardians": "Gameplay implementation slice: a 15-foot Emanation follows the caster for up to 10 minutes with Concentration. The caster designates combat creatures unaffected; other creatures take Radiant or Necrotic damage on a failed Wisdom save, half on a success, when they enter or end their turn in the Emanation, or when it moves onto them. A target saves once per turn; slots above three add 1d8. In-area movement costs twice as much for affected player and monster movement. Character alignment is not stored, so the caster chooses the alignment damage at cast time; vision outside the combat-creature list and the full clause audit remain open.",
    "aura_of_life": "Gameplay implementation slice: a 30-foot Emanation follows the caster for 10 minutes with Concentration. Party Characters in range gain Necrotic Resistance, cannot have their Hit Point maximum reduced, and regain 1 Hit Point if they start their turn at 0 Hit Points. These source-owned protections refresh as the aura moves and clear when range or Concentration ends. Only party Characters and combat time are modeled; persistent campaign-time effects and full SRD clause audit remain open.",
    "moonbeam": "Available gameplay slice: Moonbeam resolves the initial Constitution save and half damage, then tracks a concentration-linked Cylinder that can be moved up to 60 feet with a later-turn Magic action. The area moving over a creature, a creature entering it, and ending a turn inside it can trigger damage, once per combat turn; damage scales above a level-2 slot. Failed saves revert Wild Shape and prevent re-shaping until the target leaves the Cylinder. The 5-foot radius is approximated by a seven-hex area; vertical height and Dim Light rendering are not modeled.",
    "plant_growth": "Available gameplay slice: the action-cast Overgrowth mode applies a 4x movement cost in a 100-foot Sphere and combines by the strongest terrain cost without stacking with Difficult Terrain. Overgrowth is instantaneous and remains in the encounter after rounds advance. The combat map assumes normal plants everywhere, clips the area to existing hexes, and does not model excluded subareas or Enrichment's 8-hour casting and 365-day harvest benefit; combat-scene destruction discards the area.",
    "barkskin": "Available gameplay slice: Barkskin is a Bonus Action on a willing living party member and sets an Armor Class floor of 17 for one hour. Character and monster attack resolution honor the floor; higher AC is unchanged. Bark-like appearance and material inventory are not modeled; Barkskin uses the shared timed spell-effect and save-validation path, and the full clause audit remains open.",
    "mage_armor": "Available gameplay slice: Mage Armor sets an unarmored willing party member's base AC to 13 + Dexterity for eight hours, retains shield AC, and ends early when armor is donned. Material inventory is descriptive metadata; dismissal and the full clause audit remain open.",

    "bless": "Chosen-creature targeting, 60-second duration, source ownership and saved party expiry; costly Holy Symbol is descriptive metadata, not an enforced inventory requirement.",
    "shield_of_faith": "Source-owned AC ward on party or monsters; monster effects are intentionally discarded at encounter end.",
    "shield": "The Reaction is offered for Magic Missile and spell attacks. It spends only when a triggering attack hits, applies +5 AC against that attack and later attacks, or prevents all Magic Missile damage, and lasts until the start of the target's next turn. The full clause audit remains open.",
    "magic_missile": "The player assigns each base or upcast dart to a creature, including repeat targets; per-target damage is aggregated once. An active or accepted Shield prevents the darts. Visibility/line-of-sight and full SRD audit remain open.",
    "fireball": "Uses a 150-foot target range and a 20-foot sphere (30 and 4 five-foot hexes). Creature cover, flammable-object ignition, and full clause audit remain open.",
    "hold_monster": "Source-owned paralysis and repeated Wisdom saves; sight checks handle Invisible only, without terrain occlusion.",
    "hold_person": "Humanoid-only source-owned paralysis and repeated Wisdom saves; sight checks handle Invisible only, without terrain occlusion.",
    "hunters_mark": "Unavailable: the exposed implementation only adds its damage through a test helper and records a 10-round mark. It does not add Force damage on every weapon or spell attack roll, grant tracking-check Advantage, move the mark after a target drops, or apply the 8/24-hour upcast durations. Correct SRD metadata is recorded; casting is refused before costs until combat and campaign-time tracking cover those effects.",
    "spare_the_dying": "Stabilizes a downed party character, persists the Stable state, and resumes death saves with one failure if damaged; range scales to 30/60/120 feet at levels 5/11/17. The game does not track the SRD's 1d4-hour recovery to 1 Hit Point or stable non-party creatures.",
    "charm_person": "Source-owned Charmed effect ends when the target takes party damage; a hostile monster in combat has Advantage on its save and avoids its charmer when choosing an attack. The game has no NPC attitude/dialogue model for full Friendly behavior or notice when the effect ends.",
    "charm_monster": "Source-owned Charmed effect ends when the target takes party damage; a hostile monster in combat has Advantage on its save and avoids its charmer when choosing an attack. The game has no NPC attitude/dialogue model for full Friendly behavior or notice when the effect ends.",
    "faerie_fire": "Production casting selects a directed 20-foot Cube, applies source-owned outlines to creatures that fail Dexterity saves, suppresses Invisible benefits, and gives attackers Advantage when resolving attacks against affected targets. Concentration ending clears effects. Combat creatures only; hex grid approximates square geometry, objects and emitted light are not rendered, true sight occlusion and material inventory are not modeled, and full clause audit remains open.",
    "fog_cloud": "Production casting creates a source-owned Heavily Obscured Sphere for one hour; each slot level above 1 increases its radius by 20 feet. Entering or leaving updates obscured combatants, weapon/spell attacks apply the SRD Advantage and Disadvantage cancellation, and ending Concentration removes the zone. Hex footprints approximate Sphere geometry; true line-of-sight targeting, strong-wind dispersal, visual rendering and full clause audit remain open.",
    "darkness": "Production casting creates a source-owned 15-foot-radius magical Darkness Sphere for up to 10 minutes with Concentration. It obscures creatures in the area for combat attack modifiers and dispels overlapping modeled Light, Produce Flame and Dancing Lights effects. Hex footprints approximate Sphere geometry; object targeting/covering, Darkvision-specific environmental sight, terrain occlusion, visuals and full clause audit remain open.",
    "darkvision": "Production casting grants a source-owned Darkvision condition to a touched party creature for eight hours, and active effects extend its exploration visibility to 150 feet. Focused/live checks cover exact expiry. The game does not distinguish ambient bright/dim/dark lighting, model sensing in darkness during combat or advance spell time while outside combat; material component enforcement and full clause audit remain open.",
    "see_invisibility": "Production casting grants the caster a source-owned one-hour sense that allows perception of Invisible creatures at any modeled combat distance, removing the Invisible target's attack Disadvantage against them. Invisible objects and Ethereal Plane awareness/appearance are not modeled; terrain sight, material components and the full clause audit remain open.",
    "true_seeing": "Production casting grants a selected party creature source-owned Truesight perception of Invisible targets within 120 feet for one hour. The 25+ GP mushroom powder is required and consumed before slot/action costs. Darkness, visual illusions, magically transformed forms, Ethereal Plane entities and object sight are not represented by combat state; terrain line of sight and full clause audit remain open.",
    "ray_of_sickness": "Source-owned poison expires at the end of the caster's next turn and preserves unrelated poison.",
    "ray_of_enfeeblement": "Failed-save concentration repeats CON saves; successful-save attack penalty expires at the caster's next start. No general inactive-caster combat clock.",
    "animal_friendship": "Source-owned charm and party-damage break; transient monster/NPC effects are discarded at encounter end, so 24-hour world friendship is not implemented.",
    "mending": "No damaged-object state; explicitly unavailable before costs.",
    "invisibility": "Production casting applies a source-owned Invisible effect to selected combat creatures for up to one hour; higher slots add one target each. Attacks against Invisible targets have Disadvantage, and an Invisible attacker has Advantage, then loses the effect after its attack roll. Dealing damage or casting another spell also ends the affected target's effect; ending Concentration clears remaining targets. This slice covers tracked combat entities and uses the current combat visibility rules; gear invisibility, material component inventory, true terrain occlusion and a full SRD clause audit remain open.",

    "dancing_lights": "Visual combat markers; no illumination/stealth/visibility effects.",
    "light": "Caster-hex object stand-in; no hostile object save, coverings or real visibility.",
    "mage_hand": "Marker movement/dismissal; no carrying, doors, containers or loose objects.",
    "message": "Party-only temporary whisper/reply; no NPC dialogue or barrier rules.",
    "minor_illusion": "Sound/image marker; no audio, investigation or physical-interaction outcome.",
    "prestidigitation": "Cosmetic marks/images; no fire, cleaning, temperature or inventory interaction.",
    "produce_flame": "Held/hurled flame and marker; no illumination/visibility effects.",
    "protection_from_energy": "Combat duration; campaign-clock expiry not connected.",
    "protection_from_evil_and_good": "No possession or source-aware existing charm/fear save benefits.",
    "protection_from_poison": "Single poison condition; no separate poison sources or non-spell poison saves.",
    "regenerate": "No body-part regrowth; one-minute casting approximated by an action; combat timer only.",
    "beacon_of_hope": "Production selection covers any tracked party Character or combat monster within 30 feet, including an eligible downed Character. Targets gain Wisdom-save and Death Saving Throw Advantage, and covered healing paths maximize their dice through shared and combat healing handlers. Lasts up to one combat minute with Concentration cleanup. Campaign-time persistence, untracked creatures, material inventory enforcement and the full SRD clause audit remain open.",
    "divine_favor": "Production Paladin cast is a Bonus Action that spends one level-1 slot and gives the caster a source-owned one-minute effect. Every weapon hit adds a separately mitigated 1d4 Radiant packet, including critical hits. Recasting replaces the prior Divine Favor source. The implemented attack path covers combat weapon attacks; attacks outside combat and the full SRD clause audit remain open.",
    "death_ward": "Production casting wards a tracked creature with an eight-hour source-owned effect. When damage after resistance and Temporary Hit Point absorption would reduce a living target to 0 Hit Points, the target remains at 1 Hit Point and the effect is consumed. Unused wards expire on the shared clock. The 2024 SRD text does not include the older instant-death exception; other non-damage death rules are outside this spell slice. Full clause audit remains open.",
    "sanctuary": "Production casting spends a Bonus Action and level-1 slot to ward one tracked combat creature for one minute. Attack rolls and directly targeted damaging spells must pass the ward's captured Wisdom save DC; the supported failed-save choice is losing the attack or spell. Area spells are not blocked. The ward ends when its target attacks, casts a spell, deals damage or expires; taking damage alone does not end it. Selection is limited to tracked combat creatures; alternate-target selection, component inventory and the full SRD clause audit remain open.",
    "heroism": "Production casting spends a Magic Action and slot to establish Concentration on one or more willing tracked party characters for up to one minute. Targets are immune to Frightened and at the start of each turn gain Temporary Hit Points equal to the caster's captured spellcasting ability modifier (without reducing a higher existing amount). Current SRD text leaves remaining Temporary Hit Points when the spell ends. Upcasting adds one party target per slot level. Campaign-time persistence, material inventory and the full SRD clause audit remain open.",
    "magic_weapon": "Production casting spends a Magic Action and slot to enchant a tracked party character's equipped nonmagical main-hand weapon for up to one hour with Concentration. The effect adds +1 at slots 2-3, +2 at slots 4-5 and +3 at slots 6+, to attack and damage rolls, and makes the weapon magical. Only the equipped main-hand weapon is selectable; off-hand/monster items, material inventory, campaign-time persistence and full SRD clause audit remain open.",
    "enhance_ability": "Production casting spends a Magic Action and slot to grant one or more tracked party characters Advantage on ability checks using one selected ability for up to one hour with Concentration. Upcasting adds one target per slot level; each target can receive a different ability. Targets must be tracked party characters; material inventory, campaign persistence and full SRD clause audit remain open.",
    "charm_person": "Production casting targets one or more tracked combat Humanoids. A failed Wisdom save applies a source-owned Charmed condition for up to one hour; the caster's monster target avoids the charmer, and damage from the player party ends the effect. The current SRD save Advantage clause is exercised for monster combat targets. General Friendly behavior and target awareness after expiry are not modeled; target sight, component inventory and full SRD clause audit remain open.",
    "charm_monster": "Production casting targets tracked combat creatures of any type. A failed Wisdom save applies a source-owned Charmed condition for up to one hour; the caster's monster target avoids the charmer, and damage from the player party ends the effect. The current SRD save Advantage clause is exercised for monster combat targets. General Friendly behavior and target awareness after expiry are not modeled; target sight, component inventory and full SRD clause audit remain open.",
    "remove_curse": "Clears one modeled condition; no curse sources or item attunement.",
    "resilient_sphere": "No globe carrying/rolling or object targets; party willingness assumed.",
    "disintegrate": "Creature damage and healing block; no general object/force-object or restoration modes.",
    "starry_wisp": "60-foot range corrected. Creature hits suppress Invisible benefits; object targeting, dim-light presentation and line-of-sight occlusion remain outside the current combat model.",
    "blight": "Creature behavior; nonmagical plant objects absent.",
    "command": "No language/hazard interpretation; dropped items have no pickup flow.",
    "sacred_flame": "No cover model to exercise the cover exception.",
    "longstrider": "Combat speed bonus; no general campaign-clock expiry for spell conditions.",
    "bane": "Production picker covers a failed Charisma save, two targets with a level-2 slot, one shared slot cost and source-owned concentration. Each attack/save subtracts a fresh d4. Material component inventory enforcement and complete clause audit remain open.",
    "aid": "Production picker applies an eight-hour source-owned increase to current and maximum Hit Points on up to three party characters. A level-3 production cast verifies +10 HP, one slot cost and expiry restoration. Other creatures and party NPCs outside combat entities are not targetable; component inventory enforcement and full clause audit remain open.",
    "alarm": "Unavailable: the game has no persistent door/window/area ward target, creature entry/touch trigger, exclusion list, or audible/mental alert delivery. Its 30-foot range, minute casting time, ritual option, components and 8-hour duration are recorded, but no effect can be applied to the current world model.",
    "alter_self": "Production picker casts the Natural Weapons option with selected Slashing, Piercing or Bludgeoning damage. Unarmed Strikes use 1d6 plus the caster's spellcasting modifier and the source-owned option expires when concentration ends or after one hour. Aquatic Adaptation, Change Appearance and changing the option during the spell are not modeled; material inventory and full clause audit remain open.",
    "animal_shapes": "Unavailable: no spell-grade creature transformation supports any willing target, Beast stat replacement, chosen Beast forms up to CR 4, form-HP temporary hit points, duration, and later Magic-action form changes. Existing Wild Shape only supports a Druid's learned forms and spends a class resource, so it is not used as a substitute. The spell is refused before costs.",
    "animate_dead": "Verified bounded Crown room slice: one-minute level-3 casting on recorded Humanoid remains, Gentle Repose refusal, lasting Skeleton/Zombie identity/HP, Bonus-action attack/Dodge orders, independent initiative, 24-hour control expiry to a hostile actor, up-to-four renewal before expiry and entrance disk reload. Higher-slot multi-body casting, arbitrary orders/default hazard avoidance, durable creature conditions/equipment, overworld encounters and long-cast interruption remain open. See docs/mechanics/animate-dead-2024.md; full rules completeness remains uncertified.",
    "animate_objects": "Unavailable: the game has no targetable nonmagical object ownership, worn/carried/fixed state, size-cost selection, animated-object ally turn, Bonus Action command/Dodge behavior, or reversion and damage carryover. Cast remains refused before costs.",
    "antilife_shell": "Bounded combat slice: a one-minute, caster-centered 10-foot aura blocks affected player/monster crossing, blocks melee and opportunity attacks across the barrier, exempts the caster/Constructs/Undead, blocks the modeled push path, and ends if caster movement sweeps an affected creature across the boundary. Ranged and Reach attacks pass. Other forced-movement paths, room transfer, and a full clause audit remain open.",
    "grease": "Combat applies Dexterity saves on creation, entry and turn end, prone on a failed save, and Difficult Terrain. Grease now transfers its footprint, save DC and remaining duration through room return and validated JSON room-state round-trip, then restores into an encounter while active. Local exploration applies Difficult Terrain and resolves entry/re-entry Dexterity saves, applying Prone on a failure; end-of-turn saves are not modeled there. Full square geometry and clause audit remain open.",
    "freedom_of_movement": "Bounded movement slice: a production cast grants the target a Swim Speed equal to its Speed and ignores modeled Difficult Terrain in combat and local-room movement for one hour. Characters with the spell also resist spell-sourced Paralyzed and Restrained conditions. Other magical Speed reductions, escape from nonmagical restraints, non-Character targets, and a full clause audit remain open.",
    "jump": "Production picker and level-2 two-target cast are verified. Once per turn, a character can leap up to six horizontal hexes for two movement points when walking cannot reach the landing; intermediate impassable hexes can be crossed and opportunity attacks still resolve. The map has no elevation, and there is no explicit option to spend the leap when walking is already sufficient. Material component inventory enforcement remains open.",
    "levitate": "Behavior audit: no levitation/movement payload or dedicated production handler.",
    "silent_image": "Behavior audit: no image/illusion payload or dedicated production handler.",
    "disguise_self": "Behavior audit: no appearance/disguise payload or dedicated production handler.",
    "arcane_eye": "Behavior audit: no sensor/vision payload or dedicated production handler.",
    "speak_with_dead": "Behavior audit: no corpse dialogue payload or dedicated production handler.",
    "purify_food_and_drink": "No food/drink contamination target state; explicitly refused before costs.",
    "reincarnate": "No corpse/death-time, consumed oils or safe species replacement; explicitly refused before costs.",
}

# Negative production audit, not proof that other utility records work.
AUDITED_EFFECTLESS = set("hold_person levitate silent_image disguise_self arcane_eye speak_with_dead".split())

def source_fingerprint() -> str:
    paths = sorted([*ROOT.glob("src/**/*.gd"), *ROOT.glob("data/**/*.json"), ROOT / "project.godot"])
    return hashlib.sha256("\n".join(f"{p.relative_to(ROOT).as_posix()} {hashlib.sha256(p.read_bytes()).hexdigest()}" for p in paths).encode()).hexdigest()

def normalize(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower().replace("'", "").replace("’", "")).strip("_")

def reconcile_target(path: Path, spells: dict, class_lists: dict) -> dict:
    target = json.loads(path.read_text(encoding="utf-8"))
    names = {normalize(s["name"]): sid for sid, s in spells.items()}
    names.update({normalize(sid): sid for sid in spells})
    names.update({"minor": "minor_illusion", "programmed": "programmed_illusion", "acid_arrow": "melfs_acid_arrow", "bigbys_hand": "arcane_hand", "mordenkainens_sword": "arcane_sword", "evards_black_tentacles": "black_tentacles", "otilukes_freezing_sphere": "freezing_sphere", "otilukes_resilient_sphere": "resilient_sphere", "mordenkainens_faithful_hound": "faithful_hound", "drawmijs_instant_summons": "instant_summons", "ottos_irresistible_dance": "irresistible_dance", "mordenkainens_magnificent_mansion": "magnificent_mansion", "mordenkainens_private_sanctum": "private_sanctum", "leomunds_secret_chest": "secret_chest", "rarys_telepathic_bond": "telepathic_bond", "floating_disk": "tensers_floating_disk", "hideous_laughter": "tashas_hideous_laughter", "tiny_hut": "leomunds_tiny_hut", "arcanists_magic_aura": "nystuls_magic_aura"})
    memberships = {}
    unresolved = []
    missing_access = []
    for klass, entries in target.items():
        for entry in entries:
            sid = names.get(normalize(entry["name"]))
            if sid not in spells:
                unresolved.append({"class": klass, "name": entry["name"]})
                continue
            memberships.setdefault(sid, set()).add(klass)
            if sid not in class_lists.get(klass, []):
                missing_access.append({"class": klass, "id": sid})
    return {"input": path.relative_to(ROOT).as_posix() if path.is_relative_to(ROOT) else str(path), "membership_rows": sum(map(len, target.values())), "unique_resolved_ids": len(memberships), "unresolved_names": unresolved, "missing_class_memberships": missing_access, "memberships": {sid: sorted(classes) for sid, classes in memberships.items()}}

def generate(runtime_path: Path, target_path: Path) -> dict:
    runtime = json.loads(runtime_path.read_text(encoding="utf-8"))
    spells = {s["id"]: s for s in runtime["spells"]}
    raw_ids = {s["id"] for p in (ROOT / "data/core/spells").glob("*.json") for s in json.loads(p.read_text(encoding="utf-8"))}
    if set(spells) != raw_ids:
        raise ValueError("Runtime export does not match core spell IDs; re-export the production inventory.")
    availability = runtime.get("cast_availability", {})
    if set(availability) != set(spells):
        raise ValueError("Re-export production SpellSupport availability with the spell inventory.")
    batch_ids = set("bless shield_of_faith hold_person hold_monster ray_of_sickness ray_of_enfeeblement animal_friendship".split())
    live_log = ROOT / ".artifacts/effect-lifetime/live-final/spell_effect_lifetime.stdout.log"
    effects_log = ROOT / ".artifacts/effect-lifetime/acceptance-fixed/logic.stdout.log"
    batch_verified = live_log.exists() and "SCENARIO PASSED: spell_effect_lifetime" in live_log.read_text(errors="replace") and effects_log.exists() and "ALL TESTS PASSED" in effects_log.read_text(errors="replace")
    bane_live = ROOT / ".artifacts/core12-repairs/bane-final-upcast-integration/spell_effect_lifetime.stdout.log"
    bane_logic = ROOT / ".artifacts/core12-repairs/bane-effects-logic-final/logic.stdout.log"
    bane_verified = bane_live.exists() and "Production upcast Bane spends one slot, resolves two CHA saves and tracks both targets" in bane_live.read_text(errors="replace") and "SCENARIO PASSED: spell_effect_lifetime" in bane_live.read_text(errors="replace") and bane_logic.exists() and "LOGIC GROUPS: effects" in bane_logic.read_text(errors="replace") and "SELECTED LOGIC TESTS PASSED" in bane_logic.read_text(errors="replace")
    aid_live = ROOT / ".artifacts/core12-repairs/aid-live-verified/spell_effect_lifetime.stdout.log"
    aid_logic = ROOT / ".artifacts/core12-repairs/aid-effects-final2/logic.stdout.log"
    aid_verified = aid_live.exists() and "Production upcast Aid spends one slot and raises three selected party members' current and maximum HP by 10" in aid_live.read_text(errors="replace") and "Production Aid expiry restores each selected party member's original maximum HP" in aid_live.read_text(errors="replace") and "SCENARIO PASSED: spell_effect_lifetime" in aid_live.read_text(errors="replace") and aid_logic.exists() and "RESULTS: 36 passed, 0 failed" in aid_logic.read_text(errors="replace") and "SELECTED LOGIC TESTS PASSED" in aid_logic.read_text(errors="replace")
    jump_live = ROOT / ".artifacts/core12-repairs/jump-movement-integration-final2/jump_spell_movement.stdout.log"
    jump_logic = ROOT / ".artifacts/core12-repairs/jump-effects-logic-fixed/logic.stdout.log"
    jump_verified = jump_live.exists() and "SCENARIO PASSED: jump_spell_movement" in jump_live.read_text(errors="replace") and "Production movement executes the leap once and charges the remaining 10 feet" in jump_live.read_text(errors="replace") and jump_logic.exists() and "LOGIC GROUPS: effects" in jump_logic.read_text(errors="replace") and "SELECTED LOGIC TESTS PASSED" in jump_logic.read_text(errors="replace")
    alter_live = ROOT / ".artifacts/core12-repairs/alter-self-live-first/spell_effect_lifetime.stdout.log"
    alter_logic = ROOT / ".artifacts/core12-repairs/alter-self-effects-final/logic.stdout.log"
    alter_verified = alter_live.exists() and "Production Alter Self grants source-owned Slashing Natural Weapons using the Wizard's spellcasting ability" in alter_live.read_text(errors="replace") and "Production Alter Self expires after one hour and removes its Natural Weapons option" in alter_live.read_text(errors="replace") and "SCENARIO PASSED: spell_effect_lifetime" in alter_live.read_text(errors="replace") and alter_logic.exists() and "RESULTS: 39 passed, 0 failed" in alter_logic.read_text(errors="replace") and "SELECTED LOGIC TESTS PASSED" in alter_logic.read_text(errors="replace")
    eldritch_logic = ROOT / ".artifacts/core12-repairs/eldritch-blast-verification/spell.stdout.log"
    eldritch_verified = eldritch_logic.exists() and "ELDRITCH_BLAST_BEAM_GAMEPLAY_CHECKS_COMPLETE" in eldritch_logic.read_text(errors="replace") and "SELECTED LOGIC TESTS PASSED" in eldritch_logic.read_text(errors="replace")
    spare_verified = eldritch_logic.exists() and "SPARE_THE_DYING_STABILIZATION_CHECKS_COMPLETE" in eldritch_logic.read_text(errors="replace") and "SELECTED LOGIC TESTS PASSED" in eldritch_logic.read_text(errors="replace")
    shatter_logic = ROOT / ".artifacts/core12-repairs/srd-spell-gap-review/logic.stdout.log"
    shatter_log_text = shatter_logic.read_text(errors="replace") if shatter_logic.exists() else ""
    shatter_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", shatter_log_text)) and "validation failures: 0" in shatter_log_text and "SELECTED LOGIC TESTS PASSED" in shatter_log_text
    spell_slices_logic = ROOT / ".artifacts/core12-repairs/srd-spell-gap-review/focused-run-final/logic.stdout.log"
    spell_slices_log_text = spell_slices_logic.read_text(errors="replace") if spell_slices_logic.exists() else ""
    thunderwave_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", spell_slices_log_text)) and "SELECTED LOGIC TESTS PASSED" in spell_slices_log_text and "THUNDERWAVE_CUBE_PUSH_CHECKS_COMPLETE" in spell_slices_log_text
    area_spell_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", spell_slices_log_text)) and "AREA_SPELL_UPCAST_CHECKS_COMPLETE" in spell_slices_log_text
    circle_death_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", spell_slices_log_text)) and "CIRCLE_OF_DEATH_COMPONENT_CHECKS_COMPLETE" in spell_slices_log_text
    power_word_stun_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", spell_slices_log_text)) and "POWER_WORD_STUN_CHECKS_COMPLETE" in spell_slices_log_text and "SELECTED LOGIC TESTS PASSED" in spell_slices_log_text
    counterspell_logic = ROOT / ".artifacts/core12-repairs/counterspell-2024-focused-final/logic.stdout.log"
    counterspell_log_text = counterspell_logic.read_text(errors="replace") if counterspell_logic.exists() else ""
    counterspell_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", counterspell_log_text)) and "COUNTERSPELL_SAVE_AND_REFUND_CHECKS_COMPLETE" in counterspell_log_text and "SELECTED LOGIC TESTS PASSED" in counterspell_log_text
    sleep_logic = ROOT / ".artifacts/core12-repairs/sleep-2024-focused-final/logic.stdout.log"
    sleep_log_text = sleep_logic.read_text(errors="replace") if sleep_logic.exists() else ""
    sleep_live = ROOT / ".artifacts/core12-repairs/sleep-live-accepted/sleep_spell_flow.stdout.log"
    sleep_live_text = sleep_live.read_text(errors="replace") if sleep_live.exists() else ""
    sleep_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", sleep_log_text)) and "SLEEP_SEQUENCE_CHECKS_COMPLETE" in sleep_log_text and "SELECTED LOGIC TESTS PASSED" in sleep_log_text and "SCENARIO PASSED: sleep_spell_flow" in sleep_live_text and "Sleep asks which creatures to include" in sleep_live_text and "A nearby creature spends its action" in sleep_live_text
    true_strike_logic = ROOT / ".artifacts/core12-repairs/true-strike-focused/logic.stdout.log"
    true_strike_logic_text = true_strike_logic.read_text(errors="replace") if true_strike_logic.exists() else ""
    true_strike_live = ROOT / ".artifacts/core12-repairs/true-strike-live/true_strike_spell_flow.stdout.log"
    true_strike_live_text = true_strike_live.read_text(errors="replace") if true_strike_live.exists() else ""
    true_strike_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", true_strike_logic_text)) and "SELECTED LOGIC TESTS PASSED" in true_strike_logic_text and "SCENARIO PASSED: true_strike_spell_flow" in true_strike_live_text and "spends its Magic action and settles resisted weapon plus Radiant damage separately" in true_strike_live_text
    mass_cure_logic = ROOT / ".artifacts/core12-repairs/mass-cure-wounds-focused-accepted/logic.stdout.log"
    mass_cure_logic_text = mass_cure_logic.read_text(errors="replace") if mass_cure_logic.exists() else ""
    mass_cure_live = ROOT / ".artifacts/core12-repairs/mass-cure-wounds-live-final/mass_cure_wounds_flow.stdout.log"
    mass_cure_live_text = mass_cure_live.read_text(errors="replace") if mass_cure_live.exists() else ""
    mass_cure_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", mass_cure_logic_text)) and "SELECTED LOGIC TESTS PASSED" in mass_cure_logic_text and "SCENARIO PASSED: mass_cure_wounds_flow" in mass_cure_live_text and "Mass Cure Wounds restores a downed party creature" in mass_cure_live_text and "Mass Cure Wounds restores a creature monster's Hit Points" in mass_cure_live_text
    mass_healing_logic = ROOT / ".artifacts/core12-repairs/mass-healing-word-focused-accepted/logic.stdout.log"
    mass_healing_logic_text = mass_healing_logic.read_text(errors="replace") if mass_healing_logic.exists() else ""
    mass_healing_live = ROOT / ".artifacts/core12-repairs/mass-healing-word-live-accepted/mass_healing_word_flow.stdout.log"
    mass_healing_live_text = mass_healing_live.read_text(errors="replace") if mass_healing_live.exists() else ""
    mass_healing_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", mass_healing_logic_text)) and "SELECTED LOGIC TESTS PASSED" in mass_healing_logic_text and "SCENARIO PASSED: mass_healing_word_flow" in mass_healing_live_text and "Mass Healing Word accepts two distinct creature targets within its range" in mass_healing_live_text and "Mass Healing Word spends one third-level slot and one Bonus Action" in mass_healing_live_text
    blindness_logic = ROOT / ".artifacts/core12-repairs/blindness-deafness-focused/logic.stdout.log"
    blindness_logic_text = blindness_logic.read_text(errors="replace") if blindness_logic.exists() else ""
    blindness_live = ROOT / ".artifacts/core12-repairs/blindness-deafness-live/blindness_deafness_spell_flow.stdout.log"
    blindness_live_text = blindness_live.read_text(errors="replace") if blindness_live.exists() else ""
    blindness_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", blindness_logic_text)) and "BLINDNESS_DEAFNESS_REPEAT_SAVE_CHECKS_COMPLETE" in blindness_logic_text and "SELECTED LOGIC TESTS PASSED" in blindness_logic_text and "SCENARIO PASSED: blindness_deafness_spell_flow" in blindness_live_text and "Each target receives its own record for the cast source and captured save DC" in blindness_live_text and "A successful end-of-turn Constitution save ends only that target's effect" in blindness_live_text
    grease_logic = ROOT / ".artifacts/core12-repairs/grease-focused/logic.stdout.log"
    grease_logic_text = grease_logic.read_text(errors="replace") if grease_logic.exists() else ""
    grease_live = ROOT / ".artifacts/core12-repairs/grease-live/grease_spell_flow.stdout.log"
    grease_live_text = grease_live.read_text(errors="replace") if grease_live.exists() else ""
    grease_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", grease_logic_text)) and "GREASE_AREA_CHECKS_COMPLETE" in grease_logic_text and "SELECTED LOGIC TESTS PASSED" in grease_logic_text and "SCENARIO PASSED: grease_spell_flow" in grease_live_text and "GREASE_ZONE_FLOW_CHECKS_COMPLETE" in grease_live_text
    spike_growth_logic = ROOT / ".artifacts/core12-repairs/spike-growth-focused-accepted/logic.stdout.log"
    spike_growth_logic_text = spike_growth_logic.read_text(errors="replace") if spike_growth_logic.exists() else ""
    spike_growth_live = ROOT / ".artifacts/core12-repairs/spike-growth-live-final/spike_growth_spell_flow.stdout.log"
    spike_growth_live_text = spike_growth_live.read_text(errors="replace") if spike_growth_live.exists() else ""
    spike_growth_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", spike_growth_logic_text)) and "SPIKE_GROWTH_AREA_CHECKS_COMPLETE" in spike_growth_logic_text and "SELECTED LOGIC TESTS PASSED" in spike_growth_logic_text and "SCENARIO PASSED: spike_growth_spell_flow" in spike_growth_live_text and "SPIKE_GROWTH_ZONE_FLOW_CHECKS_COMPLETE" in spike_growth_live_text
    entangle_logic = ROOT / ".artifacts/core12-repairs/entangle-focused-final/logic.stdout.log"
    entangle_logic_text = entangle_logic.read_text(errors="replace") if entangle_logic.exists() else ""
    entangle_live = ROOT / ".artifacts/core12-repairs/entangle-live-final/entangle_spell_flow.stdout.log"
    entangle_live_text = entangle_live.read_text(errors="replace") if entangle_live.exists() else ""
    entangle_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", entangle_logic_text)) and "ENTANGLE_AREA_CHECKS_COMPLETE" in entangle_logic_text and "SELECTED LOGIC TESTS PASSED" in entangle_logic_text and "SCENARIO PASSED: entangle_spell_flow" in entangle_live_text and "ENTANGLE_ZONE_FLOW_CHECKS_COMPLETE" in entangle_live_text
    black_tentacles_logic = ROOT / ".artifacts/core12-repairs/black-tentacles-focused-final/logic.stdout.log"
    black_tentacles_logic_text = black_tentacles_logic.read_text(errors="replace") if black_tentacles_logic.exists() else ""
    black_tentacles_live = ROOT / ".artifacts/core12-repairs/black-tentacles-live-final/black_tentacles_spell_flow.stdout.log"
    black_tentacles_live_text = black_tentacles_live.read_text(errors="replace") if black_tentacles_live.exists() else ""
    black_tentacles_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", black_tentacles_logic_text)) and "BLACK_TENTACLES_AREA_CHECKS_COMPLETE" in black_tentacles_logic_text and "SELECTED LOGIC TESTS PASSED" in black_tentacles_logic_text and "SCENARIO PASSED: black_tentacles_spell_flow" in black_tentacles_live_text and "BLACK_TENTACLES_ZONE_FLOW_CHECKS_COMPLETE" in black_tentacles_live_text
    sleet_storm_logic = ROOT / ".artifacts/core12-repairs/sleet-storm-focused/logic.stdout.log"
    sleet_storm_logic_text = sleet_storm_logic.read_text(errors="replace") if sleet_storm_logic.exists() else ""
    sleet_storm_live = ROOT / ".artifacts/core12-repairs/sleet-storm-live/sleet_storm_spell_flow.stdout.log"
    sleet_storm_live_text = sleet_storm_live.read_text(errors="replace") if sleet_storm_live.exists() else ""
    sleet_storm_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", sleet_storm_logic_text)) and "SLEET_STORM_AREA_CHECKS_COMPLETE" in sleet_storm_logic_text and "SELECTED LOGIC TESTS PASSED" in sleet_storm_logic_text and "SCENARIO PASSED: sleet_storm_spell_flow" in sleet_storm_live_text and "SLEET_STORM_ZONE_FLOW_CHECKS_COMPLETE" in sleet_storm_live_text
    cloud_of_daggers_logic = ROOT / ".artifacts/core12-repairs/cloud-of-daggers-focused/logic.stdout.log"
    cloud_of_daggers_logic_text = cloud_of_daggers_logic.read_text(errors="replace") if cloud_of_daggers_logic.exists() else ""
    cloud_of_daggers_live = ROOT / ".artifacts/core12-repairs/cloud-of-daggers-live/cloud_of_daggers_spell_flow.stdout.log"
    cloud_of_daggers_live_text = cloud_of_daggers_live.read_text(errors="replace") if cloud_of_daggers_live.exists() else ""
    cloud_of_daggers_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", cloud_of_daggers_logic_text)) and "CLOUD_OF_DAGGERS_AREA_CHECKS_COMPLETE" in cloud_of_daggers_logic_text and "SELECTED LOGIC TESTS PASSED" in cloud_of_daggers_logic_text and "SCENARIO PASSED: cloud_of_daggers_spell_flow" in cloud_of_daggers_live_text and "CLOUD_OF_DAGGERS_ZONE_FLOW_CHECKS_COMPLETE" in cloud_of_daggers_live_text
    cloudkill_logic = ROOT / ".artifacts/core12-repairs/cloudkill-focused/logic.stdout.log"
    cloudkill_logic_text = cloudkill_logic.read_text(errors="replace") if cloudkill_logic.exists() else ""
    cloudkill_live = ROOT / ".artifacts/core12-repairs/cloudkill-live-final/cloudkill_spell_flow.stdout.log"
    cloudkill_live_text = cloudkill_live.read_text(errors="replace") if cloudkill_live.exists() else ""
    cloudkill_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", cloudkill_logic_text)) and "CLOUDKILL_AREA_CHECKS_COMPLETE" in cloudkill_logic_text and "SELECTED LOGIC TESTS PASSED" in cloudkill_logic_text and "SCENARIO PASSED: cloudkill_spell_flow" in cloudkill_live_text and "CLOUDKILL_ZONE_FLOW_CHECKS_COMPLETE" in cloudkill_live_text
    conjure_animals_logic = ROOT / ".artifacts/core12-repairs/conjure-animals-focused-final/logic.stdout.log"
    conjure_animals_logic_text = conjure_animals_logic.read_text(errors="replace") if conjure_animals_logic.exists() else ""
    conjure_animals_live = ROOT / ".artifacts/core12-repairs/conjure-animals-live/conjure_animals_spell_flow.stdout.log"
    conjure_animals_live_text = conjure_animals_live.read_text(errors="replace") if conjure_animals_live.exists() else ""
    conjure_animals_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", conjure_animals_logic_text)) and "CONJURE_ANIMALS_AREA_CHECKS_COMPLETE" in conjure_animals_logic_text and "SELECTED LOGIC TESTS PASSED" in conjure_animals_logic_text and "SCENARIO PASSED: conjure_animals_spell_flow" in conjure_animals_live_text and "CONJURE_ANIMALS_ZONE_FLOW_CHECKS_COMPLETE" in conjure_animals_live_text
    conjure_celestial_logic = ROOT / ".artifacts/core12-repairs/conjure-celestial-focused/logic.stdout.log"
    conjure_celestial_logic_text = conjure_celestial_logic.read_text(errors="replace") if conjure_celestial_logic.exists() else ""
    conjure_celestial_live = ROOT / ".artifacts/core12-repairs/conjure-celestial-live/conjure_celestial_spell_flow.stdout.log"
    conjure_celestial_live_text = conjure_celestial_live.read_text(errors="replace") if conjure_celestial_live.exists() else ""
    conjure_celestial_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", conjure_celestial_logic_text)) and "CONJURE_CELESTIAL_AREA_CHECKS_COMPLETE" in conjure_celestial_logic_text and "SELECTED LOGIC TESTS PASSED" in conjure_celestial_logic_text and "SCENARIO PASSED: conjure_celestial_spell_flow" in conjure_celestial_live_text and "CONJURE_CELESTIAL_ZONE_FLOW_CHECKS_COMPLETE" in conjure_celestial_live_text
    conjure_elemental_logic = ROOT / ".artifacts/core12-repairs/conjure-elemental-focused/logic.stdout.log"
    conjure_elemental_logic_text = conjure_elemental_logic.read_text(errors="replace") if conjure_elemental_logic.exists() else ""
    conjure_elemental_live = ROOT / ".artifacts/core12-repairs/conjure-elemental-live/conjure_elemental_spell_flow.stdout.log"
    conjure_elemental_live_text = conjure_elemental_live.read_text(errors="replace") if conjure_elemental_live.exists() else ""
    conjure_elemental_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", conjure_elemental_logic_text)) and "CONJURE_ELEMENTAL_SUMMON_CHECKS_COMPLETE" in conjure_elemental_logic_text and "SELECTED LOGIC TESTS PASSED" in conjure_elemental_logic_text and "SCENARIO PASSED: conjure_elemental_spell_flow" in conjure_elemental_live_text and "CONJURE_ELEMENTAL_ZONE_FLOW_CHECKS_COMPLETE" in conjure_elemental_live_text
    conjure_fey_logic = ROOT / ".artifacts/core12-repairs/conjure-fey-focused/logic.stdout.log"
    conjure_fey_logic_text = conjure_fey_logic.read_text(errors="replace") if conjure_fey_logic.exists() else ""
    conjure_fey_live = ROOT / ".artifacts/core12-repairs/conjure-fey-live/conjure_fey_spell_flow.stdout.log"
    conjure_fey_live_text = conjure_fey_live.read_text(errors="replace") if conjure_fey_live.exists() else ""
    conjure_fey_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", conjure_fey_logic_text)) and "CONJURE_FEY_SUMMON_CHECKS_COMPLETE" in conjure_fey_logic_text and "SELECTED LOGIC TESTS PASSED" in conjure_fey_logic_text and "SCENARIO PASSED: conjure_fey_spell_flow" in conjure_fey_live_text and "CONJURE_FEY_ZONE_FLOW_CHECKS_COMPLETE" in conjure_fey_live_text
    conjure_minor_elementals_logic = ROOT / ".artifacts/core12-repairs/conjure-minor-elementals-focused/logic.stdout.log"
    conjure_minor_elementals_logic_text = conjure_minor_elementals_logic.read_text(errors="replace") if conjure_minor_elementals_logic.exists() else ""
    conjure_minor_elementals_live = ROOT / ".artifacts/core12-repairs/conjure-minor-elementals-live/conjure_minor_elementals_spell_flow.stdout.log"
    conjure_minor_elementals_live_text = conjure_minor_elementals_live.read_text(errors="replace") if conjure_minor_elementals_live.exists() else ""
    conjure_minor_elementals_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", conjure_minor_elementals_logic_text)) and "CONJURE_MINOR_ELEMENTALS_DATA_CHECKS_COMPLETE" in conjure_minor_elementals_logic_text and "SELECTED LOGIC TESTS PASSED" in conjure_minor_elementals_logic_text and "SCENARIO PASSED: conjure_minor_elementals_spell_flow" in conjure_minor_elementals_live_text and "CONJURE_MINOR_ELEMENTALS_ZONE_FLOW_CHECKS_COMPLETE" in conjure_minor_elementals_live_text
    conjure_woodland_beings_logic = ROOT / ".artifacts/core12-repairs/conjure-woodland-beings-focused/logic.stdout.log"
    conjure_woodland_beings_logic_text = conjure_woodland_beings_logic.read_text(errors="replace") if conjure_woodland_beings_logic.exists() else ""
    conjure_woodland_beings_live = ROOT / ".artifacts/core12-repairs/conjure-woodland-beings-live/conjure_woodland_beings_spell_flow.stdout.log"
    conjure_woodland_beings_live_text = conjure_woodland_beings_live.read_text(errors="replace") if conjure_woodland_beings_live.exists() else ""
    conjure_woodland_beings_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", conjure_woodland_beings_logic_text)) and "CONJURE_WOODLAND_BEINGS_DATA_CHECKS_COMPLETE" in conjure_woodland_beings_logic_text and "SELECTED LOGIC TESTS PASSED" in conjure_woodland_beings_logic_text and "SCENARIO PASSED: conjure_woodland_beings_spell_flow" in conjure_woodland_beings_live_text and "CONJURE_WOODLAND_BEINGS_ZONE_FLOW_CHECKS_COMPLETE" in conjure_woodland_beings_live_text
    spirit_guardians_logic = ROOT / ".artifacts/core12-repairs/spirit-guardians-focused/logic.stdout.log"
    spirit_guardians_logic_text = spirit_guardians_logic.read_text(errors="replace") if spirit_guardians_logic.exists() else ""
    spirit_guardians_live = ROOT / ".artifacts/core12-repairs/spirit-guardians-live/spirit_guardians_spell_flow.stdout.log"
    spirit_guardians_live_text = spirit_guardians_live.read_text(errors="replace") if spirit_guardians_live.exists() else ""
    spirit_guardians_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", spirit_guardians_logic_text)) and "SPIRIT_GUARDIANS_DATA_CHECKS_COMPLETE" in spirit_guardians_logic_text and "SELECTED LOGIC TESTS PASSED" in spirit_guardians_logic_text and "SCENARIO PASSED: spirit_guardians_spell_flow" in spirit_guardians_live_text and "SPIRIT_GUARDIANS_ZONE_FLOW_CHECKS_COMPLETE" in spirit_guardians_live_text
    aura_of_life_logic = ROOT / ".artifacts/core12-repairs/aura-of-life-focused/logic.stdout.log"
    aura_of_life_logic_text = aura_of_life_logic.read_text(errors="replace") if aura_of_life_logic.exists() else ""
    aura_of_life_live = ROOT / ".artifacts/core12-repairs/aura-of-life-live/aura_of_life_spell_flow.stdout.log"
    aura_of_life_live_text = aura_of_life_live.read_text(errors="replace") if aura_of_life_live.exists() else ""
    aura_of_life_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", aura_of_life_logic_text)) and "AURA_OF_LIFE_DATA_CHECKS_COMPLETE" in aura_of_life_logic_text and "SELECTED LOGIC TESTS PASSED" in aura_of_life_logic_text and "SCENARIO PASSED: aura_of_life_spell_flow" in aura_of_life_live_text and "AURA_OF_LIFE_ZONE_FLOW_CHECKS_COMPLETE" in aura_of_life_live_text
    beacon_logic = ROOT / ".artifacts/core12-repairs/beacon-of-hope-focused-final/logic.stdout.log"
    beacon_logic_text = beacon_logic.read_text(errors="replace") if beacon_logic.exists() else ""
    beacon_live = ROOT / ".artifacts/core12-repairs/beacon-of-hope-live-final/beacon_of_hope_spell_flow.stdout.log"
    beacon_live_text = beacon_live.read_text(errors="replace") if beacon_live.exists() else ""
    beacon_verified = bool(re.search(r"RESULTS: 51 passed, 0 failed", beacon_logic_text)) and "BEACON_OF_HOPE_EFFECT_CHECKS_COMPLETE" in beacon_logic_text and "SELECTED LOGIC TESTS PASSED" in beacon_logic_text and "SCENARIO PASSED: beacon_of_hope_spell_flow" in beacon_live_text and "BEACON_OF_HOPE_ZONE_FLOW_CHECKS_COMPLETE" in beacon_live_text
    divine_favor_logic = ROOT / ".artifacts/core12-repairs/divine-favor-focused/logic.stdout.log"
    divine_favor_logic_text = divine_favor_logic.read_text(errors="replace") if divine_favor_logic.exists() else ""
    divine_favor_live = ROOT / ".artifacts/core12-repairs/divine-favor-live/divine_favor_spell_flow.stdout.log"
    divine_favor_live_text = divine_favor_live.read_text(errors="replace") if divine_favor_live.exists() else ""
    divine_favor_verified = bool(re.search(r"RESULTS: 54 passed, 0 failed", divine_favor_logic_text)) and "DIVINE_FAVOR_EFFECT_CHECKS_COMPLETE" in divine_favor_logic_text and "SELECTED LOGIC TESTS PASSED" in divine_favor_logic_text and "SCENARIO PASSED: divine_favor_spell_flow" in divine_favor_live_text and "DIVINE_FAVOR_LIVE_FLOW_CHECKS_COMPLETE" in divine_favor_live_text
    death_ward_logic = ROOT / ".artifacts/core12-repairs/death-ward-focused/logic.stdout.log"
    death_ward_logic_text = death_ward_logic.read_text(errors="replace") if death_ward_logic.exists() else ""
    death_ward_live = ROOT / ".artifacts/core12-repairs/death-ward-live/death_ward_spell_flow.stdout.log"
    death_ward_live_text = death_ward_live.read_text(errors="replace") if death_ward_live.exists() else ""
    death_ward_verified = bool(re.search(r"RESULTS: 58 passed, 0 failed", death_ward_logic_text)) and "DEATH_WARD_EFFECT_CHECKS_COMPLETE" in death_ward_logic_text and "SELECTED LOGIC TESTS PASSED" in death_ward_logic_text and "SCENARIO PASSED: death_ward_spell_flow" in death_ward_live_text and "DEATH_WARD_LIVE_FLOW_CHECKS_COMPLETE" in death_ward_live_text
    sanctuary_logic = ROOT / ".artifacts/core12-repairs/fog-cloud-focused/logic.stdout.log"
    sanctuary_logic_text = sanctuary_logic.read_text(errors="replace") if sanctuary_logic.exists() else ""
    sanctuary_live = ROOT / ".artifacts/core12-repairs/sanctuary-live/sanctuary_spell_flow.stdout.log"
    sanctuary_live_text = sanctuary_live.read_text(errors="replace") if sanctuary_live.exists() else ""
    sanctuary_verified = bool(re.search(r"RESULTS: 99 passed, 0 failed", sanctuary_logic_text)) and "SANCTUARY_EFFECT_CHECKS_COMPLETE" in sanctuary_logic_text and "SELECTED LOGIC TESTS PASSED" in sanctuary_logic_text and "SCENARIO PASSED: sanctuary_spell_flow" in sanctuary_live_text and "SANCTUARY_LIVE_FLOW_CHECKS_COMPLETE" in sanctuary_live_text
    heroism_logic = ROOT / ".artifacts/core12-repairs/fog-cloud-focused/logic.stdout.log"
    heroism_logic_text = heroism_logic.read_text(errors="replace") if heroism_logic.exists() else ""
    heroism_live = ROOT / ".artifacts/core12-repairs/heroism-live/heroism_spell_flow.stdout.log"
    heroism_live_text = heroism_live.read_text(errors="replace") if heroism_live.exists() else ""
    heroism_verified = bool(re.search(r"RESULTS: 99 passed, 0 failed", heroism_logic_text)) and "HEROISM_EFFECT_CHECKS_COMPLETE" in heroism_logic_text and "SELECTED LOGIC TESTS PASSED" in heroism_logic_text and "SCENARIO PASSED: heroism_spell_flow" in heroism_live_text and "HEROISM_LIVE_FLOW_CHECKS_COMPLETE" in heroism_live_text
    magic_weapon_live = ROOT / ".artifacts/core12-repairs/magic-weapon-live/magic_weapon_spell_flow.stdout.log"
    magic_weapon_live_text = magic_weapon_live.read_text(errors="replace") if magic_weapon_live.exists() else ""
    magic_weapon_verified = bool(re.search(r"RESULTS: 99 passed, 0 failed", heroism_logic_text)) and "MAGIC_WEAPON_EFFECT_CHECKS_COMPLETE" in heroism_logic_text and "SELECTED LOGIC TESTS PASSED" in heroism_logic_text and "SCENARIO PASSED: magic_weapon_spell_flow" in magic_weapon_live_text and "MAGIC_WEAPON_LIVE_FLOW_CHECKS_COMPLETE" in magic_weapon_live_text
    enhance_ability_live = ROOT / ".artifacts/core12-repairs/enhance-ability-live/enhance_ability_spell_flow.stdout.log"
    enhance_ability_live_text = enhance_ability_live.read_text(errors="replace") if enhance_ability_live.exists() else ""
    enhance_ability_verified = bool(re.search(r"RESULTS: 99 passed, 0 failed", heroism_logic_text)) and "ENHANCE_ABILITY_EFFECT_CHECKS_COMPLETE" in heroism_logic_text and "SELECTED LOGIC TESTS PASSED" in heroism_logic_text and "SCENARIO PASSED: enhance_ability_spell_flow" in enhance_ability_live_text and "ENHANCE_ABILITY_LIVE_FLOW_CHECKS_COMPLETE" in enhance_ability_live_text
    charm_person_live = ROOT / ".artifacts/core12-repairs/charm-person-live/charm_person_spell_flow.stdout.log"
    charm_person_live_text = charm_person_live.read_text(errors="replace") if charm_person_live.exists() else ""
    charm_person_verified = bool(re.search(r"RESULTS: 99 passed, 0 failed", heroism_logic_text)) and "CHARM_PERSON_EFFECT_CHECKS_COMPLETE" in heroism_logic_text and "SELECTED LOGIC TESTS PASSED" in heroism_logic_text and "SCENARIO PASSED: charm_person_spell_flow" in charm_person_live_text and "CHARM_PERSON_LIVE_FLOW_CHECKS_COMPLETE" in charm_person_live_text
    charm_monster_live = ROOT / ".artifacts/core12-repairs/charm-monster-live/charm_monster_spell_flow.stdout.log"
    charm_monster_live_text = charm_monster_live.read_text(errors="replace") if charm_monster_live.exists() else ""
    charm_monster_verified = bool(re.search(r"RESULTS: 99 passed, 0 failed", heroism_logic_text)) and "CHARM_MONSTER_EFFECT_CHECKS_COMPLETE" in heroism_logic_text and "SELECTED LOGIC TESTS PASSED" in heroism_logic_text and "SCENARIO PASSED: charm_monster_spell_flow" in charm_monster_live_text and "CHARM_MONSTER_LIVE_FLOW_CHECKS_COMPLETE" in charm_monster_live_text
    fog_cloud_live = ROOT / ".artifacts/core12-repairs/fog-cloud-live/fog_cloud_spell_flow.stdout.log"
    fog_cloud_live_text = fog_cloud_live.read_text(errors="replace") if fog_cloud_live.exists() else ""
    fog_cloud_verified = bool(re.search(r"RESULTS: 99 passed, 0 failed", heroism_logic_text)) and "FOG_CLOUD_EFFECT_CHECKS_COMPLETE" in heroism_logic_text and "SELECTED LOGIC TESTS PASSED" in heroism_logic_text and "SCENARIO PASSED: fog_cloud_spell_flow" in fog_cloud_live_text and "FOG_CLOUD_LIVE_FLOW_CHECKS_COMPLETE" in fog_cloud_live_text
    invisibility_logic = ROOT / ".artifacts/core12-repairs/invisibility-focused/logic.stdout.log"
    invisibility_logic_text = invisibility_logic.read_text(errors="replace") if invisibility_logic.exists() else ""
    invisibility_live = ROOT / ".artifacts/core12-repairs/invisibility-live/invisibility_spell_flow.stdout.log"
    invisibility_live_text = invisibility_live.read_text(errors="replace") if invisibility_live.exists() else ""
    invisibility_verified = bool(re.search(r"RESULTS: 102 passed, 0 failed", invisibility_logic_text)) and "INVISIBILITY_EFFECT_CHECKS_COMPLETE" in invisibility_logic_text and "SELECTED LOGIC TESTS PASSED" in invisibility_logic_text and "SCENARIO PASSED: invisibility_spell_flow" in invisibility_live_text and "INVISIBILITY_LIVE_FLOW_CHECKS_COMPLETE" in invisibility_live_text
    darkness_logic = ROOT / ".artifacts/core12-repairs/darkness-focused/logic.stdout.log"
    darkness_logic_text = darkness_logic.read_text(errors="replace") if darkness_logic.exists() else ""
    darkness_live = ROOT / ".artifacts/core12-repairs/darkness-live/darkness_spell_flow.stdout.log"
    darkness_live_text = darkness_live.read_text(errors="replace") if darkness_live.exists() else ""
    darkness_verified = bool(re.search(r"RESULTS: 104 passed, 0 failed", darkness_logic_text)) and "DARKNESS_EFFECT_CHECKS_COMPLETE" in darkness_logic_text and "SELECTED LOGIC TESTS PASSED" in darkness_logic_text and "SCENARIO PASSED: darkness_spell_flow" in darkness_live_text and "DARKNESS_LIVE_FLOW_CHECKS_COMPLETE" in darkness_live_text
    darkvision_logic = ROOT / ".artifacts/core12-repairs/darkvision-focused/logic.stdout.log"
    darkvision_logic_text = darkvision_logic.read_text(errors="replace") if darkvision_logic.exists() else ""
    darkvision_live = ROOT / ".artifacts/core12-repairs/darkvision-live/darkvision_spell_flow.stdout.log"
    darkvision_live_text = darkvision_live.read_text(errors="replace") if darkvision_live.exists() else ""
    darkvision_verified = bool(re.search(r"RESULTS: 221 passed, 0 failed", darkvision_logic_text)) and "DARKVISION_EFFECT_CHECKS_COMPLETE" in darkvision_logic_text and "SELECTED LOGIC TESTS PASSED" in darkvision_logic_text and "SCENARIO PASSED: darkvision_spell_flow" in darkvision_live_text and "DARKVISION_LIVE_FLOW_CHECKS_COMPLETE" in darkvision_live_text
    see_invisibility_logic = ROOT / ".artifacts/core12-repairs/see-invisibility-focused/logic.stdout.log"
    see_invisibility_logic_text = see_invisibility_logic.read_text(errors="replace") if see_invisibility_logic.exists() else ""
    see_invisibility_live = ROOT / ".artifacts/core12-repairs/see-invisibility-live/see_invisibility_spell_flow.stdout.log"
    see_invisibility_live_text = see_invisibility_live.read_text(errors="replace") if see_invisibility_live.exists() else ""
    see_invisibility_verified = bool(re.search(r"RESULTS: 224 passed, 0 failed", see_invisibility_logic_text)) and "SEE_INVISIBILITY_EFFECT_CHECKS_COMPLETE" in see_invisibility_logic_text and "SELECTED LOGIC TESTS PASSED" in see_invisibility_logic_text and "SCENARIO PASSED: see_invisibility_spell_flow" in see_invisibility_live_text and "SEE_INVISIBILITY_LIVE_FLOW_CHECKS_COMPLETE" in see_invisibility_live_text
    true_seeing_logic = ROOT / ".artifacts/core12-repairs/true-seeing-focused/logic.stdout.log"
    true_seeing_logic_text = true_seeing_logic.read_text(errors="replace") if true_seeing_logic.exists() else ""
    true_seeing_live = ROOT / ".artifacts/core12-repairs/true-seeing-live/true_seeing_spell_flow.stdout.log"
    true_seeing_live_text = true_seeing_live.read_text(errors="replace") if true_seeing_live.exists() else ""
    true_seeing_verified = bool(re.search(r"RESULTS: 227 passed, 0 failed", true_seeing_logic_text)) and "TRUE_SEEING_EFFECT_CHECKS_COMPLETE" in true_seeing_logic_text and "SELECTED LOGIC TESTS PASSED" in true_seeing_logic_text and "SCENARIO PASSED: true_seeing_spell_flow" in true_seeing_live_text and "TRUE_SEEING_LIVE_FLOW_CHECKS_COMPLETE" in true_seeing_live_text
    faerie_fire_live = ROOT / ".artifacts/core12-repairs/faerie-fire-live/faerie_fire_spell_flow.stdout.log"
    faerie_fire_live_text = faerie_fire_live.read_text(errors="replace") if faerie_fire_live.exists() else ""
    faerie_fire_verified = bool(re.search(r"RESULTS: 99 passed, 0 failed", heroism_logic_text)) and "FAERIE_FIRE_EFFECT_CHECKS_COMPLETE" in heroism_logic_text and "SELECTED LOGIC TESTS PASSED" in heroism_logic_text and "SCENARIO PASSED: faerie_fire_spell_flow" in faerie_fire_live_text and "FAERIE_FIRE_LIVE_FLOW_CHECKS_COMPLETE" in faerie_fire_live_text
    moonbeam_logic = ROOT / ".artifacts/core12-repairs/moonbeam-focused-final/logic.stdout.log"
    moonbeam_logic_text = moonbeam_logic.read_text(errors="replace") if moonbeam_logic.exists() else ""
    moonbeam_live = ROOT / ".artifacts/core12-repairs/moonbeam-live-final/moonbeam_spell_flow.stdout.log"
    moonbeam_live_text = moonbeam_live.read_text(errors="replace") if moonbeam_live.exists() else ""
    moonbeam_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", moonbeam_logic_text)) and "MOONBEAM_AREA_CHECKS_COMPLETE" in moonbeam_logic_text and "SELECTED LOGIC TESTS PASSED" in moonbeam_logic_text and "SCENARIO PASSED: moonbeam_spell_flow" in moonbeam_live_text and "MOONBEAM_ZONE_FLOW_CHECKS_COMPLETE" in moonbeam_live_text
    plant_growth_logic = ROOT / ".artifacts/core12-repairs/plant-growth-focused-final/logic.stdout.log"
    plant_growth_logic_text = plant_growth_logic.read_text(errors="replace") if plant_growth_logic.exists() else ""
    plant_growth_live = ROOT / ".artifacts/core12-repairs/plant-growth-live-final/plant_growth_spell_flow.stdout.log"
    plant_growth_live_text = plant_growth_live.read_text(errors="replace") if plant_growth_live.exists() else ""
    plant_growth_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", plant_growth_logic_text)) and "PLANT_GROWTH_AREA_CHECKS_COMPLETE" in plant_growth_logic_text and "SELECTED LOGIC TESTS PASSED" in plant_growth_logic_text and "SCENARIO PASSED: plant_growth_spell_flow" in plant_growth_live_text and "PLANT_GROWTH_ZONE_FLOW_CHECKS_COMPLETE" in plant_growth_live_text
    barkskin_logic = ROOT / ".artifacts/core12-repairs/barkskin-focused-final/logic.stdout.log"
    barkskin_logic_text = barkskin_logic.read_text(errors="replace") if barkskin_logic.exists() else ""
    barkskin_live = ROOT / ".artifacts/core12-repairs/barkskin-live-final/barkskin_spell_flow.stdout.log"
    barkskin_live_text = barkskin_live.read_text(errors="replace") if barkskin_live.exists() else ""
    barkskin_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", barkskin_logic_text)) and "BARKSKIN_AC_FLOOR_CHECKS_COMPLETE" in barkskin_logic_text and "SELECTED LOGIC TESTS PASSED" in barkskin_logic_text and "SCENARIO PASSED: barkskin_spell_flow" in barkskin_live_text and "BARKSKIN_LIVE_FLOW_CHECKS_COMPLETE" in barkskin_live_text
    mage_armor_logic = ROOT / ".artifacts/core12-repairs/mage-armor-focused-final/logic.stdout.log"
    mage_armor_logic_text = mage_armor_logic.read_text(errors="replace") if mage_armor_logic.exists() else ""
    mage_armor_live = ROOT / ".artifacts/core12-repairs/mage-armor-live-final/mage_armor_spell_flow.stdout.log"
    mage_armor_live_text = mage_armor_live.read_text(errors="replace") if mage_armor_live.exists() else ""
    mage_armor_verified = bool(re.search(r"RESULTS: \d+ passed, 0 failed", mage_armor_logic_text)) and "MAGE_ARMOR_AC_CHECKS_COMPLETE" in mage_armor_logic_text and "SELECTED LOGIC TESTS PASSED" in mage_armor_logic_text and "SCENARIO PASSED: mage_armor_spell_flow" in mage_armor_live_text and "MAGE_ARMOR_LIVE_FLOW_CHECKS_COMPLETE" in mage_armor_live_text
    bard_live = ROOT / ".artifacts/bard-acceptance/live-accepted.log"
    bard_logic = ROOT / ".artifacts/bard-acceptance/full-corrected/logic.stdout.log"
    bard_verified = bard_live.exists() and "SCENARIO PASSED: bard_action_flow" in bard_live.read_text(errors="replace") and bard_logic.exists() and "ALL TESTS PASSED" in bard_logic.read_text(errors="replace")
    groups = {}
    for key, (_, _, members) in FAMILIES.items():
        for sid in members.split():
            if sid in groups:
                raise ValueError(f"Duplicate behavior assignment: {sid}")
            if sid not in spells:
                raise ValueError(f"Unknown behavior member: {sid}")
            groups[sid] = key
    evidence = {sid: batch for batch, members in EVIDENCE_BATCHES.items() for sid in members.split()}
    familiar_log = ROOT / ".artifacts/wave4-foundations/familiar-accepted-validation.log"
    familiar_text = familiar_log.read_text(encoding="utf-8", errors="replace") if familiar_log.exists() else ""
    familiar_verified = all(marker in familiar_text for marker in ["SCENARIO PASSED: find_familiar_exploration_flow", "SCENARIO PASSED: owned_creature_lifecycle_flow", "ALL TESTS PASSED", ">> OVERALL: REQUESTED TESTS PASSED"])
    recovery_log = ROOT / ".artifacts/wave4-foundations/body-accepted-validation.log"
    recovery_text = recovery_log.read_text(encoding="utf-8", errors="replace") if recovery_log.exists() else ""
    recovery_verified = all(marker in recovery_text for marker in ["SCENARIO PASSED: party_recovery_flow", "ALL TESTS PASSED", ">> OVERALL: REQUESTED TESTS PASSED"])
    created_log = ROOT / ".artifacts/wave4-foundations/created-accepted-validation.log"
    created_text = created_log.read_text(encoding="utf-8", errors="replace") if created_log.exists() else ""
    created_verified = all(marker in created_text for marker in ["SCENARIO PASSED: created_undead_flow", "ALL TESTS PASSED", ">> OVERALL: REQUESTED TESTS PASSED"]) and ">> OVERALL: FAILED" not in created_text
    # Later checkpoint slices whose artifact directories have varied names.
    checkpoint_slices = {"message", "minor_illusion", "prestidigitation", "produce_flame", "protection_from_energy", "guidance", "resistance", "shillelagh"}
    # Older built-in spells have production resolver checks but are not certified 2024-complete.
    prior_checks = {"magic_missile", "mage_armor", "scorching_ray", "fireball", "shield", "bless", "misty_step", "eldritch_blast", "spare_the_dying", "burning_hands", "cone_of_cold", "power_word_heal", "power_word_kill", "find_steed", "divine_smite", "hunters_mark", "chain_lightning", "sunburst", "meteor_swarm", "circle_of_death", "finger_of_death", "contact_other_plane", "shatter", "antilife_shell", "freedom_of_movement"}
    target = reconcile_target(target_path.resolve(), spells, runtime["class_lists"])
    rows = []
    for sid, spell in sorted(spells.items()):
        classes = sorted(k for k, ids in runtime["class_lists"].items() if sid in ids)
        blocked = not availability[sid]["available"]
        status = "recorded_slice" if sid == "bane" and bane_verified else "recorded_slice" if sid == "jump" and jump_verified else "recorded_slice" if sid == "aid" and aid_verified else "recorded_slice" if sid == "alter_self" and alter_verified else "recorded_slice" if sid == "eldritch_blast" and eldritch_verified else "recorded_slice" if sid == "spare_the_dying" and spare_verified else "recorded_slice" if sid == "thunderwave" and thunderwave_verified else "recorded_slice" if sid in {"burning_hands", "cone_of_cold"} and area_spell_verified else "recorded_slice" if sid == "circle_of_death" and circle_death_verified else "recorded_slice" if sid == "power_word_stun" and power_word_stun_verified else "recorded_slice" if sid == "counterspell" and counterspell_verified else "recorded_slice" if sid == "sleep" and sleep_verified else "recorded_slice" if sid == "blindness/deafness" and blindness_verified else "recorded_slice" if sid == "grease" and grease_verified else "recorded_slice" if sid == "true_strike" and true_strike_verified else "recorded_slice" if sid == "mass_cure_wounds" and mass_cure_verified else "recorded_slice" if sid == "mass_healing_word" and mass_healing_verified else "recorded_slice" if sid in batch_ids and batch_verified else "implemented_unverified" if sid in {"hold_person", "hold_monster"} else "blocked" if blocked and (sid == "mending" or sid in AUDITED_EFFECTLESS or spell.get("rules_status") == "2024-gameplay-partial") else "recorded_slice" if sid in evidence or sid in checkpoint_slices else "existing_checks_need_audit" if sid in prior_checks else "needs_audit"
        if sid == "spike_growth" and spike_growth_verified:
            status = "recorded_slice"
        if sid == "entangle" and entangle_verified:
            status = "recorded_slice"
        if sid == "black_tentacles" and black_tentacles_verified:
            status = "recorded_slice"
        if sid == "sleet_storm" and sleet_storm_verified:
            status = "recorded_slice"
        if sid == "cloud_of_daggers" and cloud_of_daggers_verified:
            status = "recorded_slice"
        if sid == "cloudkill" and cloudkill_verified:
            status = "recorded_slice"
        if sid == "conjure_animals" and conjure_animals_verified:
            status = "recorded_slice"
        if sid == "conjure_celestial" and conjure_celestial_verified:
            status = "recorded_slice"
        if sid == "conjure_elemental" and conjure_elemental_verified:
            status = "recorded_slice"
        if sid == "conjure_fey" and conjure_fey_verified:
            status = "recorded_slice"
        if sid == "conjure_minor_elementals" and conjure_minor_elementals_verified:
            status = "recorded_slice"
        if sid == "conjure_woodland_beings" and conjure_woodland_beings_verified:
            status = "recorded_slice"
        if sid == "spirit_guardians" and spirit_guardians_verified:
            status = "recorded_slice"
        if sid == "aura_of_life" and aura_of_life_verified:
            status = "recorded_slice"
        if sid == "beacon_of_hope" and beacon_verified:
            status = "recorded_slice"
        if sid == "divine_favor" and divine_favor_verified:
            status = "recorded_slice"
        if sid == "death_ward" and death_ward_verified:
            status = "recorded_slice"
        if sid == "sanctuary" and sanctuary_verified:
            status = "recorded_slice"
        if sid == "heroism" and heroism_verified:
            status = "recorded_slice"
        if sid == "magic_weapon" and magic_weapon_verified:
            status = "recorded_slice"
        if sid == "enhance_ability" and enhance_ability_verified:
            status = "recorded_slice"
        if sid == "charm_person" and charm_person_verified:
            status = "recorded_slice"
        if sid == "charm_monster" and charm_monster_verified:
            status = "recorded_slice"
        if sid == "faerie_fire" and faerie_fire_verified:
            status = "recorded_slice"
        if sid == "fog_cloud" and fog_cloud_verified:
            status = "recorded_slice"
        if sid == "darkness" and darkness_verified:
            status = "recorded_slice"
        if sid == "darkvision" and darkvision_verified:
            status = "recorded_slice"
        if sid == "see_invisibility" and see_invisibility_verified:
            status = "recorded_slice"
        if sid == "true_seeing" and true_seeing_verified:
            status = "recorded_slice"
        if sid == "invisibility" and invisibility_verified:
            status = "recorded_slice"
        if sid == "moonbeam" and moonbeam_verified:
            status = "recorded_slice"
        if sid == "plant_growth" and plant_growth_verified:
            status = "recorded_slice"
        if sid == "barkskin" and barkskin_verified:
            status = "recorded_slice"
        if sid == "mage_armor" and mage_armor_verified:
            status = "recorded_slice"
        if sid in {"power_word_heal", "power_word_kill"} and bard_verified:
            status = "recorded_slice"
        if sid == "find_familiar" and familiar_verified:
            status = "recorded_slice"
        if sid in {"revivify", "gentle_repose"} and recovery_verified:
            status = "recorded_slice"
        if sid == "animate_dead" and created_verified:
            status = "recorded_slice"
        refs = ["docs/operations/current.md", "src/test_runner.gd"] if status in {"recorded_slice", "existing_checks_need_audit", "implemented_unverified"} else []
        if sid == "find_familiar" and familiar_verified:
            refs += ["docs/mechanics/find-familiar-2024.md", "src/characters/familiar_rules.gd", "src/spells/familiar_spell_delivery.gd", "src/dungeon/local_room_familiars.gd", "src/characters/familiar_checks.gd", "src/viewport_harness.gd", familiar_log.relative_to(ROOT).as_posix()]
        if sid in {"revivify", "gentle_repose"} and recovery_verified:
            refs += ["docs/mechanics/party-recovery-2024.md", "src/characters/corpse_rules.gd", "src/characters/corpse_checks.gd", "src/dungeon/local_room_bodies.gd", "src/viewport_harness.gd", recovery_log.relative_to(ROOT).as_posix()]
        if sid == "animate_dead" and created_verified:
            refs += ["docs/mechanics/animate-dead-2024.md", "src/characters/created_creature_rules.gd", "src/characters/created_creature_checks.gd", "src/combat/created_creature_combat.gd", "src/dungeon/local_room_created.gd", "src/viewport_harness.gd", created_log.relative_to(ROOT).as_posix()]
        wave2_review_log = {
            "chain_lightning": "confirmed/chain_lightning_mixed_targets_flow.stdout.log",
            "fire_bolt": "final/combat_light_visibility_flow.stdout.log",
            "mage_armor": "final/combat_light_visibility_flow.stdout.log",
            "magic_missile": "final/combat_light_visibility_flow.stdout.log",
            "healing_word": "final/combat_light_visibility_flow.stdout.log",
            "true_seeing": "final/combat_light_visibility_flow.stdout.log",
            "true_strike": "final/true_strike_spell_flow.stdout.log",
        }.get(sid)
        if wave2_review_log:
            review_log = ROOT / ".artifacts/wave2-review-fixes" / wave2_review_log
            if review_log.exists() and "SCENARIO PASSED:" in review_log.read_text(encoding="utf-8", errors="replace"):
                refs += ["docs/reviews/spell-foundations-wave2-2026-10-07.md", "src/viewport_harness.gd", review_log.relative_to(ROOT).as_posix()]
        if sid in {"power_word_heal", "power_word_kill"} and bard_verified:
            refs += ["src/bard_checks.gd", "src/viewport_harness.gd", "docs/mechanics/bard-2024.md", bard_live.relative_to(ROOT).as_posix(), bard_logic.relative_to(ROOT).as_posix()]
        if sid in batch_ids and batch_verified:
            refs += ["src/spells/spell_effects.gd", "src/spells/spell_effect_checks.gd", "src/viewport_harness.gd", live_log.relative_to(ROOT).as_posix(), effects_log.relative_to(ROOT).as_posix()]
        if sid == "sunburst" and sid in evidence:
            refs += ["src/spells/spell_effects.gd", "src/spells/spell_cast_areas.gd", "src/spells/spell_zone_terrain.gd", "src/viewport_harness.gd", ".artifacts/w2-sunburst-live-final/sunburst_spell_flow.stdout.log", ".artifacts/w2-sunburst-logic-final/logic.stdout.log"]
        if sid == "bane" and bane_verified:
            refs += ["src/spells/spell_effects.gd", "src/spells/spell_effect_checks.gd", "src/characters/character.gd", "src/characters/barbarian_rules.gd", "src/combat/combat_state.gd", "src/viewport_harness.gd", bane_live.relative_to(ROOT).as_posix(), bane_logic.relative_to(ROOT).as_posix()]
        if sid == "aid" and aid_verified:
            refs += ["src/spells/spell_effects.gd", "src/spells/spell_effect_checks.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/viewport_harness.gd", aid_live.relative_to(ROOT).as_posix(), aid_logic.relative_to(ROOT).as_posix()]
        if sid == "alter_self" and alter_verified:
            refs += ["src/spells/spell_effects.gd", "src/spells/spell_effect_checks.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/viewport_harness.gd", alter_live.relative_to(ROOT).as_posix(), alter_logic.relative_to(ROOT).as_posix()]
        if sid == "eldritch_blast" and eldritch_verified:
            refs += ["src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", eldritch_logic.relative_to(ROOT).as_posix()]
        if sid == "spare_the_dying" and spare_verified:
            refs += ["src/characters/character.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", eldritch_logic.relative_to(ROOT).as_posix()]
        if sid == "shatter" and shatter_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_action.gd", "src/spells/spell_support.gd", "src/test_runner.gd", shatter_logic.relative_to(ROOT).as_posix()]
        if sid == "thunderwave" and thunderwave_verified:
            refs += ["data/core/spells/core_spells.json", "src/combat/targeting.gd", "src/combat/combat_state.gd", "src/events/event_resolver.gd", "src/spells/spell_support.gd", "src/test_runner.gd", spell_slices_logic.relative_to(ROOT).as_posix()]
        if sid in {"burning_hands", "cone_of_cold"} and area_spell_verified:
            refs += ["data/core/spells/core_spells.json", "data/core/spells/wizard_spellbook_spells.json", "src/combat/combat_action.gd", "src/test_runner.gd", spell_slices_logic.relative_to(ROOT).as_posix()]
        if sid == "circle_of_death" and circle_death_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/core/items/srd_gear.json", "src/characters/inventory.gd", "src/combat/combat_state.gd", "src/ui/shop.gd", "src/spells/spell_support.gd", "src/test_runner.gd", spell_slices_logic.relative_to(ROOT).as_posix()]
        if sid == "power_word_stun" and power_word_stun_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "src/spells/spell_effects.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/characters/character.gd", "src/characters/fighter_rules.gd", "src/spells/spell_support.gd", "src/test_runner.gd", spell_slices_logic.relative_to(ROOT).as_posix()]
        if sid == "counterspell" and counterspell_verified:
            refs += ["data/core/spells/core_spells.json", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", counterspell_logic.relative_to(ROOT).as_posix(), ".artifacts/core12-repairs/counterspell-live-accepted/sorcerer_subtle_spell.stdout.log"]
        if sid == "sleep" and sleep_verified:
            refs += ["data/core/spells/core_spells.json", "src/spells/spell_effects.gd", "src/spells/spell_effect_checks.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", sleep_logic.relative_to(ROOT).as_posix(), sleep_live.relative_to(ROOT).as_posix()]
        if sid == "true_strike" and true_strike_verified:
            refs += ["data/core/spells/core_spells.json", "data/content_manifest.json", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/characters/character.gd", "src/spells/spell_support.gd", "src/spells/true_strike_checks.gd", "src/test_runner.gd", "src/viewport_harness.gd", true_strike_logic.relative_to(ROOT).as_posix(), true_strike_live.relative_to(ROOT).as_posix()]
        if sid == "mass_cure_wounds" and mass_cure_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "src/combat/combat_state.gd", "src/events/event_resolver.gd", "src/spells/spell_support.gd", "src/spells/mass_cure_wounds_checks.gd", "src/test_runner.gd", "src/viewport_harness.gd", mass_cure_logic.relative_to(ROOT).as_posix(), mass_cure_live.relative_to(ROOT).as_posix()]
        if sid == "mass_healing_word" and mass_healing_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_state.gd", "src/events/event_resolver.gd", "src/spells/spell_support.gd", "src/spells/mass_healing_word_checks.gd", "src/test_runner.gd", "src/viewport_harness.gd", mass_healing_logic.relative_to(ROOT).as_posix(), mass_healing_live.relative_to(ROOT).as_posix()]
        if sid == "blindness/deafness" and blindness_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/spells/spell_effects.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/spells/blindness_deafness_checks.gd", "src/test_runner.gd", "src/viewport_harness.gd", blindness_logic.relative_to(ROOT).as_posix(), blindness_live.relative_to(ROOT).as_posix()]
        if sid == "grease" and grease_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/targeting.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/events/event_resolver.gd", "src/hex/hex_grid.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", grease_logic.relative_to(ROOT).as_posix(), grease_live.relative_to(ROOT).as_posix()]
        if sid == "spike_growth" and spike_growth_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_state.gd", "src/hex/hex_grid.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", spike_growth_logic.relative_to(ROOT).as_posix(), spike_growth_live.relative_to(ROOT).as_posix()]
        if sid == "entangle" and entangle_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/characters/character.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", entangle_logic.relative_to(ROOT).as_posix(), entangle_live.relative_to(ROOT).as_posix()]
        if sid == "black_tentacles" and black_tentacles_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/targeting.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/hex/hex_grid.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", black_tentacles_logic.relative_to(ROOT).as_posix(), black_tentacles_live.relative_to(ROOT).as_posix()]
        if sid == "sleet_storm" and sleet_storm_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/targeting.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/hex/hex_grid.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", sleet_storm_logic.relative_to(ROOT).as_posix(), sleet_storm_live.relative_to(ROOT).as_posix()]
        if sid == "cloud_of_daggers" and cloud_of_daggers_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_action.gd", "src/combat/combat_command.gd", "src/combat/combat_hud.gd", "src/combat/combat_state.gd", "src/events/event_resolver.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", cloud_of_daggers_logic.relative_to(ROOT).as_posix(), cloud_of_daggers_live.relative_to(ROOT).as_posix()]
        if sid == "cloudkill" and cloudkill_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", cloudkill_logic.relative_to(ROOT).as_posix(), cloudkill_live.relative_to(ROOT).as_posix()]
        if sid == "conjure_animals" and conjure_animals_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/characters/character.gd", "src/combat/combat_command.gd", "src/combat/combat_hud.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", conjure_animals_logic.relative_to(ROOT).as_posix(), conjure_animals_live.relative_to(ROOT).as_posix()]
        if sid == "conjure_celestial" and conjure_celestial_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_command.gd", "src/combat/combat_hud.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", conjure_celestial_logic.relative_to(ROOT).as_posix(), conjure_celestial_live.relative_to(ROOT).as_posix()]
        if sid == "conjure_elemental" and conjure_elemental_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "src/combat/combat_hud.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", conjure_elemental_logic.relative_to(ROOT).as_posix(), conjure_elemental_live.relative_to(ROOT).as_posix()]
        if sid == "conjure_fey" and conjure_fey_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "src/combat/combat_action.gd", "src/combat/combat_command.gd", "src/combat/combat_hud.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", conjure_fey_logic.relative_to(ROOT).as_posix(), conjure_fey_live.relative_to(ROOT).as_posix()]
        if sid == "conjure_minor_elementals" and conjure_minor_elementals_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/hex/hex_utils.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", conjure_minor_elementals_logic.relative_to(ROOT).as_posix(), conjure_minor_elementals_live.relative_to(ROOT).as_posix()]
        if sid == "conjure_woodland_beings" and conjure_woodland_beings_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "src/combat/combat_command.gd", "src/combat/combat_hud.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", conjure_woodland_beings_logic.relative_to(ROOT).as_posix(), conjure_woodland_beings_live.relative_to(ROOT).as_posix()]
        if sid == "spirit_guardians" and spirit_guardians_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_hud.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", spirit_guardians_logic.relative_to(ROOT).as_posix(), spirit_guardians_live.relative_to(ROOT).as_posix()]
        if sid == "aura_of_life" and aura_of_life_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "src/characters/character.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", aura_of_life_logic.relative_to(ROOT).as_posix(), aura_of_life_live.relative_to(ROOT).as_posix()]
        if sid == "beacon_of_hope" and beacon_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/autoload/dice.gd", "src/characters/character.gd", "src/characters/barbarian_rules.gd", "src/combat/combat_action.gd", "src/combat/combat_hud.gd", "src/combat/combat_state.gd", "src/events/event_resolver.gd", "src/spells/spell_effects.gd", "src/spells/spell_effect_checks.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", beacon_logic.relative_to(ROOT).as_posix(), beacon_live.relative_to(ROOT).as_posix()]
        if sid == "divine_favor" and divine_favor_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_action.gd", "src/spells/spell_effect_checks.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", divine_favor_logic.relative_to(ROOT).as_posix(), divine_favor_live.relative_to(ROOT).as_posix()]
        if sid == "death_ward" and death_ward_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_action.gd", "src/spells/spell_effect_checks.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", death_ward_logic.relative_to(ROOT).as_posix(), death_ward_live.relative_to(ROOT).as_posix()]
        if sid == "sanctuary" and sanctuary_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_action.gd", "src/spells/spell_effect_checks.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", sanctuary_logic.relative_to(ROOT).as_posix(), sanctuary_live.relative_to(ROOT).as_posix()]
        if sid == "heroism" and heroism_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/characters/character.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_effect_checks.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", heroism_logic.relative_to(ROOT).as_posix(), heroism_live.relative_to(ROOT).as_posix()]
        if sid == "magic_weapon" and magic_weapon_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_effect_checks.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", heroism_logic.relative_to(ROOT).as_posix(), magic_weapon_live.relative_to(ROOT).as_posix()]
        if sid == "enhance_ability" and enhance_ability_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/characters/character.gd", "src/combat/combat_hud.gd", "src/combat/combat_state.gd", "src/events/event_resolver.gd", "src/spells/spell_effect_checks.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/viewport_harness.gd", "run_tests.ps1", heroism_logic.relative_to(ROOT).as_posix(), enhance_ability_live.relative_to(ROOT).as_posix()]
        if sid == "charm_person" and charm_person_verified:
            refs += ["data/core/spells/imported_spells.json", "src/ai/ai_controller.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_effect_checks.gd", "src/spells/spell_effects.gd", "src/viewport_harness.gd", "run_tests.ps1", heroism_logic.relative_to(ROOT).as_posix(), charm_person_live.relative_to(ROOT).as_posix()]
        if sid == "charm_monster" and charm_monster_verified:
            refs += ["data/core/spells/imported_spells.json", "src/ai/ai_controller.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_effect_checks.gd", "src/spells/spell_effects.gd", "src/viewport_harness.gd", "run_tests.ps1", heroism_logic.relative_to(ROOT).as_posix(), charm_monster_live.relative_to(ROOT).as_posix()]
        if sid == "faerie_fire" and faerie_fire_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_effect_checks.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", heroism_logic.relative_to(ROOT).as_posix(), faerie_fire_live.relative_to(ROOT).as_posix()]
        if sid == "fog_cloud" and fog_cloud_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/spells/spell_effect_checks.gd", "src/viewport_harness.gd", "run_tests.ps1", heroism_logic.relative_to(ROOT).as_posix(), fog_cloud_live.relative_to(ROOT).as_posix()]
        if sid == "darkness" and darkness_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/spells/spell_effect_checks.gd", "src/viewport_harness.gd", "run_tests.ps1", darkness_logic.relative_to(ROOT).as_posix(), darkness_live.relative_to(ROOT).as_posix()]
        if sid == "darkvision" and darkvision_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/overworld/fog_of_war.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/spells/spell_effect_checks.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", darkvision_logic.relative_to(ROOT).as_posix(), darkvision_live.relative_to(ROOT).as_posix()]
        if sid == "see_invisibility" and see_invisibility_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_action.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/spells/spell_effect_checks.gd", "src/viewport_harness.gd", "run_tests.ps1", see_invisibility_logic.relative_to(ROOT).as_posix(), see_invisibility_live.relative_to(ROOT).as_posix()]
        if sid == "true_seeing" and true_seeing_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/core/items/srd_gear.json", "data/content_manifest.json", "src/characters/inventory.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/spells/spell_effect_checks.gd", "src/viewport_harness.gd", "run_tests.ps1", true_seeing_logic.relative_to(ROOT).as_posix(), true_seeing_live.relative_to(ROOT).as_posix()]
        if sid == "invisibility" and invisibility_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/spells/spell_effect_checks.gd", "src/viewport_harness.gd", "run_tests.ps1", invisibility_logic.relative_to(ROOT).as_posix(), invisibility_live.relative_to(ROOT).as_posix()]
        if sid == "moonbeam" and moonbeam_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/characters/druid_rules.gd", "src/combat/combat_action.gd", "src/combat/combat_command.gd", "src/combat/combat_hud.gd", "src/combat/combat_state.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", moonbeam_logic.relative_to(ROOT).as_posix(), moonbeam_live.relative_to(ROOT).as_posix()]
        if sid == "plant_growth" and plant_growth_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_state.gd", "src/events/event_resolver.gd", "src/hex/hex_grid.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", plant_growth_logic.relative_to(ROOT).as_posix(), plant_growth_live.relative_to(ROOT).as_posix()]
        if sid == "barkskin" and barkskin_verified:
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/characters/character.gd", "src/combat/combat_action.gd", "src/combat/combat_state.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", barkskin_logic.relative_to(ROOT).as_posix(), barkskin_live.relative_to(ROOT).as_posix()]
        if sid == "mage_armor" and mage_armor_verified:
            refs += ["data/core/spells/core_spells.json", "data/content_manifest.json", "src/characters/character.gd", "src/combat/combat_state.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1", mage_armor_logic.relative_to(ROOT).as_posix(), mage_armor_live.relative_to(ROOT).as_posix()]
        if sid == "jump" and jump_verified:
            refs += ["src/spells/spell_effects.gd", "src/spells/spell_effect_checks.gd", "src/combat/combat_state.gd", "src/viewport_harness.gd", jump_live.relative_to(ROOT).as_posix(), jump_logic.relative_to(ROOT).as_posix()]
        if sid in AUDITED_EFFECTLESS:
            refs += ["docs/reviews/spell-behavior-and-character-plan-2026-10-05.md", "src/combat/combat_action.gd", "src/combat/combat_state.gd", ".artifacts/spell-status/behavior-audit-probe.log"]
        batch = evidence.get(sid)
        if batch:
            directory = ROOT / ".artifacts/core12-repairs" / batch
            logs = list(directory.glob("*.stdout.log"))
            # Record only existing logs with an actual passing result, never fabricate a path.
            refs += [p.relative_to(ROOT).as_posix() for p in logs if "SCENARIO PASSED:" in p.read_text(encoding="utf-8", errors="replace")]
        if sid == "detect_evil_and_good":
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_state.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1"]
        if sid == "antilife_shell":
            refs += ["src/combat/combat_state.gd", "src/spells/combat_spell_zones.gd", "src/spells/spell_zone_conjurations.gd", "src/spells/spell_cast_areas.gd", "src/spells/spell_cast_results.gd", "src/spells/spell_support.gd", "src/viewport_harness.gd", "run_tests.ps1", ".artifacts/spell-status/antilife_shell_spell_flow.stdout.log", ".artifacts/spell-status/antilife_shell_logic.stdout.log"]
        if sid == "freedom_of_movement":
            refs += ["data/core/spells/srd_additional_spells.json", "src/hex/hex_grid.gd", "src/combat/combat_state.gd", "src/dungeon/local_room_rules.gd", "src/spells/spell_effect_application.gd", "src/spells/spell_effects.gd", "src/viewport_harness.gd", "run_tests.ps1", ".artifacts/spell-status/freedom_of_movement_spell_flow.stdout.log"]
        if sid == "grease":
            refs += ["src/dungeon/local_room_combat.gd", "src/dungeon/local_room_rules.gd", "src/dungeon/dungeon_persistence.gd", "src/viewport_harness.gd", ".artifacts/spell-status/local_room_object_flow.stdout.log"]
        if sid == "detect_poison_and_disease":
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_state.gd", "src/spells/detect_poison_rules.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1"]
        if sid == "identify":
            refs += ["data/core/spells/srd_additional_spells.json", "data/core/items/srd_gear.json", "data/content_manifest.json", "src/combat/combat_hud.gd", "src/combat/combat_state.gd", "src/spells/identify_rules.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1"]
        if sid == "goodberry":
            refs += ["data/core/spells/srd_additional_spells.json", "data/content_manifest.json", "src/combat/combat_command.gd", "src/combat/combat_hud.gd", "src/combat/combat_state.gd", "src/spells/spell_effects.gd", "src/spells/spell_support.gd", "src/test_runner.gd", "src/viewport_harness.gd", "run_tests.ps1"]
        rows.append({"id": sid, "name": spell["name"], "level": spell["level"], "classes": classes, "repair_snapshot_classes": target["memberships"].get(sid, []), "delivery_status": status, "rules_completeness": "not_certified", "primary_behavior": groups.get(sid, "direct_resolution"), "data_rules_status": spell.get("rules_status", "unmarked"), "cast_available": not blocked, "cast_guard": "refuses_before_cost" if blocked else "reaction_boundary" if spell.get("casting_time") == "reaction" else "available_gameplay_slice", "declared_effects": [e.get("type", "") for e in spell.get("effects", [])], "has_damage_fields": any(spell.get(k) for k in ("damage", "damage_per_dart", "damage_per_ray")), "known_limit": LIMITS.get(sid, "Full per-spell rules audit remains open; do not infer completeness from fields or check totals."), "evidence": refs})
    register = {"schema_version": 1, "reviewed_on": "2026-10-07", "source_fingerprint": source_fingerprint(), "runtime_registry_hash": runtime["registry_hash"], "scope": "All unique core spell IDs; one row per ID, with actual core-12 casting-class membership. Rules completeness is deliberately uncertified.", "verification_boundary": "Recorded slices refer to historical passing checks. Parsing is restored. The source-owned batch has dedicated effect and live encounter checks; see their evidence paths. Historical slices retain their older evidence and limitations. Availability is exported from the production gate, independently of delivery status. This is not a fresh audit of every SRD clause.", "status_definitions": {"recorded_slice": "Reviewed dated evidence for a working gameplay slice; remaining limitations and full rules audit stay open.", "existing_checks_need_audit": "Existing resolver/class-flow checks, but no reconciled complete spell audit.", "implemented_unverified": "New implementation awaiting a valid Godot gameplay run.", "blocked": "Known incomplete or unsupported behavior; production availability gate refuses before costs.", "unimplemented_exposed": "Known absent core effect still exposed to casting (should remain zero).", "needs_audit": "Loaded/listed; production behavior and rules completeness not yet established."}, "behavior_groups": {k: {"name": v[0], "next_shared_work": v[1]} for k, v in FAMILIES.items()}, "spells": rows}
    register["repair_snapshot_reconciliation"] = {k: v for k, v in target.items() if k != "memberships"}
    for row in rows:
        row["dependency_plan"] = assign_dependencies(spells[row["id"]], row["primary_behavior"])
        if row["id"] == "find_familiar":
            row["dependency_plan"]["clause_checklist"] = [{"audit": "docs/mechanics/find-familiar-2024.md", "scope": "Four-form first version; explicit exclusions retained", "status": "verified_bounded" if familiar_verified else "unverified"}]
        if row["id"] in {"revivify", "gentle_repose"}:
            row["dependency_plan"]["clause_checklist"] = [{"audit": "docs/mechanics/party-recovery-2024.md", "scope": "Party remains/revival first version; explicit exclusions retained", "status": "verified_bounded" if recovery_verified else "unverified"}]
        if row["id"] == "animate_dead":
            row["dependency_plan"]["clause_checklist"] = [{"audit": "docs/mechanics/animate-dead-2024.md", "scope": "Level-3 recorded-remains and persistent Undead first version; explicit exclusions retained", "status": "verified_bounded" if created_verified else "unverified"}]
    validate_dependencies(rows)
    register["capabilities"] = {key: {"wave": value[0], "name": value[1], "status": value[2]} for key, value in CAPABILITIES.items()}
    register["dependency_roadmap"] = "docs/mechanics/spell-foundations.md"
    REGISTER.write_text(json.dumps(register, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    write_report(register)
    return register

def write_report(register: dict) -> None:
    rows = register["spells"]
    counts = Counter(r["delivery_status"] for r in rows)
    lines = ["# Spell delivery status and shared behavior backlog", "", "Reviewed 2026-10-06. The single status register is [spell_status.json](spell_status.json); this report and the spell section of the feature matrix are generated views of it.", "", register["scope"], "", "**No spell is certified fully rules-complete by this reconciliation.** A recorded gameplay slice is useful progress, not a completed SRD audit. The 809-row repair snapshot is a historical missing-membership list, not the current spell denominator. The older canonical artifact has 338 distinct IDs; the loaded registry has 362. Current production class lists contain 898 memberships. Those sets must not be mixed into one completion percentage.", "", "## Current verification boundary", "", register["verification_boundary"], "", f"Production casting currently enables {sum(r['cast_available'] for r in rows)} explicit gameplay slices and refuses {sum(not r['cast_available'] for r in rows)} spell IDs before costs. Availability is not full rules certification. Raw class memberships and existing saves retain the full catalog.", "", "## Status totals", "", "| Delivery status | Unique spells | Meaning |", "|---|---:|---|"]
    for status, meaning in register["status_definitions"].items():
        lines.append(f"| {status} | {counts[status]} | {meaning} |")
    lines += ["", "## Dependency waves", "", "The [current roadmap](../../roadmap.md) controls delivery. The historical [foundation plan](spell-foundations.md) retains capability gaps and wave groupings, not a live execution order. Catalog `dependency_plan` entries retain minimum requirements and exclusions; they do not select implementation work or certify a spell. Foundation status, availability and production evidence remain separate.", "", "| Capability | Wave | Foundation status |", "|---|---:|---|"]
    for capability in register["capabilities"].values():
        lines.append(f"| {capability['name']} | {capability['wave']} | {capability['status']} |")
    target = register["repair_snapshot_reconciliation"]
    lines += ["", f"Repair snapshot reconciliation: {target['membership_rows']} class/spell rows map to {target['unique_resolved_ids']} unique runtime IDs; {len(target['unresolved_names'])} unresolved names and {len(target['missing_class_memberships'])} missing class memberships. Exact unresolved entries, if any, are retained in the register. This checks names/access only."]
    lines += ["", "The delivery status describes evidence; cast availability separately controls whether a character may choose or cast the spell. Unaudited records remain in the inventory and raw class lists, but unavailable IDs are refused before costs. Mending and Invisibility no longer return effectless success.", "", "## Batches by shared behavior", "", "Every spell has one primary planning family. Counts therefore add up without duplicates. Families are inferred from current records and documented gaps; each member still needs its own rule audit. Recorded slices also retain their documented gaps. Secondary requirements (components, timers, saves, persistence) may cross families.", "", "The Recorded slices column counts only `recorded_slice` status. Without recorded-slice status includes `existing_checks_need_audit`: those spells may already be available and have gameplay checks. These columns measure reviewed evidence, not whether a family has any implementation.", "", "| Family | Total IDs | Recorded slices | Without recorded-slice status | Shared next work |", "|---|---:|---:|---:|---|"]
    for key, group in register["behavior_groups"].items():
        members = [r for r in rows if r["primary_behavior"] == key]
        done = sum(r["delivery_status"] == "recorded_slice" for r in members)
        lines.append(f"| {group['name']} | {len(members)} | {done} | {len(members)-done} | {group['next_shared_work']} |")
    lines += [
        "", "## Practical delivery order", "",
        "1. Wave 1 foundations: finish Ashvale's ordinary room/object/item loop, then campaign time and exploration casting. Arcane Lock, Knock, Mage Hand, Mending, item-target and timed-effect integrations have separate cards; later requirements keep them partial/unavailable.",
        "2. Wave 2 foundations: components/equipment, magic items, shared perception, condition consequences and full targeting. Integrate the named spells only after the foundations have gameplay and persistence evidence.",
        "3. Wave 3 foundations: environmental resources/operations, durable areas/barriers and movement modes. Preserve current area trigger caps and concentration cleanup.",
        "4. Wave 4 foundations: owned creatures/commands, bodies/forms and authored NPC/illusion interactions. Expanded forms retain explicit exclusions.",
        "5. Wave 5 foundations: campaign knowledge/messages, destinations/refuges/planes and individually scoped stored triggers/exceptional outcomes. Wish duplication uses completed paths; other outcomes remain unsupported.",
        "", "Finish a wave's supported integrations and explicit dependency deferrals before opening the next wave. Resume class expansion when its specific blockers are resolved. A foundation does not certify its spells.",
        "", "Use the [spell extension guide](../../src/spells/README.md) for implementation homes and cast ordering. [Current checkpoint](../operations/current.md) records the latest validation and known baseline/intermittent failures; focused acceptance does not mean the full suite is green. [Roadmap](../../roadmap.md) owns milestone priorities and the Quest Board owns the exact next action.",
        "", "No wholesale combat extraction, new service, or universal effect language is required. Do not let a safe-refusal check advance a spell into the recorded-playable count.",
        "", "## One row per spell", "", "Class names are actual runtime memberships; an empty list means the spell is outside these eight core casting-class lists. Evidence is retained in JSON. The detailed limitations below override optimistic imported metadata.", "",
    ]
    for key, group in register["behavior_groups"].items():
        lines += [f"### {group['name']}", "", "| Spell ID | Level | Delivery status | Casting | Classes | Known limit / next audit |", "|---|---:|---|---|---|---|"]
        for row in rows:
            if row["primary_behavior"] == key:
                lines.append(f"| `{row['id']}` | {row['level']} | {row['delivery_status']} | {'slice available' if row['cast_available'] else 'unavailable'} | {', '.join(row['classes']) or 'outside core lists'} | {row['known_limit']} |")
        lines.append("")
    lines += ["## Updating the register", "", "Export the initialized production DataLoader by running `res://scenes/spell_inventory_export.tscn` through `scripts/invoke_godot_case.ps1` in Scene mode (the direct `--script` exporter crashes on this Godot 4.7 Windows build). Then run `python scripts/generate_spell_status.py --runtime .artifacts/spell-status/runtime.json`. Update reviewed evidence/limitations in that generator when a slice ships, and regenerate `docs/feature_matrix.md` with its existing generator. Keep runtime exports and logs in ignored `.artifacts/`. Reconciliation never enables a spell or replaces a Godot gameplay check.", ""]
    REPORT.write_text("\n".join(lines), encoding="utf-8")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path, required=True)
    parser.add_argument("--target", type=Path, default=ROOT / ".artifacts/core12-repairs/srd-class-spells.json")
    args = parser.parse_args()
    result = generate(args.runtime, args.target)
    print(f"Reconciled {len(result['spells'])} unique spells: {dict(Counter(r['delivery_status'] for r in result['spells']))}")
