# Drives the demo menu for a recorded check: focus moves down the list, the
# Transitions item runs twice, then E1 is chosen and skipped back to the menu.
extends Node

var n := 0

func _ready() -> void:
	_start.call_deferred()

func _start() -> void:
	# Leave the scene slot so changing scene does not free this driver.
	reparent(get_tree().root)
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://demo/demo_menu.tscn")

func _btn(i: int) -> Button:
	var menu := get_tree().current_scene
	return menu._slots[i].get_child(0) as Button

func _process(_d: float) -> void:
	n += 1
	if not get_tree().current_scene or not ("_slots" in get_tree().current_scene):
		return
	match n:
		110: _btn(1).grab_focus()
		130: _btn(8).grab_focus()
		150, 230, 310, 390, 470, 550: _btn(8).pressed.emit()
		640: _btn(0).grab_focus()
		655: _btn(0).pressed.emit()
