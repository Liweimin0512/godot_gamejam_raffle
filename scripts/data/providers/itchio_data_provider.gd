extends "../base_data_provider.gd"
class_name ItchioDataProvider
# Itch.io数据提供者 - 从Itch.io加载GameJam数据

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
			"weight": 1.0,  # 默认权重
			"has_devlog": false # 默认无开发日志
		}
		entries.append(format_entry(entry))
	
	data_loaded.emit(entries)
