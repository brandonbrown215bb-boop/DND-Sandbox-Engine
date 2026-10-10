"""Reviewed planning assignments; gameplay evidence never comes from this file."""

CAPABILITIES = {
    "local_spaces": (1, "Authored five-foot room geometry", "bounded_version_verified"),
    "world_objects": (1, "Persistent doors, containers and loose objects", "bounded_version_verified"),
    "item_copies": (1, "Individual owned item copies and transactions", "bounded_version_verified"),
    "campaign_time": (1, "Campaign clock and exploration cast application", "partial"),
    "components_equipment": (2, "Components, focuses, tools, hands and usable supplies", "planned"),
    "magic_items": (2, "Magic item copies, charges, attunement and curses", "planned"),
    "perception": (2, "Shared lighting, sight, cover, senses and sensors", "planned"),
    "conditions": (2, "Complete condition consequences and removable sources", "partial"),
    "target_resolution": (2, "Creature/object targets, multiple areas and damage packets", "partial"),
    "environment": (3, "Environmental operations and quantified food/water", "planned"),
    "persistent_areas": (3, "Durable areas, barriers and boundary entry", "partial"),
    "movement_modes": (3, "Movement modes, elevation, falling and mounts", "partial"),
    "owned_creatures": (4, "Owned creatures, commands and familiar abilities", "partial"),
    "bodies_forms": (4, "Bodies, resurrection eligibility and reversible forms", "partial"),
    "npc_illusions": (4, "Languages, recognition, attitudes and illusion discovery", "planned"),
    "knowledge_messages": (5, "Campaign knowledge and tracked communication", "partial"),
    "destinations_spaces": (5, "Known travel destinations and authored other spaces", "planned"),
    "stored_triggers": (5, "Stored event subscriptions and exceptional outcomes", "planned"),
    "expanded_forms": (4, "Additional transformation forms and target contracts beyond first version", "excluded_first_version"),
    "open_world_operations": (5, "Individually authored exceptional world operations beyond first version", "excluded_first_version"),
}

# These are minimum dependencies to audit, not a proof of all SRD clauses.
FAMILY = {
    "timed_effects": "conditions",
    "control": "conditions movement_modes",
    "persistent_areas": "persistent_areas perception conditions",
    "summons": "owned_creatures movement_modes",
    "visibility": "perception",
    "objects": "world_objects environment",
    "social_illusions": "npc_illusions perception",
    "campaign_information": "knowledge_messages npc_illusions",
    "movement_travel": "movement_modes",
    "body_death": "bodies_forms",
    "wards_removal": "conditions",
    "weapon_riders": "conditions item_copies",
    "exceptional": "stored_triggers",
    "direct_resolution": "target_resolution",
}

EXTRA = {
    "magic_items": "identify detect_magic remove_curse magic_weapon elemental_weapon shillelagh nystuls_magic_aura",
    "world_objects": "arcane_lock knock mage_hand mending light darkness heat_metal shatter thunderwave disintegrate fire_bolt burning_hands fireball freezing_sphere fabricate stone_shape animate_objects instant_summons secret_chest",
    "environment": "prestidigitation druidcraft elementalism thaumaturgy purify_food_and_drink create_or_destroy_water create_food_and_water goodberry fire_bolt burning_hands fireball sleet_storm heroes_feast",
    "perception": "chain_lightning meteor_swarm sunburst protection_from_evil_and_good protection_from_energy",
    "persistent_areas": "alarm glyph_of_warding magic_mouth plant_growth hallucinatory_terrain mirage_arcane programmed_illusion private_sanctum leomunds_tiny_hut",
    "movement_modes": "mage_hand tensers_floating_disk find_steed arcane_eye telekinesis reverse_gravity",
    "owned_creatures": "finger_of_death animate_dead animate_objects find_familiar find_steed beast_sense awaken animal_friendship planar_binding planar_ally simulacrum",
    "bodies_forms": "finger_of_death animate_dead create_undead gentle_repose speak_with_dead revivify regenerate alter_self polymorph",
    "npc_illusions": "charm_person charm_monster animal_friendship speak_with_dead comprehend_languages tongues message sending detect_thoughts geas suggestion mass_suggestion command",
    "knowledge_messages": "speak_with_dead locate_object locate_creature locate_animals_or_plants find_traps scrying clairvoyance dream project_image mislead",
    "destinations_spaces": "astral_projection banishment demiplane etherealness gate leomunds_tiny_hut magnificent_mansion maze plane_shift private_sanctum rope_trick teleport teleportation_circle transport_via_plants tree_stride wind_walk word_of_recall planar_ally planar_binding find_the_path animal_messenger instant_summons secret_chest",
    "stored_triggers": "glyph_of_warding contingency control_weather time_stop wish magic_mouth symbol programmed_illusion alarm",
    "expanded_forms": "animal_shapes reincarnate shapechange true_polymorph true_resurrection clone magic_jar sequester imprisonment",
    "open_world_operations": "wish control_weather earthquake tsunami storm_of_vengeance mirage_arcane creation fabricate move_earth gate astral_projection simulacrum planar_ally",
}

