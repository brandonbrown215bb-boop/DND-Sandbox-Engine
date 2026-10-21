## Card Q-20261020-122658-cafa: every check class the logic runner registers
## must load and compile, or the run is red. A check file with a parse error
## used to drop its whole group while the summary still said ALL TESTS PASSED.
class_name CheckScriptGate
extends RefCounted

## Check classes named in the runner's own source ("FooChecks.run(...)").
static func registered(runner_source: String) -> Array[String]:
	var found: Array[String] = []
	var regex := RegEx.create_from_string("\\b([A-Z][A-Za-z0-9_]*Checks)\\.")
	for m in regex.search_all(runner_source):
		if m.get_string(1) not in found: found.append(m.get_string(1))
	found.sort()
	return found

static func class_paths() -> Dictionary:
	var out := {}
	for entry in ProjectSettings.get_global_class_list():
		out[str(entry.get("class", ""))] = str(entry.get("path", ""))
	return out

## Why a registered check script is unusable, or "" when it loaded and compiled.
static func load_error(name: String, script: Variant) -> String:
	if script == null or not script is Script: return "check script %s failed to load" % name
	if not (script as Script).can_instantiate(): return "check script %s failed to parse or compile" % name
	return ""

## name -> loaded Script (or null). Returns one failure message per bad script.
static func failures(scripts: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for name in scripts:
		var error := load_error(str(name), scripts[name])
		if not error.is_empty(): out.append(error)
	return out

## Load every registered check class named by the runner source.
static func load_registered(runner_path: String) -> Dictionary:
	var scripts := {}
	var paths := class_paths()
	var source := FileAccess.get_file_as_string(runner_path)
	if source.is_empty(): return {"<runner source %s>" % runner_path: null}
	for name in registered(source):
		var path := str(paths.get(name, ""))
		scripts[name] = ResourceLoader.load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
	return scripts
