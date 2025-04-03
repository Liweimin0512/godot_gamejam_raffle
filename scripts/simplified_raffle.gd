extends Control

# 引用条目列表项场景和获奖者列表项场景
const ENTRY_LIST_ITEM = preload("res://scenes/ui/entry_list_item.tscn")
const WINNER_LIST_ITEM = preload("res://scenes/ui/winner_list_item.tscn")
const CONFETTI = preload("res://scenes/confetti.tscn")

# 条目和获奖者列表的引用
@onready var entries_list = $MainPanel/ContentContainer/EntriesPanel/VBoxContainer/EntriesContainer/EntriesList
@onready var winners_list = $MainPanel/ContentContainer/WinnersPanel/VBoxContainer/WinnersContainer/WinnersList
@onready var current_winner_label = $MainPanel/DrawArea/CurrentWinner
@onready var particles_container = $MainPanel/DrawArea/ParticlesContainer
@onready var devlog_filter = $MainPanel/ControlPanel/DevlogFilter
@onready var export_dialog = $ExportDialog

# 所有条目、当前筛选后的条目和获奖者
var all_entries = []
var filtered_entries = []
var winners = []

# 当前是否正在进行抽奖动画
var is_drawing = false

func _ready():
	# 设置窗口标题
	get_window().title = "GameJam 抽奖系统 (简化版)"
	
	# 从CSV文件加载数据
	load_entries_from_csv("res://config/entries_updated.csv")
	
	# 初始筛选条目
	filter_entries()

# 从CSV文件加载参赛条目
func load_entries_from_csv(csv_path):
	all_entries.clear()
	
	var file = FileAccess.open(csv_path, FileAccess.READ)
	if file:
		# 跳过表头行
		var _header = file.get_csv_line()
		
		# 读取每一行数据
		while !file.eof_reached():
			var data = file.get_csv_line()
			if data.size() >= 8 and data[0].strip_edges() != "": # 确保有足够的数据且标题不为空
				var entry = {
					"title": data[0],
					"id": data[1],
					"url": data[2],
					"has_devlog": data[3] == "有",
					"author": data[4],
					"comment": data[5],
					"image": data[6],
					"weight": data[7].to_int() if data[7].is_valid_int() else 1
				}
				all_entries.append(entry)
		
		print("已加载 ", all_entries.size(), " 个参赛作品")
	else:
		print("无法打开文件: ", csv_path)

# 根据开发日志筛选条目
func filter_entries():
	filtered_entries.clear()
	entries_list.clear()
	
	for entry in all_entries:
		if !winners.has(entry) and (devlog_filter.button_pressed == false or entry.has_devlog):
			filtered_entries.append(entry)
			add_entry_to_list(entry)
	
	# 更新UI
	$MainPanel/ControlPanel/DrawButton.disabled = filtered_entries.size() <= 0
	
	print("筛选后剩余 ", filtered_entries.size(), " 个参赛作品")

# 将条目添加到UI列表中
func add_entry_to_list(entry):
	var item = ENTRY_LIST_ITEM.instantiate()
	entries_list.add_child(item)
	item.setup(entry)
	
	# 根据是否有开发日志设置不同的颜色
	if entry.has_devlog:
		item.modulate = Color(0.8, 1.0, 0.8)
	else:
		item.modulate = Color(1.0, 0.8, 0.8)

# 添加获奖者到UI列表
func add_winner_to_list(entry):
	var item = WINNER_LIST_ITEM.instantiate()
	winners_list.add_child(item)
	item.setup(entry)

