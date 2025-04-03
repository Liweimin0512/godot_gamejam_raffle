extends Resource
class_name EntryResource
## 参赛作品数据资源

## 基本信息
@export var id: String = ""
@export var title: String = ""
@export var user: String = ""

## 附加信息
@export var has_devlog: bool = false
@export var url: String = ""
@export var description: String = ""

## 抽奖相关
@export var weight: float = 1.0
@export_range(0, 100) var selection_chance: int = 0

## 从字典中加载数据
static func from_dict(data: Dictionary) -> EntryResource:
	var entry = EntryResource.new()
	
	# 基本信息
	entry.id = data.get("id", "")
	entry.title = data.get("title", "")
	entry.user = data.get("user", "")
	
	# 附加信息
	entry.has_devlog = data.get("has_devlog", false)
	entry.url = data.get("url", "")
	entry.description = data.get("description", "")
	
	# 抽奖相关
	entry.weight = float(data.get("weight", 1.0))
	
	return entry

## 转换为字典
func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"user": user,
		"has_devlog": has_devlog,
		"url": url,
		"description": description,
		"weight": weight,
		"selection_chance": selection_chance
	}
