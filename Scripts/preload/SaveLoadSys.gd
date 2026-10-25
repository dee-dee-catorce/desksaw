extends Node


"""
i had to redo this because the hive mind bug was really weird
heres the saving stuffs.,

s[dfuiogh iopsdfg uioesfigsdhuiopashdfyg ioasfg oaisud f 9ASDYFH ASYUISDUIOFGSH G SDVPASPUHV ZSDG OASG PASRV ASG ASDFGSD GSDFXGB SDFGH SDF ASFZGASDFG SDFGG SDFG  3QTFGWE9RUGH9-SERG H3QER GUOH]

"""

var data = {}
var text = {}
var settings = {}

var dialogueCache = {}

var skinData = []

var template = "res://Scripts/singletons/SaveTemplate.json"

var availableLanguages = []

# DO NOT FORGET TO DISABLE THIS WHENBUILDING 
var devMode = false
#turns out you can literally make a custom project setting that does something like this
#but im too  in too deep to go back now

const savePath = "user://SAVE.json"
const dialoguePath = "user://DIALOGUEDEFAULT.json"
const conPath = "user://CONFIG.json"
const skinfilepath = "user://skin"

const sysTranslation = "user://translations"


func _ready():
	# Load save file
	if FileAccess.file_exists(savePath):
		data = loadjson(savePath)
		var templateData = loadjson(template)
		fixMissing(data, templateData)

		for petId in data.get("saw", {}).keys():
			fixMissing(data["saw"][petId], templateData["sawTemplate"])
		if data.get("saw", {}).is_empty():
			addPet("Default")

	else:
		newsave()
	
	# Load dialogue file
	if FileAccess.file_exists(dialoguePath):
		text = loadjson(dialoguePath)
		fixMissing(text, loadjson("res://Scripts/singletons/DefaultDialogue.json"))
	else:
		newDialogue()

	# Load settings/config file
	if FileAccess.file_exists(conPath):
		settings = loadjson(conPath)
		fixMissing(settings, loadjson("res://Scripts/singletons/config.json"))
	else:
		newConfig()

	if DirAccess.dir_exists_absolute(skinfilepath):
		skinData = loadSkin()
	else:
		newSkinFile()


	InitAutosave()

#this bug fuxking sucks so im removing it once and for all
#automatically detect if the user is missing a setting or something related to that
#should fix the shocked face bug PERMANANTLY
func fixMissing(base: Dictionary, default: Dictionary):
	for key in default.keys():
		if not base.has(key):
			if typeof(default[key]) == TYPE_DICTIONARY:
				base[key] = default[key].duplicate(true)
			else:
				base[key] = default[key]

		elif typeof(base[key]) == TYPE_DICTIONARY and typeof(default[key]) == TYPE_DICTIONARY:
			fixMissing(base[key], default[key])


func newsave():
	# Read the save template
	if not ResourceLoader.exists(template):
		print("template not found at: ", template)
		return


	var keepAcrossSaves = data.get("everPresentAcrossSaves", null)

	#set data json to template
	data = loadjson(template).duplicate(true)

	if keepAcrossSaves != null:
		data["everPresentAcrossSaves"] = keepAcrossSaves
	#apparentally that function does nothing and hasnt done anything for a while??? or people are just lysing to me.
	#randomize()

#	what does ts even do
	#pingpong()
	var firstPetId = addPet("Default")
	data["saw"][firstPetId]["mood"] += randi_range(-5, 5)
	data["saw"][firstPetId]["hunger"] -= randi_range(1, 5)
	data["saw"][firstPetId]["trust"] += randi_range(-10, 0)

	savetodisk(savePath, data)


func addPet(skin: String = "Default") -> String:
	var newId = "id" + str(int(data.get("nextPetId", 1)))
	data["nextPetId"] = int(data.get("nextPetId", 1)) + 1

	data["saw"][newId] = data["sawTemplate"].duplicate(true)
	data["saw"][newId]["skin"] = skin
	if gbData.settings.has("spawnSize"):
		data["saw"][newId]["spawnSize"] = gbData.settings["spawnSize"]
	else:
		data["saw"][newId]["spawnSize"] = 1.0
	
	savetodisk(savePath, data)
	return newId


func removePet(id: String) -> void:
	if not data.get("saw", {}).has(id):
		return
	data["saw"].erase(id)
	data["everPresentAcrossSaves"]["PetsKilled"] += 1
	savetodisk(savePath, data)

