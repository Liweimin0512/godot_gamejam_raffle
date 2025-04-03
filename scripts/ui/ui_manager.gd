extends Node
# UI管理器
# 作为UI处理的中间层，不直接引用节点，只提供方法供调用

# 引用当前屏幕
var current_screen: Control = null

# 引用其他管理器
var raffle_manager
var data_manager
var config_manager
var effect_manager

func _ready():
	# 获取管理器引用
	raffle_manager = get_node("/root/RaffleManager")
	data_manager = get_node("/root/DataManager")
	config_manager = get_node("/root/ConfigManager")
	effect_manager = get_node("/root/EffectManager")

# 注册当前屏幕
func register_screen(screen: Control):
	current_screen = screen
	print("UI管理器: 已注册屏幕 ", screen.name)

# 更新UI
func update_all_ui():
	if current_screen and current_screen.has_method("update_all_ui"):
		current_screen.update_all_ui()

# 更新参赛作品列表
func update_entries_list():
	if current_screen and current_screen.has_method("update_entries_list"):
		current_screen.update_entries_list()

# 更新奖项列表
func update_prizes_list():
	if current_screen and current_screen.has_method("update_prizes_list"):
		current_screen.update_prizes_list()

# 更新获奖者列表
func update_winners_list():
	if current_screen and current_screen.has_method("update_winners_list"):
		current_screen.update_winners_list()

# 更新抽奖按钮状态
func update_draw_button():
	if current_screen and current_screen.has_method("update_draw_button"):
		current_screen.update_draw_button()

# 重置UI状态
func reset_ui():
	if current_screen and current_screen.has_method("_reset_ui"):
		current_screen._reset_ui()

# 显示消息对话框
func show_message(title: String, message: String):
	if current_screen and current_screen.has_method("show_message"):
		current_screen.show_message(title, message)

# 显示确认对话框
func show_confirmation(title: String, message: String, callback: Callable):
	if current_screen and current_screen.has_method("show_confirmation"):
		current_screen.show_confirmation(title, message, callback)

# 处理数据加载完成
func on_data_loaded(entries):
	raffle_manager.set_entries(entries)
	show_message("成功", "成功加载 " + str(entries.size()) + " 个参赛作品")
	update_all_ui()

# 处理数据加载错误
func on_data_error(message):
	show_message("错误", "数据加载错误: " + message)

# 处理配置变更
func on_config_changed():
	update_all_ui()

# 处理抽奖完成
func on_raffle_completed(_winner, _prize):
	# 参数虽然不在此函数中直接使用，但需要匹配信号参数
	update_all_ui()

# 处理抽奖重置
func on_raffle_reset():
	reset_ui()
