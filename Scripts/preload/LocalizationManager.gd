extends Node


func _ready() -> void:
	_init_language()
	pass

func _init_language() -> void:
	if !gbData.settings.has("language"):
		gbData.settings["language"] = "en"
		gbData.savetodisk(gbData.conPath, gbData.settings)


	loadSavedlang()

	gbData.availableLanguages = TranslationServer.get_loaded_locales()
	TranslationServer.set_locale(gbData.settings.language)
	gbData.SettingsChanged.connect(_update_language)


## test
func _update_language() -> void:
	TranslationServer.set_locale(gbData.settings.language)
	gbData.availableLanguages = TranslationServer.get_loaded_locales()


## Scans the translations folder and registers every .json locale file found.

func loadSavedlang() -> void:
	var dir: DirAccess = DirAccess.open(gbData.sysTranslation)
	if dir == null:
		return

	for file_name: String in dir.get_files():
		if file_name.get_extension().to_lower() != "json":
			continue

		var loaded: Translation = translationFromJson(
			gbData.sysTranslation.path_join(file_name)
		)
		if loaded != null:
			registerTranslation(loaded)


func translationFromJson(path: String) -> Translation:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	
	var data: Variant = JSON.parse_string(file.get_as_text())


	var translation: Translation = Translation.new()
	translation.locale = data["locale"]

##### ttqtettwefe


	for key: Variant in data["messages"]:
		translation.add_message(key, str(data["messages"][key]))
	return translation


func registerTranslation(translation: Translation) -> void:
	var existing: Translation = TranslationServer.get_translation_object(translation.locale)
	if existing != null and existing.locale == translation.locale:
		TranslationServer.remove_translation(existing)
	TranslationServer.add_translation(translation)


#test

func addlang() -> void:
	var path: String = await GlobalVariable.pickFolder()
	if path.is_empty():
		return

	
	var translation: Translation = translationFromJson(path)
	if translation == null:
		return


	registerTranslation(translation)
		#gbData.settings["language"] = translation.locale
	gbData.savetodisk(gbData.conPath, gbData.settings)
	#gbData.availableLanguages = TranslationServer.get_loaded_locales()
	_update_language()