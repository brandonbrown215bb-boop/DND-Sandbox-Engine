class_name Batch083Checks
extends RefCounted
## Batch 083 (#47 follow-up, S-162). Brandon: "treating consumption as
## destruction is fine for now; don't add a consume cause until content needs
## it. Update the technical reference, which still says consumption lacks a
## cause." This batch is docs-only for S-162; no consume cause is added.
## It also pins Review 082's dice nit: validation strips all spaces, and the
## roller (Dice.parse_dice_details / maximum_dice_string) strips all spaces too,
## so "12 d12" means 12d12 in both places.

static func run(check: Callable) -> void:
	check.call(SharedStepExecutor._formula("12 d12") and SharedStepExecutor._formula("12d12"), "083 validation accepts '12 d12' and '12d12' alike")
	check.call(Dice.maximum_dice_string("12 d12") == 144 and Dice.maximum_dice_string("12d12") == 144 and Dice.maximum_dice_string(" 12 d 12 ") == 144, "083 roller reads '12 d12' as 12d12 (max 144), agreeing with validation")
	var ok := true
	for i in 20:
		var r := Dice.parse_dice_string("12 d12")
		ok = ok and r >= 12 and r <= 144
	check.call(ok, "083 rolling '12 d12' stays within 12..144")
	# Review 083: assert the actual dice terms rolled, not just a range a flat 12 would also satisfy.
	var a := Dice.parse_dice_details("12 d12")
	var at: Array = a.get("dice_terms", [])
	check.call(at.size() == 1 and int(at[0]["count"]) == 12 and int(at[0]["sides"]) == 12, "083 review: rolling '12 d12' rolls twelve d12s")
	var b := Dice.parse_dice_details("2 d8 + 4")
	var bt: Array = b.get("dice_terms", [])
	var bsum := 0
	for v in (bt[0]["results"] if bt.size() == 1 else []): bsum += int(v)
	check.call(bt.size() == 1 and int(bt[0]["count"]) == 2 and int(bt[0]["sides"]) == 8 and int(b["final_total"]) == bsum + 4, "083 review: rolling '2 d8 + 4' rolls 2d8 and adds 4")
