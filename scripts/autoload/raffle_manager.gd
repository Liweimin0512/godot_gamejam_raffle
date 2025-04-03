extends Node
# 抽奖管理器 - 单例模式
# 负责处理抽奖核心逻辑

# 引用资源类
const PrizeResource = preload("res://scripts/data/resources/prize_resource.gd")

signal raffle_completed(winner, prize)
signal raffle_reset
signal prizes_changed

# 单例实例
static func get_instance():
	return Engine.get_main_loop().root.get_node_or_null("/root/RaffleManager")

# 参赛作品数据
var entries = []
# 奖项配置
var prizes = []
# 获奖记录
var winners = {}
# 当前正在抽取的奖项
var current_prize = null

func _ready():
	# 初始化获奖字典
	winners = {}

# 清除所有数据
func reset_raffle():
	# 重置所有奖项
	for prize in prizes:
		prize.reset()
	
	# 清空获奖记录
	winners.clear()
	
	# 发送重置信号
	raffle_reset.emit()

# 设置参赛作品
func set_entries(new_entries):
	entries = new_entries
	
# 添加奖项
func add_prize(prize_data):
	# 检查是否已存在同名奖项
	for prize in prizes:
		if prize.name == prize_data.name:
			return false
	
	# 添加新奖项
	var prize_resource = PrizeResource.from_dict(prize_data)
	prizes.append(prize_resource)
	
	# 初始化此奖项的获奖者列表
	if not winners.has(prize_resource.id):
		winners[prize_resource.id] = []
	
	prizes_changed.emit()
	return true

# 更新奖项
func update_prize(prize_id, new_prize_data):
	for i in range(prizes.size()):
		if prizes[i].id == prize_id:
			# 保留当前状态
			var remaining_count = prizes[i].remaining_count
			var current_winners = []
			if winners.has(prize_id):
				current_winners = winners[prize_id].duplicate()
			
			# 更新奖项
			var updated_prize = PrizeResource.from_dict(new_prize_data)
			
			# 恢复状态
			updated_prize.remaining_count = remaining_count
			prizes[i] = updated_prize
			
			# 更新获奖者列表
			if not winners.has(prize_id) and winners.has(updated_prize.id):
				winners[updated_prize.id] = current_winners
			
			prizes_changed.emit()
			return true
	
	return false

# 删除奖项
func remove_prize(prize_id):
	for i in range(prizes.size()):
		if prizes[i].id == prize_id:
			# 删除获奖记录
			if winners.has(prize_id):
				winners.erase(prize_id)
			
			# 删除奖项
			prizes.remove_at(i)
			prizes_changed.emit()
			return true
	
	return false

# 获取下一个要抽取的奖项
func get_next_prize():
	var active_prizes = prizes.filter(func(p): return p.is_active)
	# 按优先级排序
	active_prizes.sort_custom(func(a, b): return a.priority < b.priority)
	
	for prize in active_prizes:
		if prize.remaining_count > 0:
			return prize
	return null

# 获取还可以抽取的奖项总数
func get_available_prizes_count():
	var count = 0
	for prize in prizes:
		if prize.is_active:
			count += prize.remaining_count
	return count

## 获取所有未获奖的参赛者
## [param prize_to_draw] - 当前抽奖的奖项
func get_available_entries(prize_to_draw = null):
	var drawn_entries = []
	
	# 如果奖项允许重复获奖，只考虑其他奖项的获奖者
	for prize_id in winners:
		var prize_allows_duplicates = false
		if prize_to_draw:
			for p in prizes:
				if p.id == prize_id and p.allow_duplicate_winners:
					prize_allows_duplicates = true
					break
		
		if not prize_allows_duplicates:
			for winner in winners[prize_id]:
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

# 根据权重抽取获奖者（策略模式）
func draw_winner(available_entries, strategy = "weighted"):
	if available_entries.size() == 0:
		return null
	
	match strategy:
		"weighted":
			return _draw_winner_weighted(available_entries)
		"random":
			return _draw_winner_random(available_entries)
		_:
			return _draw_winner_weighted(available_entries)

# 加权随机抽取
func _draw_winner_weighted(available_entries):
	var total_weight = 0
	for entry in available_entries:
		total_weight += entry.get("weight", 1.0)
	
	var random_value = randf() * total_weight
	var current_sum = 0
	
	for entry in available_entries:
		current_sum += entry.get("weight", 1.0)
		if random_value <= current_sum:
			return entry
	
	# 如果因为浮点误差没有返回，返回最后一个
	return available_entries[available_entries.size() - 1]

# 完全随机抽取
func _draw_winner_random(available_entries):
	var rand_index = randi() % available_entries.size()
	return available_entries[rand_index]

# 执行抽奖
func perform_raffle(strategy = "weighted"):
	# 获取下一个奖项
	current_prize = get_next_prize()
	if not current_prize:
		return {"success": false, "message": "没有可抽取的奖项"}
	
	# 获取可抽取的参赛者
	var available_entries = get_available_entries(current_prize)
	if available_entries.size() == 0:
		return {"success": false, "message": "没有可抽取的参赛者"}
	
	# 抽取获奖者
	var winner = draw_winner(available_entries, strategy)
	if not winner:
		return {"success": false, "message": "抽取获奖者失败"}
	
	# 记录获奖信息
	if not winners.has(current_prize.id):
		winners[current_prize.id] = []
	
	winners[current_prize.id].append(winner)
	current_prize.add_winner(winner)
	
	# 发送抽奖完成信号
	raffle_completed.emit(winner, current_prize)
	
	return {
		"success": true,
		"winner": winner,
		"prize": current_prize
	}

# 从JSON加载奖项配置
func load_prizes_from_json(json_string):
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("解析奖项JSON失败: " + json.get_error_message())
		return false
	
	var data = json.get_data()
	if not data or typeof(data) != TYPE_ARRAY:
		push_error("奖项数据格式错误，应为JSON数组")
		return false
	
	# 清空当前奖项
	prizes.clear()
	winners.clear()
	
	# 加载奖项
	for prize_data in data:
		var prize = PrizeResource.from_dict(prize_data)
		prizes.append(prize)
		winners[prize.id] = []
	
	prizes_changed.emit()
	return true

# 导出奖项配置为JSON
func export_prizes_to_json():
	var prize_data = []
	for prize in prizes:
		prize_data.append(prize.to_dict())
	
	var json_string = JSON.stringify(prize_data, "  ")
	return json_string