# Named integrations start in their owner's wave. Later dependencies retain a
# partial/unavailable result and an explicit wait; they do not open another wave.
FIRST_INTEGRATIONS = {
    1: "arcane_lock knock mage_hand mending identify detect_magic detect_evil_and_good detect_poison_and_disease longstrider protection_from_energy",
    2: "remove_curse light dancing_lights darkness darkvision fog_cloud see_invisibility true_seeing arcane_eye charm_person charm_monster protection_from_evil_and_good lesser_restoration greater_restoration sunburst chain_lightning meteor_swarm",
    3: "prestidigitation purify_food_and_drink create_or_destroy_water goodberry fire_bolt burning_hands fireball alarm black_tentacles antilife_shell levitate fly spider_climb water_walk freedom_of_movement find_steed",
    4: "find_familiar animate_dead animate_objects finger_of_death revivify gentle_repose speak_with_dead regenerate alter_self polymorph comprehend_languages tongues message disguise_self minor_illusion silent_image",
    5: "contact_other_plane sending augury divination contingency glyph_of_warding control_weather time_stop wish leomunds_tiny_hut rope_trick banishment",
}


def assign(spell: dict, primary: str) -> dict:
    sid = spell["id"]
    required = set("local_spaces item_copies campaign_time components_equipment target_resolution".split())
    required.update(FAMILY[primary].split())
    for capability, members in EXTRA.items():
        if sid in members.split():
            required.add(capability)
    # Small ordinary object spells don't require all environmental operations.
    if sid in "arcane_lock knock mage_hand mending identify".split():
        required.discard("environment")
    if sid in "comprehend_languages tongues message".split():
        required.discard("knowledge_messages")
    wave = next((wave for wave, members in FIRST_INTEGRATIONS.items() if sid in members.split()), max(CAPABILITIES[key][0] for key in required))
    return {
        "integration_card": f"W{wave}-S-{sid}",
        "integration_wave": wave,
        "assignment_basis": "Minimum family and named-clause dependencies; individual SRD audit remains required.",
        "capability_checklist": [
            {"id": key, "foundation_status": CAPABILITIES[key][2], "spell_integration": "unverified"}
            for key in CAPABILITIES if key in required
        ],
        "later_dependencies": [key for key in CAPABILITIES if key in required and CAPABILITIES[key][0] > wave],
        "excluded_first_version": [key for key in CAPABILITIES if key in required and CAPABILITIES[key][2] == "excluded_first_version"],
        "rules_completion": "uncertified",
        "clause_checklist": [],
    }


def validate(rows: list[dict]) -> None:
    ids = [row["id"] for row in rows]
    assert len(ids) == len(set(ids)), "Duplicate spell IDs"
    assert set(row["primary_behavior"] for row in rows) <= FAMILY.keys()
    for row in rows:
        plan = row["dependency_plan"]
        assert plan["integration_card"] and 1 <= plan["integration_wave"] <= 5
        assert plan["rules_completion"] == "uncertified"
        assert all(item["id"] in CAPABILITIES for item in plan["capability_checklist"])
        assert all(item["spell_integration"] == "unverified" for item in plan["capability_checklist"])
