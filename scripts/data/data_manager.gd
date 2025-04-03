extends Node
# 数据管理器 - 单例模式
# 负责处理数据获取和处理

signal data_loaded(entries)
signal data_error(message)

# 数据提供者/策略
var _data_providers = {}
var _current_provider = null

func _ready():
	# 注册默认的数据提供者
	register_data_provider("file", FileDataProvider.new())
	register_data_provider("itchio", ItchioDataProvider.new())
	register_data_provider("json", JSONDataProvider.new())
	register_data_provider("csv", CSVDataProvider.new())

# 注册数据提供者
func register_data_provider(name, provider):
	_data_providers[name] = provider
	provider.connect("data_loaded", _on_provider_data_loaded)
	provider.connect("data_error", _on_provider_data_error)

# 获取数据 - 使用策略模式
func fetch_data(provider_name, params = {}):
	if not _data_providers.has(provider_name):
		data_error.emit("未知的数据提供者: " + provider_name)
		return false
	
	_current_provider = _data_providers[provider_name]
	return _current_provider.fetch_data(params)

# 处理加载完成的数据
func _on_provider_data_loaded(entries):
	data_loaded.emit(entries)

# 处理加载错误
func _on_provider_data_error(message):
	data_error.emit(message)

# 基本数据提供者类 - 抽象基类
class BaseDataProvider:
	signal data_loaded(entries)
	signal data_error(message)
	
	func fetch_data(_params = {}):
		# 抽象方法，子类必须实现
		push_error("BaseDataProvider.fetch_data() 是抽象方法")
		return false
	
	# 格式化条目数据，确保符合预期的格式
	func format_entry(entry_data):
		# 确保必要的字段存在
		if not entry_data.has("id"):
			entry_data.id = str(randi())
		
		if not entry_data.has("weight"):
			entry_data.weight = 1.0
		
		return entry_data

# 文件数据提供者 - 从本地文件加载
class FileDataProvider extends BaseDataProvider:
	func fetch_data(params = {}):
		if not params.has("path"):
			data_error.emit("未指定文件路径")
			return false
		
		var path = params.path
		var file = FileAccess.open(path, FileAccess.READ)
		if not file:
			data_error.emit("无法打开文件: " + path)
			return false
		
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error != OK:
			data_error.emit("JSON解析错误: " + json.get_error_message())
			return false
		
		var data = json.get_data()
		if not data or typeof(data) != TYPE_ARRAY:
			data_error.emit("数据格式错误，应为JSON数组")
			return false
		
		# 格式化条目数据
		var entries = []
		for entry_data in data:
			entries.append(format_entry(entry_data))
		
		data_loaded.emit(entries)
		return true

# Itch.io数据提供者 - 从Itch.io加载GameJam数据
class ItchioDataProvider extends BaseDataProvider:
	var http_request
	
	func _init():
		http_request = HTTPRequest.new()
		Engine.get_main_loop().root.add_child(http_request)
		http_request.connect("request_completed", _on_request_completed)
	
	func fetch_data(params = {}):
		var jam_id = params.get("jam_id", "")
		if jam_id.is_empty():
			data_error.emit("未指定GameJam ID")
			return false
		
		# 构建API URL - 注意：这可能需要根据实际情况修改
		var url = "https://itch.io/jam/" + jam_id + "/entries.json"
		
		# 发送请求
		var error = http_request.request(url)
		if error != OK:
			data_error.emit("HTTP请求错误: " + str(error))
			return false
		
		return true
	
	func _on_request_completed(result, response_code, _headers, body):
		if result != HTTPRequest.RESULT_SUCCESS:
			data_error.emit("HTTP请求失败: " + str(result))
			return
		
		if response_code != 200:
			data_error.emit("服务器响应错误: " + str(response_code))
			return
		
		var json = JSON.new()
		var error = json.parse(body.get_string_from_utf8())
		if error != OK:
			data_error.emit("JSON解析错误: " + json.get_error_message())
			return
		
		var data = json.get_data()
		if not data or not data.has("jam") or not data.jam.has("entries"):
			data_error.emit("数据格式不符合预期")
			return
		
		# 从API响应中提取参赛作品数据
		var entries = []
		for entry_data in data.jam.entries:
			var entry = {
				"id": entry_data.id,
				"title": entry_data.title,
				"user": entry_data.user.name,
				"url": entry_data.url,
				"weight": 1.0  # 默认权重
			}
			entries.append(format_entry(entry))
		
		data_loaded.emit(entries)

# JSON数据提供者 - 从JSON字符串加载
class JSONDataProvider extends BaseDataProvider:
	func fetch_data(params = {}):
		if not params.has("json_string"):
			data_error.emit("未提供JSON字符串")
			return false
		
		var json_string = params.json_string
		var json = JSON.new()
		var error = json.parse(json_string)
		if error != OK:
			data_error.emit("JSON解析错误: " + json.get_error_message())
			return false
		
		var data = json.get_data()
		if not data or typeof(data) != TYPE_ARRAY:
			data_error.emit("数据格式错误，应为JSON数组")
			return false
		
		# 格式化条目数据
		var entries = []
		for entry_data in data:
			entries.append(format_entry(entry_data))
		
		data_loaded.emit(entries)
		return true

# CSV数据提供者 - 从CSV文件加载
class CSVDataProvider extends BaseDataProvider:
	func fetch_data(params = {}):
		if not params.has("path"):
			data_error.emit("未指定文件路径")
			return false
		
		var path = params.path
		var file = FileAccess.open(path, FileAccess.READ)
		if not file:
			data_error.emit("无法打开文件: " + path)
			return false
		
		var entries = []
		var headers = []
		var line_index = 0
		
		while not file.eof_reached():
			var line = file.get_line()
			if line.strip_edges() == "":
				continue
			
			var columns = line.split(",")
			
			if line_index == 0:
				# 第一行是表头
				headers = columns
			else:
				# 数据行
				var entry_data = {}
				entry_data["id"] = str(line_index)
				
				# 根据表头设置条目属性
				for i in range(min(columns.size(), headers.size())):
					var header = headers[i]
					var value = columns[i]
					
					match header:
						"游戏名称":
							entry_data["title"] = value
						"作者":
							entry_data["user"] = value
						_:
							# 其他属性作为自定义属性
							entry_data[header] = value
				
				# 默认权重
				entry_data["weight"] = 1.0
				
				# 添加到条目列表
				entries.append(format_entry(entry_data))
			
			line_index += 1
		
		file.close()
		
		data_loaded.emit(entries)
		return true
