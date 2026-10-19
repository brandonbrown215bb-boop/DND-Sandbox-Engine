"""Core catalog, validation, draft workspace, 2024 reference comparator, and pack export engine.

Strictly read-only against repository game source/data (`data/core/`, `data/content_manifest.json`,
`reference/2024/`). All mutable workspaces and exports live under `tools/content_editor/`.
"""

from __future__ import annotations

import copy
import json
import re
from pathlib import Path
from typing import Any


EDITOR_ROOT = Path(__file__).resolve().parent
REPO_ROOT = EDITOR_ROOT.parent.parent
CONTRACT_PATH = EDITOR_ROOT / "contracts" / "pinned_vs83_2026_10_18.json"
DEFAULT_WORKSPACES_DIR = EDITOR_ROOT / "workspaces"
DEFAULT_EXPORTS_DIR = EDITOR_ROOT / "exports"

CONTENT_TYPE_DIRS = {
    "spell": "spells",
    "item": "items",
    "class": "classes",
    "subclass": "subclasses",
    "race": "races",
    "monster": "monsters",
    "event": "events",
    "campaign": "campaigns",
}

DURATION_TEXT_TO_SECONDS = {
    "instantaneous": None,
    "1 round": 6,
    "1 minute": 60,
    "10 minutes": 600,
    "1 hour": 3600,
    "8 hours": 28800,
    "24 hours": 86400,
}

FORMULA_RE = re.compile(r"^([0-9]{1,3}|[1-9][0-9]?d(4|6|8|10|12|20))([+][0-9]{1,3})?$")
DICE_ONLY_RE = re.compile(r"^[1-9][0-9]?d(4|6|8|10|12|20)$")
SLUG_RE = re.compile(r"[^a-z0-9_]+")
TAG_5ETOOLS_RE = re.compile(r"\{@[a-zA-Z0-9_]+\s+([^|}]+)(?:\|[^}]*)?\}")


TEMPLATES: dict[str, dict[str, Any]] = {
    "spell_attack_cantrip": {
        "id": "spell_attack_cantrip",
        "content_type": "spell",
        "label": "Attack Cantrip (Shared)",
        "category": "Spell — Flat Delivery",
        "description": "Ranged spell attack cantrip with automatic cantrip scaling at levels 5, 11, and 17.",
        "record": {
            "id": "custom:arcane_lance",
            "name": "Arcane Lance",
            "description": "Hurl a lance of raw force at one target within range.",
            "execution": "shared",
            "level": 0,
            "school": "evocation",
            "casting_time": "action",
            "range": 12,
            "target": "single",
            "attack_type": "ranged_spell",
            "damage": "1d10",
            "damage_type": "force",
            "duration": "instantaneous",
            "concentration": False,
            "ritual": False,
            "components": ["V", "S"],
            "classes": ["wizard", "sorcerer", "warlock"],
            "scaling": {"5": "2d10", "11": "3d10", "17": "4d10"},
            "effects": [],
        },
    },
    "spell_aoe_save": {
        "id": "spell_aoe_save",
        "content_type": "spell",
        "label": "Sphere AoE Save Spell (Shared)",
        "category": "Spell — Flat Delivery",
        "description": "Leveled area-of-effect spell with a saving throw, half damage on save, and slot upcasting.",
        "record": {
            "id": "custom:cinder_burst",
            "name": "Cinder Burst",
            "description": "A detonation of ash and flame erupts in a 15-foot sphere.",
            "execution": "shared",
            "level": 3,
            "school": "evocation",
            "casting_time": "action",
            "range": 18,
            "target": "area",
            "area_radius": 3,
            "attack_type": "none",
            "save": "DEX",
            "half_on_save": True,
            "damage": "6d6",
            "damage_type": "fire",
            "duration": "instantaneous",
            "concentration": False,
            "ritual": False,
            "components": ["V", "S", "M"],
            "material": "a pinch of sulfur",
            "classes": ["wizard", "sorcerer"],
            "upcast": {"damage_per_level": "1d6"},
            "effects": [
                {"type": "area_selection", "shape": "sphere", "radius": 3}
            ],
        },
    },
    "spell_condition_concentration": {
        "id": "spell_condition_concentration",
        "content_type": "spell",
        "label": "Concentration Condition + Repeat Save",
        "category": "Spell — Lifetimes & Stages",
        "description": "Applies a timed condition on a failed save with end-of-turn repeat saves and source-end rules.",
        "record": {
            "id": "custom:chains_of_dread",
            "name": "Chains of Dread",
            "description": "Spectral chains bind a creature on a failed Wisdom save until it shakes off the terror.",
            "execution": "shared",
            "level": 2,
            "school": "enchantment",
            "casting_time": "action",
            "range": 12,
            "target": "single",
            "attack_type": "none",
            "save": "WIS",
            "half_on_save": False,
            "duration": "1 minute",
            "duration_seconds": 60,
            "concentration": True,
            "repeat_save": True,
            "repeat_save_schedule": "end_of_turn",
            "components": ["V", "S"],
            "classes": ["warlock", "wizard", "bard"],
            "effects": [
                {
                    "type": "grant_condition",
                    "condition": "frightened",
                    "on_failed_save": True,
                }
            ],
            "source_end_rules": [
                {"event": "damage", "actor": "recipient", "except_source_id": "this_source"}
            ],
        },
    },
    "spell_ordered_steps": {
        "id": "spell_ordered_steps",
        "content_type": "spell",
        "label": "Multi-Step Ordered Spell (ADR-0019)",
        "category": "Spell — Ordered Steps Pipeline",
        "description": "Executes an initial ranged spell attack followed by an area saving throw step (like Ice Knife).",
        "record": {
            "id": "custom:frost_shard",
            "name": "Frost Shard",
            "description": "Fling a shard of lancing ice at a target. Hit or miss, the shard shatters in a 5-foot burst.",
            "execution": "shared",
            "level": 1,
            "school": "conjuration",
            "casting_time": "action",
            "range": 12,
            "target": "single",
            "duration": "instantaneous",
            "concentration": False,
            "components": ["S", "M"],
            "material": "a drop of water or piece of ice",
            "classes": ["druid", "sorcerer", "wizard"],
            "steps": [
                {
                    "id": "shard_attack",
                    "type": "attack",
                    "gate": "always",
                    "target": "target",
                    "attack_type": "ranged_spell",
                    "damage": "1d10",
                    "damage_type": "piercing",
                },
                {
                    "id": "burst_save",
                    "type": "save",
                    "gate": "always",
                    "target": "area",
                    "shape": "sphere",
                    "radius": 1,
                    "save": "DEX",
                    "half_on_save": False,
                    "damage": "2d6",
                    "damage_type": "cold",
                    "upcast": {"damage_per_level": "1d6"},
                },
            ],
            "effects": [],
        },
    },
    "spell_source_benefit_buff": {
        "id": "spell_source_benefit_buff",
        "content_type": "spell",
        "label": "Source-Benefit Buff Spell (+AC / +Speed)",
        "category": "Spell — Source Benefits",
        "description": "Grants live AC and walking speed bonuses via the shared source-benefit carrier contract.",
        "record": {
            "id": "custom:aegis_stride",
            "name": "Aegis Stride",
            "description": "Sheathe a willing creature in a shimmering wind that bolsters defense and footwork.",
            "execution": "shared",
            "level": 1,
            "school": "abjuration",
            "casting_time": "bonus_action",
            "range": 12,
            "target": "single",
            "attack_type": "none",
            "duration": "10 minutes",
            "duration_seconds": 600,
            "concentration": True,
            "components": ["V", "S"],
            "classes": ["cleric", "paladin", "ranger"],
            "effects": [
                {
                    "type": "grant_source_benefits",
                    "benefits": [
                        {"stat": "AC", "amount": 2},
                        {"stat": "speed", "amount": 2},
                    ],
                }
            ],
        },
    },
    "item_magic_weapon": {
        "id": "item_magic_weapon",
        "content_type": "item",
        "label": "Magic Weapon (+AC / Speed Carrier)",
        "category": "Item — Weapon",
        "description": "Equippable melee weapon with weapon properties and optional passive source_benefits.",
        "record": {
            "id": "custom:sunblade_rapier",
            "name": "Sunblade Rapier",
            "type": "weapon",
            "weapon_type": "martial_melee",
            "rarity": "rare",
            "ability": "DEX",
            "damage": "1d8",
            "damage_type": "radiant",
            "range": 1,
            "properties": ["finesse", "light"],
            "value": 500,
            "weight": 2.0,
            "description": "A slender hilt that projects a blade of golden sunlight while wielded.",
            "source_benefits": [{"stat": "AC", "amount": 1}],
            "starting_equipment_classes": ["rogue", "bard", "fighter"],
        },
    },
    "item_source_benefit_ring": {
        "id": "item_source_benefit_ring",
        "content_type": "item",
        "label": "Source-Benefit Ring (+AC / +Speed)",
        "category": "Item — Ring / Carrier",
        "description": "Batch L passive stat carrier granting AC and walking speed while equipped.",
        "record": {
            "id": "custom:signet_of_zephyrs",
            "name": "Signet of Zephyrs",
            "type": "ring",
            "rarity": "uncommon",
            "value": 250,
            "weight": 0.1,
            "description": "Carved from pale cloudstone; grants +1 AC and +10 ft (+2 hexes) walking speed.",
            "source_benefits": [
                {"stat": "AC", "amount": 1},
                {"stat": "speed", "amount": 2},
            ],
            "starting_equipment_classes": ["monk", "ranger", "wizard"],
        },
    },
    "item_spell_wand": {
        "id": "item_spell_wand",
        "content_type": "item",
        "label": "Spell-Permission Wand (Charges)",
        "category": "Item — Wand / Spell Carrier",
        "description": "Batch 021 wand granting spell_permissions with a charge pool while equipped.",
        "record": {
            "id": "custom:wand_of_cinders",
            "name": "Wand of Cinders",
            "type": "wand",
            "rarity": "uncommon",
            "value": 300,
            "weight": 1.0,
            "description": "Charred ironwood wand that grants access to fire spells using charges.",
            "spell_permissions": [
                {
                    "spells": ["burning_hands", "scorching_ray"],
                    "ability": "INT",
                    "charges": 5,
                    "maximum_charges": 5,
                    "charge_recovery": "1d4+1",
                }
            ],
            "starting_equipment_classes": ["wizard", "sorcerer"],
        },
    },
    "item_healing_consumable": {
        "id": "item_healing_consumable",
        "content_type": "item",
        "label": "Healing & Cure Elixirs (Consumable)",
        "category": "Item — Consumable",
        "description": "Single-use consumable that restores HP and removes a condition.",
        "record": {
            "id": "custom:draught_of_clarity",
            "name": "Draught of Clarity",
            "type": "consumable",
            "rarity": "common",
            "value": 75,
            "weight": 0.5,
            "description": "Restores 2d4+2 HP and clears the poisoned condition.",
            "effects": [
                {"type": "heal", "value": "2d4+2"},
                {"type": "remove_condition", "condition": "poisoned"},
            ],
            "starting_equipment_classes": ["cleric", "fighter", "rogue"],
        },
    },
}


