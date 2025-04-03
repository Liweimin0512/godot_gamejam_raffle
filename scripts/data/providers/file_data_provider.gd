extends BaseDataProvider
class_name FileDataProvider
# 文件数据提供者 - 从本地文件加载

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
