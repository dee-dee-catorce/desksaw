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
	var text = FileAccess.get_file_as_string(source_file)
	
	var test_json_conv = JSON.new()
	test_json_conv.parse(text)
	var json = test_json_conv.get_data()
	
	var translation = Translation.new()
	translation.locale = json["locale"]
	
	var messages = json["messages"]
	for messageKey in messages.keys():
		translation.add_message(messageKey, messages[messageKey])
	
	return ResourceSaver.save(translation, "%s.%s" % [save_path, _get_save_extension()])
