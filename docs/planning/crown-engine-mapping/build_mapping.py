"""Build/check the planning crosswalk. No Godot execution or rules simulation.

Paths are repository-relative and pointers are RFC 6901 JSON pointers. The
authored routing table and capability records are reviewable inputs, not a
runtime opcode registry. --check never writes. --consumer prints exact units.
"""
import argparse
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
PREP = ROOT / "docs/planning/preparation"
SETS = ["crown-spells", "crown-characters", "crown-equipment",
        "crown-reachable-items", "crown-creatures", "crown-world"]


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def esc(value):
    return str(value).replace("~", "~0").replace("/", "~1")


def resolve(document, pointer):
    value = document
    for part in pointer.split("/")[1:]:
        part = part.replace("~1", "/").replace("~0", "~")
        value = value[int(part)] if isinstance(value, list) else value[part]
    return value


def leaves(value, pointer):
    if isinstance(value, dict):
        for key, child in value.items():
            yield from leaves(child, pointer + "/" + esc(key))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from leaves(child, pointer + "/" + str(index))
    else:
        yield pointer, value


def build():
    spec = read(HERE / "capabilities.json")
    routes = read(HERE / "routes.json")
    capabilities = {r["id"]: r for r in spec["capabilities"]}
    manifests, candidates, units, inputs = [], [], [], {}
    seen = set()

    def pin(path):
        path = path.resolve()
        relative = path.relative_to(ROOT).as_posix()
        inputs[relative] = digest(path)
        return relative

    def mapped(set_name, groups):
        result = []
        for group in groups:
            assert group in routes["groups"][set_name], (set_name, group)
            result += routes["groups"][set_name][group]
        return sorted(set(result))

    def add(candidate, pointer, kind, groups, context=None):
        value = resolve(candidate["document"], pointer)
        assert value is not None
        ids = sorted(set(groups))
        assert ids and all(g in capabilities for g in ids), (candidate["path"], pointer, ids)
        row = {"candidate": candidate["key"], "pointer": pointer, "kind": kind,
               "capabilities": ids}
        if context:
            row["context"] = context
        # Small exact text makes filtering useful without copying full bodies.
        if isinstance(value, str):
            row["clause"] = value
        units.append(row)

    for set_name in SETS:
        folder = PREP / set_name
        index = read(folder / "index.json")
        pin(folder / "index.json")
        extensions = read(folder / "required-extensions.json")
        pin(folder / "required-extensions.json")
        assert set(routes["groups"][set_name]) == {g["id"] for g in extensions["groups"]}
        entries = index.get("spells", index.get("candidates"))
        manifests.append({"set": set_name, "indexed_references": len(entries)})
        for entry in entries:
            path = (folder / entry.get("file", entry.get("path", ""))).resolve()
            relative = path.relative_to(ROOT).as_posix()
            if relative in seen:
                continue
            seen.add(relative)
            d = read(path)
            c = {"key": set_name + ":" + d["id"], "set": set_name,
                 "id": d["id"], "path": pin(path), "sha256": digest(path),
                 "kind": d.get("kind", "spell"), "document": d}
            candidates.append(c)
        if set_name == "crown-characters":
            path = folder / "multiclass.json"
            d = read(path)
            candidates.append({"key": set_name + ":" + d["id"], "set": set_name,
                               "id": d["id"], "path": pin(path), "sha256": digest(path),
                               "kind": d["kind"], "document": d})
        # Preserve complete dependency/acquisition/source maps, not just samples.
        for path in sorted(folder.glob("*.json")):
            if path.name not in {"index.json", "required-extensions.json"} and path.resolve().as_posix() not in seen:
                if path.name in {"source-pages.json", "packages.json", "languages.json",
                                 "dependency-map.json", "acquisition-links.json", "consumer-trace.json",
                                 "selection-links.json", "reachability.json", "spell-materials.json",
                                 "created-item-boundaries.json", "animal-source-inventory.json"}:
                    pin(path)

    for c in candidates:
        d, name = c["document"], c["set"]
        override = routes["candidates"].get(c["key"], {})
        common = override.get("default", [])
        if name == "crown-spells":
            groups = mapped(name, [e["group"] for e in d.get("required_extensions", [])])
            common = common or groups or ["BASE"]
            add(c, "/casting", "casting_contract", ["CAST", "COMPONENT", "LIFETIME"])
            for i, rule in enumerate(d["rules"]):
                exact = override.get("rules", {}).get(rule["id"], common)
                add(c, f"/rules/{i}/text", "source_clause", exact, {"rule_id": rule["id"]})
            for i, operation in enumerate(d["authored_operations"]):
                add(c, f"/authored_operations/{i}", "operation_sequence", common,
                    {"source_rule_ids": operation.get("required_source_rules", [])})
            for i, extension in enumerate(d.get("required_extensions", [])):
                add(c, f"/required_extensions/{i}", "authoring_requirement",
                    common if extension["group"] == "retained_conversion_limit" else mapped(name, [extension["group"]]))
        elif name == "crown-characters":
            common = common or ["ACQUIRE", "CHOICE"]
            for field, groups in {"source": ["ACQUIRE", "MULTI"],
                                  "acquisition": ["ACQUIRE", "PACK", "MULTI"],
                                  "casting": ["CAST"], "weapon_mastery": ["WEAPON", "CHOICE"],
                                  "level_hit_points": ["ACQUIRE", "MULTI"],
                                  "classes": ["MULTI"], "definition": common,
                                  "rules": common}.items():
                if field in d:
                    add(c, "/" + field, "source_and_structured_rule", groups)
            for i, feature in enumerate(d.get("features", [])):
                fgroups = routes["features"].get(feature["id"])
                assert fgroups, ("missing feature route", feature["id"])
                add(c, f"/features/{i}/rules", "feature_source", fgroups,
                    {"feature": feature["id"], "class_level": feature["class_level"]})
                for j, op in enumerate(feature.get("authored_operations", [])):
                    add(c, f"/features/{i}/authored_operations/{j}", "operation_sequence", fgroups,
                        {"feature": feature["id"], "source_pointer": f"/features/{i}/rules"})
                for j, _ in enumerate(feature.get("unsupported_behavior", [])):
                    add(c, f"/features/{i}/unsupported_behavior/{j}", "retained_blocker", fgroups)
            for i, op in enumerate(d.get("authored_operations", [])):
                ogroups = override.get("operations", {}).get(str(i), common)
                add(c, f"/authored_operations/{i}", "operation_sequence", ogroups,
                    {"source_pointer": "/rules"})
            for field in ["unsupported_behavior", "equipment_resolution"]:
                for i, blocker in enumerate(d.get(field, [])):
                    bgroups = mapped(name, blocker["groups"]) if isinstance(blocker, dict) and blocker.get("groups") else common
                    add(c, f"/{field}/{i}", "retained_blocker", bgroups if field != "equipment_resolution" else ["PACK", "COMPONENT"])
        elif name in ["crown-equipment", "crown-reachable-items"]:
            common = common or mapped(name, d["required_mapping"])
            for field in ["rules", "definition"]:
                add(c, "/" + field, "source_and_structured_rule", common)
            for i, _ in enumerate(d["authored_operations"]):
                add(c, f"/authored_operations/{i}", "operation_sequence",
                    override.get("operations", {}).get(str(i), common), {"source_pointer": "/rules"})
            for i, blocker in enumerate(d.get("unsupported_behavior", [])):
                bgroups = mapped(name, [blocker["group"]]) if isinstance(blocker, dict) and blocker.get("group") in routes["groups"][name] else common
                add(c, f"/unsupported_behavior/{i}", "retained_blocker", bgroups)
                if isinstance(blocker, dict) and blocker.get("group") == "definition":
                    units[-1]["work_kinds"] = ["content_wiring", "gameplay_proof"]
                    units[-1]["assessment"] = "Missing production definition/seed is content wiring, not evidence of an absent engine operation."
            for field in ["reconciliation_note", "pricing_reconciliation"]:
                if field in d:
                    add(c, "/" + field, "source_or_policy_question", common)
        elif name == "crown-creatures":
            default = {"srd_statblock": ["ACTOR"], "campaign_encounter": ["ACTOR", "MONSTER_REWARD"],
                       "campaign_companion": ["COMPANION"], "spell_actor_template": ["ACTOR", "COMMAND"],
                       "spell_force_or_image": ["CREATION"]}
            common = common or default[d["kind"]]
            for field in ["source", "statistics", "selection", "rules", "representation", "actor_parameters",
                          "in_band_parameters", "source_differences", "source_reconciliation",
                          "conversion_policy", "explicit_blockers", "loot"]:
                if field in d:
                    groups = ["MONSTER_REWARD"] if field == "loot" else common
                    add(c, "/" + field, "source_selection_or_policy", groups)
            for i, op in enumerate(d["authored_operations"]):
                hints = [s["mapping_group"] for s in op.get("steps", []) if isinstance(s, dict) and "mapping_group" in s]
                hints += [b[4:] for b in op.get("blockers", []) if b.startswith("map_")]
                groups = mapped(name, ["map_" + s for s in set(hints)]) if hints else common
                groups = override.get("operations", {}).get(str(i), groups)
                add(c, f"/authored_operations/{i}", "behavior_sequence", groups,
                    {"name": op.get("name", op.get("key", op.get("operation", "")))})
                for field in ["full_rule", "full_rule_payload", "behavior_plan"]:
                    if field in op:
                        add(c, f"/authored_operations/{i}/{field}", "exact_behavior_clause", groups)
            for i, _ in enumerate(d.get("blockers", [])):
                blocker = d["blockers"][i]
                groups = mapped(name, [blocker]) if blocker in routes["groups"][name] else common
                add(c, f"/blockers/{i}", "retained_blocker", groups)
        else:
            common = common or mapped(name, d["required_extensions"])
            for field in ["source_parameters", "retained_input"]:
                if field in d:
                    pointer = "/retained_input/payload" if field == "retained_input" else "/source_parameters"
                    add(c, pointer, "complete_source_seed", common)
            for i, op in enumerate(d["authored_operations"]):
                groups = override.get("operations", {}).get(str(i), common)
                context = {}
                if isinstance(op, dict) and "seed_pointer" in op:
                    context["seed_pointer"] = "/retained_input/payload" + op["seed_pointer"]
                    resolve(d, context["seed_pointer"])
                add(c, f"/authored_operations/{i}", "world_sequence", groups, context)
            for i, _ in enumerate(d.get("blockers", [])):
                add(c, f"/blockers/{i}", "retained_blocker", common)

    # Supplemental acquisition/dependency occurrences keep their own identities.
    for relative, sha in list(inputs.items()):
        if relative.endswith(("source-pages.json", "index.json")):
            continue
        if relative in seen or relative.endswith("multiclass.json"):
            continue
        d = read(ROOT / relative)
        if relative.endswith("required-extensions.json"):
            set_name = Path(relative).parent.name
            for i, group in enumerate(d["groups"]):
                units.append({"candidate": relative, "pointer": f"/groups/{i}",
                              "kind": "extension_group", "capabilities": mapped(set_name, [group["id"]])})
            for i, blocker in enumerate(d.get("additional_blockers", [])):
                units.append({"candidate": relative, "pointer": f"/additional_blockers/{i}",
                              "kind": "source_or_policy_question", "capabilities": ["ACTOR", "FORM", "REMAINS"],
                              "work_kinds": ["source_fact", "campaign_policy"]})
            continue
        groups = routes["supplements"][Path(relative).name]
        # Each top-level collection member remains addressable; source context
        # text stays in its pinned file and is never reduced to extracted nums.
        for key, value in d.items():
            if isinstance(value, list):
                for i, _ in enumerate(value):
                    units.append({"candidate": relative, "pointer": f"/{esc(key)}/{i}",
                                  "kind": "dependency_or_acquisition", "relation_only": True, "capabilities": groups})
            elif isinstance(value, dict):
                units.append({"candidate": relative, "pointer": "/" + esc(key),
                              "kind": "dependency_or_acquisition", "relation_only": True, "capabilities": groups})

    # Snapshot current contracts/source, not old gap-report status.
    assert set(routes["candidates"]) <= {c["key"] for c in candidates}, "Unknown candidate override."
    actual_features = {f["id"] for c in candidates for f in c["document"].get("features", [])}
    assert set(routes["features"]) == actual_features, "Feature routing inventory drift."
    for c in candidates:
        override = routes["candidates"].get(c["key"], {})
        assert all(int(i) < len(c["document"].get("authored_operations", [])) for i in override.get("operations", {})), c["key"]
        assert set(override.get("rules", {})) <= {r["id"] for r in c["document"].get("rules", []) if isinstance(r, dict)}, c["key"]
    for cap in capabilities.values():
        for path in cap["evidence"]:
            pin(ROOT / path)
        assert cap["id"] not in cap["prerequisites"]
        assert all(g in capabilities for g in cap["prerequisites"])
        assert all(capabilities[g]["order"] < cap["order"] for g in cap["prerequisites"]), cap["id"]
        assert all(g in capabilities for g in cap.get("conditional_prerequisites", {}))
    pin(ROOT / "docs/planning/vocabulary-slices.md")
    pin(ROOT / "docs/planning/crown-spell-conversion-queue.csv")
    # Every operation, complete authored rule and explicit blocker needs a unit
    # at that pointer or an ancestor. Donor seeds are pinned comparison inputs,
    # never interpreted as a second grant list.
    required_keys = {"authored_operations", "rules", "unsupported_behavior", "blockers", "explicit_blockers"}
    for c in candidates:
        owned = [u["pointer"] for u in units if u["candidate"] == c["key"]]
        def coverage(value, pointer=""):
            if any(pointer == p or pointer.startswith(p + "/") for p in owned):
                return
            if isinstance(value, dict):
                for key, child in value.items():
                    if key.startswith("retained_") or key in {"revised_reference_entries", "reused_from"}:
                        continue
                    cp = pointer + "/" + esc(key)
                    if key in required_keys and child:
                        descendants = [p for p in owned if p.startswith(cp + "/")]
                        assert descendants or cp in owned, ("uncovered", c["path"], cp)
                    coverage(child, cp)
            elif isinstance(value, list):
                for i, child in enumerate(value):
                    coverage(child, pointer + "/" + str(i))
        coverage(c["document"])
    for i, unit in enumerate(units, 1):
        unit["id"] = f"R{i:05}"
    clean = [{k: v for k, v in c.items() if k != "document"} for c in candidates]
    return {"schema": "crown-cross-set-engine-mapping/1", "status": "planning_only_no_gameplay_acceptance",
            "routing_semantics": "Capability facets of the complete pointed sequence; the source clause and all qualifiers remain mandatory. A facet is not a support verdict or an executable operation.",
            "sets": manifests, "candidates": clean, "units": units, "pinned_inputs": dict(sorted(inputs.items()))}


