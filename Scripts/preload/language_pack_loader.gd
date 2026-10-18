extends Node
## Language pack loader.
##
## Drop `<locale>.pck` into the `languages/` folder next to the executable and
## it gets mounted at startup, overriding base game files (translation
## resources, dialogue, ...). With no pack present the game stays English.
##
## Pack layout (inside the .pck):
##   res://lang.txt                                  first line = locale code
##   res://localization/localization.<locale>.translation
##   res://Scripts/singletons/TEMPDialogue.json      (optional, localized dialogue)
##   ...any other file that should replace the base one
##
## Why this exists: the base game registers its translations at engine start,
## so a pack mounted later is not picked up automatically. This node mounts
## the pack and then registers its Translation resource by hand.

const LANG_DIR := "languages"
const MANIFEST := "res://lang.txt"

## locale -> { "pack": absolute path, "file": file name, "name": display name }
var available: Dictionary = {}
## locale currently mounted from a pack ("" when none)
var active_locale: String = ""


func _ready() -> void:
	_search_packs()
	_auto_activate()


## Mount the pack the player last selected, as early as possible.
##
## This has to happen before any other autoload reads a localized resource
## (SaveLoadSys reads res://Scripts/singletons/TEMPDialogue.json in its own
## _ready), which is why this node sits first in the autoload list and does
## the mount itself instead of leaving it to LocalizationManager.
func _auto_activate() -> void:
	var wanted := ""
	var cfg := "user://CONFIG.json"
	if FileAccess.file_exists(cfg):
		var f := FileAccess.open(cfg, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary and parsed.has("language"):
				wanted = str(parsed["language"])
	if wanted.is_empty() or not available.has(wanted):
		return
	activate(wanted)


func _search_packs() -> void:
	var dir_path := OS.get_executable_path().get_base_dir().path_join(LANG_DIR)
	if not DirAccess.dir_exists_absolute(dir_path):
		return

	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("LanguagePackLoader: cannot open '%s'" % dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension().to_lower() == "pck":
			var full := dir_path.path_join(file_name)
			var meta := _peek_manifest(full)
			var locale: String = meta.locale
			if locale.is_empty():
				locale = file_name.get_basename().get_slice(".", 0)
			available[locale] = {
				"pack": full,
				"file": file_name,
				"name": meta.name if meta.name != "" else locale,
			}
			print("LanguagePackLoader: found pack '%s' (%s)" % [locale, file_name])
		file_name = dir.get_next()
	dir.list_dir_end()


## Read lang.txt out of the pack without registering anything.
func _peek_manifest(pack_path: String) -> Dictionary:
	var result := { "locale": "", "name": "" }
	if not ProjectSettings.load_resource_pack(pack_path, false):
		return result
	if FileAccess.file_exists(MANIFEST):
		var f := FileAccess.open(MANIFEST, FileAccess.READ)
		if f != null:
			result.locale = f.get_line().strip_edges()
			if not f.eof_reached():
				result.name = f.get_line().strip_edges()
	return result


## Mount the pack for `locale` and register its translation resource.
func activate(locale: String) -> bool:
	if not available.has(locale):
		return false

	var pack_path: String = available[locale].pack
	if not ProjectSettings.load_resource_pack(pack_path, true):
		push_error("LanguagePackLoader: failed to mount '%s'" % pack_path)
		return false

	# Mounting a pack again is harmless, but registering the same Translation
	# twice is not: it would fire a locale-change signal on every settings
	# update. Only register when this locale is not active yet.
	if active_locale == locale and TranslationServer.get_loaded_locales().has(locale):
		return true

	active_locale = locale

	# The engine only scans translations at startup, so register ours now.
	var tr_path := "res://localization/localization.%s.translation" % locale
	if not ResourceLoader.exists(tr_path):
		push_warning("LanguagePackLoader: no translation at '%s'" % tr_path)
		return true

	var res := ResourceLoader.load(tr_path)
	if res is Translation:
		if not TranslationServer.get_loaded_locales().has(locale):
			TranslationServer.add_translation(res)
			print("LanguagePackLoader: registered '%s' (%s)" % [locale, tr_path])
	else:
		push_error("LanguagePackLoader: '%s' is not a Translation" % tr_path)

	print("LanguagePackLoader: activated '%s'" % locale)
	return true


func has_language(locale: String) -> bool:
	return available.has(locale)


func get_locales() -> Array:
	var out: Array = available.keys()
	out.sort()
	return out
