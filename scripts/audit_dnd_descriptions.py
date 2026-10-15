"""Reproducible review coverage, not a rules interpreter or support oracle.

Run from any directory against the saved first-pass registry inventory.
Human adjudications are keyed to exact record content hashes;
matching text alone never carries a support decision between different rules.
Unadjudicated records stay pending. No keyword match establishes support.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import tarfile
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REVIEWS = ROOT / "docs/reviews"
WORK = ROOT / ".artifacts/rules-runtime-audit"
TEXT_KEYS = {"description", "entries", "entry", "mechanical_summary", "mechanical_bullets", "text"}
# Supplemental equipment prose includes mechanical tables (for example XGE
# tool crafting). Retain it on the root while keeping the existing independent
# child units: adding a display field must not silently erase review scope.
SUPPLEMENTAL_TEXT_KEYS = {"additionalEntries"}
SOURCE_ROOTS = ("data/core", "data/mods", "data/fixtures", "5etools raw", "_staging")
ROOT_REFERENCES = ("items.json", "races.json", "skills.json", "loot.json")


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def canonical(value) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def flatten(value) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "\n".join(flatten(child) for child in value)
    if isinstance(value, dict):
        # Preserve tables, references, choices and numeric content, not just prose.
        return "\n".join(f"{key}: {flatten(child)}" for key, child in value.items())
    return str(value)


def domain_for(path: str) -> str:
    parts = path.split("/")
    for domain in ("classes", "subclasses", "races", "items", "spells", "monsters", "events", "campaigns"):
        if domain in parts:
            return domain
    if path in ROOT_REFERENCES:
        return Path(path).stem
    if path.startswith("5etools raw/"):
        return "raw_classes"
    return "staged_subclasses"


def pointer_part(key) -> str:
    return str(key).replace("~", "~0").replace("/", "~1")


def harvest(value, source: str, pointer="", parent=""):
    if isinstance(value, dict):
        name = str(value.get("id", value.get("id_slug", value.get("name", value.get("table_id", parent)))))
        text = "\n".join(f"{key}: {flatten(child)}" for key, child in value.items() if key in TEXT_KEYS | SUPPLEMENTAL_TEXT_KEYS)
        copy_data = value.get("_copy", {})
        if isinstance(copy_data, dict) and "_mod" in copy_data:
            # Copy modifications can contain entire awakened/exalted rules.
            # Keep the modifications on the same content-bound root; the
            # referenced base still needs its own independent adjudication.
            text += ("\n" if text else "") + "_copy._mod: " + flatten(copy_data["_mod"])
        identified = any(key in value for key in ("id", "id_slug", "name", "table_id"))
        if text or identified:
            domain = domain_for(source)
            fingerprint = digest((domain + "\n" + canonical(value)).encode("utf-8"))
            yield {
                "source": source, "pointer": pointer or "/", "domain": domain,
                "id_or_name": name, "parent": parent,
                "record_sha256": fingerprint, "text_sha256": digest(text.encode("utf-8")),
                "text_characters": len(text), "potential_ellipsis": "…" in text or "..." in text,
                "copy_reference": "_copy" in value, "text": text, "record": value,
            }
        for key, child in value.items():
            # Text fields are fully retained in their enclosing unit. Avoid
            # duplicating a nested paragraph as an independent rule record.
            if key not in TEXT_KEYS and key not in ("_meta", "_copy"):
                yield from harvest(child, source, pointer + "/" + pointer_part(key), name)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from harvest(child, source, pointer + "/" + str(index), parent)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--show", help="Print review units whose source starts with this prefix")
    parser.add_argument("--text-only", action="store_true")
    parser.add_argument("--pending-only", action="store_true")
    parser.add_argument("--unique", action="store_true", help="Show each exact record once")
    parser.add_argument("--start", type=int, default=0)
    parser.add_argument("--limit", type=int, default=50)
    args = parser.parse_args()
    inventory = json.loads((REVIEWS / "dnd-data-runtime-inventory.json").read_text(encoding="utf-8"))
    # DataLoader's historical get_registry_hash returns a canonical registry
    # serialization. The saved first-pass inventory retains that snapshot, so
    # the ledger can be regenerated without an ignored local Godot export.
    snapshot = inventory["registry_hash"]
    registry_records = json.loads(snapshot)
    notes_path = REVIEWS / "dnd-data-runtime-adjudications.json"
    notes = json.loads(notes_path.read_text(encoding="utf-8")) if notes_path.exists() else {"records": {}}
    annotations = notes["records"]
    # The production loader's merge retains fallback _source_record metadata.
    # Its registration table records the actual override winner. Bind that
    # separately exported evidence to this exact snapshot and loader/manifest.
    ownership = json.loads((REVIEWS / "dnd-runtime-source-ownership.json").read_text(encoding="utf-8"))
    if ownership["registry_snapshot_sha256"] != digest(snapshot.encode("utf-8")):
        raise ValueError("Source ownership belongs to a different registry snapshot")
    for path, key in (("data/content_manifest.json", "manifest_sha256"), ("src/autoload/data_loader.gd", "loader_sha256")):
        if ownership[key] != digest((ROOT / path).read_bytes()):
            raise ValueError(f"Source ownership evidence changed: {path}")
    registered = ownership["registered_sources"]
    loaded_winners = {registered[entry["type"]][entry["id"]].removeprefix("res://") for entry in registry_records}
    for path, expected in notes.get("runtime_source_sha256", {}).items():
        if digest((ROOT / path).read_bytes()) != expected:
            raise ValueError(f"Runtime evidence changed; adjudications need re-review: {path}")
    array_sources = set()
    paths = sorted({p for root in SOURCE_ROOTS for p in (ROOT / root).rglob("*.json")} | {ROOT / p for p in ROOT_REFERENCES})
    # Verify the first-pass source inventory still describes this checkout.
    old_hashes = {item["path"]: item["sha256"] for item in inventory["source_files"]}
    current_paths = {path.relative_to(ROOT).as_posix() for path in paths}
    if current_paths != set(old_hashes):
        added = sorted(current_paths - set(old_hashes))
        missing = sorted(set(old_hashes) - current_paths)
        raise ValueError(f"First-pass source inventory membership changed; added={added}, missing={missing}")
    files = []
    units = []
    file_hashes = defaultdict(list)
    for path in paths:
        source = path.relative_to(ROOT).as_posix()
        raw = path.read_bytes()
        file_hash = digest(raw)
        if source in old_hashes and old_hashes[source] != file_hash:
            raise ValueError(f"First-pass source inventory is stale: {source}")
        value = json.loads(raw.decode("utf-8-sig"))
        if isinstance(value, list):
            array_sources.add(source)
        found = list(harvest(value, source))
        files.append({"path": source, "sha256": file_hash, "units": len(found), "text_units": sum(bool(u["text"]) for u in found)})
        file_hashes[file_hash].append(source)
        units.extend(found)
    markdown_paths = sorted((ROOT / "_staging").rglob("*.md"))
    for path in markdown_paths:
        file_hashes[digest(path.read_bytes())].append(path.relative_to(ROOT).as_posix())
    # Archives are read in memory. Nothing is extracted into the workspace.
    archives = []
    for path in sorted((ROOT / "_staging").glob("*.gz")):
        members = []
        with tarfile.open(path, "r:gz") as archive:
            for member in archive.getmembers():
                if not member.isfile():
                    continue
                stream = archive.extractfile(member)
                assert stream is not None
                raw = stream.read()
                member_hash = digest(raw)
                matches = file_hashes.get(member_hash, [])
                item = {"name": member.name, "sha256": member_hash, "bytes": len(raw), "exact_extracted_matches": matches}
                if not member.name.endswith(".json") and not matches:
                    item["status"] = "pending_archive_text_review"
                if member.name.endswith(".json") and not matches:
                    source = path.relative_to(ROOT).as_posix() + "::" + member.name
                    found = list(harvest(json.loads(raw.decode("utf-8-sig")), source))
                    units.extend(found)
                    item["additional_review_units"] = len(found)
                members.append(item)
        archives.append({"path": path.relative_to(ROOT).as_posix(), "sha256": digest(path.read_bytes()), "members": members})
    # Markdown may include commentary absent from JSON; inventory it separately,
    # retaining a pending review status until that relationship is established.
    markdown = [{"path": p.relative_to(ROOT).as_posix(), "sha256": digest(p.read_bytes()), "status": "pending_markdown_review"} for p in markdown_paths]
    used = set()
    rows = []
    for unit in units:
        note = annotations.get(unit["record_sha256"], {})
        if note:
            used.add(unit["record_sha256"])
            if not note.get("requirements") or not note.get("evidence") or not note.get("status", "").startswith("reviewed_"):
                raise ValueError(f"Incomplete adjudication: {unit['source']}#{unit['pointer']}")
        row = {key: unit[key] for key in ("source", "pointer", "domain", "id_or_name", "parent", "record_sha256", "text_sha256", "text_characters", "potential_ellipsis", "copy_reference")}
        row.update(review_status=note.get("status", "pending" if unit["text"] else "no_text_structural_review_required"), requirements=note.get("requirements", ""), runtime_evidence=note.get("evidence", ""), gaps_and_limits=note.get("gaps", ""))
        row["source_status"] = "not_default_loaded"
        if unit["source"].startswith(("data/core/", "data/mods/")):
            index = int(unit["pointer"].split("/")[1]) + 1 if unit["source"] in array_sources else 1
            locator = unit["source"] + "#" + str(index)
            is_root = unit["pointer"] == "/" or (unit["source"] in array_sources and len(unit["pointer"].split("/")) == 2)
            row["source_status"] = ("winning_source_record" if is_root else "child_of_winning_source_record") if locator in loaded_winners else "overridden_source_may_supply_missing_fields"
        rows.append(row)
    orphaned = set(annotations) - used
    if orphaned:
        raise ValueError(f"Adjudications no longer match source content: {sorted(orphaned)}")
    ledger = REVIEWS / "dnd-description-runtime-coverage.csv"
    with ledger.open("w", newline="", encoding="utf-8") as output:
        writer = csv.DictWriter(output, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    summary = {
        "purpose": "Review progress; pending and structural-only entries are not support claims.",
        "registry_snapshot_sha256": digest(snapshot.encode("utf-8")), "files": files, "archives": archives, "markdown": markdown,
        "total_units": len(units), "unique_record_hashes": len({u["record_sha256"] for u in units}),
        "text_units": sum(bool(u["text"]) for u in units),
        "unique_text_records": len({u["record_sha256"] for u in units if u["text"]}),
        "review_status_counts": dict(Counter(r["review_status"] for r in rows)),
        "domain_counts": {domain: dict(Counter(r["review_status"] for r in rows if r["domain"] == domain)) for domain in sorted({r["domain"] for r in rows})},
    }
    (REVIEWS / "dnd-description-runtime-coverage.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / "description-units.json").write_text(json.dumps(units, ensure_ascii=False), encoding="utf-8")
    if args.show:
        selected = [u for u in units if u["source"].startswith(args.show) and (u["text"] or not args.text_only) and (not args.pending_only or u["record_sha256"] not in annotations)]
        if args.unique:
            selected = list({u["record_sha256"]: u for u in reversed(selected)}.values())[::-1]
        print(f"Selected units: {len(selected)}; showing {args.start}:{args.start + args.limit}")
        for unit in selected[args.start:args.start + args.limit]:
            print(f"\n{unit['source']}#{unit['pointer']} [{unit['id_or_name']}] hash={unit['record_sha256']}")
            print(unit["text"] or "[No description; inspect structured fields]")
    else:
        print(json.dumps({k: v for k, v in summary.items() if k not in ("files", "archives", "markdown")}, indent=2))
        print("Archive additional units:", sum(m.get("additional_review_units", 0) for a in archives for m in a["members"]))
        print("Markdown references:", len(markdown))


if __name__ == "__main__":
    main()
