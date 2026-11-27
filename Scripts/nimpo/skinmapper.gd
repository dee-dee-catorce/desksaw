extends Node

@export
var bodyRoot: NodePath
@export
var currtextures: Array = []
@export
var alltextures: Array = []
#paths
signal mappe(currtextures: Dictionary)
var resPath = "res://assets/Body/"
var userSkinPath = GlobalVariable.userSkinPath
#furry girlfirend 
func _ready() -> void:
	if userSkinPath == "user://skin/Default/": userSkinPath = resPath
	print("Using '", userSkinPath, "' for new expie's skin")
	mapSkin()
	loadAllTextures()

func mapSkin():
	currtextures.clear()
	var root = get_node(bodyRoot)
	var sprites = getspr(root)

	var skinFileNames = {}
	var dir = DirAccess.open(userSkinPath)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png":
				skinFileNames[file_name] = true
			file_name = dir.get_next()
		dir.list_dir_end()

	if skinFileNames.size() == 0:
		print("no skin files found in ", userSkinPath)

	for sprite in sprites:
		sprite.flip_v = false
		var appliedTex = swapTex(sprite, skinFileNames)
		if appliedTex:
			currtextures.append(appliedTex)

	mappe.emit(currtextures)


func swapTex(sprite: Sprite2D, skinFileNames: Dictionary):
	var tex = sprite.texture
	if tex == null:
		return null

	var file_name = tex.resource_path.get_file()

	if not skinFileNames.has(file_name):
		return {
			"name": file_name,
			"texture": tex
		}

	var new_path = userSkinPath + file_name
	var new_tex = loadUserTex(new_path)

	if new_tex:
		sprite.texture = new_tex
		return {
			"name": file_name,
			"texture": new_tex
		}

	return {
		"name": file_name,
		"texture": tex
	}
var textureCache:Dictionary[String, Texture2D]
func loadUserTex(userPath: String)->Texture2D:
	if textureCache.has(userPath):
		return textureCache[userPath]
	if not FileAccess.file_exists(userPath):
		return null

	# load internal resources directly, prevents the
	# debugger from getting pissed off
	if userPath.begins_with("res:"):
		return load(userPath)

	
	var image =Image.load_from_file(userPath)
	if not image:
		return null
		
	var texture=ImageTexture.create_from_image(image)
	textureCache[userPath]=texture
	return texture

func getspr(node: Node) -> Array:
	var found = []
	for child in node.get_children():
		if child is Sprite2D:
			found.append(child)
		found.append_array(getspr(child))
	return found

func getAppliedTextures() -> Array:
	return currtextures

func loadAllTextures():
	alltextures.clear()

	var dir := DirAccess.open(resPath)
	if dir == null:
		print("DIR OPEN FAILED: ", resPath)
		return

	dir.list_dir_begin()

	while true:
		var entry = dir.get_next()
		if entry == "":
			break

		if dir.current_is_dir():
			continue

		var file: String

		if entry.ends_with(".import"):
			file = entry.get_basename()
		elif entry.get_extension() in ["png", "jpg"]: # for debugging
			file = entry
		else:
			continue
		if entry.ends_with(".JSON"):
			continue
		var tex: Resource
		var user_tex = loadUserTex(userSkinPath + file)

		if user_tex is Texture2D:
			tex = user_tex
		else:
			tex = load(resPath + file)

		if tex is Texture2D:
			alltextures.append({
				"name": file,
				"texture": tex
			})


	dir.list_dir_end()