def load_pinned_contract() -> dict[str, Any]:
    with CONTRACT_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def slugify_id(text: str) -> str:
    cleaned = SLUG_RE.sub("_", text.strip().lower()).strip("_")
    return cleaned or "custom_entry"


def make_namespaced_id(pack_id: str, slug_or_name: str) -> str:
    pack_slug = slugify_id(pack_id)
    if ":" in slug_or_name:
        prefix, rest = slug_or_name.split(":", 1)
        if slugify_id(prefix) == pack_slug and rest.strip():
            return f"{pack_slug}:{slugify_id(rest)}"
    return f"{pack_slug}:{slugify_id(slug_or_name)}"


def strip_5etools_tags(text: str) -> str:
    """Converts 5etools tags like {@variantrule Short Rest|XPHB} into plain readable text."""
    return TAG_5ETOOLS_RE.sub(r"\1", str(text))


def flatten_2024_entries(entries: Any) -> list[str]:
    """Recursively flattens 2024 reference `entries` arrays into readable paragraphs."""
    paragraphs: list[str] = []
    if isinstance(entries, str):
        paragraphs.append(strip_5etools_tags(entries))
    elif isinstance(entries, list):
        for item in entries:
            paragraphs.extend(flatten_2024_entries(item))
    elif isinstance(entries, dict):
        header = str(entries.get("name", "")).strip()
        sub = flatten_2024_entries(entries.get("entries", entries.get("items", [])))
        if header and sub:
            paragraphs.append(f"{strip_5etools_tags(header)}: {sub[0]}")
            paragraphs.extend(sub[1:])
        elif header:
            paragraphs.append(strip_5etools_tags(header))
        else:
            paragraphs.extend(sub)
    return [p for p in paragraphs if p.strip()]


def _is_int_in_range(value: Any, minimum: int, maximum: int) -> bool:
    if isinstance(value, bool):
        return False
    if isinstance(value, int):
        return minimum <= value <= maximum
    if isinstance(value, float) and value.is_integer():
        return minimum <= int(value) <= maximum
    return False


def _is_valid_formula(value: Any) -> bool:
    if _is_int_in_range(value, 0, 999):
        return True
    if isinstance(value, dict):
        # Structured formula object (e.g. paid_slot_level / spellcasting_modifier)
        return bool(value)
    if not isinstance(value, str):
        return False
    compact = value.replace(" ", "")
    return FORMULA_RE.match(compact) is not None


