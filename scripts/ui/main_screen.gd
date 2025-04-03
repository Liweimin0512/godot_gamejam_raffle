extends Control
# 主屏幕场景脚本
# 负责主界面的UI逻辑和交互

# UI元素引用
@onready var entries_list = $MarginContainer/VBoxContainer/MainContainer/LeftPanel/EntryListPanel/VBoxContainer/EntriesContainer/EntriesList
@onready var prizes_list = $MarginContainer/VBoxContainer/MainContainer/LeftPanel/PrizePanel/VBoxContainer/PrizesContainer/PrizesList
@onready var winners_list = $MarginContainer/VBoxContainer/MainContainer/RightPanel/WinnerListPanel/VBoxContainer/WinnersContainer/WinnersList
@onready var winner_display_label = $MarginContainer/VBoxContainer/MainContainer/CenterPanel/DrawArea/WinnerLabel
@onready var draw_button = $MarginContainer/VBoxContainer/MainContainer/CenterPanel/DrawArea/Button
@onready var reset_button = $MarginContainer/VBoxContainer/HeaderContainer/MenuContainer/ResetButton
@onready var load_button = $MarginContainer/VBoxContainer/HeaderContainer/MenuContainer/LoadButton
@onready var load_csv_button = $MarginContainer/VBoxContainer/HeaderContainer/MenuContainer/LoadCSVButton
@onready var itch_io_button = $MarginContainer/VBoxContainer/HeaderContainer/MenuContainer/ItchIoButton
@onready var filter_button = $MarginContainer/VBoxContainer/HeaderContainer/MenuContainer/FilterButton

# 对话框容器
@onready var dialogs_container = $DialogsContainer

# 管理器引用
var raffle_manager
var data_manager
var config_manager
var effect_manager
var ui_manager

# 动画状态
var is_animating = false

signal raffle_started
signal raffle_completed(winner, prize)

func _ready():
	# 获取管理器引用
	raffle_manager = get_node("/root/RaffleManager")
	data_manager = get_node("/root/DataManager")
	config_manager = get_node("/root/ConfigManager")
	effect_manager = get_node("/root/EffectManager")
	ui_manager = get_node("/root/UIManager")
	
	# 连接信号
	draw_button.connect("pressed", _on_draw_button_pressed)
	reset_button.connect("pressed", _on_reset_button_pressed)
	load_button.connect("pressed", _on_load_button_pressed)
	load_csv_button.connect("pressed", _on_load_csv_button_pressed)
	itch_io_button.connect("pressed", _on_itch_io_button_pressed)
	filter_button.connect("pressed", _on_filter_button_pressed)
	
	# 初始化
	_reset_ui()

# 更新所有UI元素
func update_all_ui():
	update_entries_list()
	update_prizes_list()
	update_winners_list()
	update_draw_button()

# 更新参赛作品列表
func update_entries_list():
	# 清空列表
	for child in entries_list.get_children():
		child.queue_free()
	
	# 显示参赛作品
	for entry in raffle_manager.entries:
		var entry_item = preload("res://scenes/ui/entry_list_item.tscn").instantiate()
		entries_list.add_child(entry_item)
		entry_item.setup(entry)

# 更新奖项列表
func update_prizes_list():
	# 清空列表
	for child in prizes_list.get_children():
		child.queue_free()
	
	# 显示所有奖项
	for prize in raffle_manager.prizes:
		var prize_item = preload("res://scenes/ui/prize_list_item.tscn").instantiate()
		prize_item.setup(prize)
		prize_item.connect("delete_requested", _on_prize_delete_requested)
		prizes_list.add_child(prize_item)

# 处理删除奖项请求
func _on_prize_delete_requested(prize):
	raffle_manager.remove_prize(prize.name)
	update_prizes_list()

# 更新获奖者列表
func update_winners_list():
	# 清空列表
	for child in winners_list.get_children():
		child.queue_free()
	
	# 显示获奖者
	for prize_name in raffle_manager.winners:
		var prize_label = Label.new()
		prize_label.text = prize_name
		prize_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
		winners_list.add_child(prize_label)
		
		for winner in raffle_manager.winners[prize_name]:
			var winner_item_label = Label.new()
			winner_item_label.text = "    " + winner.title + " - " + winner.user
			winners_list.add_child(winner_item_label)

# 更新抽奖按钮状态
func update_draw_button():
	var next_prize = raffle_manager.get_next_prize()
	var can_draw = next_prize != null and raffle_manager.get_available_entries().size() > 0
	draw_button.disabled = is_animating or not can_draw

# 重置UI状态
func _reset_ui():
	winner_display_label.text = ""
	update_all_ui()

# 抽奖按钮被按下
func _on_draw_button_pressed():
	# 获取可用的参赛者
	var available_entries = raffle_manager.get_available_entries()
	if available_entries.size() == 0:
		dialogs_container.show_message("提示", "没有可用的参赛者")
		return
	
	# 开始动画
	is_animating = true
	draw_button.disabled = true
	winner_display_label.text = "抽奖中..."
	
	emit_signal("raffle_started")
	
	# 启动动画序列
	_animate_raffle(available_entries)

# 重置按钮被按下
func _on_reset_button_pressed():
	dialogs_container.show_confirmation(
		"重置确认", 
		"确定要重置抽奖结果吗？所有获奖者将被清空。",
		func(): raffle_manager.reset_raffle()
	)

# 加载数据按钮
func _on_load_button_pressed():
	dialogs_container.show_file_dialog()

# 加载CSV按钮
func _on_load_csv_button_pressed():
	var csv_path = "res://config/entries.csv"
	var result = data_manager.fetch_data("csv", {"path": csv_path})
	if result:
		dialogs_container.show_message("成功", "CSV数据加载成功，共加载 " + str(raffle_manager.entries.size()) + " 个参赛作品。")
		update_all_ui()
	else:
		dialogs_container.show_message("错误", "CSV数据加载失败: " + result.message)

# itch.io导入按钮
func _on_itch_io_button_pressed():
	dialogs_container.show_jam_id_dialog()

# 设置权重按钮
func _on_filter_button_pressed():
	dialogs_container.show_weight_dialog(config_manager)

# 执行抽奖动画
func _animate_raffle(available_entries):
	var frame_count = 0
	var total_frames = 30 + randi() % 20  # 30-50帧
	
	while frame_count < total_frames:
		if frame_count < total_frames - 1:
			# 随机显示参赛者
			var random_index = randi() % available_entries.size()
			var entry = available_entries[random_index]
			winner_display_label.text = entry.title + " - " + entry.user
			frame_count += 1
		else:
			# 动画结束，执行抽奖
			_perform_raffle()
			break
		
		# 等待下一帧
		await get_tree().create_timer(0.1).timeout

# 执行实际抽奖
func _perform_raffle():
	# 获取当前策略
	var strategy = config_manager.current_strategy
	
	# 执行抽奖
	var result = raffle_manager.perform_raffle(strategy)
	is_animating = false
	
	if not result.success:
		winner_display_label.text = result.message
		update_all_ui()
		return
	
	# 播放胜利特效
	effect_manager.play_win_effect($MarginContainer/VBoxContainer/MainContainer/CenterPanel/DrawArea/EffectsContainer)
	
	# 发送抽奖完成信号
	emit_signal("raffle_completed", result.winner, result.prize)
