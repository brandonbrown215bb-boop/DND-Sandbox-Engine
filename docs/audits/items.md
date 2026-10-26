# Items & Equipment audit (priority 2) — batches 1–2

Status: **partial**. Batch 2 (below, after batch 1) adds the 46 refused consumables effect by effect, every SRD adventuring-gear entry, and a code/data trace of how the magic-item shells are exposed. Batch 1 is an inventory reconciliation for every SRD item, plus a clause-level breakdown of *ordinary weapons and armor* and of the *general* magic-item rules. Individual magic-item entries are **not** broken down clause by clause yet (see Coverage). This is a docs/audit file only. It changes no runtime code, content or availability.

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

- **Consumable stubs (35):** the potions and oils, apart from 4 healing potions and Potion of Poison / Poison Resistance. `consume()` refuses them, so this is **safe**. *(Batch 2 correction: batch 1 said 46 here and 38 below. 46 is the total of all refused consumables, including gear and non-SRD potions. The correct split of the 84 is 35 consumable + 49 equippable/held.)*
- **Weapon / armor / shield / held-item stubs (49, including Hat of Many Spells as a `tool`):** for example Oathbow (`ability: STR`, 1d8, range 30, no magic), Sun Blade, Mace of Disruption, Dwarven Thrower, Javelin of Lightning, every Dragon Scale Mail, Armor of Invulnerability, Animated Shield, and all staffs except Power and Striking. These pass the normal `can_equip` and attack paths as **plain mundane gear**. That is a fidelity problem, not a crash: the engine shows an item that does not do what its SRD text says. `identify_rules.gd` recognizes `imported_magic_*` sources, but nothing stops them from being equipped. Batch 2 traced whether shop, loot or creation flows hand these out: **none do** (see B2-3).
- Records that do carry rules: Wand of Magic Missiles (charges, dawn recovery, activation spell), Staff of Power and Staff of Striking (attunement, charges, recovery, last-charge aftermath, bonus), Ring of Protection (attunement, AC/save bonus, one-ring limit), the healing potions, and Potion of Poison / Poison Resistance.

Classification: content conversion against existing hosts. Most of these need no new vocabulary, only conversion, which is out of scope here. Whether to gate the 49 equippable stubs is an availability decision for the owner. This audit makes no change.

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

## Batch 2 (2026-10-26): consumables, adventuring gear, shell exposure

Same base commit, registry hash and Linux headless export as batch 1. origin/main had not moved, so no rebase was needed. Extra artifact: `.artifacts/items-audit/srd_gear_text.json`, holding 88 gear and tool descriptions split from `pdftotext -f 94 -l 100`, plus `m2.txt` (`pdftotext -f 209 -l 253`). Each SRD clause below was read from those files.

### B2-1: the 46 refused consumables, effect by effect

46 = 7 SRD gear + 35 SRD magic potions/oils + 4 non-SRD potions (Comprehension, Fire Breath, Greater Invisibility, Pugilism; out of scope). Every one has `effects: []`, so `consume()` refuses it and the shop's `_is_buyable_item` hides it. None of them is exposed with wrong behavior.