# 抽奖按钮事件处理
func _on_draw_button_pressed():
	if is_drawing or filtered_entries.size() <= 0:
		return
	
	is_drawing = true
	
	# 随机选择一个获奖者
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# 计算权重总和
	var total_weight = 0
	for entry in filtered_entries:
		total_weight += entry.weight
	
	# 随机选择一个权重点
	var random_point = rng.randi_range(1, total_weight)
	
	# 找到对应的条目
	var current_sum = 0
	var selected_entry = null
	
	for entry in filtered_entries:
		current_sum += entry.weight
		if random_point <= current_sum:
			selected_entry = entry
			break
	
	if selected_entry == null and filtered_entries.size() > 0:
		selected_entry = filtered_entries[0]  # 防止错误，默认选择第一个
	
	# 播放抽奖动画
	var animation_duration = 2.0
	var flash_entries = []
	
	# 随机闪烁一些条目
	for i in range(10):
		var random_entry = filtered_entries[rng.randi() % filtered_entries.size()]
		flash_entries.append(random_entry)
	
	# 最后添加真正的获奖者
	flash_entries.append(selected_entry)
	
	# 创建协程进行抽奖动画
	var animation_tween = create_tween()
	
	# 闪烁各个条目
	for i in range(flash_entries.size()):
		var entry = flash_entries[i]
		var delay = animation_duration * i / flash_entries.size()
		
		animation_tween.tween_callback(func(): 
			current_winner_label.text = entry.title
		).set_delay(delay)
	
	# 动画完成后的处理
	animation_tween.tween_callback(func():
		# 添加到获奖者列表
		winners.append(selected_entry)
		add_winner_to_list(selected_entry)
		
		# 播放庆祝特效
		var confetti_instance = CONFETTI.instantiate()
		particles_container.add_child(confetti_instance)
		
		# 更新筛选
		filter_entries()
		
		is_drawing = false
	).set_delay(0.5)  # 结束后稍微停顿一下

# 重置按钮事件处理
func _on_reset_button_pressed():
	# 清空获奖者列表
	winners.clear()
	
	for child in winners_list.get_children():
		child.queue_free()
	
	# 清空当前获奖者显示
	current_winner_label.text = ""
	
	# 清空粒子效果容器
	for child in particles_container.get_children():
		child.queue_free()
	
	# 重新筛选和显示条目
	filter_entries()

# 开发日志筛选开关切换
func _on_devlog_filter_toggled(_toggled_on):
	filter_entries()

# 导出按钮事件处理
func _on_export_button_pressed():
	if winners.size() <= 0:
		var dialog = AcceptDialog.new()
		dialog.title = "提示"
		dialog.dialog_text = "没有获奖者可以导出"
		add_child(dialog)
		dialog.popup_centered()
		# 自动关闭对话框
		var auto_close_timer = Timer.new()
		add_child(auto_close_timer)
		auto_close_timer.timeout.connect(func():
			dialog.queue_free()
			auto_close_timer.queue_free()
		)
		auto_close_timer.start(2.0)
		return
	
	# 显示导出对话框
	export_dialog.current_path = "winners_" + Time.get_datetime_string_from_system().replace(":", "-") + ".csv"
	export_dialog.popup_centered()

# 导出对话框确认按钮事件处理
func _on_export_dialog_confirmed():
	var export_path = export_dialog.current_path
	
	var file = FileAccess.open(export_path, FileAccess.WRITE)
	if file:
		# 写入表头
		file.store_csv_line(["游戏名称", "游戏ID", "游戏链接", "是否有开发日志", "作者", "主观评价"])
		
		# 写入获奖者数据
		for winner in winners:
			file.store_csv_line([
				winner.title,
				winner.id,
				winner.url,
				"是" if winner.has_devlog else "否",
				winner.author,
				winner.comment
			])
		
		# 显示成功消息
		var dialog = AcceptDialog.new()
		dialog.title = "导出成功"
		dialog.dialog_text = "获奖名单已导出到: " + export_path
		add_child(dialog)
		dialog.popup_centered()
		
		# 自动关闭对话框
		var auto_close_timer = Timer.new()
		add_child(auto_close_timer)
		auto_close_timer.timeout.connect(func():
			dialog.queue_free()
			auto_close_timer.queue_free()
		)
		auto_close_timer.start(2.0)
	else:
		# 显示错误消息
		var dialog = AcceptDialog.new()
		dialog.title = "导出失败"
		dialog.dialog_text = "无法写入文件: " + export_path
		add_child(dialog)
		dialog.popup_centered()
		
		# 自动关闭对话框
		var auto_close_timer = Timer.new()
		add_child(auto_close_timer)
		auto_close_timer.timeout.connect(func():
			dialog.queue_free()
			auto_close_timer.queue_free()
		)
		auto_close_timer.start(2.0)
