# Batch 043 build: S-196 / S-202

Stacks on Batch 042 (PR #10, `batch-042-s162-s165` @ 1e055f0).

## Selection
Ready slices had status Planned, every dependency Verified or built in the open 034-042 stack, and no claim. They also had to stay out of the excluded areas:
- tools/content_editor/
- the wand charge path
- non-class mode_choice / rule_alternatives (F1)
- DruidRules / Wild Shape
- S-120 successor code
- BondRules linked-group disposal triggers (give, container, sell)
- S-165 vessel / item-projection scope, including S-166

The picks:
- **S-196, exact contents and mass/volume compartments.** Deps S-032 and S-049 are Verified. It has the widest unblock: S-170, S-197, S-198 and S-210 (with S-161), and S-167 later.
- **S-202, persistent curse and attunement restrictions.** Deps S-161 (built in 041) and S-072 (Verified). It unblocks S-203 and makes the existing cursed-attunement path data-declared.

Also ready but lower value or overlapping: S-087, S-107, S-121, S-127, S-140, S-150, S-152, S-156, S-175, S-177, S-180, S-184, S-190, S-206, S-212, S-214, S-216.

## Design
- **`ContainerRules` (S-196)**
  - An item declares `container.compartments[{id, item_types?, max_count, max_weight?, max_volume?}]`, and DataLoader validates it.
  - `put` moves the exact carried, unequipped copy into `state.contents[compartment]` of the container record. It refuses before anything moves when:
    - the compartment is undeclared
    - the item type isn't allowed
    - the count, weight or volume limit would be exceeded (an item with no recorded weight or volume can't be measured)
    - the container would hold itself or another container
    - the copy is cursed or attuned
    - the copy is **bonded** (so no container trigger touches BondRules)
  - `remove` returns the same record to the backpack once, and checks backpack space first.
  - Giving the container carries its contents.
  - HUD: the local-room item row gains **Stow** (`ContainerRules.stow`) and **Take out** (`retrieve_last`).
  - Saves: contents ride in the container's copy record.
    - `ContainerRules.saved_error`, run in both SaveManager paths, refuses: duplicated or re-carried identities, undeclared compartments, over-limit contents, contents held by a non-container, nested containers, attuned children and future serials.
    - `InventoryCopies.ownership_error` now also counts contained ids across characters.
- **`CurseRules` (S-202)**
  - An item declares `curse: {removal: blocked|allowed, lingering?: {blocks_attunement}, break: {spells, min_slot_level}}`. It requires `cursed` and `requires_attunement`, and DataLoader validates it.
  - With `removal: allowed` the cursed copy can be unequipped, but its curse and attunement stay on that copy, and it still can't be given or taken.
  - Voluntary unattunement stays refused.
  - When an attuned cursed copy is destroyed or dropped, a declared lingering curse is recorded on the actor (`item_curses[instance_id]`), and it blocks new attunement.
  - Remove Curse (`spell_effect_application`) now also calls `CurseRules.break_with(target, "remove_curse", slot_level)`. That breaks only the copies and lingering curses whose declared spell and minimum slot level the cast meets. The rest are reported as resisting.
  - The legacy blanket `break_cursed_item_attunements` skips declared curses. Undeclared cursed items, such as the Sword of Vengeance, keep their old route.
  - Other copies of the same item stay independent.
  - Saves: `item_curses` is saved and restored. `CurseRules.saved_error` refuses undeclared, weakened, extended and still-held records.
- Every new public function has a production caller: DataLoader, SaveManager, Character, Inventory hooks, the Remove Curse effect, the local-room HUD buttons and `InventoryCopies.ownership_error`.

## Validation
- Logic: **5214 passed / 0 failed**, against a fresh baseline at 1e055f0 of 5182/0. That is **+32**, equal to the 32 checks in `batch_043_checks.gd`.
- Scenarios (0 FAIL each): 031 25, 032 33, 033 70, 034 10, 035 9, 036 7, 037 11, 038 7, 039 10, 040 13, 041 11, 042 9, **043 10**, shared_spell_flow 67. There was no SCRIPT ERROR or Parse Error in any log.
- `batch_043_container_curse_flow` covers:
  - Real unequip of an allowed-removal cursed copy, then a real drop of a second one, which leaves its lingering curse.
  - A real HUD Remove Curse at slot 3: the slot is spent and both declared curses resist.
  - A real HUD Remove Curse at slot 4: exactly those curses break.
  - The HUD stow route for two exact copies.
  - A real `SaveManager` save/load with the contents and a new lingering curse live, with no state clearing:
    - the contents are in place
    - the re-attuned copy is still cursed and the lingering block holds
    - Take out after the load returns the exact copy once

## Limits
- Containers can't nest. Bonded, attuned and cursed copies can't be stowed, which is deliberate while container triggers in BondRules wait on Brandon.
- Destroying a container destroys its contents.
- Contained child copies keep their state, but SaveManager doesn't re-validate their item-specific state (charges and similar).
- World room containers (`LocalRoomRules` put/take) are unchanged and separate.
- The HUD has no compartment chooser: Stow picks the first carried compartment that accepts the copy, and Take out takes the most recent one.
- The only declared curse consequence is blocking attunement. The curse break spell list is data, but only Remove Curse calls `break_with`.
- The fixtures use type `tool` because of F3 (Q-20261020-175109-7d43).
