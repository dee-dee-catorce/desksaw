extends Node

#i probably shouldve put these here earlier but better late than never

var pop = preload("res://scenes/ui/popup.tscn")
#ill fix the scripts that redefine these when it bothers me enough
var screenWidth: int = DisplayServer.screen_get_usable_rect().size.x
var screenHeight: int = DisplayServer.screen_get_usable_rect().size.y

var taskbarPos: int = DisplayServer.screen_get_usable_rect().end.y

var clickZoneSum: int = 0
@warning_ignore("unused_signal")
signal persistenceWarning() # used to warn user if they have more than 20 expies stored in persistence save
signal raga()
@warning_ignore("unused_signal")
signal vulkanToggle()
signal skinswap()
signal resize()
signal pet(t: bool)
@warning_ignore("unused_signal")
signal console(t: bool)
signal raisemood(t: int)
signal feed(t: int)
#signal bus shit this probably has like one thing in it
func petf(t: bool):
	pet.emit(t)
func Fresize():
	resize.emit()
func ragaa():
	raga.emit()
func skinswapFunc(data):
	skinswap.emit(data)

func raisemoodF(t: int):
	raisemood.emit(t)

func feedf(t: int):
	feed.emit(t)

@warning_ignore("unused_signal") # for now, we use other scripts to emit these
signal TerminalOpenPressed(is_native: bool)
@warning_ignore("unused_signal")
signal dataNuked
#make this
func makePopUp(text: String, parent: CanvasLayer, position: Vector2) -> bool:
	#add the scene properly this time
	var newpop = pop.instantiate()
	parent.add_child(newpop)

	newpop.labelText = text

	#configure
	newpop.titleText = "Hey!"
	newpop.yesButtonText = "Yes"
	newpop.noButtonText = "No"
	newpop.position = position
	#ts dont work
	newpop.size = Vector2(500, 300)
	#apply
	newpop.update_labels()
	newpop.update_buttons()


	var result = await newpop.hasPressedSignal

	newpop.queue_free()
	
	return result == CustomPopup.popupResultEnum.YES

"""
func makePopUp(text: String, parent: CanvasLayer, position: Vector2) -> bool:
	var path = "res://scenes/ui/popUp.tscn"
	var scene = load(path)
	var instance = scene.instantiate()
	parent.add_child(instance)
	instance.owner = parent
	instance.position = position
	var result: bool = await instance.setup(text)
	return result
"""
#just ignore this. pretend like i didnt waste time adding this and it just doesnt work
func _apply_renderer_and_restart(use_vulkan: bool) -> void:
	var method := "forward_plus" if use_vulkan else "gl_compatibility"
	ProjectSettings.set_setting("rendering/renderer/rendering_method", method)
	ProjectSettings.save()

	OS.set_restart_on_exit(true, OS.get_cmdline_args())

	gbData.settings.renderingMode = use_vulkan
	gbData.data["firstLaunch"] = false
	gbData.savetodisk("user://SAVE.json", gbData.data)
	gbData.savetodisk("user://CONFIG.json", gbData.settings)
	get_tree().quit()
#????????????????
var userSkinPath = "user://skin/Body/"


func getNumFromString(inputString: String):
	var number_string = ""
	
	for i in range(inputString.length()):
		var character = inputString[i]
		if character.is_valid_int():
			number_string += character
			
	return number_string


func checkpositive(num):
	if num is int or num is float:
		return num >= 0
	return false


func pickFolder():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true

	dialog.add_filter("*.translation ; Godot Translation File")

	add_child(dialog)
	dialog.popup_file_dialog()

	var path = await dialog.file_selected
	dialog.queue_free()

	return path


func _process(_d: float) -> void:
	if Input.is_action_just_pressed("Open Terminal"):
		TerminalOpenPressed.emit(true)