def render(data):
    # One exact-pointer unit per line keeps the tracked ledger reviewable.
    parts = ["{"]
    for key, value in data.items():
        label = json.dumps(key) + ": "
        if key == "units":
            body = "[\n" + ",\n".join("    " + json.dumps(u, ensure_ascii=False) for u in value) + "\n  ]"
        else:
            body = json.dumps(value, ensure_ascii=False, indent=2).replace("\n", "\n  ")
        parts.append("  " + label + body + ("," if key != list(data)[-1] else ""))
    parts.append("}")
    return "\n".join(parts) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--consumer")
    parser.add_argument("--capability")
    args = parser.parse_args()
    data = build()
    target = HERE / "requirements.json"
    rendered = render(data)
    if args.check:
        assert target.read_text(encoding="utf-8") == rendered, "Mapping or source pins changed; inspect before rebuilding."
        print(f"OK: {len(data['candidates'])} unique candidates, {len(data['units'])} exact-pointer units; all six extension sets, dependency maps, source pins and assignment prerequisites checked. No gameplay checks.")
    elif args.consumer or args.capability:
        candidates = {c["key"]: c for c in data["candidates"]}
        for u in data["units"]:
            if args.consumer and args.consumer not in u["candidate"]:
                continue
            if args.capability and args.capability not in u["capabilities"]:
                continue
            c = candidates.get(u["candidate"], {"path": u["candidate"]})
            print(u["id"], c["path"] + "#" + u["pointer"], ",".join(u["capabilities"]))
    else:
        target.write_text(rendered, encoding="utf-8")
        print(f"Wrote {len(data['candidates'])} candidates / {len(data['units'])} pointer units.")


if __name__ == "__main__":
    main()
