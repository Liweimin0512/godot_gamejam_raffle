extends BaseDataProvider
class_name CSVDataProvider
# CSV数据提供者 - 从CSV文件加载

## 获取数据
## [param params] - 参数
## [return] 是否成功
func fetch_data(params : Dictionary = {}) -> bool:
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
						entry_data["author"] = value
					"是否有开发日志":
						entry_data["has_devlog"] = (value == "有")
					"图片":
						if ResourceLoader.exists(value):
							entry_data["image"] = load(value)
						else:
							push_warning("无法加载图片: %s" % value)
					"游戏链接":
						entry_data["url"] = value
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
