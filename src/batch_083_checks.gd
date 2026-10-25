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
