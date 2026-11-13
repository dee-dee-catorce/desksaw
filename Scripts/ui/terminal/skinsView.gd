extends Panel

@export_category("Nodes - DONT CHANGE")
#im gonna change it FUCK YOU
@export var defaultSkinButton: Button
@export var spawnButton: Button

@export var addDialogue: Button
@export var openFolderButton: Button
@export var refreshButton: Button
@export var openDBButton: Button
@export var expieDisplayWidget: ExpieWidget
@export var skinsButtonList: BoxContainer
@export var skinNameLabel: RichTextLabel

class SkinEntry:
	var name: String
	var path: String

var _root_path = "user://skin"
var skinsDirectoryArray: Array = []
var selectedSkin = null # can be SkinEntry or null

var skinButtons: Array[Button] = []

func _ready() -> void:
	spawnButton.pressed.connect(_on_spawn_button_press)
	addDialogue.pressed.connect(_on_cd_button_press)
	defaultSkinButton.pressed.connect(_on_skin_button_press)
	openFolderButton.pressed.connect(_on_skin_folder_button_press)
	refreshButton.pressed.connect(_on_refresh_button_press)
	openDBButton.pressed.connect(_on_db_button_press)

	visibility_changed.connect(_update)
	scan_for_skins()

func _update() -> void:
	if !visible:
		return
	# refresh expie display
	skinNameLabel.text = get_skin_name()
	GlobalVariable.userSkinPath = (
		"res://assets/Body/" if selectedSkin == null
		else selectedSkin.path
	)
	expieDisplayWidget.ApplyTextures(GlobalVariable.userSkinPath)

func get_skin_name() -> String:
	return "Experiment" if selectedSkin == null else selectedSkin.name

func spawnExpie(petId: String = ""):
	var path = "res://scenes/sawianBase.tscn"
	var scene = load(path)
	var instance = scene.instantiate()

	if petId == "":
		var n = selectedSkin.name if selectedSkin else gbData.settings.get("defaultSkin", "Body")
		petId = gbData.addPet(n)
	instance.get_node("behavior").petId = petId

	var wrapper = Node2D.new()
	wrapper.scale = Vector2(4.0, 4.0)

	get_tree().current_scene.add_child(wrapper)
	wrapper.owner = get_tree().current_scene

	wrapper.add_child(instance)
	instance.owner = get_tree().current_scene

	"""
	# im totally not upset that it took me 20 minutes to fuigye0=fuwerauoasdfg to figure out that this was running seperately
	from the spawn command.
	which is why the ids werent being added to the dictionary
 	im totally not.

	maybe i should go over prs for an extra hour or two next time

	
	"""

	instance.global_position.x = float(GlobalVariable.screenWidth) / 2
	instance.global_position.y = - float(GlobalVariable.screenHeight) * 2
	wrapper.set_meta("Category", "entity")


## Look for all available user skins and store them.
func scan_for_skins() -> void:
	skinsDirectoryArray = []
	var dirac = DirAccess.open(_root_path)
	if !dirac:
		push_warning("skins folder not found?")
		return

	var directories = dirac.get_directories()

	for directory_name in directories:
		# ignore our default folder name.
		if directory_name == gbData.settings.get("defaultSkin", null):
			continue
		# register otherwise.
		var _skin = SkinEntry.new()
		_skin.name = directory_name
		_skin.path = _root_path.path_join(directory_name).path_join("/")
		skinsDirectoryArray.append(_skin)

	print("scanned for skins. found %s" % [len(skinsDirectoryArray)])
	regenerate_buttons()

## Create buttons for our custom skins.
func regenerate_buttons() -> void:
	for b in skinButtons: # remove existing ones
		b.queue_free()
	skinButtons.clear()
	# generate buttons using skin data.
	for skin in skinsDirectoryArray:
		var btn = Button.new()
		skinsButtonList.add_child(btn)
		btn.owner = skinsButtonList
		btn.text = skin.name
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(_on_skin_button_press.bind(skin))
		skinButtons.append(btn)

## Select a skin when pressing on a skin button.
func _on_skin_button_press(skin_entry = null) -> void:
	if skin_entry is SkinEntry:
		print("pressed on %s @ '%s'!" % [skin_entry.name, skin_entry.path])
	else:
		print("pressed default!")
	selectedSkin = skin_entry
	_update()

# buton

func _on_spawn_button_press() -> void:
	GlobalVariable.userSkinPath = (
		"res://assets/Body/" if selectedSkin == null
		else selectedSkin.path
	)
	CommandsGlobal.spawnExpie()

func _on_skin_folder_button_press() -> void:
	OS.shell_open(ProjectSettings.globalize_path("user://skin"))

func _on_refresh_button_press() -> void:
	scan_for_skins()

func _on_db_button_press() -> void:
	OS.shell_open("https://skin.cat-bot.de/")

#just following the naming conventions here, i fucking hate snake case personally
func _on_cd_button_press() -> void:
	newDialogue(ProjectSettings.globalize_path(GlobalVariable.userSkinPath))


func newDialogue(skin_dir: String) -> void:
	var defaultTrans = "res://Scripts/singletons/CustomDialogueTemplate.json"
	var dialoguepath = skin_dir.path_join("CUSTOM-DIALOGUE.json")


	if !FileAccess.file_exists(dialoguepath):
		var text = gbData.loadjson(defaultTrans).duplicate(true)
		gbData.savetodisk(dialoguepath, text)


	OS.shell_open(dialoguepath)


"""

TODO: CHANGE TEXT IF THERES ALREADY A CUSTOM FILE THERE
CHANGE*

"""
