"""Automated round-trip, ordered-steps, 2024 reference, and contract tests for tools/content_editor."""

from __future__ import annotations

import copy
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

EDITOR_ROOT = Path(__file__).resolve().parent
if str(EDITOR_ROOT) not in sys.path:
    sys.path.insert(0, str(EDITOR_ROOT))

from engine import (  # noqa: E402
    CatalogIndex,
    PackWorkspace,
    convert_spell_to_shared,
    diff_records,
    evaluate_record_support,
    prepare_game_pack_record,
    restore_from_exported_record,
    strip_5etools_tags,
)


class ContentEditorRoundTripTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.catalog = CatalogIndex()

    def test_update_route_rejects_mismatched_record_identity(self) -> None:
        from app import make_handler

        with tempfile.TemporaryDirectory() as tmp:
            ws = PackWorkspace("identity_test", workspaces_root=Path(tmp), catalog=self.catalog)
            original = {"id": "identity_test:second", "name": "Second", "execution": "shared", "damage": "2d6"}
            ws.save_draft("spell", original)
            metadata = ws.get_metadata()
            handler_type = make_handler(SimpleNamespace(get_workspace=lambda pack_id: ws))
            handler = handler_type.__new__(handler_type)
            handler.path = "/api/update_draft"
            responses = []
            handler._send_json = lambda payload, status=200: responses.append((status, payload))
            for destination in [original["id"], "identity_test:missing"]:
                handler._read_body_json = lambda: {
                    "content_type": "spell", "record_id": destination,
                    "record": {"id": "identity_test:first", "name": "First", "damage": "1d6"},
                }
                handler.do_POST()
                self.assertEqual(responses[-1][0], 400)
                self.assertEqual(ws.get_draft("spell", original["id"])["record"], original)
                self.assertEqual(ws.get_metadata(), metadata)
                self.assertIsNone(ws.get_draft("spell", "identity_test:missing"))

            handler._read_body_json = lambda: {
                "content_type": "spell", "record_id": original["id"],
                "record": dict(original, name="Renamed"),
            }
            handler.do_POST()
            self.assertEqual(responses[-1][0], 200)
            self.assertEqual(ws.get_draft("spell", original["id"])["record"]["name"], "Renamed")

    def test_catalog_deduplication_and_manifest_merge(self) -> None:
        cure = self.catalog.get_entry("spell", "cure_wounds")
        self.assertIsNotNone(cure)
        assert cure is not None
        self.assertEqual(cure["active_record"].get("execution"), "shared")
        diag = evaluate_record_support("spell", cure["active_record"], self.catalog.contract)
        self.assertEqual(diag["status"], "shared-ready")

        # Verify manifest override deduplication on item with replaced_sources
        alch = self.catalog.get_entry("item", "alchemists_supplies")
        self.assertIsNotNone(alch)
        assert alch is not None
        self.assertEqual(
            alch["winner_coord"], "res://data/core/items/imported_magic_tools.json#2"
        )
        self.assertGreaterEqual(len(alch["replaced_sources"]), 1)

    def test_native_id_bound_and_clone_conversion(self) -> None:
        false_life = self.catalog.get_entry("spell", "false_life")
        self.assertIsNotNone(false_life)
        assert false_life is not None

        orig_diag = evaluate_record_support(
            "spell", false_life["active_record"], self.catalog.contract, is_cloned_homebrew=False
        )
        self.assertEqual(orig_diag["status"], "native-id-bound")
        self.assertTrue(orig_diag["convertible_to_shared"])

        with tempfile.TemporaryDirectory() as tmp:
            ws = PackWorkspace("test_pack", workspaces_root=Path(tmp), catalog=self.catalog)
            cloned = ws.clone_as_homebrew("spell", "false_life", "vitality_shroud", "Vitality Shroud")
            self.assertEqual(cloned["id"], "test_pack:vitality_shroud")
            self.assertEqual(cloned["diagnostics"]["status"], "draft-unsupported")

            converted_rec = convert_spell_to_shared(cloned["record"], self.catalog.contract)
            saved = ws.save_draft("spell", converted_rec, origin=cloned["origin"])
            self.assertEqual(saved["diagnostics"]["status"], "shared-ready")

            renamed = ws.update_draft(
                "spell",
                "test_pack:vitality_shroud",
                {"name": "Renamed Vitality Shroud", "id": "attempted_id_hijack"},
            )
            self.assertEqual(renamed["id"], "test_pack:vitality_shroud")
            self.assertEqual(renamed["record"]["id"], "test_pack:vitality_shroud")
            self.assertEqual(renamed["record"]["name"], "Renamed Vitality Shroud")

    def test_ordered_steps_pipeline_and_source_end_rules_validation(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            ws = PackWorkspace("step_pack", workspaces_root=Path(tmp), catalog=self.catalog)
            draft = ws.create_from_template("spell_ordered_steps", "frost_shard", "Frost Shard")
            self.assertEqual(draft["diagnostics"]["status"], "shared-ready")
            self.assertEqual(draft["diagnostics"]["errors"], [])

            # Mixing top-level attack_type with steps should be flagged
            bad_mix = copy.deepcopy(draft["record"])
            bad_mix["attack_type"] = "ranged_spell"
            bad_diag = evaluate_record_support("spell", bad_mix, self.catalog.contract)
            self.assertEqual(bad_diag["status"], "draft-unsupported")
            self.assertTrue(any("attack_type" in e for e in bad_diag["errors"]))

            # Concentration condition template with repeat_save and source_end_rules
            cond_draft = ws.create_from_template(
                "spell_condition_concentration", "chains_of_dread", "Chains of Dread"
            )
            self.assertEqual(cond_draft["diagnostics"]["status"], "shared-ready")

    def test_lossless_round_trip_and_editor_meta_parking(self) -> None:
        custom_spell = {
            "id": "test_pack:experimental_ray",
            "name": "Experimental Ray",
            "description": "Tests unknown field preservation across top-level, effects, and steps.",
            "execution": "shared",
            "level": 1,
            "school": "evocation",
            "casting_time": "action",
            "range": 12,
            "target": "single",
            "duration": "instantaneous",
            "classes": ["wizard"],
            "future_engine_top_key": {"experimental": True, "tier": 3},
            "steps": [
                {
                    "id": "ray_hit",
                    "type": "attack",
                    "gate": "always",
                    "target": "target",
                    "attack_type": "ranged_spell",
                    "damage": "2d6",
                    "damage_type": "fire",
                    "future_step_annotation": "vfx_beam_gold",
                }
            ],
            "effects": [],
        }

        game_candidate = prepare_game_pack_record("spell", custom_spell, self.catalog.contract)
        self.assertNotIn("future_engine_top_key", game_candidate)
        self.assertNotIn("future_step_annotation", game_candidate["steps"][0])
        self.assertIn("_editor_meta", game_candidate)

        cand_diag = evaluate_record_support("spell", game_candidate, self.catalog.contract)
        self.assertEqual(cand_diag["status"], "shared-ready")
        self.assertEqual(cand_diag["errors"], [])

        restored = restore_from_exported_record(game_candidate)
        self.assertEqual(restored, custom_spell)

    def test_2024_class_reference_comparator_and_field_diff(self) -> None:
        self.assertEqual(
            strip_5etools_tags("Finish a {@variantrule Short Rest|XPHB} to cast {@spell Light|XPHB}."),
            "Finish a Short Rest to cast Light.",
        )
        with tempfile.TemporaryDirectory() as tmp:
            ws = PackWorkspace("audit_pack", workspaces_root=Path(tmp), catalog=self.catalog)
            ws.create_from_template("spell_attack_cantrip", "arcane_lance", "Arcane Lance")
            comp = self.catalog.build_class_comparison("wizard", workspace=ws)
            self.assertIsNotNone(comp)
            assert comp is not None
            self.assertEqual(comp["id"], "wizard")
            self.assertEqual(len(comp["levels"]), 20)
            self.assertGreaterEqual(len(comp["reference_subclasses"]), 4)
            self.assertIn("audit_pack:arcane_lance", comp["pack_spell_additions"])

            # Verify structured diff_records
            cure = self.catalog.get_entry("spell", "cure_wounds")
            assert cure is not None
            modified = copy.deepcopy(cure["active_record"])
            modified["range"] = 6
            rows = diff_records(
                cure["winner_record"],
                cure["replaced_sources"],
                cure["active_record"],
                modified,
            )
            range_row = next(r for r in rows if r["field"] == "range")
            self.assertEqual(range_row["state"], "modified_in_draft")
            self.assertEqual(range_row["draft"], 6)


if __name__ == "__main__":
    unittest.main()
