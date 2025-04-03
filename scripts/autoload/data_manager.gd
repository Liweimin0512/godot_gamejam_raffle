extends Node

# 数据管理器 - 单例模式
# 负责加载、转换、缓存和导出数据

signal data_loaded(entries: Array[EntryResource])
signal data_error(message: String)

# 数据提供者/策略
var _data_providers : Dictionary[String, BaseDataProvider] = {}
var _current_provider : BaseDataProvider = null
# 数据缓存
var _entries_cache : Array[EntryResource] = []

func _ready() -> void:
	# 注册默认的数据提供者
	register_data_provider("local_file", FileDataProvider.new())
	register_data_provider("itch_io", ItchioDataProvider.new())
	register_data_provider("json", JSONDataProvider.new())
	register_data_provider("csv", CSVDataProvider.new())

## 注册数据提供者
## [param provider_id] - 提供者ID
## [param provider] - 提供者实例
func register_data_provider(provider_id: String, provider: BaseDataProvider) -> void:
	if _data_providers.has(provider_id):
		push_warning("Overwriting existing data provider: %s" % provider_id)
	_data_providers[provider_id] = provider
	# Connect signals safely
	if not provider.is_connected("data_loaded", _on_provider_data_loaded):
		provider.data_loaded.connect(_on_provider_data_loaded)
	if not provider.is_connected("data_error", _on_provider_data_error):
		provider.data_error.connect(_on_provider_data_error)

## 获取数据 - 使用策略模式
## [param provider_id] - 提供者ID
## [param params] - 参数
## [return] 是否成功启动获取过程 (现在是异步的)
func fetch_data(provider_id: String, params : Dictionary = {}) -> bool:
	if not _data_providers.has(provider_id):
		var error_msg : String = "Unknown data provider: %s" % provider_id
		data_error.emit(error_msg)
		printerr(error_msg)
		return false
	
	_current_provider = _data_providers[provider_id]
	# Fetching is now asynchronous, triggered by the provider via signals
	var success : bool = _current_provider.fetch_data(params)
	if not success:
		# Provider might fail immediately (e.g., missing params)
		# Error signal should have been emitted by the provider
		printerr("Provider '%s' failed to initiate fetch." % provider_id)
		
	return success # Returns success of *initiating* the fetch

# 数据提供者加载成功的回调
func _on_provider_data_loaded(raw_entries: Array) -> void:
	print("DataManager: Received %d raw entries from provider." % raw_entries.size())
	_entries_cache.clear()
	for entry_data in raw_entries:
		if typeof(entry_data) == TYPE_DICTIONARY:
			_entries_cache.append(convert_to_entry_resource(entry_data))
		else:
			printerr("Invalid entry data type received from provider: ", typeof(entry_data))
			# Optionally skip or try to handle
	print("DataManager: Converted and cached %d entries." % _entries_cache.size())
	data_loaded.emit(_entries_cache)

# 数据提供者加载失败的回调
func _on_provider_data_error(message: String) -> void:
	data_error.emit(message)
	printerr("DataManager: Error from provider: %s" % message)

## 导出获奖者数据
## [param path] - 导出路径
## [return] - 返回导出结果字典 {success: bool, message: String}
func export_winners(path: String) -> Dictionary:
	var export_data : Array[Dictionary] = []
	# Get RaffleManager safely
	var raffle_manager = get_node_or_null("/root/RaffleManager")
	if not raffle_manager:
		var error_msg : String = "Export failed: RaffleManager not found."
		printerr(error_msg)
		return {"success": false, "message": error_msg}
	
	# Assume RaffleManager.get_winners() returns Array[EntryResource]
	var winners : Array[EntryResource] = raffle_manager.get_winners()
	
	for winner: EntryResource in winners:
		# Convert EntryResource back to Dictionary for export (if needed)
		# Assuming a to_dict() method exists in EntryResource
		if winner.has_method("to_dict"):
			export_data.append(winner.to_dict())
		else:
			# Fallback or manual conversion
			printerr("Winner object lacks to_dict() method for export. Skipping...")
			# Alternatively, create dict manually:
			# export_data.append({"id": winner.id, "title": winner.title, ... })

	# Write to file (Using FileAccess for robustness)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var error_msg : String = "Export failed: Cannot open file for writing at %s. Error: %s" % [path, error_string(FileAccess.get_open_error())]
		printerr(error_msg)
		return {"success": false, "message": error_msg}
	
	# Assuming export format is JSON
	var json_string : String = JSON.stringify(export_data, "\t") # Pretty print with tabs
	if json_string.is_empty() and not export_data.is_empty():
		file.close()
		var error_msg : String = "Export failed: Failed to stringify winner data to JSON."
		printerr(error_msg)
		return {"success": false, "message": error_msg}
	
	file.store_string(json_string)
	file.close() # Ensure file is closed
	
	print("DataManager: Winners exported successfully to %s" % path)
	return {"success": true, "message": "导出成功"}

# 获取缓存的条目
func get_entries() -> Array[EntryResource]:
	return _entries_cache

# 将条目转换为EntryResource资源
func convert_to_entry_resource(entry_data: Dictionary) -> EntryResource:
	return EntryResource.from_dict(entry_data)
