"""Rebuild the source inventory accompanying the monster execution proposal.

This inventories JSON and manifest precedence. It does not execute Godot or
certify any mechanic. The output is an intentional planning deliverable.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def inventory(repo: Path) -> dict:
    manifest_path = repo / "data/content_manifest.json"
    manifest = read_json(manifest_path)
    overrides = {
        entry["id"]: entry
        for entry in manifest["overrides"]
        if entry["type"] == "monster"
    }
    by_id = defaultdict(list)
    files = []
    for path in sorted((repo / "data/core/monsters").glob("*.json")):
        records = read_json(path)
        if not isinstance(records, list):
            raise ValueError(f"Expected an array in {path}")
        relative = path.relative_to(repo).as_posix()
        files.append({
            "path": relative,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "record_count": len(records),
        })
        for index, record in enumerate(records, 1):
            by_id[record["id"]].append({
                "locator": f"res://{relative}#{index}",
                "record": record,
            })

    winners = []
    rows = []
    for creature_id, candidates in sorted(by_id.items()):
        if len(candidates) == 1:
            winning = candidates[0]
        else:
            override = overrides.get(creature_id, {})
            matches = [c for c in candidates if c["locator"] == override.get("winner")]
            if len(matches) != 1:
                raise ValueError(f"Unresolved manifest winner for {creature_id}")
            expected = {c["locator"] for c in candidates} - {matches[0]["locator"]}
            if expected != set(override.get("replaces", [])):
                raise ValueError(f"Manifest replacement mismatch for {creature_id}")
            winning = matches[0]
        record = winning["record"]
        winners.append(record)
        traits = record.get("special_abilities", [])
        attacks = record.get("attacks", [])
        rows.append({
            "id": creature_id,
            "name": record["name"],
            "winner": winning["locator"],
            "overridden_sources": [c["locator"] for c in candidates if c is not winning],
            "rules_source": record.get("rules_source"),
            "present_fields": sorted(record),
            "missing_explicit_fields": [
                key for key in (
                    "rules_source", "creature_type", "proficiency_bonus",
                    "senses", "skills", "saving_throw_bonuses", "initiative_bonus",
                ) if key not in record
            ],
            "attack_names": [a["name"] for a in attacks],
            "attack_effect_types": sorted({
                effect["type"] for attack in attacks
                for effect in attack.get("extra_effects", [])
            }),
            "traits": [{
                "id": trait["id"],
                "name": trait.get("name", trait["id"]),
                "description": trait.get("description"),
            } for trait in traits],
            "reconciliation_status": "not_reviewed_against_complete_2024_source",
            "execution_support_status": "not_audited_by_this_inventory",
        })

    trait_counts = Counter(t["id"] for r in winners for t in r.get("special_abilities", []))
    effect_counts = Counter(
        e["type"] for r in winners for a in r.get("attacks", [])
        for e in a.get("extra_effects", [])
    )
    return {
        "inventory_format_version": 1,
        "purpose": "Source reconciliation input; not an executable schema or support certificate.",
        "scope": "data/core/monsters/*.json; manifest-declared winners; mods and rules corpus not inventoried",
        "regenerate": "python scripts/inventory_monster_design.py",
        "manifest": {
            "path": "data/content_manifest.json",
            "sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
            "pack_ruleset_compatibility": {
                p["id"]: p.get("ruleset_compatibility") for p in manifest["packs"]
            },
        },
        "files": files,
        "summary": {
            "source_records": sum(f["record_count"] for f in files),
            "distinct_ids": len(rows),
            "ids_with_multiple_sources": sum(len(c) > 1 for c in by_id.values()),
            "winning_records_by_file": dict(sorted(Counter(
                row["winner"].split("#")[0] for row in rows
            ).items())),
            "winning_attack_records": sum(len(r.get("attacks", [])) for r in winners),
            "winning_trait_records": sum(trait_counts.values()),
            "traits_with_descriptions": sum(
                "description" in t for r in winners for t in r.get("special_abilities", [])
            ),
            "distinct_trait_ids": len(trait_counts),
            "distinct_attack_effect_types": len(effect_counts),
            "explicit_field_counts": {
                key: sum(key in r for r in winners)
                for key in ("rules_source", "creature_type", "proficiency_bonus", "senses", "skills", "saving_throw_bonuses", "initiative_bonus")
            },
            "ai_behavior_counts": dict(sorted(Counter(r["ai_behavior"] for r in winners).items())),
        },
        "trait_id_counts": dict(sorted(trait_counts.items())),
        "attack_effect_type_counts": dict(sorted(effect_counts.items())),
        "creatures": rows,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    repo = args.repo.resolve()
    result = inventory(repo)
    output = args.output or repo / "docs/architecture/data-driven-2024-monster-inventory.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(output), "summary": result["summary"]}, indent=2))


if __name__ == "__main__":
    main()
