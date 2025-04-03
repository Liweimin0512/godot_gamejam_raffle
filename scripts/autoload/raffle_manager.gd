extends Node

## 负责处理抽奖核心逻辑 - MVP Simplified Version (No Prizes)

signal winner_drawn(winner: EntryResource)			## 获奖者发生变化时发出信号
signal raffle_reset									## 抽奖重置时发出信号

## 参赛作品数据
var entries : Array[EntryResource] = []
## 获奖记录
var winners : Array[EntryResource] = []

var is_debug : bool = false

func _ready() -> void:
	# Connect to DataManager signals if needed
	DataManager.data_loaded.connect(_on_data_manager_data_loaded)
	entries = DataManager.get_entries()

## 设置参赛作品数据
func set_entries(new_entries: Array[EntryResource]) -> void:
	entries = new_entries
	reset() # Reset raffle state when new entries are loaded
	if is_debug:
		print("RaffleManager: Entries set, count: ", entries.size())

## 重置抽奖状态
func reset() -> void:
	if is_debug:
		print("RaffleManager: Resetting raffle...")
	winners.clear()
	# Reset any other state if needed
	raffle_reset.emit()

## 获取获奖者
## [return] - 获奖者列表
func get_winners() -> Array[EntryResource]:
	return winners

## 获取所有未获奖的参赛者
## [param respect_filter] - 是否启用devlog过滤
## [param filter_state] - devlog过滤状态 (true = 只显示有devlog的)
func get_available_entries(respect_filter: bool = false) -> Array[EntryResource]:
	var available : Array[EntryResource] = []
	for entry: EntryResource in entries:
		# 1. Check if already won
		if entry in winners:
			continue
			
		# 2. Apply devlog filter if requested
		if respect_filter and entry.has_devlog == false:
			continue
			
		available.append(entry)
	
	return available

## 使用加权随机选择执行绘图过程
## 获取呼叫者计算的潜在候选人列表
## 返回抽取的获胜者条目，如果失败，则返回null
func draw_winner_from_list(available_entries: Array[EntryResource]) -> EntryResource:
	if available_entries.is_empty():
		printerr("Draw attempt with empty available entries list.")
		return null
	
	var winner: EntryResource = _draw_winner_weighted(available_entries)
	
	if winner:
		winners.append(winner) # Add to winners list
		winner_drawn.emit(winner) # Emit signal
		print("RaffleManager: Winner drawn - ", winner.title)
	else:
		printerr("Weighted draw failed to select a winner from the provided list.")
		
	return winner

## 加权随机抽取
## 获取呼叫者计算的潜在候选人列表
## 返回抽取的获胜者条目，如果失败，则返回null
func _draw_winner_weighted(available_entries: Array[EntryResource]) -> EntryResource:
	var total_weight : float = 0.0 # Use float for weights
	for entry: EntryResource in available_entries:
		# Ensure weight is treated as float, default to 1.0 if missing or invalid
		var weight : float = entry.weight
		# Already typed in EntryResource, maybe add validation there?
		if weight <= 0.0:
			push_warning("Non-positive weight for entry %s ('%s'), using 1.0." % [entry.id, entry.title])
			weight = 1.0
		
		total_weight += weight
	
	if total_weight <= 0.0:
		printerr("Total weight is zero or negative, cannot perform weighted draw. Falling back to random.")
		# Fallback to simple random if weights are messed up
		return _draw_winner_random(available_entries) 
	
	var random_value : float = randf() * total_weight
	var current_sum : float = 0.0
	for entry: EntryResource in available_entries:
		var weight : float = entry.weight # Use the validated/defaulted weight logic if needed again
		if weight <= 0.0: weight = 1.0 # Ensure positive weight used in sum
		
		current_sum += weight
		if random_value <= current_sum:
			return entry
			
	# Fallback in case of floating point issues, return last entry
	printerr("Weighted draw reached end without selecting, possibly due to float issues. Returning last entry.")
	return available_entries[-1] if not available_entries.is_empty() else null

## 纯随机抽取（备用）
func _draw_winner_random(available_entries: Array[EntryResource]) -> Variant: # Can return EntryResource or null
	if available_entries.is_empty():
		return null
	return available_entries.pick_random()

## 数据加载回调
func _on_data_manager_data_loaded(loaded_entries: Array[EntryResource]) -> void:
	set_entries(loaded_entries)
