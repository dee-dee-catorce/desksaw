extends Node

#i probably shouldve put these here earlier but better late than never

#ill fix the scripts that redefine these when it bothers me enough
var screenWidth: int = DisplayServer.screen_get_usable_rect().size.x
var screenHeight: int = DisplayServer.screen_get_usable_rect().size.y

var taskbarPos: int = DisplayServer.screen_get_usable_rect().end.y

var clickZoneSum: int = 0
signal persistenceWarning() # used to warn user if they have more than 20 expies stored in persistence save
signal raga()
signal skinswap()
signal resize()
signal pet(t: bool)
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

func consoleF(t: bool):
	console.emit(t)

func raisemoodF(t: int):
	raisemood.emit(t)

func feedf(t: int):
	feed.emit(t)


func makePopUp(text: String, parent: CanvasLayer, position: Vector2) -> bool:
	var path = "res://scenes/popUp.tscn"
	var scene = load(path)
	var instance = scene.instantiate()
	parent.add_child(instance)
	instance.owner = parent
	instance.position = position
	var result: bool = await instance.setup(text)
	return result


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
