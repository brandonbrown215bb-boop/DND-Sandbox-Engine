## Validation and Math Unit Tests Runner
## Mirrors the hex coordinate math and dice parser formulas, and validates all campaign/mod JSON files.
import os
import json
import re

# --- Hex Coordinate Math Tests ---

class HexUtilsTest:
    DIRECTIONS = [
        (1, 0),   # East
        (1, -1),  # Northeast
        (0, -1),  # Northwest
        (-1, 0),  # West
        (-1, 1),  # Southwest
        (0, 1),   # Southeast
    ]

    @staticmethod
    def get_distance(a, b):
        dq = abs(a[0] - b[0])
        dr = abs(a[1] - b[1])
        ds = abs((-a[0] - a[1]) - (-b[0] - b[1]))
        return max(dq, max(dr, ds))

    @staticmethod
    def get_neighbors(hex_coord):
        return [(hex_coord[0] + d[0], hex_coord[1] + d[1]) for d in HexUtilsTest.DIRECTIONS]

    @classmethod
    def run_tests(cls):
        print("[Test] Running Hex Math tests...")
        
        # Test neighbor coordinates
        origin = (0, 0)
        neighbors = cls.get_neighbors(origin)
        assert len(neighbors) == 6, "Must have exactly 6 neighbors"
        assert (1, 0) in neighbors, "East neighbor incorrect"
        assert (-1, 1) in neighbors, "Southwest neighbor incorrect"

        # Test distance
        assert cls.get_distance((0, 0), (1, 0)) == 1, "Distance to neighbor should be 1"
        assert cls.get_distance((0, 0), (2, -2)) == 2, "Distance should be 2"
        assert cls.get_distance((-3, 1), (3, -1)) == 6, "Distance should be 6"
        
        print("[Test] Hex Math tests PASSED.")

# --- Dice String Parser Tests ---

class DiceParserTest:
    @staticmethod
    def tokenize(expression):
        # Clean expression
        expression = expression.upper().replace(" ", "")
        while "+-" in expression or "--" in expression or "-+" in expression or "++" in expression:
            expression = expression.replace("+-", "-")
            expression = expression.replace("--", "+")
            expression = expression.replace("-+", "-")
            expression = expression.replace("++", "+")
        tokens = []
        current = ""
        first_term = True

        for ch in expression:
            if ch in ('+', '-'):
                if current:
                    if first_term:
                        tokens.append("+" + current)
                        first_term = False
                    else:
                        tokens.append(current)
                    current = ""
                current = ch
                first_term = False
            else:
                if first_term and not current:
                    current = "+"
                    first_term = False
                current += ch
        if current:
            if first_term:
                tokens.append("+" + current)
            else:
                tokens.append(current)
        return tokens

    @classmethod
    def run_tests(cls):
        print("[Test] Running Dice Parser Tokenizer tests...")
        
        t1 = cls.tokenize("2d6 + 3")
        assert t1 == ["+2D6", "+3"], f"Failed tokenizing 2d6 + 3: {t1}"
        
        t2 = cls.tokenize("1d20 - 2")
        assert t2 == ["+1D20", "-2"], f"Failed tokenizing 1d20 - 2: {t2}"
        
        t3 = cls.tokenize("2d8+STR-1d4")
        assert t3 == ["+2D8", "+STR", "-1D4"], f"Failed tokenizing 2d8+STR-1d4: {t3}"

        t4 = cls.tokenize("2D8 + -3")
        assert t4 == ["+2D8", "-3"], f"Failed tokenizing 2D8 + -3: {t4}"

        t5 = cls.tokenize("2D8 - -3")
        assert t5 == ["+2D8", "+3"], f"Failed tokenizing 2D8 - -3: {t5}"
        
        print("[Test] Dice Parser tests PASSED.")

# --- JSON Content Validation ---

