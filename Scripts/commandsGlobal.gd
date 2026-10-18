extends Node

signal toggleDebugText
signal resizeCommandCalled(size: Vector2, force: bool)

signal runInitialCommands
var has_run_commands: bool = false

"""
    ###

    there was a bunch of bullshit planning on how i would go about this and there ended up being an addon that did literally
    everything i was planning on adding

    here you go

    https://github.com/4d49/godot-console


    this script just registers a bunch of commands and contains their the functions for their code

    to create a custom command, create a function that contains ur code, and then register it in _ready
    ###
"""

func _log(strang: String):
	return strang

func _cust(cmd: String):
	return cmd

func openskinfold():
	OS.shell_open(ProjectSettings.globalize_path("user://skin"))

func _setmood(val: float):
	Console.warning(tr("CONSOLE_MOOD_DISABLED_MESSAGE"))
	return val

func reload():
	get_tree().change_scene_to_file("res://scenes/newmain.tscn")


func spawnExpie(petId: String = ""):
	var instance = preload("res://scenes/sawianBase.tscn").instantiate()

	if petId == "":
		var skinName = GlobalVariable.userSkinPath.substr(0, len(GlobalVariable.userSkinPath) - 1)
		skinName = skinName.substr(skinName.rfind("/") + 1)
		petId = gbData.addPet(skinName)
	instance.get_node("behavior").petId = petId

	var wrapper = Node2D.new()
	wrapper.scale = Vector2(4.0, 4.0)
	
	#Update scale based on saved info or spawn setting
	if gbData.data["saw"][petId].has("spawnSize"):
		wrapper.scale *= gbData.data["saw"][petId]["spawnSize"]
	else:
		if gbData.settings.has("spawnSize"):
			wrapper.scale *= gbData.settings["spawnSize"]
		
	get_tree().current_scene.add_child(wrapper)
	wrapper.owner = get_tree().current_scene

	wrapper.add_child(instance)
	instance.owner = get_tree().current_scene

	instance.global_position.x = float(GlobalVariable.screenWidth) / 2
	instance.global_position.y = - float(GlobalVariable.screenHeight) * 2
	wrapper.set_meta("Category", "entity")


func _additem(item: String = "containercrate"):
	# add crate only for now
	var path = "res://scenes/objects/" + item + ".tscn"
	if !ResourceLoader.exists(path):
		Console.error(tr("CONSOLE_NO_SUCH_OBJECT_MESSAGE") % item)
		return
	var scene = load(path)
	var instance = scene.instantiate()
	get_tree().current_scene.add_child(instance)
	instance.global_position = instance.get_global_mouse_position()
	instance.owner = get_tree().current_scene
	instance.set_meta("itemName", item)


func clearObj(category: String = "object"):
	var exclude = [
		"Floor",
		"SideR",
		"SideL",
		"CanvasLayer",
		"CanvasLayer2"
	]
	

	for child in get_tree().current_scene.get_children():
		if not exclude.has(child.name):
			if category == str(child.get_meta("Category")) or category == str(child.get_meta("itemName")): ## this one is fucking me rn
				print(child)
				if gbData.data["saw"].has(child.get_meta("itemName")): # check if deleting a pet
					gbData.removePet(child.get_meta("itemName"))
				await get_tree().create_timer(.005).timeout
				child.queue_free()


	if category == "entity":
		gbData.data["saw"] = {}
		print("cleared pet persistence data")


func nukesettings():
	#command that fixes the "terror" bug
	gbData.killEverything()
	GlobalVariable.dataNuked.emit()

func setmonitor(monitorIndex: int = 1):
	DisplayServer.window_set_current_screen(monitorIndex)
	GlobalVariable.Fresize()

func resize(nx, ny, isForce = "no") -> String:
	var ex = str(nx).to_float()
	var ey = str(ny).to_float()
	if (
		(ex < 200 or ey < 100)
		or (ex > float(GlobalVariable.screenWidth) / 2 or ey > GlobalVariable.screenHeight)
		) and isForce == "no":
		Console.warning(tr("CONSOLE_RESIZING_WARNING_MESSAGE"))
		Console.print(tr("CONSOLE_RESIZE_OVERRIDE_MESSAGE").format([nx, ny]))
		return tr("CONSOLE_RESIZE_NOTE")
	# if it goes through, call a resize
	var _target_size = Vector2(ex, ey)
	resizeCommandCalled.emit(_target_size, true)
	#save to config
	if isForce == "no":
		gbData.settings.ConsoleSize.x = ex
		gbData.settings.ConsoleSize.y = ey

	#debugshit
	if gbData.devMode == true:
		print(gbData.settings.ConsoleSize.x)
		print(gbData.settings.ConsoleSize.y)

	# please work please

	gbData.savetodisk("user://CONFIG.json", gbData.settings)
	return "resized"

func toggleExpieDebugIDs():
	toggleDebugText.emit()

func deathLoop():
	while true:
		Console.execute("log I_HATE_YOU")
		await get_tree().create_timer(.1).timeout

func _ready():
	# connect our signal to running initial commands
	runInitialCommands.connect(_do_i_cmds)

	# register commands
	Console.create_command("log", _log, tr("CONSOLE_LOG_COMMAND_DESCRIPTION"))
	Console.create_command("resizeConsole", resize, tr("CONSOLE_RESIZECONSOLE_COMMAND_DESCRIPTION"))
	#dont use this it breaks alot of shit Console.create_command("reload", reload, "reload everything")
	Console.create_command("setMonitor", setmonitor, tr("CONSOLE_SETMONITOR_COMMAND_DESCRIPTION"))
	##Console.create_command("killExpie", killExpie, "Yeha")
	#Console.create_command("setMood", _setmood, "debugging tool that doesnt work because i disabled mood stuff for this build")
	Console.create_command("spawn", _additem, tr("CONSOLE_SPAWN_COMMAND_DESCRIPTION"))
	Console.create_command("clearItems", clearObj, tr("CONSOLE_CLEARITEMS_COMMAND_DESCRIPTION"))
	Console.create_command("spawnExpie", spawnExpie, tr("CONSOLE_SPAWNEXPIE_COMMAND_DESCRIPTION"))
	#Console.create_command("openSkinFolder", openskinfold, "opens the skin folder")
	Console.create_command("nukeData", nukesettings, tr("CONSOLE_NUKEDATA_COMMAND_DESCRIPTION"))
	#Console.create_command("expieID", toggleExpieDebugIDs, "toggles debug IDs for expies")
	#Console.create_command("deathLoop", deathLoop, "please dont crash")


func _do_i_cmds():
	if has_run_commands:
		return
	has_run_commands = true

	# i thought this had to be run from the console node itself but turns out its reflected on all consoles! hooray!
	Console.execute("setMonitor {0}".format([int(gbData.settings.get("defaultMonitor", 0))]))
	Console.execute("help")
	Console.print(tr("CONSOLE_DISCLAIMER_MESSAGE"))


"""	
	# if any of these flags are true, cancel function
var x = false
var y = false
var z = false
func checkthingbad();

	#this is fine but its hard to read

    if x:
        if y:
            if z:
                return
                print("z is true, cancel function")
		else:
			return
			print("y is true, cancel function")
	else:
		return
		print("x is true, cancel function")

	# do thing here

func checkthing();

	## i like this better

	if (x):
		print("x is true, cancel function")
		return
	if (y):
		print("y is true, cancel function")
		return
	if (z):
		print("z is true, cancel function")
		return

		## logic here
"""
