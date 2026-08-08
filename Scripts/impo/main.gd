extends Node2D

@onready
var settings = gbData.settings


var screenWidth: int = DisplayServer.screen_get_usable_rect().size.x
var screenHeight: int = DisplayServer.screen_get_usable_rect().size.y

var taskbarPos: int = DisplayServer.screen_get_usable_rect().end.y

@export
var console: Node
# Called when the node enters the scene tree for the first time.
func _ready():
	DisplayServer.window_set_size(Vector2i(screenWidth, screenHeight) - Vector2i(1, 1))
	DisplayServer.window_set_position(DisplayServer.screen_get_position())
	if OS.get_name() == "Linux":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

	if OS.get_name() == "Linux" and OS.get_environment("XDG_SESSION_TYPE").to_lower() == "wayland" and not TransparentWindow.UsesInputRegions():
		OS.alert("DeskSaw could not enable its XWayland input-region workaround. Click-through interaction may not work correctly. Make sure DeskSaw is running through X11/XWayland with the XShape extension available, or use an X11 session.")

	GlobalVariable.console.connect(yeah)
	#fix()
	createBorders()

	GlobalVariable.resize.connect(updateBorders)

	update_obj_metas()

	var def = gbData.settings.get("defaultSkin", "Body")
	GlobalVariable.userSkinPath = "user://skin/" + def + "/"

	if gbData.settings["expiePersistence"]:
		loadExpiePersistence()
	else:
		$CanvasLayer2/ConsoleContainer/Main/ConsoleContainer/Commands.spawnExpie()


	if gbData.data["firstLaunch"]:
		gbData.data["firstLaunch"] =false
		var use_vulkan: bool = await GlobalVariable.makePopUp(
			"Do you currently see a black screen behind the application? \n\n Clicking yes will switch the rendering to [wave]Vulkan[/wave] \n This can be changed later in settings.",
			$CanvasLayer2,
			Vector2(screenWidth / 2, screenHeight / 2)
		)
		GlobalVariable._apply_renderer_and_restart(use_vulkan)


func yeah(t: bool):
	console.visible = t
	if t:
		console.showw()


func createBorders():
	taskbarPos = clampi(taskbarPos, 0, screenHeight)
	$Floor.position = Vector2(screenWidth / 2, taskbarPos)
	$SideL.position = Vector2(0, screenHeight / 2)
	$SideR.position = Vector2(screenWidth, screenHeight / 2)


func updateBorders():
	print("resizing")
	var oldheight = screenHeight
	screenWidth = DisplayServer.screen_get_usable_rect().size.x
	screenHeight = DisplayServer.screen_get_usable_rect().size.y
	taskbarPos = DisplayServer.screen_get_usable_rect().end.y

	DisplayServer.window_set_size(Vector2i(screenWidth, screenHeight) - Vector2i(1, 1))
	DisplayServer.window_set_position(DisplayServer.screen_get_position())
	for child in get_tree().current_scene.get_children():
			if child.has_meta("entity") or child.has_meta("object"):
				child.position.y -= screenHeight - oldheight
	createBorders()

func update_obj_metas():
	"""Assign 'catagory' meta with 'object' to all scenes in the object path."""
	
	var dir = DirAccess.open("res://scenes/objects")
	dir.list_dir_begin()
	var fileName = dir.get_next()
	
	while fileName != "":
		if fileName.ends_with(".tscn"):
			var path = "res://scenes/object".path_join(fileName)
			var object = load(path)
			if object is PackedScene:
				var instance = object.instantiate()
				add_child(instance)
		fileName = dir.get_next()
	dir.list_dir_end()


func loadExpiePersistence():
	print("loading expies...")
	

	if gbData.data["saw"].size() > 20:
		GlobalVariable.persistenceWarning.emit()
		print("Awaiting response from warning popup...")
		await GlobalVariable.persistenceWarning
		print("Response detected. Continuing...")

	for petId in gbData.data["saw"].keys():
		var petData = gbData.data["saw"][petId]
		print("loading '", petId, "' (skin: ", petData.get("skin", "Default"), ")...")
		await get_tree().create_timer(0.25).timeout
		GlobalVariable.userSkinPath = "user://skin/" + petData.get("skin", "Default") + "/"
		$CanvasLayer2/ConsoleContainer/Main/ConsoleContainer/Commands.spawnExpie(petId)
		print("loaded ", petId)
