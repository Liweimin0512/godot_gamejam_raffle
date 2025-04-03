extends Node
# 抽奖管理器 - 单例模式
# 负责处理抽奖核心逻辑

signal raffle_completed(winner, prize)
signal raffle_reset

# 单例实例
var _instance = null
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
	# 重置所有奖项的已抽数量
	for prize in prizes:
		prize.drawn = 0
	
	# 清空获奖记录
	winners.clear()
	
	# 发送重置信号
	raffle_reset.emit()

# 设置参赛作品
func set_entries(new_entries):
	entries = new_entries
	
# 添加奖项
func add_prize(prize_name, count):
	# 检查是否已存在同名奖项
	for prize in prizes:
		if prize.name == prize_name:
			return false
	
	# 添加新奖项
	prizes.append({
		"name": prize_name,
		"count": count,
		"drawn": 0
	})
	
	# 初始化此奖项的获奖者列表
	if not winners.has(prize_name):
		winners[prize_name] = []
	
	return true

# 删除奖项
func remove_prize(prize_name):
	for i in range(prizes.size()):
		if prizes[i].name == prize_name:
			# 删除获奖记录
			if winners.has(prize_name):
				winners.erase(prize_name)
			
			# 删除奖项
			prizes.remove_at(i)
			return true
	
	return false

# 获取下一个要抽取的奖项
func get_next_prize():
	for prize in prizes:
		if prize.drawn < prize.count:
			return prize
	return null

# 获取还可以抽取的奖项总数
func get_available_prizes_count():
	var count = 0
	for prize in prizes:
		count += prize.count - prize.drawn
	return count

# 获取所有未获奖的参赛者
func get_available_entries():
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

# 基于权重的抽奖策略
func _draw_winner_weighted(available_entries):
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

# 完全随机抽奖策略
func _draw_winner_random(available_entries):
	var random_index = randi() % available_entries.size()
	return available_entries[random_index]

# 执行抽奖
func perform_raffle(strategy = "weighted"):
	# 获取当前可用奖项
	current_prize = get_next_prize()
	if not current_prize:
		return {"success": false, "message": "没有可用的奖项"}
	
	# 获取还未获奖的参赛者
	var available_entries = get_available_entries()
	if available_entries.size() == 0:
		return {"success": false, "message": "没有足够的参赛者"}
	
	# 抽取获奖者
	var winner = draw_winner(available_entries, strategy)
	if not winner:
		return {"success": false, "message": "抽奖失败"}
	
	# 记录获奖者
	winners[current_prize.name].append(winner)
	
	# 更新奖项已抽取数量
	current_prize.drawn += 1
	
	# 发送抽奖完成信号
	raffle_completed.emit(winner, current_prize)
	
	return {"success": true, "winner": winner, "prize": current_prize}

# 导出抽奖结果为JSON
func export_results():
	var results = {
		"timestamp": Time.get_datetime_string_from_system(),
		"total_entries": entries.size(),
		"prizes": prizes,
		"winners": winners
	}
	
	return JSON.stringify(results, "\t")
