extends Panel
# 参赛作品面板

signal import_requested

# 节点引用
@onready var entries_list = $VBoxContainer/EntriesContainer/EntriesList

# 引用其他管理器
var raffle_manager
var data_manager

func _ready():
	# 获取管理器引用
	raffle_manager = get_node("/root/RaffleManager")
	data_manager = get_node("/root/DataManager")
	
	# 连接数据加载信号
	data_manager.connect("data_loaded", _on_data_loaded)

# 更新参赛作品列表
func update_entries_list():
	# 清空列表
	for child in entries_list.get_children():
		child.queue_free()
	
	# 显示所有参赛作品
	for entry in raffle_manager.entries:
		var entry_item = preload("res://scenes/ui/entry_list_item.tscn").instantiate()
		entry_item.setup(entry)
		entries_list.add_child(entry_item)

# 处理数据加载完成
func _on_data_loaded(entries):
	update_entries_list()

# 导入按钮被按下
func _on_import_button_pressed():
	# 通知主场景打开文件对话框
	import_requested.emit()

# 筛选按钮被按下
func _on_filter_button_pressed():
	# 打开筛选对话框
	var filter_dialog = $"/root/MainScene/DialogsContainer/FilterDialog"
	if filter_dialog:
		filter_dialog.popup_centered()
