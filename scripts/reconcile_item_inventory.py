"""Reconcile the exported production item registry against SRD 5.2.1 entry lists.

Inputs: .artifacts/items-audit/runtime.json (scenes/item_inventory_export.tscn),
.artifacts/items-audit/{mi,eq}.xml (pdftohtml -xml of SRD_CC_v5.2.1.pdf pages 209-253, 89-106).
Writes .artifacts/items-audit/reconciliation.json. No content is changed.
"""
import html, json, re, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
A = ROOT / ".artifacts/items-audit"

def texts(name):
    x = (A / name).read_text()
    return [(f, re.sub("<.*?>", "", html.unescape(s)).strip()) for f, s in re.findall(r'<text [^>]*font="(\d+)"[^>]*>(.*?)</text>', x)]

def norm(s):
    s = s.lower().replace("’", "'").replace("'", "")
    s = re.sub(r"\(.*?\)", "", s)
    return re.sub(r"[^a-z0-9]+", "_", s).strip("_")

HEAD = re.compile(r"^(Armor|Weapon|Wondrous|Potion|Ring|Rod|Scroll|Staff|Wand)")
def _magic_with_text():
    items = magic_items()
    (A / "srd_magic_text.json").write_text(json.dumps({e["name"]: e["_text"] for e in items}, indent=1, ensure_ascii=False))
    for e in items: e.pop("_at"); e.pop("_text")
    return items

def magic_items():
    t = texts("mi.xml"); out = []; i = 0
    while i < len(t):
        f, s = t[i]
        if f in ("5", "15") and s:
            name = s
            while i + 1 < len(t) and t[i + 1][0] == f and not HEAD.match(t[i + 1][1]):
                i += 1; name += " " + t[i][1]
            j = i + 1
            while j < len(t) and not t[j][1]: j += 1
            if j < len(t) and HEAD.match(t[j][1]):
                out.append({"name": name, "category": "magic_item", "line": t[j][1], "_at": j})
        i += 1
    # Body text = every text run between this entry's type line and the next entry's heading.
    for k, e in enumerate(out):
        end = out[k + 1]["_at"] - 1 if k + 1 < len(out) else len(t)
        e["_text"] = re.sub(r"\s+", " ", " ".join(s for _, s in t[e["_at"]:end] if not s.startswith("System Reference Document"))).strip()
    return out

WEAPONS = "Club Dagger Greatclub Handaxe Javelin|Light Hammer|Mace Quarterstaff Sickle Spear Dart|Light Crossbow|Shortbow Sling Battleaxe Flail Glaive Greataxe Greatsword Halberd Lance Longsword Maul Morningstar Pike Rapier Scimitar Shortsword Trident Warhammer|War Pick|Whip Blowgun|Hand Crossbow|Heavy Crossbow|Longbow Musket Pistol"
ARMOR = ["Padded Armor", "Leather Armor", "Studded Leather Armor", "Hide Armor", "Chain Shirt", "Scale Mail", "Breastplate", "Half Plate Armor", "Ring Mail", "Chain Mail", "Splint Armor", "Plate Armor", "Shield"]
def weapon_names():
    out = []
    for chunk in WEAPONS.split("|"):
        out += [chunk] if " " in chunk and chunk[0].isupper() and chunk.count(" ") == 1 and chunk in ("Light Hammer", "Light Crossbow", "War Pick", "Hand Crossbow", "Heavy Crossbow") else chunk.split()
    return out

def gear():
    out = []
    for f, s in texts("eq.xml"):
        m = re.match(r"^([A-Z][\w’' ,\-]+?) \(([\d,]+ (?:CP|SP|GP|EP|PP)|Varies)\)$", s)
        if f == "12" and m: out.append({"name": m.group(1), "category": "equipment_entry", "cost": m.group(2)})
    return out

# SRD entries that define a family of variants; loaded variant ids count as that entry.
FAMILIES = {
    "potions_of_healing": r"^potion_(of_)?(greater_|superior_|supreme_)?healing$",
    "potion_of_giant_strength": r"^potion_of_\w+_giant_strength$",
    "potion_of_resistance": r"^potion_of_\w+_resistance$",
    "dragon_scale_mail": r"^\w+_dragon_scale_mail$",
    "armor_of_vulnerability": r"^armor_of_vulnerability",
    "musical_instrument": r"^(bagpipes|drum|dulcimer|flute|horn|lute|lyre|pan_flute|shawm|viol)$",
    "gaming_set": r"(dice|playing_card|dragonchess|three_dragon|gaming)",
    "arcane_focus": r"^arcane_(crystal|orb|rod|staff|wand)$",
    "druidic_focus": r"^(sprig_of_mistletoe|wooden_staff|yew_wand|totem)$",
    "holy_symbol": r"^(amulet|emblem|reliquary|holy_symbol)$",
    "ammunition": r"^(arrows?|bolts?|bullets?|needles?)$",
}

