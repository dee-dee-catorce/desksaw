extends Node
@onready
var VERSION = "0.3.1"
const RELEASES = "https://api.github.com/repos/dee-dee-catorce/deskpublic/releases"

var http: HTTPRequest

func _ready():
	http = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(_request_done)
	http.request(
		RELEASES,
		["User-Agent: DeskSaw"],
		HTTPClient.METHOD_GET
	)

func _request_done(_result, code, _headers, body):
	if code != 200:
		print("err", code)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return

	var releases = json.data
	if releases.is_empty():
		return

	var latest = releases[0].get("tag_name", "")
	if latest == "":
		return

	print("Latest version:", latest)

	if version_is_newer(latest, VERSION):
		# LOL
		#get_tree().change_scene_to_file("res://scenes/OLD/what.tscn")
		if gbData.settings["updNotif"]:
			OS.alert(tr("VERSION_DIALOG_MESSAGE") % [latest, VERSION], tr("VERSION_DIALOG_TITLE"))
		#gbData.outdated()


func version_is_newer(latest: String, current: String) -> bool:
	var a = latest.trim_prefix("v").split(".")
	var b = current.trim_prefix("v").split(".")

	while a.size() < 3:
		a.append("0")
	while b.size() < 3:
		b.append("0")

	for i in range(3):
		var x = int(a[i])
		var y = int(b[i])

		if x > y:
			return true
		if x < y:
			return false

	return false
