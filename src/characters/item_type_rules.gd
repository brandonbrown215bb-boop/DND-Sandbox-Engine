class_name ItemTypeRules
extends RefCounted
## Batch 048 (card Q-20261020-175109-7d43): magic-item types and measurements.
## Staffs and rods are held in the hand like wands. A wondrous item is worn only
## at a place its definition declares ("worn_slot"); without one it is carried.
## Weight (lb.) and volume (cubic feet) are optional facts: an absent value is
## unknown, never zero, so measured containers refuse it.

const HELD_TYPES := ["wand", "staff", "rod"]
const WORN_SLOTS := {"head": Inventory.Slot.HEAD, "feet": Inventory.Slot.FEET}

static func _measure(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v) >= 0.0 and float(v) <= 100000.0

static func definition_error(item: Dictionary) -> String:
	for key in ["weight", "volume"]:
		if item.has(key) and not _measure(item[key]): return "Item %s must be a non-negative number of %s, or absent when unknown" % [key, "pounds" if key == "weight" else "cubic feet"]
	if item.has("worn_slot"):
		if str(item.get("type", "")) != "wondrous": return "Only wondrous items declare a worn_slot"
		if not WORN_SLOTS.has(str(item.worn_slot)): return "Wondrous worn_slot must be one of %s" % str(WORN_SLOTS.keys())
	return ""

## The equipment slot a wondrous item is worn in, or -1 when it is only carried.
static func worn_slot(item: Dictionary) -> int:
	return int(WORN_SLOTS.get(str(item.get("worn_slot", "")), -1))
