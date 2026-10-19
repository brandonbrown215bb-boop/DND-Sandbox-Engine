"""Build a reference-only XPHB view without changing mixed-edition raw inputs.

This copies selected records verbatim. It does not translate rules, resolve
external references, certify SRD coverage, or promote anything into runtime data.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "reference" / "2024"
CLASSES = (
    "barbarian", "bard", "cleric", "druid", "fighter", "monk",
    "paladin", "ranger", "rogue", "sorcerer", "warlock", "wizard",
)
GROUPS = ("class", "subclass", "classFeature", "subclassFeature")


def encode(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def expected_files() -> dict[Path, str]:
    files: dict[Path, str] = {}
    manifest = {
        "reference_only": True,
        "source": "XPHB",
        "rule_authority": "SRD 5.2.1 is separate; metadata is not verification.",
        "classes": [],
    }
    for class_id in CLASSES:
        raw = ROOT / "5etools raw" / "class" / f"class-{class_id}.json"
        payload = raw.read_bytes()
        source = json.loads(payload)
        primary = [r for r in source["class"] if r.get("source") == "XPHB"]
        if len(primary) != 1 or primary[0].get("edition") != "one":
            raise ValueError(f"Expected one revised class in {raw.name}")
        name = primary[0]["name"]
        view: dict[str, list] = {}
        indices: dict[str, list[int]] = {}
        for group in GROUPS:
            selected = []
            for index, record in enumerate(source.get(group, [])):
                if record.get("source") != "XPHB":
                    continue
                if group == "class":
                    eligible = record.get("name") == name
                else:
                    eligible = (
                        record.get("classSource") == "XPHB"
                        and record.get("className") == name
                    )
                if eligible:
                    selected.append((index, record))
            indices[group] = [index for index, _ in selected]
            view[group] = [record for _, record in selected]
        destination = OUTPUT / "classes" / f"{class_id}.json"
        files[destination] = encode(view)
        manifest["classes"].append({
            "id": class_id,
            "raw_file": raw.relative_to(ROOT).as_posix(),
            "raw_sha256": hashlib.sha256(payload).hexdigest(),
            "view_file": destination.relative_to(ROOT).as_posix(),
            "raw_indices": indices,
        })
    files[OUTPUT / "source-index.json"] = encode(manifest)
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check without writing")
    args = parser.parse_args()
    files = expected_files()
    stale = []
    for path, content in files.items():
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != content:
                stale.append(path.relative_to(ROOT).as_posix())
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8", newline="\n")
    extra = set((OUTPUT / "classes").glob("*.json")) - set(files)
    stale.extend(p.relative_to(ROOT).as_posix() for p in sorted(extra))
    if stale:
        print("Reference view needs review: " + ", ".join(stale))
        return 1
    print(f"{'Checked' if args.check else 'Built'} {len(CLASSES)} revised class references; raw inputs unchanged.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
