# Exact container contents and attached parts (S-196/S-210)

Status: **PARTIAL** (batch 068). The room HUD and projected-vessel cargo
controls let the player choose the exact compartment, contained copy, socket or
attached part instead of the old first-fit / last-out behavior.

## Data
There are no new fields. Compartments come from the item's existing
`container.compartments` and sockets from its `attachments.sockets` (ADR-0018).
There are no per-ID branches. Contents (`state.contents`) and attachments
(`state.attached`) were already saved and validated by
`ContainerRules.saved_error` / `AttachmentRules.saved_error` in both the
`players` DTO and party save paths. Legacy saves load unchanged.

## Rules (reused)
- `ContainerRules.stow_options / compartment_options / content_options` list
  only the choices that `put_error` accepts now, or the copies actually held.
  `stow_into` calls `put`, which revalidates everything. `take_out` refuses a
  stale offer (the copy is no longer in that compartment, or the container has
  left the holder) before anything moves, then calls `remove`.
- `AttachmentRules.socket_options / part_options` list only sockets that
  `attach_error` accepts, or parts that are actually attached. `attach_into` calls
  `attach`, which revalidates. `detach_part` refuses unless that socket still
  holds the offered instance, then calls `detach`.

## UI (`LocalRoomView.choose_exact`)
- No eligible option: the old first-fit/last-out function runs only to report
  its refusal reason.
- One option: it is applied directly.
- Two or more: a PopupMenu (`ExactChoiceMenu`) lists them with copy ordinals.
  - Dismissing the menu spends nothing and passes no time.
  - A pick is accepted once (serial check); a replay is ignored.
  - A pick made after the actor changed, or a stale pick, is refused before any
    time passes.
  - A successful move costs the existing 6 seconds, once.
- Hosts: the room **Stow / Take out / Attach / Detach** buttons, and the vessel
  **Stow cargo / Take out cargo** buttons.

## PARTIAL
- Worn or equipped hosts and containers aren't listed in the room item
  selector, so their exact parts can't be chosen from the HUD yet (the rules
  support them).
- Combat-turn hosts aren't wired. Nested containers stay unsupported, as before.
