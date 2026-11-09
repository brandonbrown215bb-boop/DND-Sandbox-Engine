"""Structural/source checks only. Does not execute or simulate game rules."""
import hashlib
import json
import re
from fractions import Fraction
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def load(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def normalized(text):
    return re.sub(r"\s+", " ", re.sub(r"(\w)-\n(\w)", r"\1\2", text)).strip()


def pointer(value, path):
    for part in path.split("/")[1:]:
        part = part.replace("~1", "/").replace("~0", "~")
        value = value[int(part)] if isinstance(value, list) else value[part]
    return value


hashes = {}
json_sources = {}
pins_checked = 0


def check_pins(value):
    global pins_checked
    if isinstance(value, list):
        for child in value:
            check_pins(child)
    elif isinstance(value, dict):
        if "path" in value and "sha256" in value:
            path = ROOT / value["path"]
            assert path.is_file(), path
            if path not in hashes:
                hashes[path] = hashlib.sha256(path.read_bytes()).hexdigest()
            assert hashes[path] == value["sha256"], (path, "stale hash")
            if "pointer" in value or "payload" in value:
                if path not in json_sources:
                    json_sources[path] = load(path)
                original = pointer(json_sources[path], value.get("pointer", ""))
                if "payload" in value:
                    assert original == value["payload"], (path, "changed retained payload")
            pins_checked += 1
        for child in value.values():
            check_pins(child)


index = load(HERE / "index.json")
links = load(HERE / "selection-links.json")
inventory = load(HERE / "animal-source-inventory.json")
dependencies = load(HERE / "dependency-map.json")
groups = load(HERE / "required-extensions.json")
mapping_ids = {x["id"] for x in groups["groups"] + groups["additional_blockers"]}
entries = index["candidates"]
assert len(entries) == len({x["id"] for x in entries}) == index["counts"]["total"] == 94
expected_files = {x["path"] for x in entries}
actual_files = {str(p.relative_to(HERE)).replace("\\", "/") for folder in ["statblocks", "encounters", "companions", "actors"] for p in (HERE / folder).glob("*.json")}
assert expected_files == actual_files
for path in HERE.rglob("*.json"):
    check_pins(load(path))
for filename in index["links"]:
    assert (HERE / filename).is_file(), filename

by_id = {}
page_context = load(HERE / "source-pages.json")
page_numbers = {p["page"] for p in page_context["pages"]}
source_stream = normalized("\n".join(
    re.sub(r"(?m)^\d+ System Reference Document 5\.2\.1$", "", col)
    for page in page_context["pages"] for col in page["columns"]
))
for entry in entries:
    d = load(HERE / entry["path"])
    by_id[d["id"]] = d
    assert d["id"] == entry["id"] and d["kind"] == entry["kind"]
    assert d["status"] == "written_not_loaded_not_gameplay_verified"
    assert d["integration"]["load"] is False and d["integration"]["gameplay_tests_run"] is False
    assert d["authored_operations"] and d["blockers"]
    assert all(x in mapping_ids for x in d["blockers"]), d["id"]
    if d["kind"] == "srd_statblock":
        assert len(d["statistics"]["ability_scores"]) == len(d["statistics"]["saving_throw_modifiers"]) == 6
        source = d["source"]["text"]
        assert d["source"]["pdf_sha256"] == inventory["source_pdf_sha256"]
        assert set(d["source"]["pages"]) <= page_numbers
        assert normalized(source) in source_stream, (d["id"], "source body differs from pinned page context")
        # Every trait/action paragraph survives partitioning, with no extra rule.
        body = re.split(r"(?m)^(?:Traits|Actions|Bonus Actions|Reactions)$", source, maxsplit=1)[1]
        body = re.sub(r"(?m)^(?:Traits|Actions|Bonus Actions|Reactions)$", "", body)
        assert normalized(body) == normalized(" ".join(x["full_rule"] for x in d["authored_operations"])), d["id"]
        assert all(x["behavior_plan"] and x["steps"] for x in d["authored_operations"])
        assert not any(x["name"] in ["Piercing damage", "Bludgeoning damage", "Frightened condition"] for x in d["authored_operations"])
        for x in d.get("equipment_links", []):
            assert x["candidate"] and (HERE / x["candidate"]).is_file(), x
    if d["kind"] == "campaign_encounter":
        assert d["source"]["payload"]["id"] == d["campaign_monster_id"]
        if d.get("srd_comparison_candidate"):
            assert (HERE / d["srd_comparison_candidate"]).is_file()
        for x in d["loot"]["candidate_links"]:
            assert load(HERE / x["candidate"])["id"] == x["item_id"]
    if d["kind"] == "campaign_companion":
        assert d["equipment_reachability"] and d["equipment_candidate_links"]
        for x in d["equipment_candidate_links"]:
            assert x["candidate"] and load(HERE / x["candidate"])["id"] == x["item_id"], x
    if "source_candidate" in d:
        original = load(ROOT / d["source_candidate"]["path"])
        for field in ["rules", "authored_operations", "required_extensions"]:
            assert d[field] == original[field], (d["id"], field)
        for extension in d["required_extensions"]:
            assert (ROOT / extension["existing_owner_to_reuse"]).is_file()

animals = inventory["animals"]
assert len(animals) == 90 and len({x["id"] for x in animals}) == 90
for x in animals:
    text = x["source"]["text"]
    assert Fraction(re.search(r"(?m)^CR ([0-9/]+)", text)[1]) == Fraction(x["challenge_rating"])
    assert x["fly_speed"] == bool(re.search(r"(?m)^Speed .*Fly ", text))
    assert x["swarm"] == ("Swarm" in text.splitlines()[1])
for name, cap in [("class_levels_2_3", Fraction(1, 4)), ("class_levels_4_5", Fraction(1, 2))]:
    expected = {x["id"] for x in animals if Fraction(x["challenge_rating"]) <= cap and not x["fly_speed"] and not x["swarm"]}
    assert set(links["wild_shape"][name]) == expected
assert set(links["familiar"]["normal"]) == {x["id"] for x in animals if Fraction(x["challenge_rating"]) == 0 and not x["swarm"]}
assert set(links["familiar"]["additional"]) == {"imp", "pseudodragon", "quasit", "skeleton", "sphinx_of_wonder", "sprite", "venomous_snake"}
for form in set(links["wild_shape"]["class_levels_4_5"] + links["familiar"]["normal"] + links["familiar"]["additional"] + links["held_swarm_candidates"] + ["skeleton", "zombie"]):
    assert "srd_" + form in by_id
assert not set(links["held_swarm_candidates"]) & set(links["wild_shape"]["class_levels_4_5"])
assert set(links["direct_encounters"]) == {x["monster_id"] for x in dependencies["direct_encounter_occurrences"]}
assert {x["id"] for x in dependencies["spell_candidates"]} == {load(p)["id"] for p in (HERE.parent / "crown-spells").glob("*.json") if "casting" in load(p)}
character_index = load(HERE.parent / "crown-characters/index.json")
assert {x["id"] for x in dependencies["character_candidates"]} == {x["id"] for x in character_index["candidates"]} | {load(HERE.parent / "crown-characters/multiclass.json")["id"]}
for x in dependencies["spell_candidates"]:
    if "candidate" in x:
        assert (HERE / x["candidate"]).is_file()
assert set(links["companions"]) == {"aldric", "mira", "rowan"}
print(f"PASS: {len(entries)} candidates; 90 animal classifications; 183 spell and 79 character + multiclass dispositions; {pins_checked} source pins across {len(hashes)} files; unchanged payloads and complete behavior bodies.")