def main():
    rt = json.loads((A / "runtime.json").read_text())
    items = {i["id"]: i for i in rt["items"]}
    by_norm = {}
    for i in rt["items"]:
        for k in {norm(i["id"]), norm(i["name"])}: by_norm.setdefault(k, i["id"])
    srd = [{"name": n, "category": "weapon"} for n in weapon_names()] + [{"name": n, "category": "armor"} for n in ARMOR] + gear() + _magic_with_text()
    for e in srd:
        k = norm(e["name"]); cands = [k, k + "_armor", k.replace("_armor", "")]
        if "," in e["name"] and "+" not in e["name"]:
            a, b = e["name"].split(",", 1); cands.append(norm(b + " " + a))
        e["loaded_id"] = next((by_norm[c] for c in cands if c in by_norm), "")
        fam = FAMILIES.get(k)
        e["loaded_variants"] = sorted(i for i in items if fam and re.search(fam, i))
        if not e["loaded_id"] and e["loaded_variants"]: e["loaded_id"] = e["loaded_variants"][0]
    out = {"runtime_registry_hash_sha256": rt["registry_hash_sha256"], "loaded_unique_items": len(items), "srd_entries": srd,
           "srd_missing": [e for e in srd if not e["loaded_id"]],
           "loaded_not_srd_matched": sorted(set(items) - {e["loaded_id"] for e in srd} - {v for e in srd for v in e["loaded_variants"]})}
    mastery_table = dict(re.findall(r'"(\w+)": "(\w+)"', (ROOT / "src/characters/fighter_rules.gd").read_text().split("static func")[0]))
    out["weapon_field_diffs"] = compare_weapons(items, mastery_table)
    out["loaded_magic_rule_fields"] = magic_rule_fields(items, srd)
    (A / "reconciliation.json").write_text(json.dumps(out, indent=1))
    from collections import Counter
    print("loaded", len(items), "srd", Counter(e["category"] for e in srd), "missing", Counter(e["category"] for e in out["srd_missing"]), "loaded_unmatched", len(out["loaded_not_srd_matched"]))



def srd_weapon_rows():
    """Parse the SRD Weapons table (pdftotext -layout pages 89-106 -> eq.txt)."""
    rows, cur = {}, None
    lines = (A / "eq.txt").read_text().splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip() == "Simple Melee Weapons")
    for l in lines[start:]:
        if l.strip().startswith("91") or l.strip() == "Armor": break
        m = re.match(r"^\s{4,8}([A-Z][A-Za-z ]+?)\s+(\d+d?\d*) (\w+)\s{2,}(.+?)\s{2,}(\w+)\s+(\S+(?: lb\.)?)\s+(\d+ \w\w)\s*$", l)
        if m:
            cur = norm(m.group(1)); rows[cur] = {"damage": m.group(2), "damage_type": m.group(3).lower(), "properties": m.group(4), "mastery": m.group(5).lower(), "weight": m.group(6), "cost": m.group(7)}
        elif cur and re.match(r"^\s{30,}\S", l) and len(l.strip()) < 40:
            rows[cur]["properties"] += " " + l.strip()
    return rows

def compare_weapons(items, mastery_table):
    out = {}
    for wid, s in srd_weapon_rows().items():
        i = items.get(wid, {}); props = s["properties"].lower(); diffs = []
        if i.get("damage") != s["damage"]: diffs.append(f"damage {i.get('damage')} vs SRD {s['damage']}")
        if i.get("damage_type") != s["damage_type"]: diffs.append(f"damage_type {i.get('damage_type')} vs {s['damage_type']}")
        if i.get("mastery", "") != s["mastery"]: diffs.append(f"item mastery {i.get('mastery')!r} vs {s['mastery']}")
        if mastery_table.get(wid, "") != s["mastery"]: diffs.append(f"FighterRules table {mastery_table.get(wid)!r} vs {s['mastery']}")
        lp = set(i.get("properties", []))
        for p in ["ammunition", "finesse", "heavy", "light", "loading", "reach", "thrown", "two_handed", "versatile"]:
            if (p.replace("_", "-") in props) != (p in lp): diffs.append(f"property {p}: loaded={p in lp} SRD={p.replace('_','-') in props}")
        rng = re.search(r"range (\d+)/(\d+)", props)
        if rng: diffs.append(f"long range {rng.group(2)} ft not represented (loaded range={i.get('range')}, thrown_range={i.get('thrown_range')})")
        out[wid] = {"srd": s, "loaded_source": i.get("_source_record", ""), "diffs": diffs}
    return out


RULE_FIELDS = ["magical", "effects", "requires_attunement", "cursed", "maximum_charges", "charge_recovery", "activation",
               "last_charge_aftermath", "source_benefits", "weapon_bonus", "armor_bonus", "container", "linked"]

def magic_rule_fields(items, srd):
    """For every loaded item matched to an SRD *magic* entry, list which rule-bearing fields it carries."""
    out = {}
    for e in srd:
        if e["category"] != "magic_item": continue
        for iid in sorted(set(([e["loaded_id"]] if e["loaded_id"] else []) + e["loaded_variants"])):
            i = items[iid]
            present = [f for f in RULE_FIELDS if i.get(f) not in (None, [], {}, False, "")]
            out[iid] = {"srd_name": e["name"], "srd_line": e.get("line", ""), "type": i["type"], "source": i["_source_record"],
                        "rule_fields": present, "use_status": "", "stub": not present}
    return out


if __name__ == "__main__": main()
