# Items & Equipment audit (priority 2) — batch 1

Status: **partial**. Batch 1 is an inventory reconciliation for every SRD item, plus a clause-level breakdown of *ordinary weapons and armor* and of the *general* magic-item rules. Individual magic-item entries are **not** broken down clause by clause yet (see Coverage). This is a docs/audit file only. It changes no runtime code, content or availability.

## Provenance

| | |
|---|---|
| Base commit | `ede0a3cdfa66f21b0b3415f498c2e186e56a0db4` (origin/main, 2026-10-26 07:40 CDT) |
| Runner | **Linux headless Godot 4.7.2.stable.official.ed1daf0bf** (`Godot_v4.7.2-stable_linux.x86_64 --headless`). The Windows runner was unreachable, so this is not a Windows result. |
| Inventory source | Initialized production `DataLoader` autoload (`get_all_items()`), with no fixtures |
| Registry | 289 unique items, 362 spells, 481 monsters, 0 validation failures (the existing warning about 25 effectless feature records was rejected) |
| `registry_hash_sha256` | `70a83cc74e530743e90f8fadc992bd0651f56b51cb84b06cd73fcaf22187845e` (sha256 of `DataLoader.get_registry_hash()`) |
| SRD text | SRD 5.2.1 PDF. Equipment pp.89–106, Magic Items pp.209–253. Every statement below comes from that text, not from memory. |

To rerun (artifacts are git-ignored under `.artifacts/items-audit/`):

```
godot --headless --path . res://scenes/item_inventory_export.tscn      # writes runtime.json
pdftotext -layout -f 89 -l 106 SRD_CC_v5.2.1.pdf .artifacts/items-audit/eq.txt
pdftohtml -xml -i -f 89 -l 106 SRD_CC_v5.2.1.pdf .artifacts/items-audit/eq
pdftohtml -xml -i -f 209 -l 253 SRD_CC_v5.2.1.pdf .artifacts/items-audit/mi
python3 scripts/reconcile_item_inventory.py                          # writes reconciliation.json
```

`scripts/export_item_inventory_node.gd` reports how each item can be used by copying the production `Inventory.consume()` gate: the item must be a consumable, it must have effects, and every effect must pass `EventResolver.is_effect_supported`. Light sources have their own path. The script adds no rules of its own.

## Totals

| SRD category | SRD entries | Loaded | Missing |
|---|---|---|---|
| Weapons (Weapons table) | 38 | 38 | 0 |
| Armor + Shield (Armor table) | 13 | 13 | 0 |
| Other equipment entries (gear, tools, packs, focuses) | 104 | 59 | 45 |
| Magic items | 258 | 66 entries (94 loaded records, counting variants) | 192 |

Loaded items that match no SRD entry: 67. These are supplement and future content (firearms, laser weapons, Blackrazor, Moonblade, Sword of Kas, Sword of Answering ×10, enspelled staffs, Whelm, Wave, Efreeti Chain, and others), campaign items (ashvale_brass_key, crown_fragment, dark_shard_amulet), and components or currency (gemstones, powders, gold, antidote, spellbook). They are outside this audit. Full list: `reconciliation.json → loaded_not_srd_matched`.

How the 289 loaded items can be used: 232 are not consumables; 46 consumables are **refused** ("no implemented effect"); 9 consumables are supported; 2 are light sources.

**Missing equipment (45):** Gaming Set; Ammunition; Barrel; Basket; Block and Tackle; Book; Bottle, Glass; Bucket; Burglar's / Diplomat's / Dungeoneer's / Scholar's Pack; Candle; Case, Crossbow Bolt; Case, Map or Scroll; Chain; Chest; Clothes, Fine / Traveler's; Flask; Grappling Hook; Hunting Trap; Ink; Ink Pen; Jug; Ladder; Lock; Magnifying Glass; Manacles; Map; Paper; Parchment; Perfume; Pole; Pot, Iron; Pouch; Quiver; Ram, Portable; Sack; Shovel; Signal Whistle; Spikes, Iron; String; Tent; Vial.