| Item(s) | SRD clause (summary) | Reusable operation | Classification | Owner |
|---|---|---|---|---|
| Acid, Alchemist's Fire, Holy Water | replace one attack: throw at a target within 20 ft; DEX save, DC 8 + Dex + PB; 2d6 Acid / 1d4 Fire + Burning / 2d8 Radiant only vs Fiend or Undead; item used up | thrown-object attack replacement with a save | **genuine gap → PROPOSED-items-8** | S-126 DC profile (verified); Burning exists in combat_object_rules.gd |
| Oil (douse creature/object) | same throw; on a failed save the target is covered; next Fire damage within 1 min +5 Fire | PROPOSED-items-8 plus a timed next-damage rider | gap (8) + already planned | S-076 next result grant (planned) |
| Oil (pour on a space), Caltrops | Utilize: cover a 5-ft square; entry triggers (Oil once lit / Caltrops DC 15 DEX: 1 Piercing, Speed 0); 10 min to recover Caltrops | item-deployed hazard area | **genuine gap → PROPOSED-items-11** | entry scopes S-184 (planned); zone host combat_spell_zones.gd |
| Oil (fuel) | fuel for Lamp/Lantern | existing supported | — | S-064 (`fuel_item_id` on hooded lantern) |
| Antitoxin | Bonus Action; Advantage on saves to avoid or end Poisoned for 1 hour | timed, condition-scoped save advantage | **genuine gap → PROPOSED-items-9** | `roll_modifier` exists but no condition-scoped timed route was verified |
| Basic Poison | Bonus Action; coat 1 weapon or 3 ammo; next Piercing/Slashing damage +1d4 Poison; lasts 1 min or until dealt | weapon-coating next-damage grant | already planned | S-076 (+ S-013 P2); ammo half needs PROPOSED-items-1 |
| Potion of Resistance ×10, Potion of Invulnerability | Resistance to one type for 1 h / all damage for 1 min | timed self-resistance from an item | **gap → PROPOSED-items-9** | — |
| Potion of Giant Strength ×6 | STR *becomes* 21/23/23/25/27/29 for 1 h; no effect if STR is already ≥ that score | timed score setting | **host exists, no consumable route → PROPOSED-items-9** | S-039 score setting (verified, VS-46) |
| Potion of Climbing, Potion of Flying | Climb Speed = Speed + Advantage on climb checks / Fly Speed + hover, 1 h; fall when it ends | timed movement mode | **gap → PROPOSED-items-9**; fall on expiry already planned | S-179 modes (verified); S-181 (planned) |
| Potion of Water Breathing | breathe underwater for 24 h | timed breathing adaptation | already planned | S-205 |
| Potion of Heroism | 10 Temp HP for 1 h + Bless with no Concentration | Temp HP (supported) + item spell effect | conversion + **PROPOSED-items-10** | S-015 / `temporary_hp` |
| Clairvoyance, Diminution, Growth, Gaseous Form, Speed, Mind Reading (DC 13), Oil of Etherealness, Oil of Slipperiness (Freedom of Movement 8 h, or Grease over a 10-ft square) | "gain the effect of spell X", usually with no Concentration, a fixed duration or DC, and sometimes an end clause removed (Speed: no lethargy) | item-delivered spell effect with source overrides | **genuine gap → PROPOSED-items-10** | S-134 covers *casting* from items, not "gain the effect" without casting; spells run on the shared runtime |
| Potion of Animal Friendship | "you can cast" the level-3 version, save DC 13 | casting from an item at a fixed level and DC | existing host, conversion only | S-134, S-139 |
| Potion of Invisibility | Invisible for 1 h; ends early on an attack roll, dealing damage, or casting a spell | condition with action-triggered early end | **gap → PROPOSED-items-9** (end triggers) | `grant_condition` supported; observer side is S-191 (planned) |
| Philter of Love | charmed by the next creature you see within 10 min, for 1 h | observer-dependent deferred trigger | already planned (observer) + ADR-0023 judgment for "see" | S-190 |
| Elixir of Health | cures magical contagions; ends Blinded, Deafened, Paralyzed, Poisoned | `remove_condition` ×4 | conversion only (supported type); "contagions" is a source gap (no disease model) | — |
| Potion of Vitality | removes all Exhaustion, ends Poisoned; for 24 h Hit Point Dice heal their maximum | remove (supported) + timed HD-max modifier | conversion + **gap → PROPOSED-items-9** | — |
| Potion of Longevity | physical age −(1d6+6), minimum 13; 10% cumulative backfire | no age model | **source gap / ADR-0023 deferred** | — |
| Oil of Sharpness | coat a nonmagical Slashing/Piercing melee weapon or 20 ammo → +3 | magic template over a base item | gap → PROPOSED-items-7 | — |

### B2-2: adventuring gear and tools, entry by entry

I read the SRD text for every entry in the Tools and Adventuring Gear sections. "Conv" means the existing host covers it and only the data needs converting (out of scope here).

**Tools (25 entries, 24 loaded):** every tool's Utilize DC belongs to the verified **S-028** purpose-aware tool checks, and every Craft list to **S-198/S-199** (planned). Two notes:
- The 23 records imported from `imported_magic_tools.json` carry `effects: []`, so their Utilize benefits aren't converted (conv).
- Only Thieves' Tools has an authored effect (`enable_check: lockpick`), and I found no production consumer of `enable_check`. Lock picking does work through local-room rules, but I didn't verify that path.
- Gaming Set is missing (conv).

**Focuses:** Arcane Focus ×5, Druidic Focus ×4, Holy Symbol and Component Pouch are existing supported through `Inventory.has_spellcasting_focus`. The Druidic Focus records have `effects: []`; I didn't verify whether the compatibility check is id-based.

**Gear entries:**

