extends Resource
class_name PrizeResource
## 奖项数据资源

## 基本信息
@export var id: String = ""  # 奖项唯一标识符
@export var name: String = ""  # 奖项名称
@export var count: int = 1  # 奖项数量
@export var description: String = ""  # 奖项描述

## 抽奖相关设置
@export var allow_duplicate_winners: bool = false  # 是否允许同一参赛者获得多个该奖项
@export var priority: int = 0  # 抽取优先级，数字越小优先级越高
@export var is_active: bool = true  # 是否激活该奖项

## 抽奖状态
@export var remaining_count: int = 1  # 剩余可抽取数量
var winners = []  # 该奖项的获奖者列表

## 从字典中加载数据
static func from_dict(data: Dictionary) -> PrizeResource:
	var prize = PrizeResource.new()
	
	# 基本信息
	prize.id = data.get("id", str(randi()))
	prize.name = data.get("name", "未命名奖项")
	prize.count = data.get("count", 1)
	prize.description = data.get("description", "")
	
	# 抽奖相关设置
	prize.allow_duplicate_winners = data.get("allow_duplicate_winners", false)
	prize.priority = data.get("priority", 0)
	prize.is_active = data.get("is_active", true)
	
	# 初始化剩余数量
	prize.remaining_count = prize.count
	
	return prize

## 转换为字典
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"count": count,
		"description": description,
		"allow_duplicate_winners": allow_duplicate_winners,
		"priority": priority,
		"is_active": is_active,
		"remaining_count": remaining_count
	}

## 添加获奖者
func add_winner(entry):
	if remaining_count > 0:
		winners.append(entry)
		remaining_count -= 1
		return true
	return false

## 重置奖项状态
func reset():
	winners.clear()
	remaining_count = count