**Missing magic items (192):** listed in `reconciliation.json → srd_missing`. They include whole families the engine has none of: every ring except Protection, every rod, every Wand except Magic Missiles, Spell Scroll, Bag of Holding / Handy Haversack / Portable Hole, Armor/Weapon/Shield/Ammunition +1/+2/+3, Belt of Giant Strength, Ioun Stone, Figurine of Wondrous Power, Deck/Mysterious Deck, Ring of Three Wishes, Sphere of Annihilation, Sending Stones.

Name-matching caveats: matching uses normalized names plus a small family map. Spell Scroll and Gaming Set were spot-checked and really are absent; they are not naming misses. Sword of Vengeance is loaded but SRD 5.2.1 has no entry with that name.

## Finding F-1: most loaded SRD magic items have no rules

Of the 94 loaded records that match SRD magic items, **84 carry no rule-bearing field**. The fields checked are magical, effects, attunement, curse, charges, recovery, activation, aftermath, source_benefits, bonuses, container and links. The 84 split two ways:

- **Consumable stubs (46):** the potions and oils, apart from 4 healing potions and Potion of Poison / Poison Resistance. `consume()` refuses them, so this is **safe**.
- **Weapon / armor / shield / held-item stubs (38):** for example Oathbow (`ability: STR`, 1d8, range 30, no magic), Sun Blade, Mace of Disruption, Dwarven Thrower, Javelin of Lightning, every Dragon Scale Mail, Armor of Invulnerability, Animated Shield, and all staffs except Power and Striking. These pass the normal `can_equip` and attack paths as **plain mundane gear**. That is a fidelity problem, not a crash: the engine shows an item that does not do what its SRD text says. `identify_rules.gd` recognizes `imported_magic_*` sources, but nothing stops them from being equipped. Batch 1 did not check whether shop, loot or creation flows actually hand these out.
- Records that do carry rules: Wand of Magic Missiles (charges, dawn recovery, activation spell), Staff of Power and Staff of Striking (attunement, charges, recovery, last-charge aftermath, bonus), Ring of Protection (attunement, AC/save bonus, one-ring limit), the healing potions, and Potion of Poison / Poison Resistance.

Classification: content conversion against existing hosts. Most of these need no new vocabulary, only conversion, which is out of scope here. Whether to gate the 38 equippable stubs is an availability decision for the owner. This audit makes no change.

## Ordinary weapons (reviewed at clause level)

Field comparison of all 38 SRD weapons against the loaded records (`reconciliation.json → weapon_field_diffs`): damage, damage type and the finesse, heavy, light, loading, reach, thrown, two-handed and versatile flags **match for all 38**.

The diffs are:
- The **Ammunition** property is missing on all 9 ammunition weapons. The loader uses a `ranged` tag instead.
- **Long range** is not represented on any of the 16 ranged or thrown weapons. Only normal range is stored, in 5-ft cells.
- Musket and Pistol have no mastery in either the item record or the FighterRules table.

| Clause (SRD p.89–90) | Behavior | Classification | Owner / evidence |
|---|---|---|---|
| Category, proficiency | Simple/Martial; proficiency adds PB | existing supported (not re-tested) | `weapon_type` field; class proficiencies |
| Finesse | choose STR or DEX, same for attack and damage | existing supported | combat_action.gd, rogue/fighter rules |
| Light | extra Bonus Action attack with a different Light weapon, no positive modifier | existing supported | off-hand slot requires Light (`can_equip`) |
| Two-Handed | needs two hands | existing supported | `can_equip` blocks shield/off-hand |
| Versatile | larger die when wielded two-handed | existing supported | combat_action.gd:1169; `versatile_damage` on all 7 SRD versatile weapons |
| Loading | one shot per action/BA/reaction | existing supported (attack-action path only) | combat_state.gd:3853. BA/reaction firing not verified |
| Reach | +5 ft reach, including opportunity attacks | existing supported (not re-tested for OAs) | `"reach" in properties` in combat_state.gd / fighter_rules.gd |
| Ammunition | needs and expends 1 piece; free hand to load; recover half after a fight | **genuine gap → PROPOSED-items-1** | no ammo items, no property, no consumption |
| Range (normal/long) | Disadvantage beyond normal range; no attack beyond long range | **genuine gap → PROPOSED-items-2** | long range not stored; no range-band roll mode found |
| Heavy | Disadvantage if melee and STR < 13, or ranged and DEX < 13 | **genuine gap → PROPOSED-items-2** | `heavy` is read only for class features (GWM etc.), not as an attack predicate |
| Thrown | draw as part of the attack; melee weapon keeps its melee ability | existing supported (partly) | `thrown_range` exists; draw/ability parity not verified; long range is under PROPOSED-items-2 |
| Mastery: Cleave, Graze, Nick, Push, Sap, Slow, Topple, Vex | per the SRD text | existing supported | fighter_rules.gd:300–340, combat_state.gd:5358–5360; mastery choice and expansion is **already planned under S-127** |
| Mastery source | each weapon's mastery property | existing supported, with a conversion note | FighterRules reads a **hardcoded table keyed by weapon id**, not `item.mastery`, so a magic weapon built on a base weapon gets no mastery. Fixing that belongs with PROPOSED-items-7 |
| Improvised weapons | Rules Glossary | **not reviewed** | — |
| Selling at half cost | economy | **not reviewed** (shop.gd) | — |

