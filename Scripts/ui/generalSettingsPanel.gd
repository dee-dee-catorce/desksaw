extends Panel


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_intit_languages()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_intit_languages()
	pass
	

func _intit_languages() -> void:
	var languages: Array[String] = []
	languages.assign(gbData.availableLanguages)
	$ScrollContainer/VBoxContainer/Language.set_items(languages)
