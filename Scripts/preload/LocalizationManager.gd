extends Node

## Handles language selection.
##
## Languages ship inside `localization/localization.<locale>.translation`.
## Additional languages can be provided as external `.pck` files placed in
## the `languages/` folder next to the executable (see language_pack_loader.gd);
## those are mounted before the translation server reads its locale list.


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_init_language()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _init_language() -> void:
	if !gbData.settings.has("language"):
		gbData.settings["language"] = "en"
		gbData.savetodisk(gbData.conPath, gbData.settings)

	# Mount the language pack for the currently selected locale (if any)
	# *before* the translation server is queried, so its .translation file
	# becomes part of the loaded locale list.
	var wanted: String = str(gbData.settings.language)
	if LanguagePackLoader.has_language(wanted):
		LanguagePackLoader.activate(wanted)

	gbData.availableLanguages = _collect_locales()
	TranslationServer.set_locale(wanted)
	gbData.SettingsChanged.connect(_update_language)


func _update_language() -> void:
	var chosen: String = str(gbData.settings.language)
	# A pack can be mounted later than startup, so make sure it is active
	# whenever the user picks a locale that ships as an external pack.
	if LanguagePackLoader.has_language(chosen):
		LanguagePackLoader.activate(chosen)

	gbData.availableLanguages = _collect_locales()
	TranslationServer.set_locale(chosen)

	# Dialogue lives in its own JSON rather than in the translation table, so it
	# has to be re-read for a language change to apply without restarting.
	if gbData.has_method("reloadDialogue"):
		gbData.reloadDialogue()


## Locales known to the translation server, plus any shipped in a pack.
func _collect_locales() -> PackedStringArray:
	var locales := PackedStringArray(TranslationServer.get_loaded_locales())
	for loc in LanguagePackLoader.get_locales():
		if not locales.has(loc):
			locales.append(loc)
	return locales