## Armor and shields (reviewed at clause level)

AC values for all 13 entries match the SRD. The stealth-disadvantage flag matches. Medium armor's Dex cap is handled in AC code, though I did not re-test it. Weight is missing on the 10 records imported from `imported_base_items` (also noted in docs/mechanics/srd-item-weights.md).

| Clause (SRD p.92–93) | Behavior | Classification | Owner |
|---|---|---|---|
| AC formula and Dex cap | base AC, + Dex, max 2 for medium | existing supported | character AC code |
| Shield +2, one shield | | existing supported | shield slot |
| Strength column | Speed −10 ft unless STR ≥ requirement (Chain Mail 13, Splint and Plate 15) | **genuine gap → PROPOSED-items-3** | no requirement field, no code |
| Stealth column | Disadvantage on Dexterity (Stealth) checks while worn | **missing consumer → PROPOSED-items-3** | the field exists but only `ui/shop.gd` reads it |
| Armor training | without training: Disadvantage on STR/DEX D20 Tests, no spellcasting | **genuine gap → PROPOSED-items-3** (pending verification) | `armor_proficiencies` list exists; grep found no penalty consumer |
| Don/Doff times | Light 1/1 min, Medium 5/1, Heavy 10/5; Shield is a Utilize action | **genuine gap → PROPOSED-items-4** | equipping is instant; no action/time cost |

## Tools, containers, supplies (reviewed at family level only)

| Family | Classification | Owner |
|---|---|---|
| Tool proficiency and purpose-aware checks | existing supported | S-028 (VS-24) |
| Tool crafting | already planned | S-198 / S-199 |
| Gaming Set (absent), tool weights | content conversion | srd-item-weights.md follow-up |
| Packs: expanding into contents | existing supported (`expand_pack_instance`) | 4 of 7 SRD packs are missing (conversion only) |
| Containers: exact non-nested contents | existing supported | S-196 (VS-131). Volume capacity is deliberately not enforced (weight only) |
| Liquids, oil and fuel quantities | already planned | S-197 |
| Light sources (lamp/lantern/torch) | existing supported | S-064 (VS-135) |
| Rations and food | already planned | S-200 / S-201 |
| Thrown or applied supplies (Acid, Alchemist's Fire, Holy Water, Basic Poison, Caltrops, Ball Bearings, Healer's Kit, Antitoxin): 46 refused consumables include these | **not reviewed clause by clause.** Likely reuses for attack-with-object, weapon-coating riders (S-076 planned) and area hazards | batch 2 |
| Mounts, vehicles, trade goods, lifestyle, services | **not reviewed** | — |

## General magic-item rules (reviewed at clause level, SRD pp.209–212)

