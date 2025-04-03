extends Node
# 数据管理器 - 单例模式
# 负责处理数据获取和处理

signal data_loaded(entries)
signal data_error(message)

# 预加载EntryResource
const EntryResource = preload("res://scripts/data/resources/entry_resource.gd")

# 数据提供者/策略
var _data_providers : Dictionary[String, BaseDataProvider] = {}
var _current_provider : BaseDataProvider = null

func _ready() -> void:
	# 注册默认的数据提供者
	register_data_provider("local_file", FileDataProvider.new())
	register_data_provider("itch_io", ItchioDataProvider.new())
	register_data_provider("json", JSONDataProvider.new())
	register_data_provider("csv", CSVDataProvider.new())

## 注册数据提供者
## [param provider_id] - 提供者ID
## [param provider] - 
func register_data_provider(provider_id, provider: BaseDataProvider):
	_data_providers[provider_id] = provider
	provider.data_loaded.connect(_on_provider_data_loaded)
	provider.data_error.connect(_on_provider_data_error)

# 获取数据 - 使用策略模式
func fetch_data(provider_id, params = {}):
	if not _data_providers.has(provider_id):
		data_error.emit("未知的数据提供者: " + provider_id)
		return {"success": false, "message": "未知的数据提供者"}
	
	_current_provider = _data_providers[provider_id]
	var result = _current_provider.fetch_data(params)
	
	if typeof(result) == TYPE_BOOL:
		# 为了兼容性，将布尔结果转换为字典格式
		return {"success": result, "message": "操作" + ("成功" if result else "失败")}
	
	return result

# 处理加载完成的数据
func _on_provider_data_loaded(entries):
	data_loaded.emit(entries)

# 处理加载错误
func _on_provider_data_error(message):
	data_error.emit(message)

# 导出获奖者数据
func export_winners(path):
	var export_data = []
	var raffle_manager = get_node("/root/RaffleManager")
	
	for winner in raffle_manager.winners:
		var winner_data = {
			"奖项": winner.prize.name,
			"获奖作品": winner.entry.title,
			"作者": winner.entry.user
		}
		export_data.append(winner_data)
	
	# 导出为CSV
	var csv_content = ""
	
	# 添加表头
	if export_data.size() > 0:
		var headers = export_data[0].keys()
		csv_content += ",".join(headers) + "\n"
		
		# 添加数据行
		for item in export_data:
			var values = []
			for header in headers:
				values.append(str(item[header]))
			csv_content += ",".join(values) + "\n"
	
	# 写入文件
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return {"success": false, "message": "无法写入文件: " + path}
	
	file.store_string(csv_content)
	file.close()
	
	return {"success": true, "message": "导出成功"}

# 将条目转换为EntryResource资源
func convert_to_entry_resource(entry_data):
	return EntryResource.from_dict(entry_data)
