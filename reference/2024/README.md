# Revised class reference view

For source-preparation tasks, read only the selected file in `classes/` first.
These twelve class files contain the local **XPHB revised records only**, with
their feature/subclass records. Artificer, Mystic, 2014 records and unrelated
supplement records are outside this view.

The view is a mechanical extraction, not curated rule interpretation. Records
are copied unchanged from [the original mixed-edition inputs](../../5etools%20raw/README.md).
SRD 5.2.1 remains the staged milestone's authority. An `srd52` flag does not
verify a rule, and a missing flag does not supply a missing official source.
The broader revised subclasses here are reference requirements, not a claim that
they are all in the SRD or implemented by the game.

| Task | Use |
|---|---|
| Read Fighter or Wizard source | [Fighter](classes/fighter.json), [Wizard](classes/wizard.json); other classes have the same filename convention. |
| Recover exact original coordinates | [source-index.json](source-index.json): each output array index maps to the same-position entry in `raw_indices`, identifying the original array index. Each input has its SHA-256. |
| Check current game behavior | [Authoring contracts](../../docs/mechanics/README.md), relevant mechanics contract, runtime source and production evidence. These reference JSON files are not loaded by the game. |
| Locate unsupported or absent rules | Record the exact missing body/reference. Do not fill it from memory or treat current code as a rule source. |

Select records by name/source/class identity; do not guess array positions.
References inside records may still point to absent feat, item, book or spell
bodies. Extraction does not resolve those references, repair inconsistencies,
add general multiclass rules, or certify official-source coverage.

Rebuild after intentional original-source updates:

```powershell
python scripts/build_revised_class_reference.py
python scripts/build_revised_class_reference.py --check
```

Edit original sources only for an authorized source update, not to repair a game
definition. Generated view files are not a place to author runtime behavior.