| Entry | Loaded | SRD rule (summary) | Classification |
|---|---|---|---|
| Acid, Alchemist's Fire, Antitoxin, Basic Poison, Caltrops, Holy Water, Oil | yes | see B2-1 | B2-1 |
| Ball Bearings | yes (`tool`, no effects) | Utilize: 10-ft square; DC 10 DEX or Prone on entry; 10 min to recover | **PROPOSED-items-11** |
| Hunting Trap | no | Utilize to set; DEX save on stepping on the plate; restrained by the trap | **PROPOSED-items-11** + S-168/S-169 escape |
| Net | **yes, as a weapon: 1d4 bludgeoning, STR, value 1, sold in the shop** | replace an attack; DEX save or Restrained, auto-success vs Huge+; DC 10 Athletics escape; Net AC 10, 5 HP | **data divergence that is exposed** (it deals damage it shouldn't and doesn't restrain); behavior is PROPOSED-items-8 + continuation of S-168/S-169 |
| Manacles, Chain, Rope (bind) | Rope yes; Manacles, Chain no | Utilize vs a Grappled/Incapacitated/Restrained target; DC 13 check; bound = Restrained; escape/burst DCs | continuation of verified **S-168 / S-169** (restraint relation, escape); conv |
| Rope (knot), String | Rope yes | Utilize knot, DC 10 Sleight of Hand; burst DC 20 | S-028 conv. **Divergence:** loaded Rope grants +2 Athletics (climbing), which the SRD text doesn't say |
| Climber's Kit | yes | Utilize anchor: can't fall more than 25 ft, or move more than 25 ft until undone (BA) | **divergence:** loaded as +2 Athletics (climbing), not in the SRD; anchor is a tether, continuation of S-168 |
| Crowbar | yes | Advantage on Strength checks where leverage applies | **divergence:** loaded as +2 Athletics (prying); local_room_rules.gd requires a Crowbar to pry, which is supported. Advantage belongs to the S-028 roll-mode host |
| Costume, Magnifying Glass, Perfume, Pole (vault) | Costume yes; others no | Advantage on a scoped ability check (Perfume: 1 h, Indifferent Humanoid within 5 ft) | existing host S-028 (purpose-aware), conv; Perfume's audience scope is an ADR-0023 judgment |
| Book, Map | no | +5 to scoped Int/Wis checks when consulting an accurate one | S-028 conv; "accurate" is an ADR-0023 judgment |
| Portable Ram | no | +4 to the Strength check to break doors; a helper gives Advantage | S-028 / local-room door rules, conv |
| Healer's Kit | yes (no effects) | 10 uses; Utilize to stabilize at 0 HP with no Medicine check | **missing host continuation:** stabilize exists (zero_hp_aftermath_rules.gd, character.gd) but no item route; uses are covered by the S-063 charge vocabulary |
| Lamp | yes (**no `light_source`**) | burns Oil; Bright 15 ft + Dim 30 ft | S-064 conv (the light-source host exists) |
| Lantern, Hooded | yes (light_source) | Bright 30 + Dim 30; hood down as a BA | existing supported (S-064). Hood toggle is not represented (conv) |
| Lantern, Bullseye | yes, **as a consumable with `vision_bonus` for 10, no fuel** | 60-ft Cone Bright + 60 Dim, burns Oil | **data divergence.** Its use path is supported, but it doesn't match the SRD; cone light → S-190 (planned) |
| Torch | yes (light_source 20/40, 1 h) | as above; can attack as a Simple Melee weapon for 1 Fire | light existing supported (S-064); torch-as-weapon not represented (conv) |
| Candle | no | 1 h, Bright 5 + Dim 5 | S-064 conv |
| Tinderbox | yes (no effects) | lights a fuel source as a BA, other fires in 1 min | the lighting action cost isn't modeled; S-064 conv |
| Backpack | yes (container 30 lb) | 30 lb within 1 cu ft | existing supported (S-196). Volume deliberately not enforced |
| Barrel, Basket, Bottle, Bucket, Case ×2, Chest, Flask, Jug, Pot, Pouch, Quiver, Sack, Vial | no | capacity in lb, cu ft, gallons, pints or ounces, or a count (Quiver 20 Arrows) | S-196 conv; liquid capacity S-197 (planned); ammo-count capacity PROPOSED-items-1 |
| Entertainer's, Explorer's, Priest's Pack | yes | expands into its contents | existing supported (`expand_pack_instance`) |
| Burglar's, Diplomat's, Dungeoneer's, Scholar's Pack | no | expands into its contents | conv |
| Rations, Waterskin | yes | malnutrition/dehydration via the Rules Glossary | `nourish` supported; exposure S-200/S-201 (planned) |
| Bedroll, Blanket, Tent | Bedroll, Blanket yes; Tent no | auto-succeed / Advantage on extreme-cold saves; sleeps 1–2 | S-201 (planned) |
| Block and Tackle | no | hoist 4× lift capacity | **not classified**: carrying-capacity host not located (batch 3) |
| Grappling Hook | no | Utilize throw within 50 ft, DC 13 Acrobatics to catch; climb if roped | S-028 + S-179 climb, conv |
| Ladder, Pole (reach), Shovel (1 h dig), Iron Spikes, Bell, Signal Whistle, Mirror, Spyglass, Ink, Ink Pen, Paper, Parchment, Clothes ×2, Robe | mixed (Bell, Mirror, Robe loaded) | descriptive, narrative or world-interaction | **ADR-0023 bounded judgment / deferred.** No discrete mechanic beyond flavor, local-room use or time cost |
| Spell Scroll (gear table) | no | see PROPOSED-items-6 | PROPOSED-items-6 |

Reconciler note: the batch-1 gear header parser missed **Spyglass** (1,000 GP, not loaded), so the corrected missing-equipment count is **46**, not 45. Iron Spikes, Chest and Portable Ram text was split by the PDF's two-column layout; I read those entries by hand where the text was recoverable (Ram) and left the rest unchecked (Spikes, Chest).

### B2-3: are the 49 equippable magic-item shells handed out?

