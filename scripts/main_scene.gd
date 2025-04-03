extends Control

# 节点引用
@onready var entries_list = %EntriesList
@onready var winners_list = %WinnersList
@onready var current_winner_label = %CurrentWinner
@onready var draw_button = %DrawButton
@onready var reset_button = %ResetButton
@onready var devlog_filter_checkbox = %DevlogFilter
@onready var export_button = %ExportButton
@onready var export_dialog = $ExportDialog
# Assume EntriesList is an HBoxContainer inside this ScrollContainer
@onready var entries_scroll_container = %EntriesScrollContainer 

const CSV_PATH = "res://config/entries.csv"

# Scrolling Effect Variables
var scroll_speed = 50.0  # Pixels per second
var scroll_direction = 1.0
var enable_scrolling = true # Control scrolling activation

func _ready():
	# 初始化UI
	current_winner_label.text = ""
	
	# Load data using DataManager (similar to main_screen.gd snippet)
	var result = DataManager.fetch_data("csv", {"path": CSV_PATH})
	if result: # Assuming fetch_data returns true on success, false on error
		print("CSV data loaded successfully via DataManager. Entries: ", RaffleManager.entries.size()) # Assuming get_entries() exists
		update_ui() # Update UI after successful load
	else:
		# Assuming fetch_data might return a dictionary with an error message on failure
		var error_message = "Unknown error loading CSV data."
		if typeof(result) == TYPE_DICTIONARY and result.has("message"):
			error_message = result.message
		printerr("Failed to load CSV data via DataManager: ", error_message)
		OS.alert("加载参赛作品失败: " + error_message, "错误")
		update_ui() # Update UI even on failure to clear lists etc.

func _process(delta):
	if not enable_scrolling or not is_instance_valid(entries_scroll_container):
		return
		
	var scroll_bar = entries_scroll_container.get_h_scroll_bar()
	if not is_instance_valid(scroll_bar):
		return # Scrollbar might not be ready immediately

	var max_scroll = scroll_bar.max_value
	
	# Only scroll if content is wider than the container
	if max_scroll > 0:
		# Update scroll position
		var new_scroll = entries_scroll_container.scroll_horizontal + scroll_speed * scroll_direction * delta
		
		# Check boundaries and reverse direction
		if new_scroll >= max_scroll and scroll_direction > 0:
			scroll_direction = -1.0
			new_scroll = max_scroll # Clamp to max
		elif new_scroll <= 0 and scroll_direction < 0:
			scroll_direction = 1.0
			new_scroll = 0 # Clamp to min
			
		entries_scroll_container.scroll_horizontal = new_scroll
	else:
		# Reset scroll if content becomes smaller than container
		entries_scroll_container.scroll_horizontal = 0


