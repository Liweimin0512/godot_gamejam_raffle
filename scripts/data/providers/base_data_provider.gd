extends Object
class_name BaseDataProvider
# 基本数据提供者类 - 抽象基类

signal data_loaded(entries: Array)
signal data_error(message: String)

## 获取数据
## [param params] - 参数
func fetch_data(_params : Dictionary = {}) -> bool:
	# 抽象方法，子类必须实现
	push_error("BaseDataProvider.fetch_data() 是抽象方法")
	return false

## 格式化条目数据，确保符合预期的格式
## [param entry_data] - 条目数据
func format_entry(entry_data) -> Dictionary:
	# 确保必要的字段存在
	if not entry_data.has("id"):
		entry_data.id = str(randi())
	
	if not entry_data.has("weight"):
		entry_data.weight = 1.0
	
	return entry_data