I traced code and data paths only.
- **Shop (`src/ui/shop.gd`):** `_is_buyable_item` requires `value > 0`, and all 49 shells have `value: 0`. **Not sold.** Selling isn't relevant, because a player never receives one.
- **Loot:**
  - The dungeon generator hard-codes `gold_100` and `potion_healing`.
  - Dungeon `loot` lists, monster `loot_table`s and event `give_item`/`success_loot` all use explicit ids.
  - A full-text search of every non-item JSON under the repo found **no reference** to any of the 49 ids, apart from `data/content_manifest.json` (approved overrides) and `docs/reviews/dnd-runtime-source-ownership.json`. **Not dropped.**
- **Character creation:** it uses class `starting_equipment` (explicit ids), and none are shells. **Not granted.**
- The only other `get_all_items()` caller in production code is the shop.

Conclusion: in the current production content, the shells can't be reached through normal play. They are still reachable through authored content, mods, saves and test harnesses, because the DataLoader validates the ids as real items. The **Net** (B2-2) is the one SRD item that really is exposed with wrong behavior, since it's buyable.

### Batch 2 proposed slices

**PROPOSED-items-8 — Thrown-object attack replacement.**
- Source: SRD gear entries Acid, Alchemist's Fire, Holy Water, Oil (douse) and Net: "When you take the Attack action, you can replace one of your attacks with throwing…".
- Affects: those 5 entries; Bottle/Flask improvised throws are out of scope.
- Reuses: the Attack-action swing count (combat_state.gd), the S-126 save-DC profile (DC 8 + Dex + PB), the Burning hazard, S-168 restraint for Net, and item-copy destruction.
- Depends on: S-076 (planned) for Oil's next-Fire rider only.
- **Done when:** a check shows a level-5 Fighter can spend one of 2 Attack-action swings throwing Acid at a target 20 ft away (and is refused at 25 ft). The target makes a DEX save against DC 8 + Dex + PB, takes 2d6 Acid on a failure, and the vial is removed while the second swing stays available. Holy Water deals no damage to a non-Fiend, non-Undead target. Alchemist's Fire applies Burning on a failure. A Net restrains a Medium target, automatically fails against a Huge one, and the target escapes with DC 10 Athletics.

**PROPOSED-items-9 — Timed self-modifiers from consumables.**
- Source: Antitoxin, Potion of Resistance, Invulnerability, Giant Strength, Climbing, Flying, Invisibility (end triggers) and Vitality (HD maximum).
- Affects: 22 loaded consumables.
- Reuses: S-039 score setting, S-179 movement modes, condition grants, S-015 source-owned expiry, and campaign/combat time (S-064).
- Depends on: S-181 (planned) for falling when flight expires.
- **Done when:** a check shows that after drinking Potion of Hill Giant Strength, a STR 10 character's attack and Athletics use STR 21 for exactly 1 hour, then revert to 10; a STR 22 drinker is unchanged. Fire Resistance halves Fire damage only, and only for 1 hour. Antitoxin gives Advantage on a save against Poisoned but not on another CON save. Invisibility ends when the drinker makes an attack roll. Flying grants a Fly Speed equal to Speed. Every effect survives save/load with its remaining time.

**PROPOSED-items-10 — Item-delivered spell effects with source overrides.**
- Source: the potions and oils that say "you gain the effect of the X spell" (Clairvoyance, Diminution, Growth, Gaseous Form, Speed, Mind Reading, Heroism/Bless, Etherealness, Slipperiness).
- Affects: 9 loaded consumables, plus future wondrous items worded the same way.
- Reuses: the shared spell runtime (ADR-0017) and the S-134 permission model.
- Depends on: whichever of these spells the spell audit marks as supported.
- **Done when:** a check shows Potion of Speed applies the Haste effect for 10 rounds, the drinker is not concentrating, and the effect produces no lethargy turn when it ends. Potion of Mind Reading uses save DC 13 regardless of the drinker. Diminution's duration is rolled once (1d4 hours). The effect is not cast: it uses no slot, no components, and doesn't trigger "when a creature casts a spell" reactions. A spell the runtime does not support makes the potion refuse with that reason, instead of being consumed with no effect.

**PROPOSED-items-11 — Item-deployed hazard areas.**
- Source: Caltrops, Ball Bearings, Oil (pour + ignite), Hunting Trap, and Oil of Slipperiness (Grease mode).
- Affects: 5 entries (3 loaded).
- Reuses: the spell-zone hosts (combat_spell_zones.gd, spell_zone_terrain.gd), the Utilize action, and S-122 placement.
- Depends on: S-184 entry scopes (planned).
- **Done when:** a check shows Caltrops deployed with a Utilize action on a 5-ft square within 5 ft. The first creature to enter it that turn makes a DC 15 DEX save; on a failure it takes 1 Piercing and has Speed 0 until the start of its next turn, and a second entry in the same turn doesn't trigger it again. Recovering the Caltrops takes 10 minutes and returns the item. Ball Bearings cause Prone on a failed DC 10 save across a 10-ft square. Poured Oil burns only after it is lit.

### Batch 2 data divergences (conversion corrections; no proposal; not changed here)