func newDialogue():
	#fix this later make it bassdfjogsdjfoigjsdfgjosdifgjiosdfjg nvm its good as it
	var defaultTrans = "res://Scripts/singletons/TEMPDialogue.json"
	
	text = loadjson(defaultTrans).duplicate(true)
	savetodisk(dialoguePath, text)

func newConfig():
	var configFile = "res://Scripts/singletons/config.json"

	settings = loadjson(configFile).duplicate(true)
	savetodisk(conPath, settings)

func newSkinFile():
	var readMeF = skinfilepath + "/READ.txt"
	

	if not DirAccess.dir_exists_absolute(skinfilepath):
		var error = DirAccess.make_dir_recursive_absolute(skinfilepath)
		
		if error == OK:
			var txt = FileAccess.open(readMeF, FileAccess.WRITE)
			

			if txt:
				txt.store_line("""Drop the Body folder of your skin into this folder!


In theory, everything on https://skin.cat-bot.de/ should be compatible with this!

If you want multiple skins, just rename your 'Body' folder to whatever you want to call it, then use the skin spawner.
(however you have to keep a 'Body' folder with any skin in it for it to work!)
If you have both a 'Body' and 'Head' folder, combine the files inside them into a new folder and drag them in here.

If your skin is only on the head, try restarting the app. That usually fixes it.

If you want custom dialogue for a specific skin, just copy the 'TRANSLATION.json' file from outside the folder and paste it into skin’s folder!
Skin with TRANSLATION.json file will use it's own dialogue instead of the default one.
""")
				txt.close()
	
	var folder_to_copy = "res://assets/Body"
	
	var new_dir_path: String = "user://skin/Body"
	DirAccess.make_dir_absolute(new_dir_path)
	
	#Copy each file and folder into the new folder
	var old_files: PackedStringArray = DirAccess.get_files_at(folder_to_copy)
	for f: String in old_files:
		# only copy images
		if !f.get_extension().to_lower() == "png":
			continue
		DirAccess.copy_absolute(folder_to_copy + "/" + f, new_dir_path + "/" + f)
	#var old_directories: PackedStringArray = DirAccess.get_directories_at(folder_to_copy)


func loadSkin():
		var _ifliterallyanythingisthere = false
		var added = []
		var pt = skinfilepath + "/Body"
		if DirAccess.dir_exists_absolute(pt):
			var files = DirAccess.get_files_at(pt)
			for file in files:
				if file.get_extension().to_lower() == "png":
					_ifliterallyanythingisthere = true
					added.append(pt.path_join(file))
			
		return added


# my favorite helpers!
#theyre gone nvm
func loadjson(filepath: String):
	if FileAccess.file_exists(filepath):
		var datafile = FileAccess.open(filepath, FileAccess.READ)
		var parsedresult = JSON.parse_string(datafile.get_as_text())
		if parsedresult is Dictionary:
			return parsedresult
		else:
			if gbData.devMode:
				print("Error parsing JSON file: " + filepath)
			return {}
	else:
		if gbData.devMode:
			print("File not found: " + filepath)
		return {}

# looks for a TRANSLATION.json in the skin folder, falls back to the global one
func getDialogueForSkin(skinPath: String):
	if skinPath.begins_with("res:"):
		return text.diaGlobal
	if dialogueCache.has(skinPath):
		return dialogueCache[skinPath]
	var merged = text.diaGlobal.duplicate(true)
	var skinFile = skinPath + "CUSTOM-DIALOGUE.json"
	if FileAccess.file_exists(skinFile):
		var skinText = loadjson(skinFile)
		if skinText is Dictionary and skinText.get("diaGlobal") is Dictionary:
			for key in skinText["diaGlobal"]:
				merged[key] = skinText["diaGlobal"][key]
			dialogueCache[skinPath] = merged
	return merged

func savetodisk(path, dt):
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			var json_string = JSON.stringify(dt, "\t")
			file.store_line(json_string)
			file.close()


func InitAutosave():
	while true:
		await get_tree().create_timer(3.0).timeout
		if gbData.devMode:
			print("saved")

		savetodisk(savePath, data)
		savetodisk(conPath, settings)


func killEverything():
	newsave()
	newDialogue()
	newSkinFile()
	newConfig()

func outdated():
	if settings.outdated:
		print("already outdated")
		return
	settings.outdated = true
	killEverything()

func checkupdated():
	if !settings.outdated: return
	print("version is current")
	settings.outdated = false

@warning_ignore("unused_signal") # called externally
signal SettingsChanged()

# used for getting settings in csharp scripts
# let me know if there's a better way to do this
func GetSetting(key: String, default):
	return settings.get(key, default)