extends Control

# 保存所有参赛作品数据
var entries = []
# 保存当前配置的奖项
var prizes = []
# 保存已经抽过的获奖者
var winners = {}
# 当前正在抽取的奖项
var current_prize = null
# 抽奖动画期间的参与者
var animation_entries = []
# 抽奖动画速度控制
var animation_speed = 0.05
var animation_duration = 3.0
var is_drawing = false

# 用于存储粒子特效的场景
var confetti_scene

# 节点引用
@onready var entries_list = $MainPanel/VBoxContainer/HBoxContainer/DataPanel/VBoxContainer/EntriesContainer/EntriesList
@onready var prizes_list = $MainPanel/VBoxContainer/HBoxContainer/PrizePanel/VBoxContainer/PrizesContainer/PrizesList
@onready var winners_list = $WinnersPanel/VBoxContainer/WinnersContainer/WinnersList
@onready var current_winner_label = $MainPanel/VBoxContainer/DrawArea/CurrentWinner
@onready var draw_button = $MainPanel/VBoxContainer/HBoxContainer/DrawButton
@onready var reset_button = $MainPanel/VBoxContainer/HBoxContainer/ResetButton
@onready var http_request = $HTTPRequest
@onready var prize_dialog = $PrizeDialog
@onready var prize_name_input = $PrizeDialog/VBoxContainer/PrizeNameContainer/PrizeName
@onready var prize_count_input = $PrizeDialog/VBoxContainer/PrizeCountContainer/PrizeCount
@onready var prize_error_label = $PrizeDialog/VBoxContainer/ErrorLabel
@onready var file_dialog = $FileDialog
@onready var message_dialog = $MessageDialog
@onready var particles_container = $MainPanel/VBoxContainer/DrawArea/ParticlesContainer
@onready var draw_animation = $DrawAnimation

func _ready():
	# 初始化UI
	current_winner_label.text = ""
	update_ui()
	
	# 加载场景
	confetti_scene = load("res://scenes/confetti.tscn")
	
	# 创建抽奖动画
	_create_draw_animation()

# 更新UI显示
func update_ui():
	# 清空列表
	for child in entries_list.get_children():
		child.queue_free()
	
	for child in prizes_list.get_children():
		child.queue_free()
		
	for child in winners_list.get_children():
		child.queue_free()
	
	# 显示所有参赛作品
	for entry in entries:
		var label = Label.new()
		label.text = entry.title + " - " + entry.user
		entries_list.add_child(label)
	
	# 显示所有奖项
	for prize in prizes:
		var hbox = HBoxContainer.new()
		
		var label = Label.new()
		label.text = prize.name + " (x" + str(prize.count) + ")"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var delete_btn = Button.new()
		delete_btn.text = "删除"
		delete_btn.pressed.connect(_on_delete_prize_pressed.bind(prize))
		
		hbox.add_child(label)
		hbox.add_child(delete_btn)
		prizes_list.add_child(hbox)
	
	# 显示获奖者
	for prize_name in winners:
		var prize_label = Label.new()
		prize_label.text = prize_name + ":"
		winners_list.add_child(prize_label)
		
		for winner in winners[prize_name]:
			var winner_label = Label.new()
			winner_label.text = "    " + winner.title + " - " + winner.user
			winners_list.add_child(winner_label)
	
	# 更新按钮状态
	var can_draw = entries.size() > 0 and prizes.size() > 0 and _get_available_prizes() > 0
	draw_button.disabled = is_drawing or not can_draw

# 获取itch.io jam数据
func _on_fetch_data_button_pressed():
	var jam_url = "https://itch.io/jam/httpsgithubcomli-game-academy-craft-2/entries.json"
	http_request.request(jam_url)
	message_dialog.dialog_text = "正在获取数据..."
	message_dialog.popup_centered()

