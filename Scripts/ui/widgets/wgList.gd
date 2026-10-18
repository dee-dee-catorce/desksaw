@tool

extends PanelContainer

@export_category("Settings")
## Text to be shown alongside the checkbox.
@export_multiline var label: String:
	set(new_label):
		label = new_label
		_update_label()
## Config. key to change when switching the checkbox.
@export var key: String

@export_category("Values")
@export var values: Array[String] = []
@export var selectedValue: String
@export var defaultValue: String

@export_category("Nodes - DONT CHANGE")
@export var _optionButton: OptionButton
@export var _label: Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not Engine.is_editor_hint():
		refresh()
		_optionButton.item_selected.connect(_on_option_button_item_selected)
		GlobalVariable.dataNuked.connect(_read_refresh)

		# Language pickers leave `values` empty so the list is built from the
		# locales that are actually available at runtime (including any
		# external language pack that was mounted at startup).
		if values.is_empty():
			values = _available_options()

		set_items(values)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func refresh() -> void:
	_update_label()
	_update_state()


func _update_state() -> void:
	var init_v = gbData.settings.get(key)
	if init_v == null:
		# if the key doesn't exist, create it!
		_init_variable(false)
		selectedValue = defaultValue
	elif !(init_v is String):
		# if the key is not a boolean, fuss about it!
		push_error("Key '%s' is not a string! Only string values are supported in this list" % [key])
		# for the sake of preventing confusion, we won't initiate the variable on
		# failure to load. instead, make sure you're not mixing up key types and widgets!
	else:
		# update starting pressed state according to value
		var value: String = init_v
		selectedValue = value


var _ignore_next_change: bool = false
func _read_refresh() -> void:
	# currently calling this when we nuke our config to
	# correctly display all values.
	_ignore_next_change = true
	refresh()


func _init_variable(save: bool = false) -> void:
	gbData.settings.set(key, defaultValue)
	if save:
		gbData.savetodisk(gbData.conPath, gbData.settings)


func _update_label() -> void:
	# this function is called before the label can ready up, which is
	# prettyy annoying. couldn't find a proper way to call this once.
	if not _label:
		return
	_label.text = label


func _set_selected_value(index : int) -> void:
	if values.size() - 1 < index :
		push_error("Key '%s' is not a string! checkbox widgets are not made for these!" % [key])
		return
	
	selectedValue = values[index]


func _on_option_button_item_selected(index: int) -> void:
	_set_selected_value(index)
	
	gbData.settings.set(key, selectedValue)
	print("Key '%s' [%s] set to '%s'" % [label, key, selectedValue])
	# save!
	gbData.savetodisk(gbData.conPath, gbData.settings)
	gbData.SettingsChanged.emit()
	pass # Replace with function body.


func set_items(items : Array[String]) -> void:
	values = items
	var index = 0
	_optionButton.clear()
	for item in values:
		_optionButton.add_item(item, index)
		if(item == selectedValue):
			_optionButton.select(index)
		
		index = index + 1


## Options to populate an empty list widget with.
## For the language key this is every locale the game can actually switch to.
func _available_options() -> Array[String]:
	var result: Array[String] = []
	if key == "language":
		var locales: PackedStringArray = TranslationServer.get_loaded_locales()
		if typeof(gbData) != TYPE_NIL:
			var known = gbData.get("availableLanguages")
			if known != null:
				for loc in known:
					if not locales.has(loc):
						locales.append(loc)
		# keep a stable, readable order: english first, then alphabetical
		if locales.has("en"):
			result.append("en")
		var rest: Array[String] = []
		for loc in locales:
			if loc != "en":
				rest.append(loc)
		rest.sort()
		result.append_array(rest)
	return result

