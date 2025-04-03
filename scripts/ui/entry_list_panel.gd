extends Panel
# 参赛作品面板

signal import_requested

# 节点引用
@onready var entries_list = $VBoxContainer/EntriesContainer/EntriesList
@onready var devlog_filter = $VBoxContainer/FiltersContainer/DevlogFilter
@onready var filter_label = $VBoxContainer/FiltersContainer/FilterLabel

# 筛选设置
var filter_has_devlog: int = 0  # 0: 全部, 1: 有开发日志, 2: 无开发日志

# 引用其他管理器
var raffle_manager
var data_manager

func _ready():
	# 获取管理器引用
	raffle_manager = get_node("/root/RaffleManager")
	data_manager = get_node("/root/DataManager")
	
	# 连接数据加载信号
	data_manager.connect("data_loaded", _on_data_loaded)
	
	# 初始化筛选控件
	_setup_filters()

# 设置筛选控件
func _setup_filters():
	if devlog_filter:
		devlog_filter.clear()
		devlog_filter.add_item("全部作品", 0)
		devlog_filter.add_item("有开发日志", 1)
		devlog_filter.add_item("无开发日志", 2)
		devlog_filter.select(0)
		devlog_filter.connect("item_selected", _on_devlog_filter_changed)

# 更新参赛作品列表
func update_entries_list():
	# 清空列表
	for child in entries_list.get_children():
		child.queue_free()
	
	# 获取筛选后的参赛作品
	var filtered_entries = _get_filtered_entries()
	
	# 显示筛选后的参赛作品
	for entry in filtered_entries:
		var entry_item = preload("res://scenes/ui/entry_list_item.tscn").instantiate()
		entry_item.setup(entry)
		entries_list.add_child(entry_item)
	
	# 更新筛选状态显示
	_update_filter_status(filtered_entries.size())

# 获取筛选后的作品列表
func _get_filtered_entries() -> Array:
	if filter_has_devlog == 0:  # 全部
		return raffle_manager.entries
	
	var filtered_entries = []
	for entry in raffle_manager.entries:
		var has_devlog = entry.get("has_devlog", false)
		
		if (filter_has_devlog == 1 and has_devlog) or (filter_has_devlog == 2 and not has_devlog):
			filtered_entries.append(entry)
	
	return filtered_entries

# 更新筛选状态显示
func _update_filter_status(filtered_count: int):
	if filter_label:
		var total_count = raffle_manager.entries.size()
		filter_label.text = "已筛选：%d/%d" % [filtered_count, total_count]

# 处理开发日志筛选变更
func _on_devlog_filter_changed(index: int):
	filter_has_devlog = index
	update_entries_list()

# 处理数据加载完成
func _on_data_loaded(_entries):
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