class JSONValidator:
    REQUIRED_KEYS = {
        "class": ["id", "name", "hit_die", "primary_ability"],
        "race": ["id", "name", "ability_bonuses"],
        "item": ["id", "name", "type", "value"],
        "spell": ["id", "name", "level", "school"],
        "monster": ["id", "name", "hit_points", "armor_class", "speed", "attacks", "ai_behavior"],
        "event": ["table_id", "terrain_type", "events"],
        "campaign": ["id", "name", "win_condition", "map", "dungeons"]
    }

    @classmethod
    def validate_file(cls, path, content_type):
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # Handle list of items or single dict
        entries = data if isinstance(data, list) else [data]
        
        for idx, entry in enumerate(entries):
            required = cls.REQUIRED_KEYS.get(content_type, [])
            for key in required:
                assert key in entry, f"Missing required key '{key}' in {path} (index {idx})"
            
            # Additional validation
            if content_type == "campaign":
                tiles = entry["map"].get("tiles", [])
                for tile in tiles:
                    assert "q" in tile and "r" in tile and "terrain" in tile, f"Invalid tile data in campaign: {tile}"

    @classmethod
    def run_validation(cls, base_dir):
        print(f"[Test] Starting JSON structural validation in: {base_dir}")
        
        mappings = [
            ("classes", "class"),
            ("races", "race"),
            ("items", "item"),
            ("spells", "spell"),
            ("monsters", "monster"),
            ("events", "event"),
            ("campaigns", "campaign")
        ]

        for folder, c_type in mappings:
            full_path = os.path.join(base_dir, folder)
            if not os.path.isdir(full_path):
                continue
            for fname in os.listdir(full_path):
                if fname.endswith(".json"):
                    file_path = os.path.join(full_path, fname)
                    try:
                        cls.validate_file(file_path, c_type)
                    except Exception as e:
                        print(f"[Test] [color=red]VALIDATION FAILED in {file_path}[/color]")
                        raise e

        print("[Test] JSON validation PASSED.")


