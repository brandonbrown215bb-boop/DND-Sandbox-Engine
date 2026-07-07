## Event Chain
## Handles multi-step events where one event leads to another.
class_name EventChain
extends RefCounted

## Follow an event chain. If the event has a chain_event, return it.
## Otherwise return an empty dictionary.
static func get_chain_event(event_data: Dictionary) -> Dictionary:
	if event_data.get("type", "") == "chain":
		return event_data.get("chain_event", {})
	return {}


## Check if an event has a follow-up chain.
static func has_chain(event_data: Dictionary) -> bool:
	return event_data.get("type", "") == "chain" and event_data.has("chain_event")