| Item | Divergence |
|---|---|
| Net | modeled as a damaging weapon (1d4 bludgeoning) and sold in the shop |
| Lantern, Bullseye | consumable `vision_bonus`; no cone, no fuel |
| Lamp | no `light_source` |
| Crowbar | +2 Athletics instead of Advantage |
| Rope, Climber's Kit | +2 Athletics (climbing), not in the SRD |
| Healer's Kit | no stabilize route |
| Thieves' Tools | `enable_check` with no consumer found |
| Imported tools | no Utilize data |


## Batch 3 (2026-10-26): reconciler fix + missing magic items (rings, wands, boots, cloaks)

Same base commit `ede0a3c`, since origin/main had not moved. The registry hash is unchanged (`70a83cc7…845e`).

### B3-0: Reconciler fix

- **Spyglass fix:** `gear()` now accepts thousands separators in costs (`[\d,]+`), so Spyglass (1,000 GP) is parsed.
- **SRD entry counts:** now 105 gear/tool, 258 magic, 38 weapon and 13 armor. Missing: **46 equipment** and **192 magic**. Loaded-but-unmatched stays at 67.
- **Unchanged sections:** I compared the weapon diffs, magic rule fields, loaded list and hash in `reconciliation.json` against the batch-2 file (with `srd_entries`/`srd_missing` removed), and they are identical.
- **Magic item text export:** the reconciler now also writes `.artifacts/items-audit/srd_magic_text.json`, the full SRD body text for each magic item, sliced from `mi.xml` between consecutive item headings. The batch-2 `m2.txt` split truncated some entries, such as Boots of Speed and Ring of Animal Influence. Every clause below comes from this export.
- **Known limitation:** the text follows the PDF's reading order. Page numbers and the occasional table line run into the body text, and the tables were read by hand.

### B3-1: Host facts used for classification (read from code this batch)

- **Equipped-item benefits (S-049, verified VS-59):** `SourceBenefitRules.benefits_error` accepts **only `AC` and `speed` (walking) additions**, from 1 to 10, gated on attunement and S-203 suppression. No passive resistance, save bonus, roll mode, non-walking speed or condition immunity can ride an equipped copy.
- **Item-carried features:** `OwnedFeatureSources.item_features` gives an equipped, attuned copy its `features` with copy-scoped ids. Item activations therefore reuse:
  - the class-feature vocabulary (`COMMON_SELF_EFFECTS`);
  - exact-source pools (S-006), dawn and random recovery (S-063) and last-charge aftermath (S-060);
  - item casting permissions (S-134 and S-139).
  The precedent is the loaded Wand of Magic Missiles.
- **Resistance:** `Character.resist_damage` hard-codes each source (Rage, features, Protection from Energy, and so on), plus a `feature_uses["damage_resistances"]` list that no production code writes. There's no item route.
- **Divergence in loaded data (new):** `ring_of_protection` carries `armor_class_bonus` and `saving_throw_bonus` effects that **no production code consumes**. Its AC should come through `source_benefits` and its save bonus needs PROPOSED-items-12. It isn't exposed, because its value is 0 (B2-3).
- **Spells:** whether each named spell works is the spell audit's domain. Below, "S-134 conversion" means the item side (permission, DC, charges, recovery) has a verified host. It doesn't mean the spell itself is supported.

### B3-2: Entry-by-entry classification (47 entries: 21 rings, 12 wands, 14 boots/cloaks/slippers)

"Conv" means an existing host covers it and only data needs converting. Charge pools are always S-006 and dawn recovery S-063. A last-charge 1d20 crumble roll is S-060. All of these are verified, and I don't repeat them per row unless they're the only rule.

