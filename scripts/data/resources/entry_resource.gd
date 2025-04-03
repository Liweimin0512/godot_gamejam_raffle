extends Resource
class_name EntryResource
## 参赛作品数据资源

# 基本信息
## 唯一标识符
@export var id: String = ""
## 标题
@export var title: String = ""
## 作者信息
@export var author: String = ""
## 图片
@export var image: Texture2D

# 附加信息
## 是否有开发日志
@export var has_devlog: bool = false
## 链接
@export var url: String = ""
## 描述
@export var description: String = ""

## 抽奖相关
@export var weight: float = 1.0
## 选取概率
@export_range(0, 100) var selection_chance: int = 0

## 从字典中加载数据
static func from_dict(data: Dictionary) -> EntryResource:
	var entry = EntryResource.new()
	
	# 基本信息
	entry.id = data.get("id", "")
	entry.title = data.get("title", "")
	entry.author = data.get("author", "")
	entry.image = data.get("image", null)
	
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
		"author": author,
		"image": image,
		"has_devlog": has_devlog,
		"url": url,
		"description": description,
		"weight": weight,
		"selection_chance": selection_chance
	}
