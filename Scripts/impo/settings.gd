extends Node

# thank you randoms on discord
@onready

var settings = gbData.settings
@export var list: Control


@export var partent: Control
var sMAP = {
	"deathBool": {"key": "invincible", "type": "toggle"},
	"lobotomize": {"key": "lobotomize", "type": "toggle"},
	"useVulkan": {"key": "useVulkan", "type": "toggle"},
	"expiePersistence": {"key": "expiePersistence", "type": "toggle"},
	"pixel": {"key": "pixel", "type": "toggle"},
	"expieFontSize": {"key": "expieDialogueSize", "type": "text"},
	"hungerRate": {"key": "hungerDecayRate", "type": "text"},
	"openAlert": {"key": "messageEnabled", "type": "toggle"},
	"mute": {"key": "mute", "type": "toggle"},
	"mutePassive": {"key": "mutePassive", "type": "toggle"},
	"dialogueSoundBool": {"key": "dialogueSoundEnabled", "type": "toggle"},
	"whiningSoundBool": {"key": "whiningSoundEnabled", "type": "toggle"},
	"barkSoundBool": {"key": "barkSoundEnabled", "type": "toggle"},
	"pettingSoundBool": {"key": "pettingSoundEnabled", "type": "toggle"},
	"minMood": {"key": "minMood", "type": "text"},
	"maxMood": {"key": "maxMood", "type": "text"},
	"normalize": {"key": "normalize", "type": "text"},
	"soundVolume": {"key": "soundVolume", "type": "slider"},
	"defaultSkin": {"key": "defaultSkin", "type": "string"},
}


func _ready() -> void:
	if gbData.devMode:
		#print("Settings ", settings)
		pass
	_initset()
	
	assign_tab_meta_to_leftovers() # does what it says, so if a setting doesnt have 'Tab' meta, its created and "General" is assgined
	for child in $VSplitContainer/ScrollContainer/ItemList.get_children(): # apply meta tag to say that a setting is not visible by default. e.i. disabled settings
		if !child.visible:
			child.set_meta("DefaultVisibility", true)
	_on_general_tab_pressed() # pretend that general was just pressed


func _initset() -> void:
	$VSplitContainer/ScrollContainer.custom_minimum_size = partent.size
	for node_name in sMAP:
		var node = findSettingN(node_name)
		if node == null:
			continue

		var entry = sMAP[node_name]
		var key = entry["key"]
		var type = entry["type"]

		match type:
			"toggle":
				node.button_pressed = settings.get(key, false)
				node.toggled.connect(func(on): sett(key, on))

			"text":
				node.text = str(settings.get(key, ""))
				node.text_submitted.connect(func(val): sett(key, float(val)))

			"string":
				node.text = str(settings.get(key, ""))
				node.text_submitted.connect(func(val): sett(key, val))

			"slider":
				node.value = settings.get(key, node.min_value)
				node.value_changed.connect(func(val): sett(key, val))


# 
func findSettingN(node_name: String) -> Node:
	for child in list.get_children():
		if child.name == node_name:
			return child
	return null


func sett(key: String, value) -> void:
	settings[key] = value
	_saveSettings()


func _saveSettings() -> void:
	$VSplitContainer/ScrollContainer.custom_minimum_size = partent.size
	gbData.savetodisk(gbData.conPath, gbData.settings)
	if gbData.devMode:
		print("Settings saved")


func _on_expie_persistence_pressed(): # special case, as if disabled we want to wipe everything
	if not gbData.settings.expiePersistence:
		gbData.data["saw"] = {}


### Tab handling:
## This is VERY hard-coded, so adding a new tab is a bit of a process. sry abt that. Hopefully I re-write at some point :P

@onready var GeneralTabN = $VSplitContainer/TabsScrollContainer/HBoxContainer/GeneralTab
@onready var AudioTabN = $VSplitContainer/TabsScrollContainer/HBoxContainer/AudioTab

func assign_tab_meta_to_leftovers():
	var children: Array[Node] = $VSplitContainer/ScrollContainer/ItemList.get_children()
	
	for child in children:
		if !child.has_meta("Tab"):
			child.set_meta("Tab", "General")

func get_tab_nodes(TabName):
	var results: Array[Node] = []
	var children: Array[Node] = $VSplitContainer/ScrollContainer/ItemList.get_children()

	for child in children:
		if child.has_meta("Tab"):
			if child.get_meta("Tab") == TabName:
				results.append(child)
	return results


func hide_all_settings():
	for child in $VSplitContainer/ScrollContainer/ItemList.get_children():
		child.visible = false

func show_all_tab_type(type):
	var nodes = get_tab_nodes(type)
	for node in nodes:
		if node.get_meta("DefaultVisibility"):
			pass
		else:
			node.visible = true


func _on_general_tab_pressed():
	AudioTabN.button_pressed = false
	GeneralTabN.button_mask = 0 # disable mouse clicks, so user cannot disable the button
	AudioTabN.button_mask = 1 # enable mouse click for other tab
	hide_all_settings()
	show_all_tab_type("General")


func _on_audio_tab_pressed():
	GeneralTabN.button_pressed = false
	GeneralTabN.button_mask = 1 # enable mouse click for other tab
	AudioTabN.button_mask = 0 # disable mouse clicks, so user cannot disable the button
	hide_all_settings()
	show_all_tab_type("Audio")




func _on_use_vulkan_toggled(toggled_on: bool) -> void:
	if toggled_on == gbData.settings.useVulkan: return
	GlobalVariable._apply_renderer_and_restart(toggled_on)
	pass # Replace with function body.