func update_ui():
	# 清空列表
	# --- Clear Entries List --- 
	for child in entries_list.get_children():
		child.queue_free()

	# --- Clear Winners List --- 
	for child in winners_list.get_children():
		child.queue_free()

	# 显示所有参赛作品 (Using DataManager)
	# Similar to main_screen.gd snippet
	var entry_item_scene = load("res://scenes/ui/entry_list_item.tscn")
	var current_entries = DataManager.get_entries() # Assuming this method exists
	var show_devlog_only = devlog_filter_checkbox.button_pressed
	
	# Reset scroll position before repopulating
	if is_instance_valid(entries_scroll_container):
		entries_scroll_container.scroll_horizontal = 0
		
	for entry in current_entries:
		# Filter based on devlog status if checkbox is checked
		if show_devlog_only and entry.get("has_devlog", false) == false:
			continue
		var item = entry_item_scene.instantiate()
		if item.has_method("setup"):
			item.setup(entry)
		else:
			printerr("entry_list_item.tscn scene instance is missing the setup() method!")
			# Add placeholder if item type is unknown
			var placeholder = Label.new()
			placeholder.text = entry.get("title", "N/A")
			item = placeholder # Replace item with a simple label
		entries_list.add_child(item)

	# --- Populate Winners List (Using RaffleManager) --- 
	var winner_item_scene = load("res://scenes/ui/winner_list_item.tscn") 
	var current_winners = RaffleManager.get_winners() # Assuming this method exists
	if not current_winners.is_empty():
		var title_label = Label.new()
		title_label.text = "获奖名单:"
		winners_list.add_child(title_label)
		
		for winner_entry in current_winners:
			var item = winner_item_scene.instantiate()
			if item.has_method("setup"):
				item.setup(winner_entry) 
			else:
				printerr("winner_list_item.tscn scene instance is missing the setup() method!")
				if item is Label: # Fallback for basic Label
					item.text = winner_entry.get("title", "N/A") + " - " + winner_entry.get("user", "N/A")
				else: # Generic fallback
					var placeholder = Label.new()
					placeholder.text = winner_entry.get("title", "N/A") + " - " + winner_entry.get("user", "N/A")
					item = placeholder
			winners_list.add_child(item)

	# 更新按钮状态 (Using RaffleManager and DataManager)
	# Can draw if total entries > current winners
	var can_draw = DataManager.get_entries().size() > RaffleManager.get_winners().size() 
	# is_drawing state should be checked from RaffleManager if it manages it
	# draw_button.disabled = RaffleManager.is_drawing() or not can_draw 
	draw_button.disabled = not can_draw # Simplified for now

# 开始抽奖按钮
func _on_draw_button_pressed():
	var respect_filter = devlog_filter_checkbox.button_pressed
	# Get available entries from RaffleManager
	var available_entries = RaffleManager.get_available_entries() # Assuming signature matches
	
	if available_entries.is_empty():
		current_winner_label.text = "没有可抽奖的作品"
		return

	# Disable button immediately (RaffleManager might handle internal state)
	draw_button.disabled = true 
	enable_scrolling = false # Stop scrolling during draw

	# Execute draw via RaffleManager
	var selected_winner = RaffleManager.draw_winner(available_entries) # Assuming this selects and returns the winner
	
	if not selected_winner:
		printerr("RaffleManager.draw_winner failed to return a winner.")
		current_winner_label.text = "抽奖失败"
		# Re-enable button if draw failed internally (RaffleManager might handle this via signals)
		draw_button.disabled = false 
		enable_scrolling = true
		return

	# Update label with the winner
	current_winner_label.text = selected_winner.get("title", "N/A") + " - " + selected_winner.get("user", "N/A")
	
	# UI update should happen in response to RaffleManager signals (e.g., winner_drawn)
	# For simplicity here, we call update_ui directly after potential state change in RaffleManager
	update_ui() 
	enable_scrolling = true # Resume scrolling

# 重置抽奖按钮
func _on_reset_button_pressed():
	RaffleManager.reset_raffle() # Assuming this clears winners in RaffleManager
	current_winner_label.text = ""
	# UI update should happen in response to RaffleManager signals (e.g., raffle_reset)
	# Calling directly for simplicity
	update_ui() 

# --- New Signal Handlers ---

func _on_devlog_filter_toggled(_button_pressed):
	# Filter state is read directly in update_ui and _on_draw_button_pressed
	update_ui() 

func _on_export_button_pressed():
	export_dialog.popup_centered()

func _on_export_dialog_confirmed(path):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_line("游戏名称,作者")  # Simplified CSV Header for MVP
		var current_winners = RaffleManager.get_winners() # Get winners from manager
		for winner_entry in current_winners:
			var title = winner_entry.get("title", "N/A")
			var user = winner_entry.get("user", "N/A")
			title = title.replace('"', '""')
			user = user.replace('"', '""')
			var line = '"%s","%s"' % [title, user]
			file.store_line(line)
		file.close()
		print("Export successful to: ", path)
		OS.alert("导出成功！已保存到: " + path, "导出完成")
	else:
		printerr("Failed to open file for export: ", path)
		OS.alert("导出文件失败！无法写入路径: " + path, "导出错误")