def _is_valid_dice_formula(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    return DICE_ONLY_RE.match(value.replace(" ", "")) is not None


def merge_missing_fields(winner: dict[str, Any], fallback: dict[str, Any]) -> dict[str, Any]:
    """Replicates DataLoader._merge_missing_fields without mutating inputs."""
    merged = copy.deepcopy(winner)
    for key, value in fallback.items():
        if key not in merged or key in ("_source", "_source_record"):
            merged[key] = copy.deepcopy(value)
    return merged


def diff_records(
    winner_record: dict[str, Any] | None,
    replaced_sources: list[dict[str, Any]],
    active_record: dict[str, Any] | None,
    draft_record: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Computes a structured field-by-field diff across Winner, Replaced Fallback(s), Merged Active, and Draft."""
    winner = winner_record or {}
    active = active_record or {}
    draft = draft_record if draft_record is not None else active
    fallback_merged: dict[str, Any] = {}
    for rep in replaced_sources:
        rec = rep.get("record", {})
        if isinstance(rec, dict):
            for k, v in rec.items():
                if k not in fallback_merged:
                    fallback_merged[k] = v

    all_keys = sorted(
        set(winner.keys()) | set(fallback_merged.keys()) | set(active.keys()) | set(draft.keys())
    )
    rows: list[dict[str, Any]] = []
    for key in all_keys:
        if key in ("_source", "_source_record"):
            continue
        w_val = winner.get(key, None)
        f_val = fallback_merged.get(key, None)
        a_val = active.get(key, None)
        d_val = draft.get(key, None)

        state = "unchanged"
        if draft_record is not None and d_val != a_val:
            state = "modified_in_draft"
        elif key not in winner and key in fallback_merged:
            state = "backfilled_from_fallback"
        elif replaced_sources and w_val != f_val and key in fallback_merged:
            state = "overridden_by_winner"

        rows.append(
            {
                "field": key,
                "state": state,
                "winner": w_val,
                "fallback": f_val,
                "active": a_val,
                "draft": d_val,
            }
        )
    return rows


class CatalogIndex:
    """Read-only index over data/core, data/content_manifest.json, and reference/2024."""

    def __init__(self, repo_root: Path = REPO_ROOT) -> None:
        self.repo_root = repo_root
        self.contract = load_pinned_contract()
        self.manifest = self._read_manifest()
        self.records_by_type: dict[str, dict[str, dict[str, Any]]] = {
            ctype: {} for ctype in CONTENT_TYPE_DIRS
        }
        self._load_all()

    def _read_manifest(self) -> dict[str, Any]:
        manifest_path = self.repo_root / "data" / "content_manifest.json"
        if not manifest_path.exists():
            return {"overrides": [], "packs": [], "layers": []}
        with manifest_path.open("r", encoding="utf-8") as handle:
            return json.load(handle)

    def _find_override(
        self, content_type: str, record_id: str, existing_coord: str, candidate_coord: str
    ) -> dict[str, Any] | None:
        for entry in self.manifest.get("overrides", []):
            if (
                isinstance(entry, dict)
                and str(entry.get("type", "")) == content_type
                and str(entry.get("id", "")) == record_id
            ):
                replaces = entry.get("replaces", [])
                winner = str(entry.get("winner", ""))
                if winner in (existing_coord, candidate_coord) and (
                    existing_coord in replaces or candidate_coord in replaces
                ):
                    return entry
        return None

    def _load_all(self) -> None:
        core_root = self.repo_root / "data" / "core"
        for content_type, folder_name in CONTENT_TYPE_DIRS.items():
            dir_path = core_root / folder_name
            if not dir_path.exists():
                continue
            for file_path in sorted(dir_path.glob("*.json"), key=lambda p: p.name):
                self._load_json_file(file_path, content_type)
        self._attach_curated_class_spell_lists()
        self._attach_reference_2024()

    def _load_json_file(self, file_path: Path, content_type: str) -> None:
        rel_res = "res://" + file_path.relative_to(self.repo_root).as_posix()
        with file_path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        entries: list[tuple[int, dict[str, Any]]] = []
        if isinstance(data, dict):
            entries.append((1, data))
        elif isinstance(data, list):
            for idx, item in enumerate(data, start=1):
                if isinstance(item, dict):
                    entries.append((idx, item))
        for idx, raw_entry in entries:
            record_id = str(raw_entry.get("id", raw_entry.get("table_id", "")))
            if not record_id:
                continue
            coord = f"{rel_res}#{idx}"
            bucket = self.records_by_type[content_type]
            if record_id not in bucket:
                bucket[record_id] = {
                    "id": record_id,
                    "content_type": content_type,
                    "active_record": copy.deepcopy(raw_entry),
                    "winner_coord": coord,
                    "winner_record": copy.deepcopy(raw_entry),
                    "replaced_sources": [],
                    "reference_2024": None,
                }
            else:
                existing = bucket[record_id]
                existing_coord = existing["winner_coord"]
                override = self._find_override(content_type, record_id, existing_coord, coord)
                if override is not None:
                    winner_coord = str(override.get("winner", ""))
                    if coord == winner_coord:
                        merged = merge_missing_fields(raw_entry, existing["active_record"])
                        existing["replaced_sources"].append(
                            {
                                "coord": existing_coord,
                                "record": copy.deepcopy(existing["winner_record"]),
                            }
                        )
                        existing["winner_coord"] = coord
                        existing["winner_record"] = copy.deepcopy(raw_entry)
                        existing["active_record"] = merged
                    else:
                        merged = merge_missing_fields(existing["active_record"], raw_entry)
                        existing["replaced_sources"].append(
                            {"coord": coord, "record": copy.deepcopy(raw_entry)}
                        )
                        existing["active_record"] = merged
                else:
                    existing["replaced_sources"].append(
                        {"coord": coord, "record": copy.deepcopy(raw_entry)}
                    )

    def _attach_curated_class_spell_lists(self) -> None:
        """Populates inferred class membership on spells when class spell_list_ids exist."""
        spell_to_classes: dict[str, list[str]] = {}
        for class_id, class_entry in self.records_by_type.get("class", {}).items():
            class_rec = class_entry["active_record"]
            for spell_id in class_rec.get("spell_list_ids", []):
                spell_to_classes.setdefault(str(spell_id), [])
                if class_id not in spell_to_classes[str(spell_id)]:
                    spell_to_classes[str(spell_id)].append(class_id)
        for spell_id, spell_entry in self.records_by_type.get("spell", {}).items():
            active = spell_entry["active_record"]
            if "classes" not in active and spell_id in spell_to_classes:
                active["classes"] = sorted(spell_to_classes[spell_id])

    def _attach_reference_2024(self) -> None:
        ref_classes_dir = self.repo_root / "reference" / "2024" / "classes"
        if not ref_classes_dir.exists():
            return
        for ref_file in sorted(ref_classes_dir.glob("*.json")):
            class_id = ref_file.stem.lower()
            try:
                with ref_file.open("r", encoding="utf-8") as handle:
                    ref_data = json.load(handle)
            except Exception:
                continue
            if class_id not in self.records_by_type.get("class", {}):
                continue

            parsed_ref = self._parse_2024_class_file(ref_file.name, ref_data)
            self.records_by_type["class"][class_id]["reference_2024"] = parsed_ref

    def _parse_2024_class_file(self, filename: str, ref_data: Any) -> dict[str, Any]:
        if not isinstance(ref_data, dict):
            return {"path": f"reference/2024/classes/{filename}", "subclasses": [], "features_by_level": {}}

        class_arr = ref_data.get("class", [])
        class_header = class_arr[0] if isinstance(class_arr, list) and class_arr else {}

        subclasses: list[dict[str, Any]] = []
        for sc in ref_data.get("subclass", []):
            if not isinstance(sc, dict):
                continue
            subclasses.append(
                {
                    "name": str(sc.get("name", "")),
                    "short_name": str(sc.get("shortName", sc.get("name", ""))),
                    "source": str(sc.get("source", "XPHB")),
                    "srd52": bool(sc.get("srd52", False)),
                }
            )

        features_by_level: dict[str, list[dict[str, Any]]] = {str(lvl): [] for lvl in range(1, 21)}
        for feat in ref_data.get("classFeature", []):
            if not isinstance(feat, dict):
                continue
            lvl = int(feat.get("level", 1))
            lvl_key = str(max(1, min(20, lvl)))
            features_by_level.setdefault(lvl_key, []).append(
                {
                    "name": str(feat.get("name", "")),
                    "level": lvl,
                    "srd52": bool(feat.get("srd52", False)),
                    "source": str(feat.get("source", "XPHB")),
                    "paragraphs": flatten_2024_entries(feat.get("entries", [])),
                }
            )

        subclass_features: list[dict[str, Any]] = []
        for sfeat in ref_data.get("subclassFeature", []):
            if not isinstance(sfeat, dict):
                continue
            subclass_features.append(
                {
                    "name": str(sfeat.get("name", "")),
                    "subclass_short_name": str(sfeat.get("subclassShortName", "")),
                    "level": int(sfeat.get("level", 3)),
                    "srd52": bool(sfeat.get("srd52", False)),
                    "paragraphs": flatten_2024_entries(sfeat.get("entries", []))[:4],
                }
            )

        return {
            "path": f"reference/2024/classes/{filename}",
            "edition": str(class_header.get("edition", "one")),
            "caster_progression": str(class_header.get("casterProgression", "none")),
            "spellcasting_ability": str(class_header.get("spellcastingAbility", "")).upper(),
            "prepared_progression": class_header.get("preparedSpellsProgression", []),
            "cantrip_progression": class_header.get("cantripProgression", []),
            "subclasses": subclasses,
            "features_by_level": features_by_level,
            "subclass_features": subclass_features,
            "summary": {
                "subclass_count": len(subclasses),
                "class_feature_count": sum(len(v) for v in features_by_level.values()),
                "srd_subclasses": [s["name"] for s in subclasses if s["srd52"]],
            },
        }

    def build_class_comparison(
        self, class_id: str, workspace: "PackWorkspace | None" = None
    ) -> dict[str, Any] | None:
        """Builds a Level 1-20 progression & spell-list audit comparing core class JSON vs 2024 Reference."""
        entry = self.get_entry("class", class_id)
        if entry is None:
            return None
        core = entry["active_record"]
        ref = entry.get("reference_2024") or {}
        core_feats_by_lvl = core.get("features_by_level", {}) if isinstance(core.get("features_by_level"), dict) else {}
        ref_feats_by_lvl = ref.get("features_by_level", {}) if isinstance(ref.get("features_by_level"), dict) else {}

        levels: list[dict[str, Any]] = []
        total_core_enabled = 0
        total_core_quarantined = 0
        for lvl in range(1, 21):
            lkey = str(lvl)
            c_list = core_feats_by_lvl.get(lkey, [])
            r_list = ref_feats_by_lvl.get(lkey, [])
            formatted_core: list[dict[str, Any]] = []
            for cf in (c_list if isinstance(c_list, list) else []):
                if not isinstance(cf, dict):
                    continue
                enabled = bool(cf.get("enabled", True))
                effects = cf.get("effects", []) if isinstance(cf.get("effects"), list) else []
                if enabled and effects:
                    total_core_enabled += 1
                    support_state = "enabled"
                elif enabled and not effects:
                    total_core_quarantined += 1
                    support_state = "enabled_no_effects"
                else:
                    total_core_quarantined += 1
                    support_state = "quarantined"
                formatted_core.append(
                    {
                        "id": str(cf.get("id", "")),
                        "name": str(cf.get("name", "")),
                        "description": str(cf.get("description", "")),
                        "type": str(cf.get("type", "passive")),
                        "enabled": enabled,
                        "rules_status": str(cf.get("rules_status", "")),
                        "effect_types": [
                            str(e.get("type", "")) for e in effects if isinstance(e, dict)
                        ],
                        "support_state": support_state,
                    }
                )
            levels.append(
                {
                    "level": lvl,
                    "core_features": formatted_core,
                    "reference_features": r_list if isinstance(r_list, list) else [],
                }
            )

        # Audit spell_list_ids on this class
        curated_spells = [str(s) for s in core.get("spell_list_ids", [])]
        spell_counts = {"shared-ready": 0, "native-id-bound": 0, "draft-unsupported": 0}
        for sid in curated_spells:
            sp_entry = self.get_entry("spell", sid)
            if sp_entry is not None:
                st = evaluate_record_support("spell", sp_entry["active_record"], self.contract)["status"]
                spell_counts[st] = spell_counts.get(st, 0) + 1

        pack_spell_additions: list[str] = []
        pack_equipment_additions: list[str] = []
        if workspace is not None:
            for d in workspace.list_drafts():
                if d["content_type"] == "spell" and class_id in [
                    str(c).lower() for c in d["record"].get("classes", [])
                ]:
                    pack_spell_additions.append(d["id"])
                elif d["content_type"] == "item" and class_id in [
                    str(c).lower() for c in d["record"].get("starting_equipment_classes", [])
                ]:
                    pack_equipment_additions.append(d["id"])

        return {
            "id": class_id,
            "name": str(core.get("name", class_id.title())),
            "hit_die": str(core.get("hit_die", "")),
            "primary_ability": str(core.get("primary_ability", "")),
            "saving_throw_proficiencies": core.get("saving_throw_proficiencies", []),
            "starting_equipment": core.get("starting_equipment", []),
            "curated_spell_count": len(curated_spells),
            "curated_spell_breakdown": spell_counts,
            "core_enabled_features": total_core_enabled,
            "core_quarantined_features": total_core_quarantined,
            "reference_path": ref.get("path"),
            "reference_subclasses": ref.get("subclasses", []),
            "reference_subclass_features": ref.get("subclass_features", []),
            "levels": levels,
            "pack_spell_additions": pack_spell_additions,
            "pack_equipment_additions": pack_equipment_additions,
        }

    def get_entry(self, content_type: str, record_id: str) -> dict[str, Any] | None:
        return self.records_by_type.get(content_type, {}).get(record_id)

    def list_entries(
        self,
        content_type: str,
        search: str = "",
        status_filter: str = "",
    ) -> list[dict[str, Any]]:
        bucket = self.records_by_type.get(content_type, {})
        query = search.strip().lower()
        results: list[dict[str, Any]] = []
        for record_id in sorted(bucket.keys()):
            entry = bucket[record_id]
            active = entry["active_record"]
            name = str(active.get("name", record_id))
            if query and query not in record_id.lower() and query not in name.lower():
                continue
            diag = evaluate_record_support(content_type, active, self.contract)
            if status_filter and diag["status"] != status_filter:
                continue
            results.append(
                {
                    "id": record_id,
                    "name": name,
                    "content_type": content_type,
                    "winner_coord": entry["winner_coord"],
                    "replaced_count": len(entry["replaced_sources"]),
                    "has_reference_2024": entry["reference_2024"] is not None,
                    "status": diag["status"],
                    "status_label": diag["status_label"],
                    "summary": _summarize_record(content_type, active),
                }
            )
        return results


def _summarize_record(content_type: str, record: dict[str, Any]) -> str:
    if content_type == "spell":
        lvl = record.get("level", 0)
        school = record.get("school", "")
        rng = record.get("range", 0)
        feet = int(rng) * 5 if isinstance(rng, (int, float)) else "?"
        mode = "Steps" if "steps" in record else "Flat"
        return f"Lvl {lvl} {school} · {rng} hex ({feet} ft) · {mode}"
    if content_type == "item":
        itype = record.get("type", "unknown")
        rarity = record.get("rarity", "standard")
        extras = []
        if record.get("source_benefits"):
            extras.append("source_benefits")
        if record.get("spell_permissions"):
            extras.append("spell_permissions")
        suffix = f" · {' + '.join(extras)}" if extras else ""
        return f"{itype} ({rarity}){suffix}"
    if content_type == "class":
        hd = record.get("hit_die", "")
        prim = record.get("primary_ability", "")
        spells = len(record.get("spell_list_ids", []))
        return f"Hit Die {hd} · Primary {prim} · {spells} spells"
    return str(record.get("description", ""))[:80]


def evaluate_record_support(
    content_type: str,
    record: dict[str, Any],
    contract: dict[str, Any] | None = None,
    is_cloned_homebrew: bool = False,
) -> dict[str, Any]:
    """Evaluates a record against the pinned VS-83 editor contract without faking runtime proof."""
    if contract is None:
        contract = load_pinned_contract()

    if content_type == "spell":
        return _evaluate_spell_support(record, contract, is_cloned_homebrew=is_cloned_homebrew)
    if content_type == "item":
        return _evaluate_item_support(record, contract)
    if content_type == "class":
        feats = record.get("features_by_level", {})
        enabled_count = 0
        quarantined_count = 0
        if isinstance(feats, dict):
            for flist in feats.values():
                if isinstance(flist, list):
                    for f in flist:
                        if isinstance(f, dict):
                            if f.get("enabled", True) and f.get("effects"):
                                enabled_count += 1
                            else:
                                quarantined_count += 1
        return {
            "status": "staged-reference",
            "status_label": f"2024 Reference Audit ({enabled_count} Active / {quarantined_count} Quarantined)",
            "contract_revision": contract.get("revision", ""),
            "errors": [],
            "warnings": [
                "Class records are read-only in the pack workbench; use 'classes' on spells and 'starting_equipment_classes' on items to emit composable pack.json additions."
            ],
            "unknown_fields": [],
            "unit_warnings": [],
            "convertible_to_shared": False,
        }
    return {
        "status": "staged-reference",
        "status_label": "Staged / Browse Only",
        "contract_revision": contract.get("revision", ""),
        "errors": [],
        "warnings": [
            f"Guided authoring focuses on spells and items; '{content_type}' is read-only reference in this pass."
        ],
        "unknown_fields": [],
        "unit_warnings": [],
        "convertible_to_shared": False,
    }


def _validate_effect_list(
    effects: Any,
    sc: dict[str, Any],
    path_prefix: str = "effects",
) -> tuple[list[str], bool, int, list[str]]:
    """Validates a list of shared effects. Returns (blockers, has_condition_or_benefit, area_count, unknown_nested)."""
    blockers: list[str] = []
    unknown_nested: list[str] = []
    has_condition_or_benefit = False
    area_count = 0
    allowed_effects = set(sc["effects"])
    allowed_conditions = set(sc["conditions"])

    if not isinstance(effects, list):
        blockers.append(f"{path_prefix} must be an array.")
        return blockers, False, 0, unknown_nested

    for idx, eff in enumerate(effects):
        if not isinstance(eff, dict):
            blockers.append(f"{path_prefix}[{idx}] must be an object.")
            continue
        eff_type = str(eff.get("type", ""))
        if eff_type not in allowed_effects:
            blockers.append(
                f"Effect '{eff_type}' at {path_prefix}[{idx}] is not a supported shared operation ({', '.join(sc['effects'])})."
            )
            continue
        allowed_eff_keys = {"type", "on_spell_hit", "on_failed_save", "rider_by_outcome", "when"}
        if eff_type in ("heal", "temporary_hp"):
            allowed_eff_keys.update({"value", "ability_bonus_from_caster"})
            if not _is_valid_formula(eff.get("value")):
                blockers.append(f"{path_prefix}[{idx}] ({eff_type}) requires a valid formula or integer value.")
        elif eff_type in ("grant_condition", "remove_condition"):
            allowed_eff_keys.add("condition")
            cond = str(eff.get("condition", ""))
            if cond not in allowed_conditions:
                blockers.append(
                    f"Condition '{cond}' at {path_prefix}[{idx}] is not in supported shared conditions."
                )
            if eff_type == "grant_condition":
                has_condition_or_benefit = True
        elif eff_type == "grant_source_benefits":
            allowed_eff_keys.add("benefits")
            has_condition_or_benefit = True
            benefits = eff.get("benefits")
            if not isinstance(benefits, list) or not benefits:
                blockers.append(f"{path_prefix}[{idx}] (grant_source_benefits) requires a non-empty benefits array.")
            else:
                seen_stats: set[str] = set()
                for b_idx, b in enumerate(benefits):
                    if not isinstance(b, dict) or set(b.keys()) != {"stat", "amount"}:
                        blockers.append(
                            f"{path_prefix}[{idx}].benefits[{b_idx}] must have only 'stat' and 'amount'."
                        )
                        continue
                    st = str(b.get("stat", ""))
                    if st not in ("AC", "speed") or st in seen_stats:
                        blockers.append(
                            f"{path_prefix}[{idx}].benefits[{b_idx}] stat '{st}' must be unique in ['AC', 'speed']."
                        )
                    seen_stats.add(st)
                    if not _is_int_in_range(b.get("amount"), 1, 10):
                        blockers.append(
                            f"{path_prefix}[{idx}].benefits[{b_idx}] amount must be an integer 1-10."
                        )
        elif eff_type == "area_selection":
            allowed_eff_keys.update({"shape", "radius", "size"})
            area_count += 1
            shape = str(eff.get("shape", ""))
            if shape not in ("sphere", "cone", "cube"):
                blockers.append(f"Unsupported area_selection shape '{shape}' at {path_prefix}[{idx}].")
            else:
                g_key = "radius" if shape == "sphere" else "size"
                if not _is_int_in_range(eff.get(g_key), 1, 100):
                    blockers.append(f"{path_prefix}[{idx}] ({shape}) requires integer {g_key} 1-100 in hexes.")

        extra_eff_keys = [k for k in eff.keys() if k not in allowed_eff_keys]
        if extra_eff_keys:
            for ek in extra_eff_keys:
                unknown_nested.append(f"{path_prefix}[{idx}].{ek}")
            blockers.append(
                f"Unsupported keys on {path_prefix}[{idx}] ({eff_type}) unless parked in _editor_meta: {', '.join(extra_eff_keys)}"
            )

    return blockers, has_condition_or_benefit, area_count, unknown_nested


def _validate_steps_pipeline(
    steps: Any,
    contract: dict[str, Any],
) -> tuple[list[str], bool, list[str]]:
    """Validates ADR-0019 ordered `steps` against SharedStepExecutor rules."""
    sc = contract["shared_spell"]
    allowed_step_fields = set(sc.get("step_fields", []))
    allowed_step_types = set(sc.get("step_types", ["attack", "save", "damage", "effect"]))
    allowed_gates = set(sc.get("step_gates", ["always", "hit", "miss", "failed_save", "successful_save"]))
    allowed_targets = set(sc.get("step_targets", ["target", "self", "area"]))
    blockers: list[str] = []
    unknown_step_fields: list[str] = []
    has_condition_or_benefit = False

    if not isinstance(steps, list) or not (1 <= len(steps) <= 8):
        return ["steps must be a non-empty array of 1 to 8 step objects."], False, []

    seen_ids: dict[str, str] = {}
    prior_outcome_step_type: str | None = None

    for idx, step in enumerate(steps):
        if not isinstance(step, dict):
            blockers.append(f"steps[{idx}] must be an object.")
            continue
        for k in step.keys():
            if k not in allowed_step_fields:
                unknown_step_fields.append(f"steps[{idx}].{k}")
                blockers.append(f"Unsupported step field 'steps[{idx}].{k}' unless parked in _editor_meta.")

        step_id = str(step.get("id", "")).strip()
        if step_id:
            if step_id in seen_ids:
                blockers.append(f"Duplicate step id '{step_id}' at steps[{idx}].")
        step_type = str(step.get("type", ""))
        if step_type not in allowed_step_types:
            blockers.append(f"steps[{idx}].type '{step_type}' must be one of {sorted(allowed_step_types)}.")
            continue

        gate = str(step.get("gate", "always"))
        if gate not in allowed_gates:
            blockers.append(f"steps[{idx}].gate '{gate}' must be one of {sorted(allowed_gates)}.")
        gate_step = str(step.get("gate_step", "")).strip()
        if gate == "always" and gate_step:
            blockers.append(f"steps[{idx}] cannot set gate_step when gate is 'always'.")
        elif gate != "always":
            ref_type = seen_ids.get(gate_step) if gate_step else prior_outcome_step_type
            if gate_step and gate_step not in seen_ids:
                blockers.append(f"steps[{idx}].gate_step '{gate_step}' must reference an earlier step id.")
            if gate in ("hit", "miss") and ref_type != "attack":
                blockers.append(f"steps[{idx}] gate '{gate}' requires an earlier 'attack' step.")
            if gate in ("failed_save", "successful_save") and ref_type != "save":
                blockers.append(f"steps[{idx}] gate '{gate}' requires an earlier 'save' step.")

        starget = str(step.get("target", "target"))
        if starget not in allowed_targets:
            blockers.append(f"steps[{idx}].target '{starget}' must be in {sorted(allowed_targets)}.")
        if starget == "area":
            shape = str(step.get("shape", ""))
            if shape not in ("sphere", "cone", "cube"):
                blockers.append(f"steps[{idx}] area target requires shape in ['sphere', 'cone', 'cube'].")
            else:
                g_key = "radius" if shape == "sphere" else "size"
                if not _is_int_in_range(step.get(g_key), 1, 100):
                    blockers.append(f"steps[{idx}] ({shape}) requires integer {g_key} 1-100 in hexes.")

        has_damage = "damage" in step
        has_dmg_comps = "damage_components" in step
        if has_damage and has_dmg_comps:
            blockers.append(f"steps[{idx}] cannot declare both 'damage' and 'damage_components'.")
        if has_damage:
            if not _is_valid_formula(step.get("damage")) or str(step.get("damage_type", "")) not in contract["damage_types"]:
                blockers.append(f"steps[{idx}] damage requires valid formula and damage_type.")
        if has_dmg_comps:
            if step_type != "save":
                blockers.append(f"steps[{idx}] damage_components is only supported on 'save' steps.")
            comps = step.get("damage_components")
            if not isinstance(comps, list) or not (1 <= len(comps) <= 4):
                blockers.append(f"steps[{idx}].damage_components must be an array of 1-4 entries.")

        step_effects = step.get("effects", [])
        if "effects" in step:
            eff_blockers, eff_cond, eff_area, eff_unk = _validate_effect_list(
                step_effects, sc, path_prefix=f"steps[{idx}].effects"
            )
            blockers.extend(eff_blockers)
            unknown_step_fields.extend(eff_unk)
            if eff_cond:
                has_condition_or_benefit = True
            if eff_area > 0:
                blockers.append(f"steps[{idx}] must use step target='area' instead of area_selection effect.")

        has_step_effects = isinstance(step_effects, list) and len(step_effects) > 0
        if step_type == "attack":
            if str(step.get("attack_type", "")) not in ("ranged_spell", "melee_spell"):
                blockers.append(f"steps[{idx}] (attack) requires attack_type 'ranged_spell' or 'melee_spell'.")
            if "save" in step:
                blockers.append(f"steps[{idx}] (attack) cannot declare 'save'.")
            if not has_damage and not has_step_effects:
                blockers.append(f"steps[{idx}] (attack) requires damage or effects.")
        elif step_type == "save":
            if str(step.get("save", "")) not in contract["abilities"]:
                blockers.append(f"steps[{idx}] (save) requires a valid save ability {contract['abilities']}.")
            if "attack_type" in step:
                blockers.append(f"steps[{idx}] (save) cannot declare 'attack_type'.")
            if not has_damage and not has_dmg_comps and not has_step_effects:
                blockers.append(f"steps[{idx}] (save) requires damage, damage_components, or effects.")
        elif step_type == "damage":
            if not has_damage or "attack_type" in step or "save" in step or has_step_effects:
                blockers.append(f"steps[{idx}] (damage) requires 'damage' without attack_type, save, or effects.")
        elif step_type == "effect":
            if not has_step_effects or has_damage or "attack_type" in step or "save" in step:
                blockers.append(f"steps[{idx}] (effect) requires 'effects' without damage, attack_type, or save.")

        if step_id:
            seen_ids[step_id] = step_type
        if step_type in ("attack", "save"):
            prior_outcome_step_type = step_type

    return blockers, has_condition_or_benefit, unknown_step_fields


def _evaluate_spell_support(
    spell: dict[str, Any],
    contract: dict[str, Any],
    is_cloned_homebrew: bool = False,
) -> dict[str, Any]:
    sc = contract["shared_spell"]
    allowed_fields = set(sc["allowed_fields"])
    native_ids = set(sc["native_available_slices"])
    dedicated_fields = set(sc["dedicated_handler_fields"])

    spell_id = str(spell.get("id", ""))
    execution = str(spell.get("execution", ""))
    is_shared = execution == "shared"

    warnings: list[str] = []
    unknown_fields: list[str] = []
    unit_warnings: list[str] = []

    for key in spell.keys():
        if key not in allowed_fields and not str(key).startswith("_"):
            unknown_fields.append(str(key))

    # Unit checks (hexes vs feet & duration text vs duration_seconds)
    rng = spell.get("range")
    if isinstance(rng, (int, float)) and not isinstance(rng, bool):
        if int(rng) >= 30 and int(rng) % 5 == 0 and str(spell.get("range_kind", "")) == "":
            unit_warnings.append(
                f"range={rng} hexes equals {int(rng) * 5} ft. Verify this was authored in 5-ft hexes, not raw feet."
            )
    dur_text = str(spell.get("duration", "")).strip().lower()
    dur_secs = spell.get("duration_seconds")
    if dur_text in DURATION_TEXT_TO_SECONDS:
        expected_secs = DURATION_TEXT_TO_SECONDS[dur_text]
        if expected_secs is not None and dur_secs is not None and int(dur_secs) != expected_secs:
            unit_warnings.append(
                f"Duration text '{spell.get('duration')}' expects {expected_secs}s, but duration_seconds is {dur_secs}."
            )
        elif expected_secs is not None and dur_secs is None and dur_text != "instantaneous":
            unit_warnings.append(
                f"Duration text is '{spell.get('duration')}', but duration_seconds ({expected_secs}s) is missing."
            )

    shared_blockers: list[str] = []
    if not spell_id or not str(spell.get("name", "")).strip():
        shared_blockers.append("Shared spells require a non-empty id and name.")
    if not _is_int_in_range(spell.get("level"), 0, 9):
        shared_blockers.append("Spell level must be an integer 0-9.")
    if not _is_int_in_range(spell.get("range"), 0, 1000):
        shared_blockers.append("Spell range must be an integer 0-1000 in 5-ft hexes.")

    for d_field in dedicated_fields:
        if d_field in spell:
            shared_blockers.append(
                f"Field '{d_field}' requires a dedicated native handler and is rejected by SharedSpell."
            )

    casting_time = str(spell.get("casting_time", "action"))
    if casting_time not in sc["casting_times"] or str(spell.get("trigger", "")):
        shared_blockers.append(
            f"Shared spells only support Action or Bonus Action casting_time without triggers (found '{casting_time}')."
        )

    target = str(spell.get("target", "single"))
    if target not in sc["targets"]:
        shared_blockers.append(
            f"Target selector '{target}' is not in supported shared targets {sc['targets']}."
        )

    if unknown_fields:
        shared_blockers.append(
            "Unknown top-level fields rejected by SharedSpell unless parked in _editor_meta: "
            + ", ".join(unknown_fields)
        )

    effects = spell.get("effects", [])
    eff_blockers, has_condition_or_benefit, area_count, eff_unknown = _validate_effect_list(
        effects, sc, path_prefix="effects"
    )
    shared_blockers.extend(eff_blockers)
    unknown_fields.extend(eff_unknown)

    has_steps = "steps" in spell
    if has_steps:
        for forbidden_flat in (
            "attack_type",
            "damage",
            "damage_type",
            "save",
            "half_on_save",
            "damage_scale_by_outcome",
            "damage_dice_policy",
            "damage_result_multiplier",
        ):
            if forbidden_flat in spell and spell.get(forbidden_flat) not in (None, "none", False):
                shared_blockers.append(
                    f"Ordered 'steps' spells cannot combine top-level '{forbidden_flat}' with steps."
                )
        if isinstance(effects, list) and len(effects) > 0:
            shared_blockers.append("Ordered 'steps' spells must place effects inside steps, not top-level 'effects'.")
        step_blockers, step_cond, step_unk = _validate_steps_pipeline(spell.get("steps"), contract)
        shared_blockers.extend(step_blockers)
        unknown_fields.extend(step_unk)
        if step_cond:
            has_condition_or_benefit = True
    else:
        attack_type = str(spell.get("attack_type", "none"))
        if attack_type not in sc["attack_types"]:
            shared_blockers.append(f"Unsupported attack_type '{attack_type}'.")
        if "save" in spell and str(spell.get("save")) not in contract["abilities"]:
            shared_blockers.append(f"Invalid save ability '{spell.get('save')}'.")
        if "save" in spell and attack_type != "none":
            shared_blockers.append("Flat shared spells cannot declare both attack_type and save (use Ordered Steps instead).")
        if "damage" in spell:
            if not _is_valid_formula(spell.get("damage")) or str(spell.get("damage_type", "")) not in contract["damage_types"]:
                shared_blockers.append("Shared damage requires a valid dice/integer formula and supported damage_type.")
        if attack_type != "none" and "damage" not in spell:
            shared_blockers.append("Shared attack spells require a damage payload.")

    has_payload = (
        "damage" in spell
        or has_steps
        or any(
            isinstance(e, dict) and str(e.get("type", "")) != "area_selection"
            for e in (effects if isinstance(effects, list) else [])
        )
    )
    if not has_payload:
        shared_blockers.append("Shared spells require an executable payload (damage, steps, or non-area effect).")

    if not has_steps:
        if target in ("area", "cone") and area_count == 0:
            shared_blockers.append("Area/cone flat shared spells require an area_selection effect.")
        if area_count > 1 or (area_count > 0 and target not in ("area", "cone")):
            shared_blockers.append("area_selection effect requires target to be 'area' or 'cone'.")

    if has_condition_or_benefit and not _is_int_in_range(spell.get("duration_seconds"), 1, 86400):
        shared_blockers.append("Condition or source-benefit grants require duration_seconds (1-86400).")

    # Validate source_end_rules if present
    if "source_end_rules" in spell:
        ser = spell.get("source_end_rules")
        if not isinstance(ser, list) or len(ser) > 16:
            shared_blockers.append("source_end_rules must be an array of at most 16 rule objects.")
        else:
            allowed_events = set(sc.get("source_end_events", []))
            allowed_actors = set(sc.get("source_end_actors", []))
            for r_idx, rule in enumerate(ser):
                if not isinstance(rule, dict):
                    shared_blockers.append(f"source_end_rules[{r_idx}] must be an object.")
                    continue
                ev = str(rule.get("event", ""))
                ac = str(rule.get("actor", "any"))
                if ev not in allowed_events:
                    shared_blockers.append(f"source_end_rules[{r_idx}].event '{ev}' must be in {sorted(allowed_events)}.")
                if ac not in allowed_actors:
                    shared_blockers.append(f"source_end_rules[{r_idx}].actor '{ac}' must be in {sorted(allowed_actors)}.")

    # Validate repeat_save_stages if present
    if "repeat_save_stages" in spell:
        stages = spell.get("repeat_save_stages")
        if not spell.get("repeat_save"):
            shared_blockers.append("repeat_save_stages requires repeat_save=true.")
        if not isinstance(stages, list) or not (1 <= len(stages) <= 8):
            shared_blockers.append("repeat_save_stages must be a non-empty array of 1-8 stage objects.")
        else:
            for s_idx, stg in enumerate(stages):
                if not isinstance(stg, dict):
                    shared_blockers.append(f"repeat_save_stages[{s_idx}] must be an object.")
                    continue
                cond = str(stg.get("condition", ""))
                if cond not in sc["conditions"]:
                    shared_blockers.append(f"repeat_save_stages[{s_idx}].condition '{cond}' is not supported.")
                if "on_failure" in stg and str(stg.get("on_failure")) not in ("stay", "advance", "end"):
                    shared_blockers.append(f"repeat_save_stages[{s_idx}].on_failure must be 'stay', 'advance', or 'end'.")

    upcast = spell.get("upcast", {})
    if isinstance(upcast, dict):
        for uk, uv in upcast.items():
            if uk in ("damage_per_level", "healing_dice_per_level"):
                if not _is_valid_dice_formula(uv):
                    shared_blockers.append(f"upcast.{uk} must be a plain dice expression like '1d6'.")
            elif uk in (
                "starting_level",
                "levels_per_increment",
                "additional_targets_per_level",
                "temporary_hp_per_level",
                "healing_per_level",
            ):
                if not _is_int_in_range(uv, 0, 100):
                    shared_blockers.append(f"upcast.{uk} must be an integer 0-100.")
            else:
                shared_blockers.append(f"Unsupported shared upcast key '{uk}'.")

    if is_shared:
        if shared_blockers:
            return {
                "status": "draft-unsupported",
                "status_label": "Draft / Shared Contract Errors",
                "contract_revision": contract.get("revision", ""),
                "errors": shared_blockers,
                "warnings": warnings,
                "unknown_fields": unknown_fields,
                "unit_warnings": unit_warnings,
                "convertible_to_shared": False,
            }
        return {
            "status": "shared-ready",
            "status_label": "Shared-Ready (Pinned VS-83 Contract)",
            "contract_revision": contract.get("revision", ""),
            "errors": [],
            "warnings": warnings,
            "unknown_fields": unknown_fields,
            "unit_warnings": unit_warnings,
            "convertible_to_shared": False,
        }

    if spell_id in native_ids and not is_cloned_homebrew:
        warnings.append(
            f"Spell '{spell_id}' relies on the hardcoded native ID allowlist (SpellSupport.AVAILABLE_SLICES). "
            "Cloning it to a new homebrew ID will stop working unless converted to 'execution: shared'."
        )
        if shared_blockers:
            warnings.extend([f"If converted to shared: {b}" for b in shared_blockers])
        return {
            "status": "native-id-bound",
            "status_label": "Native-ID-Bound (Breaks If Cloned Without Shared Conversion)",
            "contract_revision": contract.get("revision", ""),
            "errors": [],
            "warnings": warnings,
            "unknown_fields": unknown_fields,
            "unit_warnings": unit_warnings,
            "convertible_to_shared": True,
        }

    reason_prefix = (
        f"Cloned ID '{spell_id}' is not in SpellSupport.AVAILABLE_SLICES and is missing \"execution\": \"shared\"."
        if ":" in spell_id or is_cloned_homebrew
        else f"Spell '{spell_id}' is neither \"execution\": \"shared\" nor in SpellSupport.AVAILABLE_SLICES."
    )
    return {
        "status": "draft-unsupported",
        "status_label": "Draft / Blocked on Engine or Shared Conversion",
        "contract_revision": contract.get("revision", ""),
        "errors": [reason_prefix] + shared_blockers,
        "warnings": warnings,
        "unknown_fields": unknown_fields,
        "unit_warnings": unit_warnings,
        "convertible_to_shared": True,
    }


def _evaluate_item_support(item: dict[str, Any], contract: dict[str, Any]) -> dict[str, Any]:
    ic = contract["item"]
    errors: list[str] = []
    warnings: list[str] = []
    unit_warnings: list[str] = []

    for req in ic["required_fields"]:
        if req not in item or str(item.get(req, "")).strip() == "":
            errors.append(f"Item is missing required field '{req}'.")

    itype = str(item.get("type", ""))
    if itype not in ic["allowed_types"]:
        errors.append(f"Item type '{itype}' is not in DataLoader allowed types {ic['allowed_types']}.")

    rng = item.get("range")
    if isinstance(rng, (int, float)) and not isinstance(rng, bool) and int(rng) >= 20 and int(rng) % 5 == 0:
        unit_warnings.append(
            f"Item range={rng} hexes equals {int(rng) * 5} ft. Verify this was authored in 5-ft hexes."
        )

    if "source_benefits" in item:
        if itype not in ic["source_benefit_carrier_types"]:
            errors.append(
                f"source_benefits is only supported on {ic['source_benefit_carrier_types']} (found '{itype}')."
            )
        benefits = item.get("source_benefits")
        if not isinstance(benefits, list) or not benefits:
            errors.append("source_benefits must be a non-empty array of {stat, amount}.")
        else:
            seen_stats: set[str] = set()
            for idx, b in enumerate(benefits):
                if not isinstance(b, dict) or set(b.keys()) != {"stat", "amount"}:
                    errors.append(f"source_benefits[{idx}] must contain only 'stat' and 'amount'.")
                    continue
                stat = str(b.get("stat", ""))
                if stat not in ic["source_benefit_stats"] or stat in seen_stats:
                    errors.append(
                        f"source_benefits[{idx}] stat '{stat}' must be unique and in {ic['source_benefit_stats']}."
                    )
                seen_stats.add(stat)
                if not _is_int_in_range(b.get("amount"), 1, 10):
                    errors.append(f"source_benefits[{idx}] amount must be an integer 1-10.")

    if "spell_permissions" in item:
        perms = item.get("spell_permissions")
        if not isinstance(perms, list) or not perms:
            errors.append("spell_permissions must be a non-empty array.")
        else:
            for idx, perm in enumerate(perms):
                if not isinstance(perm, dict):
                    errors.append(f"spell_permissions[{idx}] must be an object.")
                    continue
                spells = perm.get("spells")
                if not isinstance(spells, list) or not spells:
                    errors.append(f"spell_permissions[{idx}] requires a non-empty 'spells' array.")
                ability = str(perm.get("ability", ""))
                if ability and ability not in contract["abilities"]:
                    errors.append(f"spell_permissions[{idx}] has invalid ability '{ability}'.")
                if "charges" in perm and not _is_int_in_range(perm.get("charges"), 1, 100):
                    errors.append(f"spell_permissions[{idx}] charges must be an integer 1-100.")

    effects = item.get("effects", [])
    unsupported_effects: list[str] = []
    if isinstance(effects, list):
        for eff in effects:
            if isinstance(eff, dict):
                etype = str(eff.get("type", ""))
                if etype and etype not in ic["supported_item_effect_types"]:
                    unsupported_effects.append(etype)

    if unsupported_effects:
        errors.append(
            "Item contains unverified/unsupported effect types: " + ", ".join(unsupported_effects)
        )

    item_id = str(item.get("id", ""))
    if ":" in item_id and not item.get("starting_equipment_classes"):
        warnings.append(
            "New homebrew item has no starting_equipment_classes selected; players will not automatically receive it at character creation."
        )

    status = "shared-ready" if not errors else "draft-unsupported"
    status_label = (
        "Game-Ready Item (Pinned VS-83 Contract)"
        if not errors
        else "Draft / Item Contract Errors"
    )
    return {
        "status": status,
        "status_label": status_label,
        "contract_revision": contract.get("revision", ""),
        "errors": errors,
        "warnings": warnings,
        "unknown_fields": [],
        "unit_warnings": unit_warnings,
        "convertible_to_shared": False,
    }


def convert_spell_to_shared(spell: dict[str, Any], contract: dict[str, Any] | None = None) -> dict[str, Any]:
    """Converts a draft spell record toward the shared spell contract without losing data."""
    if contract is None:
        contract = load_pinned_contract()
    updated = copy.deepcopy(spell)
    updated["execution"] = "shared"

    if updated.get("target") == "single_ally":
        updated["target"] = "multi" if _is_int_in_range(updated.get("base_targets"), 2, 100) else "single"

    if "steps" not in updated:
        if updated.get("target") == "area":
            effects = updated.setdefault("effects", [])
            if isinstance(effects, list) and not any(
                isinstance(e, dict) and e.get("type") == "area_selection" for e in effects
            ):
                radius = int(updated.get("area_radius", 1)) if _is_int_in_range(updated.get("area_radius"), 1, 100) else 2
                effects.insert(0, {"type": "area_selection", "shape": "sphere", "radius": radius})

        if updated.get("target") == "cone":
            effects = updated.setdefault("effects", [])
            if isinstance(effects, list) and not any(
                isinstance(e, dict) and e.get("type") == "area_selection" for e in effects
            ):
                size = int(updated.get("cone_size", 3)) if _is_int_in_range(updated.get("cone_size"), 1, 100) else 3
                effects.insert(0, {"type": "area_selection", "shape": "cone", "size": size})

    dur_text = str(updated.get("duration", "")).strip().lower()
    if dur_text in DURATION_TEXT_TO_SECONDS and DURATION_TEXT_TO_SECONDS[dur_text] is not None:
        if "duration_seconds" not in updated:
            updated["duration_seconds"] = DURATION_TEXT_TO_SECONDS[dur_text]

    return updated


def _allowed_keys_for_effect(eff_type: str) -> set[str]:
    allowed = {"type", "on_spell_hit", "on_failed_save", "rider_by_outcome", "when"}
    if eff_type in ("heal", "temporary_hp"):
        allowed.update({"value", "ability_bonus_from_caster"})
    elif eff_type in ("grant_condition", "remove_condition"):
        allowed.add("condition")
    elif eff_type == "grant_source_benefits":
        allowed.add("benefits")
    elif eff_type == "area_selection":
        allowed.update({"shape", "radius", "size"})
    return allowed


def prepare_game_pack_record(
    content_type: str,
    draft_record: dict[str, Any],
    contract: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Formats a record for Luna's game pack loader while parking non-contract fields in _editor_meta."""
    if contract is None:
        contract = load_pinned_contract()
    record = copy.deepcopy(draft_record)
    parked_top_level: dict[str, Any] = {}
    parked_effect_fields: dict[str, dict[str, Any]] = {}
    parked_step_fields: dict[str, dict[str, Any]] = {}

    if content_type == "spell" and record.get("execution") == "shared":
        allowed_top = set(contract["shared_spell"]["allowed_fields"])
        for key in list(record.keys()):
            if key not in allowed_top and not str(key).startswith("_"):
                parked_top_level[key] = record.pop(key)

        effects = record.get("effects")
        if isinstance(effects, list):
            for idx, eff in enumerate(effects):
                if not isinstance(eff, dict):
                    continue
                allowed_eff = _allowed_keys_for_effect(str(eff.get("type", "")))
                extra = {}
                for ek in list(eff.keys()):
                    if ek not in allowed_eff:
                        extra[ek] = eff.pop(ek)
                if extra:
                    parked_effect_fields[str(idx)] = extra

        steps = record.get("steps")
        if isinstance(steps, list):
            allowed_step = set(contract["shared_spell"].get("step_fields", []))
            for s_idx, step in enumerate(steps):
                if not isinstance(step, dict):
                    continue
                extra_step: dict[str, Any] = {}
                for sk in list(step.keys()):
                    if sk not in allowed_step:
                        extra_step[sk] = step.pop(sk)
                if extra_step:
                    parked_step_fields[str(s_idx)] = extra_step

    elif content_type == "item":
        if "starting_equipment_classes" in record:
            parked_top_level["starting_equipment_classes"] = record.pop("starting_equipment_classes")

    if parked_top_level or parked_effect_fields or parked_step_fields:
        meta = copy.deepcopy(record.get("_editor_meta", {})) if isinstance(record.get("_editor_meta"), dict) else {}
        if parked_top_level:
            existing_top = meta.get("parked_top_level", {})
            existing_top.update(parked_top_level)
            meta["parked_top_level"] = existing_top
        if parked_effect_fields:
            existing_eff = meta.get("parked_effect_fields", {})
            existing_eff.update(parked_effect_fields)
            meta["parked_effect_fields"] = existing_eff
        if parked_step_fields:
            existing_stp = meta.get("parked_step_fields", {})
            existing_stp.update(parked_step_fields)
            meta["parked_step_fields"] = existing_stp
        record["_editor_meta"] = meta

    return record


def restore_from_exported_record(exported_record: dict[str, Any]) -> dict[str, Any]:
    """Reconstructs the lossless draft record from a Game Pack Export record with _editor_meta."""
    restored = copy.deepcopy(exported_record)
    meta = restored.get("_editor_meta")
    if not isinstance(meta, dict):
        return restored

    parked_top = meta.pop("parked_top_level", None)
    if isinstance(parked_top, dict):
        for k, v in parked_top.items():
            restored[k] = copy.deepcopy(v)

    parked_eff = meta.pop("parked_effect_fields", None)
    if isinstance(parked_eff, dict) and isinstance(restored.get("effects"), list):
        for idx_str, fields in parked_eff.items():
            if idx_str.isdigit():
                idx = int(idx_str)
                if 0 <= idx < len(restored["effects"]) and isinstance(restored["effects"][idx], dict):
                    restored["effects"][idx].update(copy.deepcopy(fields))

    parked_stp = meta.pop("parked_step_fields", None)
    if isinstance(parked_stp, dict) and isinstance(restored.get("steps"), list):
        for idx_str, fields in parked_stp.items():
            if idx_str.isdigit():
                idx = int(idx_str)
                if 0 <= idx < len(restored["steps"]) and isinstance(restored["steps"][idx], dict):
                    restored["steps"][idx].update(copy.deepcopy(fields))

    if not meta:
        restored.pop("_editor_meta", None)
    else:
        restored["_editor_meta"] = meta
    return restored


class PackWorkspace:
    """Manages an isolated authoring workspace under tools/content_editor/workspaces/<pack_id>/."""

    def __init__(
        self,
        pack_id: str,
        workspaces_root: Path = DEFAULT_WORKSPACES_DIR,
        catalog: CatalogIndex | None = None,
    ) -> None:
        self.pack_id = slugify_id(pack_id)
        self.workspaces_root = workspaces_root
        self.root = self.workspaces_root / self.pack_id
        self.catalog = catalog or CatalogIndex()
        self.contract = self.catalog.contract
        self._ensure_initialized()

    def _ensure_initialized(self) -> None:
        self.root.mkdir(parents=True, exist_ok=True)
        (self.root / "drafts" / "spells").mkdir(parents=True, exist_ok=True)
        (self.root / "drafts" / "items").mkdir(parents=True, exist_ok=True)
        meta_path = self.root / "workspace.json"
        if not meta_path.exists():
            default_meta = {
                "pack_id": self.pack_id,
                "name": self.pack_id.replace("_", " ").title(),
                "author": "Rook",
                "version": "0.1.0",
                "ruleset_compatibility": "rook-5e-lite-v1",
                "contract_revision": self.contract.get("revision", "2026-10-18-vs83"),
                "dependencies": ["core"],
                "draft_metadata": {},
            }
            self._write_json(meta_path, default_meta)

    def _read_json(self, path: Path) -> Any:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)

    def _write_json(self, path: Path, payload: Any) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=2, ensure_ascii=False)
            handle.write("\n")

    def get_metadata(self) -> dict[str, Any]:
        return self._read_json(self.root / "workspace.json")

    def update_metadata(self, patch: dict[str, Any]) -> dict[str, Any]:
        meta = self.get_metadata()
        for key in ("name", "author", "version", "ruleset_compatibility"):
            if key in patch and str(patch[key]).strip():
                meta[key] = str(patch[key]).strip()
        self._write_json(self.root / "workspace.json", meta)
        return meta

    def _draft_file_path(self, content_type: str, record_id: str) -> Path:
        folder = "spells" if content_type == "spell" else "items"
        safe_filename = record_id.replace(":", "__").replace("/", "_") + ".json"
        return self.root / "drafts" / folder / safe_filename

    def create_from_template(
        self,
        template_id: str,
        new_slug_or_id: str,
        new_name: str,
    ) -> dict[str, Any]:
        """Instantiates a new homebrew draft from one of the built-in VS-83 archetypes."""
        if template_id not in TEMPLATES:
            raise KeyError(f"Unknown template '{template_id}'.")
        tmpl = TEMPLATES[template_id]
        content_type = tmpl["content_type"]
        record = copy.deepcopy(tmpl["record"])
        new_id = make_namespaced_id(self.pack_id, new_slug_or_id or new_name)
        record["id"] = new_id
        record["name"] = new_name.strip() if new_name.strip() else tmpl["record"]["name"]
        return self.save_draft(
            content_type,
            record,
            origin={
                "mode": "homebrew_new",
                "template_id": template_id,
                "replaces": [],
            },
        )

    def delete_draft(self, content_type: str, record_id: str) -> bool:
        draft_path = self._draft_file_path(content_type, record_id)
        existed = draft_path.exists()
        if existed:
            draft_path.unlink()
        meta = self.get_metadata()
        key = f"{content_type}:{record_id}"
        if key in meta.get("draft_metadata", {}):
            meta["draft_metadata"].pop(key, None)
            self._write_json(self.root / "workspace.json", meta)
            existed = True
        return existed

    def stage_override(self, content_type: str, source_id: str) -> dict[str, Any]:
        """Imports a catalog record into the draft workspace with its original ID for override editing."""
        entry = self.catalog.get_entry(content_type, source_id)
        if entry is None:
            raise KeyError(f"Unknown {content_type} record '{source_id}' in catalog.")
        draft_record = copy.deepcopy(entry["active_record"])
        return self.save_draft(
            content_type,
            draft_record,
            origin={
                "mode": "override",
                "source_id": source_id,
                "winner_coord": entry["winner_coord"],
                "replaces": [entry["winner_coord"]]
                + [r["coord"] for r in entry["replaced_sources"]],
            },
        )

    def clone_as_homebrew(
        self,
        content_type: str,
        source_id: str,
        new_slug_or_id: str,
        new_name: str | None = None,
    ) -> dict[str, Any]:
        """Duplicates a catalog or draft record into a new homebrew definition with a stable namespaced ID."""
        existing_draft = self.get_draft(content_type, source_id)
        if existing_draft is not None:
            base_record = copy.deepcopy(existing_draft["record"])
            source_coord = existing_draft.get("origin", {}).get("winner_coord", f"draft:{source_id}")
        else:
            entry = self.catalog.get_entry(content_type, source_id)
            if entry is None:
                raise KeyError(f"Unknown {content_type} record '{source_id}'.")
            base_record = copy.deepcopy(entry["active_record"])
            source_coord = entry["winner_coord"]

        new_id = make_namespaced_id(self.pack_id, new_slug_or_id)
        base_record["id"] = new_id
        if new_name and new_name.strip():
            base_record["name"] = new_name.strip()
        elif "name" in base_record:
            base_record["name"] = f"{base_record['name']} (Homebrew)"

        return self.save_draft(
            content_type,
            base_record,
            origin={
                "mode": "homebrew_clone",
                "cloned_from_id": source_id,
                "cloned_from_coord": source_coord,
                "replaces": [],
            },
        )

    def save_draft(
        self,
        content_type: str,
        record: dict[str, Any],
        origin: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Saves a draft record losslessly (preserving all unknown fields and nested arrays)."""
        if content_type not in ("spell", "item"):
            raise ValueError(f"Unsupported draft content_type '{content_type}'.")
        record_id = str(record.get("id", "")).strip()
        if not record_id:
            raise ValueError("Draft record requires a non-empty 'id'.")

        meta = self.get_metadata()
        draft_meta_map = meta.setdefault("draft_metadata", {})
        key = f"{content_type}:{record_id}"
        existing_origin = draft_meta_map.get(key, {}).get("origin", {})
        final_origin = origin if origin is not None else existing_origin
        if not final_origin:
            final_origin = {
                "mode": "homebrew_new" if ":" in record_id else "override",
                "replaces": [],
            }

        draft_path = self._draft_file_path(content_type, record_id)
        self._write_json(draft_path, record)

        is_clone = final_origin.get("mode") in ("homebrew_clone", "homebrew_new") or ":" in record_id
        diag = evaluate_record_support(
            content_type, record, self.contract, is_cloned_homebrew=is_clone
        )
        draft_meta_map[key] = {
            "id": record_id,
            "content_type": content_type,
            "file": draft_path.name,
            "origin": final_origin,
            "status": diag["status"],
        }
        self._write_json(self.root / "workspace.json", meta)
        return {
            "id": record_id,
            "content_type": content_type,
            "record": record,
            "origin": final_origin,
            "diagnostics": diag,
        }

    def update_draft(
        self,
        content_type: str,
        record_id: str,
        patch: dict[str, Any],
    ) -> dict[str, Any]:
        """Applies guided edits to an existing draft while locking its ID and preserving untouched fields."""
        current = self.get_draft(content_type, record_id)
        if current is None:
            raise KeyError(f"Draft '{content_type}:{record_id}' does not exist in workspace '{self.pack_id}'.")
        record = copy.deepcopy(current["record"])
        for key, value in patch.items():
            if key == "id":
                # Renaming a label or sending a patch must never silently rewrite record identity.
                continue
            if value is None:
                record.pop(key, None)
            else:
                record[key] = copy.deepcopy(value)
        return self.save_draft(content_type, record, origin=current["origin"])

    def get_draft(self, content_type: str, record_id: str) -> dict[str, Any] | None:
        draft_path = self._draft_file_path(content_type, record_id)
        if not draft_path.exists():
            return None
        record = self._read_json(draft_path)
        meta = self.get_metadata()
        key = f"{content_type}:{record_id}"
        origin = meta.get("draft_metadata", {}).get(key, {}).get("origin", {})
        is_clone = origin.get("mode") in ("homebrew_clone", "homebrew_new") or ":" in record_id
        diag = evaluate_record_support(
            content_type, record, self.contract, is_cloned_homebrew=is_clone
        )
        return {
            "id": record_id,
            "content_type": content_type,
            "record": record,
            "origin": origin,
            "diagnostics": diag,
        }

    def list_drafts(self) -> list[dict[str, Any]]:
        meta = self.get_metadata()
        draft_meta_map = meta.get("draft_metadata", {})
        items: list[dict[str, Any]] = []
        for key in sorted(draft_meta_map.keys()):
            info = draft_meta_map[key]
            ctype = info["content_type"]
            rid = info["id"]
            loaded = self.get_draft(ctype, rid)
            if loaded is not None:
                items.append(loaded)
        return items

    def preview_pack_manifest(self, mode: str = "game_pack_candidate", revision: str = "r1") -> dict[str, Any]:
        """Builds the live pack.json manifest without writing export files to disk."""
        meta = self.get_metadata()
        drafts = self.list_drafts()
        spell_list_additions: dict[str, list[str]] = {}
        starting_equipment_additions: dict[str, list[str]] = {}
        overrides: list[dict[str, Any]] = []
        diagnostics_summary: list[dict[str, Any]] = []

        for draft in drafts:
            ctype = draft["content_type"]
            rid = draft["id"]
            raw_rec = draft["record"]
            origin = draft["origin"]
            diag = draft["diagnostics"]

            if ctype == "spell":
                for cls_id in raw_rec.get("classes", []):
                    cls_norm = str(cls_id).strip().lower()
                    if cls_norm in self.contract["classes"]:
                        spell_list_additions.setdefault(cls_norm, [])
                        if rid not in spell_list_additions[cls_norm]:
                            spell_list_additions[cls_norm].append(rid)
            elif ctype == "item":
                for cls_id in raw_rec.get("starting_equipment_classes", []):
                    cls_norm = str(cls_id).strip().lower()
                    if cls_norm in self.contract["classes"]:
                        starting_equipment_additions.setdefault(cls_norm, [])
                        if rid not in starting_equipment_additions[cls_norm]:
                            starting_equipment_additions[cls_norm].append(rid)

            if origin.get("mode") == "override" and origin.get("replaces"):
                folder = "spells" if ctype == "spell" else "items"
                file_name = rid.replace(":", "__") + ".json"
                overrides.append(
                    {
                        "type": ctype,
                        "id": rid,
                        "winner": f"pack://{self.pack_id}/{folder}/{file_name}#1",
                        "replaces": origin["replaces"],
                    }
                )

            diagnostics_summary.append(
                {
                    "id": rid,
                    "content_type": ctype,
                    "origin_mode": origin.get("mode", "unknown"),
                    "status": diag["status"],
                    "status_label": diag["status_label"],
                    "errors": diag["errors"],
                    "warnings": diag["warnings"],
                    "unit_warnings": diag["unit_warnings"],
                    "unknown_fields": diag["unknown_fields"],
                }
            )

        return {
            "schema_version": 1,
            "export_status": mode,
            "export_note": (
                "Candidate additive pack for Luna's external pack loader. "
                "Structural/pinned-contract checks ran in tools/content_editor; production Godot validation owns runtime acceptance."
            ),
            "revision": revision,
            "contract_revision": self.contract.get("revision", "2026-10-18-vs83"),
            "pack": {
                "id": self.pack_id,
                "name": meta.get("name", self.pack_id),
                "author": meta.get("author", "Rook"),
                "version": meta.get("version", "0.1.0"),
                "dependencies": meta.get("dependencies", ["core"]),
                "ruleset_compatibility": meta.get("ruleset_compatibility", "rook-5e-lite-v1"),
            },
            "spell_list_additions": spell_list_additions,
            "starting_equipment_additions": starting_equipment_additions,
            "overrides": overrides,
            "diagnostics": diagnostics_summary,
        }

    def export_pack(
        self,
        mode: str = "game_pack_candidate",
        output_root: Path = DEFAULT_EXPORTS_DIR,
        revision: str = "r1",
    ) -> dict[str, Any]:
        """Exports the workspace into a versioned bundle directory."""
        if mode not in ("draft_lossless", "game_pack_candidate"):
            raise ValueError(f"Unsupported export mode '{mode}'.")

        drafts = self.list_drafts()
        export_dir = output_root / f"{self.pack_id}_{revision}_{mode}"
        spells_dir = export_dir / "spells"
        items_dir = export_dir / "items"
        spells_dir.mkdir(parents=True, exist_ok=True)
        items_dir.mkdir(parents=True, exist_ok=True)

        exported_spells: list[dict[str, Any]] = []
        exported_items: list[dict[str, Any]] = []

        for draft in drafts:
            ctype = draft["content_type"]
            rid = draft["id"]
            raw_rec = draft["record"]

            if mode == "draft_lossless":
                out_rec = copy.deepcopy(raw_rec)
            else:
                out_rec = prepare_game_pack_record(ctype, raw_rec, self.contract)

            file_name = rid.replace(":", "__") + ".json"
            if ctype == "spell":
                self._write_json(spells_dir / file_name, out_rec)
                exported_spells.append(out_rec)
            elif ctype == "item":
                self._write_json(items_dir / file_name, out_rec)
                exported_items.append(out_rec)

        pack_manifest = self.preview_pack_manifest(mode=mode, revision=revision)
        self._write_json(export_dir / "pack.json", pack_manifest)
        return {
            "export_dir": str(export_dir),
            "pack_manifest": pack_manifest,
            "spell_count": len(exported_spells),
            "item_count": len(exported_items),
        }