| Clause | Classification | Owner |
|---|---|---|
| Attunement: 1 hour, max 3 items, one copy at a time | existing supported | inventory.gd `attune_instance`; S-202 (VS-132) |
| Attunement prerequisites ("by a Wizard", "by a Spellcaster", and others) | **genuine gap → PROPOSED-items-5** | no prerequisite field or check |
| Curses: attunement can't be ended, removed by Remove Curse | existing supported | S-202 (VS-132), `break_cursed_item_attunements` |
| Charges, dawn/dusk recovery | existing supported | S-063 (VS-93) |
| Last-charge aftermath / destroyed item | existing supported | S-060 (VS-118) |
| Child-copy charges (spent charges carried to split copies) | already planned | S-211 |
| Activation: Magic action, casting from an item | existing supported | S-134 (VS-76), S-139 |
| Stored spells, then release (Ring of Spell Storing, etc.) | already planned | S-150 / S-151 |
| Linked copies (Sending Stones, etc.) | existing supported | S-162 (VS-129) |
| Attached parts | existing supported | S-210 (VS-133) |
| Repair and mending | already planned | S-212 |
| Random-table items (Bag of Tricks, Deck of Illusions, Wand of Wonder, …) | already planned | S-214 / S-215 |
| Wish-class items (Ring of Three Wishes) | already planned | S-220–S-222 |
| Magic-item saving bonus (Ring/Cloak of Protection) | existing supported | `magic_item_saving_bonus` |
| Spell Scroll: cast if the spell is on your list; ability check for a higher-level spell; scroll is consumed; scroll as a ready-made spell slot | **genuine gap → PROPOSED-items-6** | item missing; S-134 gives casting permission but not the list/check gate or one-use consumption |
| "Armor / Weapon / Ammunition (Any …)" templates over a chosen base item | **genuine gap → PROPOSED-items-7** | no base-item template; at least 17 SRD entries have "(Any …)" in their category line (a lower bound, since only the first category line is parsed) |
| Item durability (AC/HP of objects), resilience | existing supported | object destruction rules, S-072 (not re-verified for items) |
| Sentient items, artifacts | **not reviewed** (source sections not decomposed) | — |
| Wearing/wielding limits (two boots, one cloak, etc.) | existing supported (worn_slot) | not re-verified for all slots |

## Proposed slices (placeholders; no S-/V- numbers assigned)

**PROPOSED-items-1 — Ammunition consumption and recovery.**
- Source: SRD p.90 "Ammunition".
- Affects: 9 ammunition weapons, the Ammunition entry, Quiver and the Crossbow Bolt Case, and Ammunition +1/+2/+3, Ammunition of Slaying and Efficient Quiver.
- Reuses: S-196 exact contents (quiver), S-197 counted quantities, the S-060 copy destruction pattern.
- Depends on: an `ammunition` property and an `ammunition_type` on the weapon, plus counted ammo items.
- **Done when:** a headless check shows a Longbow attack is refused with "no ammunition" when the wielder holds 0 arrows. With 3 arrows, two attacks leave 1. After combat ends, spending 1 minute restores floor(2/2) = 1 arrow, and the other is lost. A save/load round trip keeps the count.

**PROPOSED-items-2 — Weapon range bands and the Heavy predicate.**
- Source: SRD p.90 "Range", "Heavy", "Thrown".
- Affects: 16 ranged or thrown weapons (long range), 9 Heavy weapons.
- Reuses: the existing attack roll-mode advantage/disadvantage aggregation.
- Depends on: storing `long_range` per weapon (a data field; the conversion happens in this slice).
- **Done when:** a check shows a Longbow attack at 160 ft rolls with Disadvantage and is refused at 610 ft. A STR 12 creature attacking with a Greatsword rolls with Disadvantage and a STR 13 one does not. A DEX 12 creature firing a Heavy Crossbow rolls with Disadvantage. A thrown Dagger uses the same ability the wielder would use in melee.

**PROPOSED-items-3 — Worn-armor predicates.**
- Source: SRD p.92 Armor table "Strength" and "Stealth" columns, and Armor Training.
- Affects: all 12 armors plus Shield (training only).
- Reuses: S-028 purpose-aware checks for Stealth; the existing speed-modifier and spellcasting-permission hosts.
- Depends on: a `strength_requirement` data field on Chain Mail, Splint and Plate.
- **Done when:** a check shows a STR 14 wearer of Plate has Speed −10 ft and a STR 15 wearer does not. A Scale Mail wearer has Disadvantage on a Dexterity (Stealth) check. A wearer without Heavy armor training has Disadvantage on STR/DEX D20 Tests and is refused when casting a spell. All three effects go away when the armor is unequipped.