# HTTP请求完成后的处理
func _on_http_request_completed(result, response_code, _headers, body):
	message_dialog.hide()
	
	if result != HTTPRequest.RESULT_SUCCESS:
		message_dialog.dialog_text = "获取数据失败，请检查网络连接"
		message_dialog.popup_centered()
		return
	
	if response_code != 200:
		message_dialog.dialog_text = "获取数据失败，服务器响应码: " + str(response_code)
		message_dialog.popup_centered()
		return
	
	# 解析JSON数据
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())
	if error != OK:
		message_dialog.dialog_text = "解析数据失败: " + json.get_error_message()
		message_dialog.popup_centered()
		return
	
	var data = json.get_data()
	if data and data.has("jam") and data.jam.has("entries"):
		entries = []
		for entry_data in data.jam.entries:
			var entry = {
				"id": entry_data.id,
				"title": entry_data.title,
				"user": entry_data.user.name,
				"url": entry_data.url,
				"weight": 1.0  # 默认权重为1
			}
			entries.append(entry)
		
		message_dialog.dialog_text = "成功获取 " + str(entries.size()) + " 个参赛作品"
		message_dialog.popup_centered()
		update_ui()
	else:
		message_dialog.dialog_text = "获取数据格式不正确"
		message_dialog.popup_centered()

# 导入数据按钮
func _on_import_button_pressed():
	file_dialog.popup_centered()

# 选择文件后的处理
func _on_file_dialog_file_selected(path):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		message_dialog.dialog_text = "无法打开文件"
		message_dialog.popup_centered()
		return
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(content)
	if error != OK:
		message_dialog.dialog_text = "解析数据失败: " + json.get_error_message()
		message_dialog.popup_centered()
		return
	
	var data = json.get_data()
	if data and typeof(data) == TYPE_ARRAY:
		entries = data
		message_dialog.dialog_text = "成功导入 " + str(entries.size()) + " 个参赛作品"
		message_dialog.popup_centered()
		update_ui()
	else:
		message_dialog.dialog_text = "导入数据格式不正确，应为JSON数组"
		message_dialog.popup_centered()

# 添加奖项按钮
func _on_add_prize_button_pressed():
	prize_name_input.text = ""
	prize_count_input.value = 1
	if prize_error_label:
		prize_error_label.text = ""
	prize_dialog.popup_centered()

# 奖项对话框确认
func _on_prize_dialog_confirmed():
	var prize_name = prize_name_input.text.strip_edges()
	var count = int(prize_count_input.value)
	
	if prize_name.is_empty():
		if prize_error_label:
			prize_error_label.text = "奖项名称不能为空"
		return
	
	# 检查是否已经存在同名奖项
	for prize in prizes:
		if prize.name == prize_name:
			if prize_error_label:
				prize_error_label.text = "已经存在同名奖项"
			return
	
	# 添加新奖项
	prizes.append({
		"name": prize_name,
		"count": count,
		"drawn": 0
	})
	
	# 初始化此奖项的获奖者列表
	if not winners.has(prize_name):
		winners[prize_name] = []
	
	update_ui()

# 删除奖项
func _on_delete_prize_pressed(prize):
	# 删除此奖项的获奖者
	if winners.has(prize.name):
		winners.erase(prize.name)
	
	# 从奖项列表中移除
	prizes.erase(prize)
	update_ui()

# 开始抽奖
func _on_draw_button_pressed():
	if is_drawing:
		return
	
	# 获取当前可用奖项
	current_prize = _get_next_prize()
	if not current_prize:
		message_dialog.dialog_text = "没有可用的奖项"
		message_dialog.popup_centered()
		return
	
	# 获取还未获奖的参赛者
	var available_entries = _get_available_entries()
	if available_entries.size() == 0:
		message_dialog.dialog_text = "没有足够的参赛者"
		message_dialog.popup_centered()
		return
	
	# 开始抽奖动画
	is_drawing = true
	draw_button.disabled = true
	_start_draw_animation(available_entries)

