@tool
extends EditorImportPlugin

func _get_importer_name():
	return "json_translations_importer"

func _get_visible_name():
	return "JSON Translation"

func _get_recognized_extensions():
	return ["json"]
	
func _get_save_extension():
	return "translation"
	
func _get_resource_type():
	return "Translation"

func _get_preset_count():
	return 1

func _get_preset_name(preset):
	return "Default"
			
func _get_import_options(path, preset_index):
	return []
			
func _get_import_order():
	return 0
			
func _get_priority():
	return 1

func _import(source_file, save_path, options, r_platform_variants, r_gen_files):
	var file = FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		push_error("Cannot open %s: %s" % [source_file, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()

	var text = file.get_as_text()
	file.close()

	var parser = JSON.new()
	var err = parser.parse(text)
	if err != OK:
		push_error("JSON parse error in %s line %d: %s" % [source_file, parser.get_error_line(), parser.get_error_message()])
		return err

	var json = parser.get_data()
	if typeof(json) != TYPE_DICTIONARY or not json.has("locale") or not json.has("messages"):
		push_error("%s is not a valid translation JSON (needs 'locale' and 'messages')" % source_file)
		return ERR_INVALID_DATA

	var translation = Translation.new()
	translation.locale = json["locale"]

	var messages = json["messages"]
	for messageKey in messages.keys():
		translation.add_message(messageKey, messages[messageKey])

	return ResourceSaver.save(translation, "%s.%s" % [save_path, _get_save_extension()])