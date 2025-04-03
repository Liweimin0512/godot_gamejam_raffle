extends BaseDataProvider
class_name JSONDataProvider
# JSON数据提供者 - 从JSON字符串加载

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
