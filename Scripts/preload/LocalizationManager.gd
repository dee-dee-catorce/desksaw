extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_init_language()
	pass # Replace with function body.


func _init_language() -> void:
	if !gbData.settings.has("language"):
		gbData.settings["language"] = "en"
		gbData.savetodisk(gbData.conPath, gbData.settings)
		
	gbData.availableLanguages = TranslationServer.get_loaded_locales()
	TranslationServer.set_locale(gbData.settings.language)
	gbData.SettingsChanged.connect(_update_language)


func _update_language() -> void:
	TranslationServer.set_locale(gbData.settings.language)
	gbData.availableLanguages = TranslationServer.get_loaded_locales()


## test

func addlang() -> void:
	var path: String = await GlobalVariable.pickFolder()
	var file_name := path.get_file()
	var destination := gbData.sysTranslation.path_join(file_name)

	if path.is_empty():
		return

	var err := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(gbData.sysTranslation)
		)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return
	err = DirAccess.copy_absolute(
		path,
		ProjectSettings.globalize_path(destination)
	)
		#3

	var translation := ResourceLoader.load(destination) as Translation

	if translation == null:
		push_error("Failed to load translation: " + destination)
		return

	TranslationServer.add_translation(translation)

		#gbData.settings["language"] = translation.locale
	gbData.savetodisk(gbData.conPath, gbData.settings)
	gbData.availableLanguages = TranslationServer.get_loaded_locales()
	_update_language()
