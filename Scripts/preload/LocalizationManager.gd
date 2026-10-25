extends Node


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
		
	gbData.availableLanguages = TranslationServer.get_loaded_locales()
	TranslationServer.set_locale(gbData.settings.language)
	gbData.SettingsChanged.connect(_update_language)


func _update_language() -> void:
	TranslationServer.set_locale(gbData.settings.language)
	gbData.availableLanguages = TranslationServer.get_loaded_locales()


## test
func addlang() -> void:
		var path: String = await GlobalVariable.pickFolder()

		if path.is_empty():
			return

		var translation = ResourceLoader.load(path) as Translation

		if translation == null:
			push_error("Failed to load translation file: " + path)
			return

		TranslationServer.add_translation(translation)
		_update_language()