| Item | Clause → classification |
|---|---|
| Boots of Elvenkind | silent steps → ADR-0023 narrative; Advantage on Stealth → **PROPOSED-items-12** (passive roll mode; S-091 host has no item carrier) |
| Boots of Levitation | cast Levitate on self at will → S-134 conv; self-only target restriction not confirmed in S-134 (**check**) |
| Boots of Speed | BA toggle doubles Speed; OA against you at Disadvantage; 10 min total, then until Long Rest → toggle/cumulative time S-064 conv; doubling Speed and OA Disadvantage → **PROPOSED-items-12** |
| Boots of Striding and Springing | Speed floor 30; no encumbrance or Heavy Armor speed reduction → **PROPOSED-items-12**; jump 30 ft for 10 ft of movement → **jump host not located** (unreviewed) |
| Boots of the Winterlands | Cold Resistance → **PROPOSED-items-12**; cold tolerance → S-201 (planned); ignore ice/snow Difficult Terrain → S-179 terrain costs conv |
| Winged Boots | 4 charges; Magic action: Fly 30 for 1 h → timed self-grant S-012 + S-179 conv (non-walking speed needs PROPOSED-items-12 payload); 30 ft/round descent on expiry → S-181 (planned) |
| Slippers of Spider Climbing | Climb Speed = Speed, hands free → **PROPOSED-items-12** + S-179; not on slippery surfaces → S-179 surface rules conv |
| Cloak of Arachnida | Poison Resistance → **12**; spider climb → **12** + S-179; immune to webs, webs are Difficult Terrain → **12** (source-specific exemption); Web DC 13, double area, 1/dawn → S-134/S-126 conv + area change S-141 (planned) |
| Cloak of Displacement | attackers have Disadvantage → **12**; stops on damage until your next turn starts, suppressed at Speed 0 → S-203 suppression + S-072 termination conv |
| Cloak of Elvenkind | Disadvantage on Perception to perceive you; Advantage on Stealth → **12** (observer-side half: S-188/S-190, planned) |
| Cloak of Invisibility | 3 charges; Magic action: Invisible 1 h; ends on hood down or doffing → `grant_condition` + S-072 equipment termination conv; observer effects S-191 (planned) |
| Cloak of Protection | +1 AC → S-049 conv; +1 saves → **12** |
| Cloak of the Bat | Advantage on Stealth → **12**; Fly 40 only in Dim Light or Darkness → **12** + light predicate S-190 (planned); Polymorph into a Bat keeping Int/Wis/Cha, 1/dawn → S-134 + S-163 retained-stat projection conv |
| Cloak of the Manta Ray | breathe underwater → S-205 (planned); Swim 60 → **12** |
| Ring of Animal Influence | 3 charges; Animal Friendship, Fear (Beasts only), Speak with Animals at DC 13 → S-134/S-139/S-126 conv; Beast-only target filter → S-025 binding (verified) conv |
| Ring of Djinni Summoning | summon a Friendly obedient djinni within 120 ft, Concentration up to 1 h → S-154/S-155/S-156/S-158 conv; 24 h cooldown → S-014 conv; nonmagical if the djinni dies → S-203 destruction conv |
| Ring of Elemental Command | **Bane:** Advantage vs Elementals, they have Disadvantage vs you → **12**. **Compulsion:** DC 18 Wis, Charmed and you control its move/action → S-173 (planned). **Focus:** languages → S-218 (planned); resistance/immunity, fly + hover, swim → **12** + S-179; earth passage and shunt → S-180/S-181 (planned); breathing → S-205 (planned). **Spells:** 5 charges, DC 18, per-spell charge costs (Feather Fall 0) → S-134/S-139 conv |
| Ring of Evasion | 3 charges; Reaction after a failed DEX save → succeed instead → S-092 explicit success conv (Reaction budget S-160 is planned for off-turn types; **check**) |
| Ring of Feather Falling | descend 60 ft/round, no falling damage → S-181 (planned) |
| Ring of Free Action | Difficult Terrain costs nothing extra → S-179 conv; magic can't reduce Speeds or cause Paralyzed/Restrained → **12** (source-scoped condition and speed immunity) |
| Ring of Invisibility | Magic action: Invisible until removed, or a BA to end → `grant_condition` + S-072 conv; observer side S-191 (planned) |
| Ring of Jumping | Jump, self only → S-134 conv (self-only: **check**) |
| Ring of Mind Shielding | immune to thought, lie, alignment and type detection → S-195 (planned); telepathy only by permission → S-218 (planned); imperceptible toggle → ADR-0023 narrative; soul enters the ring on death → S-175 (planned) + **unreviewed** (no soul-in-item host) |
| Ring of Regeneration | regain 1d6 HP every 10 min while at ≥1 HP → **PROPOSED-items-13**; regrow parts over 1d6+1 days → S-206/S-207 (planned) |
| Ring of Resistance | Resistance to one gem-determined type (1d10 table) → **12**; gem variant → PROPOSED-items-7 template |
| Ring of Shooting Stars | Dancing Lights and Light at will; Faerie Fire for 1 charge → S-134 conv. **Lightning Spheres** (2 charges, Concentration, moving spheres discharging on first approach, DC 15, damage by sphere count) → S-154 created actor + S-184 first approach (planned) + S-016 table lookup; **unreviewed** whether a moving discharge host exists. **Shooting Stars** (1–3 charges, one 15-ft cube per charge, DC 15, 5d4 Radiant) → **unreviewed** (item area-save activation host not located) |
| Ring of Spell Storing | stores up to 5 levels with the original caster's DC, attack and slot → S-150/S-151 (planned) |
| Ring of Spell Turning | Advantage on saves vs spells → **12**; a successful save vs a spell of level ≤7 negates it → S-116 conv; reflect a single-target spell as a Reaction, using the caster's own DC → S-133 (planned) |
| Ring of Swimming | Swim 40 → **12** |
| Ring of Telekinesis | cast Telekinesis → S-134 conv |
| Ring of the Ram | 1–3 charges: ranged spell attack +7, 2d10 Force per charge and a 5-ft push per charge → fixed-attack profile S-126 conv; **forced push host not located (unreviewed)**; break an object, Str +5 per charge → S-028 + S-032 conv |
| Ring of Three Wishes | 3 charges cast Wish → S-221 (planned); nonmagical after the last charge → S-060 conv |
| Ring of Warmth | Cold damage −2d8 → S-109 component reduction (verified) via a **12** item carrier; unharmed at ≤0 °F → S-201 (planned) |
| Ring of Water Walking | Water Walk on self → S-134 conv |
| Ring of X-ray Vision | Magic action: 30-ft X-ray for 1 min, material limits → S-195 (planned); reuse before a Long Rest needs DC 15 Con or Exhaustion → S-090 history with Long Rest reset conv |
| Wand of Binding | 7 charges; Hold Monster (5) or Hold Person (2) at DC 17 → S-134/S-139/S-126 conv |
| Wand of Enemy Detection | 1 charge: direction (not distance) of the nearest Hostile within 60 ft for 1 min, including Invisible or hidden ones; ends if you let go → S-194 (planned) + S-072 conv |
| Wand of Fear | Command (flee or grovel only, 1 charge) or Fear (60-ft Cone, 3) at DC 15 → S-134 conv; restricted Command options → S-085 conv (**check**) |
| Wand of Fireballs / Lightning Bolts | ≤3 charges; level 3 plus 1 per extra charge, DC 15 → S-134/S-139 conv (charge-scaled level: **check** against S-139 upcast rules) |
| Wand of Magic Detection | 3 charges, Detect Magic → S-134 conv |
| Wand of Paralysis | 1 charge: DC 15 Con or Paralyzed 1 min, repeat the save each turn → S-068 conv (activation as an item feature) |
| Wand of Polymorph / Web | Polymorph DC 15 / Web DC 13 → S-134 conv |
| Wand of Secrets | 1 charge: points to the nearest secret door or trap within 60 ft → S-194 (planned) |
| Wand of the War Mage +1/+2/+3 | bonus to spell attacks → S-022 flat bonus via a **12** carrier; ignore Half Cover → **cover host not located (unreviewed)**; +N variants → PROPOSED-items-7 |
| Wand of Wonder | 1d100 effect table, DC 15, 120-ft range floor → S-214/S-215 (planned) + S-223 partial support (planned); the child spells are the spell audit's |