**PROPOSED-items-4 — Don/Doff timing.**
- Source: SRD p.92 table group headers and the Shield row.
- Affects: all armor and shields.
- Reuses: the campaign time-cost host (ADR-0007) and the Utilize action cost.
- Depends on: nothing beyond the existing action costs.
- **Done when:** a check shows that equipping Plate outside combat advances campaign time by 10 minutes and removing it by 5. In combat, Medium or Heavy armor cannot be donned, and donning a Shield spends the Utilize action. The result reports the time spent.

**PROPOSED-items-5 — Attunement prerequisites.**
- Source: SRD p.210 "Attunement" (prerequisite clause) and each entry's "Requires Attunement by …".
- Affects: SRD entries with class, spellcaster or other attunement qualifiers (at least 11 entries have "by a …" in their first category line; the full count is batch 2; for example Staff of Power and Robe of the Archmagi).
- Reuses: `attune_instance`; class and spellcasting predicates (QRY-06 owned predicates).
- **Done when:** a check shows a Fighter is refused attunement to a "by a Sorcerer, Warlock, or Wizard" item with that reason, a Wizard succeeds, and a loaded item that requires attunement but has no qualifier is unaffected.

**PROPOSED-items-6 — Spell Scroll use.**
- Source: SRD Spell Scroll entry (Magic Items, "Scroll, Rarity Varies").
- Affects: Spell Scroll for every spell level. Also usable by future scroll-like consumables.
- Reuses: S-134 item casting permission, the shared spell runtime (ADR-0017), S-060 destruction.
- **Done when:** a check shows a Wizard casts *Magic Missile* from a level-1 scroll and the scroll is gone. A Fighter is refused because the spell is not on their list. A caster reading a scroll above their highest slot level makes the ability check at DC 10 + spell level: on a failure the scroll is lost and nothing is cast, and on a success the spell resolves. The scroll's save DC and attack bonus come from the scroll's level table, not the caster.

**PROPOSED-items-7 — Magic templates over a base item.**
- Source: SRD entries written as "Weapon (Any Simple or Martial)", "Armor (Any Medium or Heavy …)", Weapon/Armor/Shield/Ammunition +1/+2/+3, Flame Tongue, Vorpal Sword, Adamantine/Mithral Armor, and others.
- Affects: at least 17 SRD entries with "(Any …)" (lower bound).
- Reuses: the existing item copies (ADR-0013) and `weapon_bonus` / `armor_bonus`.
- Depends on: PROPOSED-items-2 for range data inheritance; mastery being read from the item rather than the FighterRules id table.
- **Done when:** a check creates a "+1 Weapon" copy over a Longsword. The copy reports 1d8 slashing, Versatile 1d10, mastery Sap and +1 to attack and damage. A Fighter with Weapon Mastery applies Sap with it. A "Mithral Armor" copy over Half Plate has no Stealth disadvantage and no Strength requirement. Both survive save/load.

## Coverage

Reviewed (clause level):
- Weapons table and properties
- Mastery properties
- Armor table and armor rules
- The general magic-item rules (attunement, curses, charges, activation, stored spells, linked items, destruction)

Reviewed (field level, not clause by clause): the 94 loaded SRD magic records (F-1).

**Not reviewed:**
- The 192 missing magic items, entry by entry. Families were only placed against slices.
- The 46 refused consumables, effect by effect.
- Adventuring gear entries, one at a time (for example Hunting Trap, Manacles, Grappling Hook, Healer's Kit).
- Tools' Utilize DCs and craftable lists.
- Mounts and vehicles, trade goods, improvised weapons, selling, sentient items, artifacts.
- The 67 loaded non-SRD items.
- Whether shop, loot or creation flows expose the F-1 stubs.

## Next queue

1. Refused consumables, effect by effect: map each of the 46 to existing effect types, planned slices, or new PROPOSED items.
2. Adventuring gear entries: Utilize actions, hazards, restraints.
3. Missing magic items, entry by entry. Start with high-frequency families (rings, wands, boots, cloaks) and count the attunement qualifiers for PROPOSED-items-5.
4. Check whether shop, loot or creation flows expose the F-1 equippable stubs.
5. Run the Windows runner for the same export when it is reachable, and compare the registry hash.