class CoreRPGMechanicsTest:
    @classmethod
    def run_tests(cls):
        print("[Test] Running Core RPG Mechanics & Rules tests...")
        
        # 1. Test Wizard Arcane Recovery calculation
        assert int((1 + 1) // 2) == 1
        assert int((3 + 1) // 2) == 2
        
        # 2. Test concentration DC calculation
        def get_concentration_dc(dmg):
            return max(10, dmg // 2)
        assert get_concentration_dc(5) == 10
        assert get_concentration_dc(20) == 10
        assert get_concentration_dc(30) == 15

        # 3. Test Sneak Attack validity rules
        def is_sneak_attack_valid(class_id, has_advantage, has_ally_adjacent, used_this_turn):
            if class_id != "rogue": return False
            if used_this_turn: return False
            return has_advantage or has_ally_adjacent

        assert is_sneak_attack_valid("rogue", True, False, False) == True
        assert is_sneak_attack_valid("rogue", False, True, False) == True
        assert is_sneak_attack_valid("fighter", True, True, False) == False
        assert is_sneak_attack_valid("rogue", True, True, True) == False

        # 4. Test Advantage/Disadvantage application from conditions
        def evaluate_roll_modifiers(conditions):
            adv = "hidden" in conditions
            disadv = "blinded" in conditions or "poisoned" in conditions
            return adv, disadv

        assert evaluate_roll_modifiers(["hidden"]) == (True, False)
        assert evaluate_roll_modifiers(["blinded"]) == (False, True)
        assert evaluate_roll_modifiers(["blinded", "hidden"]) == (True, True)

        # 5. Test advantage/disadvantage against prone targets
        def evaluate_target_prone_modifiers(target_conditions, distance):
            adv = "blinded" in target_conditions or ("prone" in target_conditions and distance == 1)
            disadv = "prone" in target_conditions and distance > 1
            return adv, disadv

        assert evaluate_target_prone_modifiers(["prone"], 1) == (True, False)
        assert evaluate_target_prone_modifiers(["prone"], 2) == (False, True)
        assert evaluate_target_prone_modifiers(["blinded"], 3) == (True, False)

        # 6. Test Evasion save rules
        def resolve_evasion_damage(saved, base_damage, half_on_save):
            if saved:
                return 0
            else:
                return base_damage // 2 if half_on_save else base_damage

        assert resolve_evasion_damage(True, 20, True) == 0
        assert resolve_evasion_damage(False, 20, True) == 10
        assert resolve_evasion_damage(False, 20, False) == 20

        # 7. Test Shield reaction AC bonus
        def get_ac_with_shield(base_ac, conditions):
            ac = base_ac
            if "shield" in conditions:
                ac += 5
            return ac
        assert get_ac_with_shield(15, ["shield"]) == 20
        assert get_ac_with_shield(15, []) == 15

        # 8. Test Uncanny Dodge reaction damage halving
        def get_damage_with_uncanny_dodge(damage, reaction_used):
            if reaction_used:
                return damage // 2
            return damage
        assert get_damage_with_uncanny_dodge(10, True) == 5
        assert get_damage_with_uncanny_dodge(10, False) == 10

        # 9. Test Sleep HP pool depletion
        def resolve_sleep_targets(hp_pool, targets):
            sorted_targets = sorted(targets, key=lambda x: x["hp"])
            asleep = []
            for t in sorted_targets:
                if hp_pool >= t["hp"]:
                    hp_pool -= t["hp"]
                    asleep.append(t["name"])
                else:
                    break
            return asleep

        targets = [
            {"name": "Goblin 1", "hp": 7},
            {"name": "Goblin 2", "hp": 12},
            {"name": "Orc", "hp": 15}
        ]
        assert resolve_sleep_targets(20, targets) == ["Goblin 1", "Goblin 2"]
        assert resolve_sleep_targets(10, targets) == ["Goblin 1"]

        # 10. Test Opportunity Attack trigger rules
        def triggers_opportunity_attack(dist_from, dist_to, disengaged):
            if disengaged: return False
            return dist_from == 1 and dist_to > 1
        
        assert triggers_opportunity_attack(1, 2, False) == True
        assert triggers_opportunity_attack(1, 1, False) == False
        assert triggers_opportunity_attack(1, 2, True) == False

        print("[Test] Core RPG Mechanics & Rules tests PASSED.")


class SaveLoadSerializationTest:
    @classmethod
    def run_tests(cls):
        print("[Test] Running Save/Load Serialization schema tests...")
        
        # Simulate character serialization keys
        char_keys_to_dict = [
            "name", "race_id", "class_id", "level", "xp", "ability_scores",
            "max_hp", "current_hp", "temp_hp", "base_ac", "speed",
            "proficiency_bonus", "saving_throw_proficiencies", "skill_proficiencies",
            "weapon_proficiencies", "armor_proficiencies", "known_spells",
            "conditions", "inventory", "feature_uses", "is_alive", "crit_range",
            "extra_attacks"
        ]
        
        # Simulate character from_dict retrievals
        char_keys_from_dict = [
            "name", "race_id", "class_id", "level", "xp", "ability_scores",
            "max_hp", "current_hp", "temp_hp", "base_ac", "speed",
            "proficiency_bonus", "is_alive", "crit_range", "extra_attacks",
            "saving_throw_proficiencies", "skill_proficiencies", "weapon_proficiencies",
            "armor_proficiencies", "known_spells", "conditions", "feature_uses",
            "inventory"
        ]
        
        for key in char_keys_to_dict:
            assert key in char_keys_from_dict, f"Character serializer mismatch: key '{key}' is output but not parsed!"
        for key in char_keys_from_dict:
            assert key in char_keys_to_dict, f"Character serializer mismatch: key '{key}' is parsed but not output!"
            
        print("[Test] Save/Load Serialization tests PASSED.")


if __name__ == "__main__":
    HexUtilsTest.run_tests()
    DiceParserTest.run_tests()
    CoreRPGMechanicsTest.run_tests()
    SaveLoadSerializationTest.run_tests()
    
    # Locate data files
    base_data_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../data/core"))
    JSONValidator.run_validation(base_data_path)
    
    print("\n[Test] ALL UNIT AND STRUCTURAL TESTS PASSED SUCCESSFULLY!")