**Batch 3 proposed slices**

**PROPOSED-items-12 — Passive equipped-item modifiers beyond AC and walking speed.**
- **Source:** the "while you wear/hold" clauses above.
- **Affects:** 19 of the 47 entries, plus loaded Ring of Protection.
  - Typed Resistance and Immunity.
  - Flat saving-throw bonus.
  - Scoped ability-check Advantage, and Disadvantage for observers.
  - Attack modes against or for the wearer, and Opportunity Attack Disadvantage.
  - Speed floor, doubling and immunity to encumbrance.
  - Climb, swim and fly speeds and hover.
  - Source-scoped condition and speed-reduction immunity.
  - Spell-attack bonus.
  - Damage reduction by dice.
- **Reuses:**
  - S-049/VS-59 carrier identity, attunement gating and S-203 suppression (extending `benefits_error`'s stat allowlist rather than adding a new channel).
  - S-091 roll modes, S-109 reduction, S-022 attack bonus and S-179 modes.
- **Depends on:** nothing planned. Observer-side clauses (Elvenkind) keep S-188/S-190 as their owners.
- **Done when:** a check shows:
  - An attuned, equipped Ring of Resistance (fire) halves a 10-Fire hit to 5 and leaves 10 Cold at 10.
  - Unequipping it, or ending the attunement, restores 10 Fire.
  - Cloak of Protection adds +1 to a DEX save and +1 AC, and two Cloaks of Protection on different characters don't affect each other.
  - Boots of Elvenkind give Advantage on Stealth only, not Acrobatics.
  - Ring of Swimming grants Swim 40 without changing walking Speed.
  - Ring of Free Action prevents Hold Person's Paralyzed but not a non-magical grapple's Restrained.
  - A save/load keeps all of this without turning it into permanent stats.
  - Ring of Protection's loaded AC and save bonuses take effect through this route.

**PROPOSED-items-13 — Periodic elapsed-time effects from a worn item.**
- **Source:** Ring of Regeneration, "regain 1d6 Hit Points every 10 minutes if you have at least 1 Hit Point".
- **Affects:** Ring of Regeneration. Unreviewed wondrous items are likely candidates, to be confirmed in batch 4.
- **Reuses:** S-064 cumulative active time (verified), S-049 carrier identity, `heal`, and the campaign clock.
- **Depends on:** none.
- **Done when:** a check shows that a wearer at 5/30 HP heals 1d6 after exactly 10 minutes of campaign time.
  - It heals 3×1d6 after 30 minutes, with each roll recorded once.
  - It doesn't heal at 0 HP, or while the ring is unequipped.
  - A save/load at minute 7 heals at minute 10, not minute 17.
  - Combat rounds count toward the 10 minutes, at 6 s per round.

### B3-3: Unreviewed magic items (145; family-level only from batch 1)

- **Armor (5):** Adamantine Armor; Armor, +1, +2, or +3; Armor of Resistance; Mithral Armor; Shield, +1, +2, or +3
- **Weapon (20):** Ammunition, +1, +2, or +3; Ammunition of Slaying; Berserker Axe; Dancing Sword; Defender; Dragon Slayer; Energy Bow; Flame Tongue; Frost Brand; Giant Slayer; Holy Avenger; Luck Blade; Nine Lives Stealer; Sword of Life Stealing; Sword of Sharpness; Sword of Wounding; Vicious Weapon; Vorpal Sword; Weapon, +1, +2, or +3; Weapon of Warning
- **Wondrous Item (112):** Amulet of Health; Amulet of Proof against Detection and Location; Amulet of the Planes; Apparatus of the Crab; Bag of Beans; Bag of Devouring; Bag of Holding; Bag of Tricks; Bead of Force; Bead of Nourishment; Belt of Dwarvenkind; Belt of Giant Strength; Bowl of Commanding Water Elementals; Bracers of Archery; Bracers of Defense; Brazier of Commanding Fire Elementals; Brooch of Shielding; Broom of Flying; Candle of Invocation; Cape of the Mountebank; Carpet of Flying; Censer of Controlling Air Elementals; Chime of Opening; Circlet of Blasting; Crystal Ball; Crystal Ball of Mind Reading; Crystal Ball of Telepathy; Crystal Ball of True Seeing; Cube of Force; Cubic Gate; Decanter of Endless Water; Deck of Illusions; Dimensional Shackles; Dragon Orb; Dust of Disappearance; Dust of Dryness; Dust of Sneezing and Choking; Efficient Quiver; Efreeti Bottle; Elemental Gem; Eversmoking Bottle; Eyes of Charming; Eyes of Minute Seeing; Eyes of the Eagle; Feather Token; Figurine of Wondrous Power; Folding Boat; Gauntlets of Ogre Power; Gem of Brightness; Gem of Seeing; Gloves of Missile Snaring; Gloves of Swimming and Climbing; Gloves of Thievery; Goggles of Night; Handy Haversack; Hat of Disguise; Headband of Intellect; Helm of Brilliance; Helm of Comprehending Languages; Helm of Telepathy; Helm of Teleportation; Horn of Blasting; Horn of Valhalla; Horseshoes of a Zephyr; Horseshoes of Speed; Instant Fortress; Ioun Stone; Iron Bands; Iron Flask; Lantern of Revealing; Mantle of Spell Resistance; Manual of Bodily Health; Manual of Gainful Exercise; Manual of Golems; Manual of Quickness of Action; Marvelous Pigments; Medallion of Thoughts; Mirror of Life Trapping; Mysterious Deck; Necklace of Adaptation; Necklace of Fireballs; Necklace of Prayer Beads; Pearl of Power; Periapt of Health; Periapt of Proof against Poison; Periapt of Wound Closure; Pipes of Haunting; Pipes of the Sewers; Portable Hole; Robe of Eyes; Robe of Scintillating Colors; Robe of Stars; Robe of the Archmagi; Robe of Useful Items; Rope of Climbing; Rope of Entanglement; Scarab of Protection; Sending Stones; Sovereign Glue; Sphere of Annihilation; Stone of Controlling Earth Elementals; Stone of Good Luck (Luckstone); Talisman of Pure Good; Talisman of the Sphere; Talisman of Ultimate Evil; Tome of Clear Thought; Tome of Leadership and Influence; Tome of Understanding; Universal Solvent; Well of Many Worlds; Wind Fan; Wings of Flying
- **Rod (7):** Immovable Rod; Rod of Absorption; Rod of Alertness; Rod of Lordly Might; Rod of Resurrection; Rod of Rulership; Rod of Security
- **Scroll (1):** Spell Scroll

## Coverage (after batch 3)

**Reviewed at clause level:**
- Batches 1–2 as listed before: weapons, armor, general magic rules, the 46 refused consumables, and SRD gear and tools. Iron Spikes and Chest are not reviewed, and Block and Tackle is not classified.
- **47 of the 192 missing magic items**: every Ring (21), Wand (12) and Boots/Cloak/Slippers entry (14), in B3-2. Clauses marked **check** or **unreviewed** in B3-2 are the open sub-items: self-only casting, Reaction budget, Command option restriction, charge-scaled upcast, jump, forced push, cover, sphere and cube activation hosts, and soul-in-item.

**Traced:** shell exposure (B2-3).

**Field level only:** the 94 loaded SRD magic records.

**Not reviewed:**
- **The 145 missing magic items in B3-3:** 112 Wondrous, 20 Weapon, 7 Rod, 5 Armor and 1 Scroll. Wondrous here excludes boots and cloaks.
- **The 49 equippable shells,** clause by clause.
- **Other SRD sections:** Ammunition, mounts and vehicles, improvised weapons, selling, lifestyle, trade goods, and sentient items and artifacts.
- **The 67 non-SRD items.**
- **Carrying capacity.**
- **Whether each named spell works in the runtime** (the spell audit's domain).

## Next queue

1. **Batch 4:** continue B3-3 with the Wondrous items (bags, amulets, belts, bracers, gloves, helms, figurines, and the rest), then Rods, Weapons and Armor. Apply PROPOSED-items-12/13 where they fit before adding anything new.
2. **Resolve the B3-2 "check" and "unreviewed" sub-items** against S-134, S-139 and S-085 code, and locate the jump, push and cover hosts.
3. **The 49 equippable shells,** clause by clause.
4. **Recover the Iron Spikes and Chest text,** and classify Block and Tackle once carrying capacity is located.
5. **Mounts, vehicles and Ammunition;** compare the Windows-runner registry hash.