# 重置抽奖
func _on_reset_button_pressed():
	# 清空所有获奖记录
	winners.clear()
	
	# 重置所有奖项的已抽数量
	for prize in prizes:
		prize.drawn = 0
	
	current_winner_label.text = ""
	update_ui()
	
	message_dialog.dialog_text = "已重置所有抽奖结果"
	message_dialog.popup_centered()

# 获取下一个要抽取的奖项
func _get_next_prize():
	for prize in prizes:
		if prize.drawn < prize.count:
			return prize
	return null

# 获取还可以抽取的奖项总数
func _get_available_prizes():
	var count = 0
	for prize in prizes:
		count += prize.count - prize.drawn
	return count

# 获取所有未获奖的参赛者
func _get_available_entries():
	var drawn_entries = []
	
	# 收集所有已抽取的参赛者
	for prize_name in winners:
		for winner in winners[prize_name]:
			drawn_entries.append(winner)
	
	# 过滤出未获奖的参赛者
	var available = []
	for entry in entries:
		var already_won = false
		for winner in drawn_entries:
			if entry.id == winner.id:
				already_won = true
				break
		
		if not already_won:
			available.append(entry)
	
	return available

# 根据权重抽取获奖者
func _draw_winner(available_entries):
	if available_entries.size() == 0:
		return null
	
	# 计算总权重
	var total_weight = 0.0
	for entry in available_entries:
		total_weight += entry.weight
	
	# 生成随机权重
	var random_weight = randf() * total_weight
	
	# 根据权重选择获奖者
	var current_weight = 0.0
	for entry in available_entries:
		current_weight += entry.weight
		if random_weight <= current_weight:
			return entry
	
	# 如果出现意外情况，返回最后一个
	return available_entries[available_entries.size() - 1]

# 创建抽奖动画
func _create_draw_animation():
	var animation = Animation.new()
	var track_idx = animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(track_idx, self.get_path())
	
	var duration = animation_duration
	animation.length = duration
	
	# 添加动画更新的关键帧
	var time = 0.0
	while time < duration:
		animation.track_insert_key(track_idx, time, {
			"method": "_update_animation_entry",
			"args": []
		})
		time += animation_speed
	
	# 添加动画结束的关键帧
	animation.track_insert_key(track_idx, duration, {
		"method": "_finalize_draw",
		"args": []
	})
	
	# 创建动画库
	var library = AnimationLibrary.new()
	library.add_animation("draw", animation)
	draw_animation.add_animation_library("default", library)

# 开始抽奖动画
func _start_draw_animation(available_entries):
	animation_entries = available_entries
	current_winner_label.text = "抽奖中..."
	draw_animation.play("default/draw")

# 更新动画帧
func _update_animation_entry():
	if animation_entries.size() > 0:
		var random_index = randi() % animation_entries.size()
		var entry = animation_entries[random_index]
		current_winner_label.text = entry.title + " - " + entry.user

# 完成抽奖
func _finalize_draw():
	is_drawing = false
	
	# 获取可用参赛者
	var available_entries = _get_available_entries()
	if available_entries.size() == 0:
		current_winner_label.text = "没有可用参赛者"
		return
	
	# 抽取获奖者
	var winner = _draw_winner(available_entries)
	if not winner:
		current_winner_label.text = "抽奖失败"
		return
	
	# 播放特效
	_play_win_effect()
	
	# 更新获奖者显示
	current_winner_label.text = winner.title + " - " + winner.user
	
	# 记录获奖者
	winners[current_prize.name].append(winner)
	
	# 更新奖项已抽取数量
	current_prize.drawn += 1
	
	# 更新UI
	update_ui()

# 播放获奖特效
func _play_win_effect():
	# 创建粒子特效
	var confetti = confetti_scene.instantiate()
	particles_container.add_child(confetti)
	
	# 设置特效位置
	confetti.position = Vector2(particles_container.size.x / 2, 0)
	
	# 播放特效
	confetti.emitting = true
	
	# 设置定时器清理特效
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 2.0
	timer.one_shot = true
	timer.timeout.connect(func(): confetti.queue_free(); timer.queue_free())
	timer.start()
