extends Control
class_name WinnerDialog

signal confirmed(winner: EntryResource)

@onready var entry_container = %EntryContainer
@onready var confirm_button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ConfirmButton

var winner_entry: EntryResource = null
var entry_instance: EntryListItem = null

func _ready():
	# Connect confirm button signal
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	
	# Set up initial scale for animation
	scale = Vector2.ZERO
	
	# Play open animation
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.5)

# Set the winner entry and display it
func set_winner(entry: EntryResource):
	winner_entry = entry
	
	# Clear any existing entry
	if entry_instance:
		entry_instance.queue_free()
	
	# Create new entry list item
	entry_instance = load("res://scenes/ui/entry_list_item.tscn").instantiate()
	entry_container.add_child(entry_instance)
	
	# Setup the entry
	entry_instance.setup(entry)
	
	# Center the entry in the container
	entry_instance.position = Vector2(
		(entry_container.size.x - entry_instance.size.x) / 2,
		(entry_container.size.y - entry_instance.size.y) / 2
	)
	
	# Add a small bounce animation to the entry
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BOUNCE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(entry_instance, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(entry_instance, "scale", Vector2.ONE, 0.2)

# Close the dialog with animation
func close():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	tween.tween_callback(queue_free)

# Confirm button pressed handler
func _on_confirm_button_pressed():
	confirmed.emit(winner_entry)
	close()
