extends Control
# 主场景脚本，负责管理所有子场景和功能集成

# 主屏幕场景预加载
var main_screen_scene = preload("res://scenes/ui/main_screen.tscn")
var main_screen_instance

# 管理器引用
var raffle_manager
var data_manager
var config_manager
var ui_manager
var effect_manager

func _ready():
	# 获取管理器引用
	raffle_manager = get_node("/root/RaffleManager")
	data_manager = get_node("/root/DataManager")
	config_manager = get_node("/root/ConfigManager")
	ui_manager = get_node("/root/UIManager")
	effect_manager = get_node("/root/EffectManager")
	
	# 实例化主屏幕场景
	main_screen_instance = main_screen_scene.instantiate()
	add_child(main_screen_instance)
	
	# 注册主屏幕到UI管理器
	ui_manager.register_screen(main_screen_instance)
	
	# 连接主屏幕的信号
	_connect_main_screen_signals()
	
	# 加载配置
	config_manager.load_config()

# 连接主屏幕信号
func _connect_main_screen_signals():
	if main_screen_instance:
		main_screen_instance.connect("raffle_started", _on_raffle_started)
		main_screen_instance.connect("raffle_completed", _on_raffle_completed)
		
		# 连接数据管理器和抽奖管理器的信号到UI管理器
		data_manager.connect("data_loaded", ui_manager.on_data_loaded)
		data_manager.connect("data_error", ui_manager.on_data_error)
		raffle_manager.connect("raffle_completed", ui_manager.on_raffle_completed)
		raffle_manager.connect("raffle_reset", ui_manager.on_raffle_reset)
		config_manager.connect("config_changed", ui_manager.on_config_changed)

# 加载按钮被按下
func _on_load_button_pressed():
	main_screen_instance.dialogs_container.show_file_dialog()

# 加载CSV按钮被按下
func _on_load_csv_button_pressed():
	var csv_path = "res://config/entries.csv"
	var result = data_manager.fetch_data("csv", {"path": csv_path})
	if result.success:
		ui_manager.update_all_ui()
		main_screen_instance.dialogs_container.show_message("成功", "CSV数据加载成功，共加载 " + str(raffle_manager.entries.size()) + " 个参赛作品。")
	else:
		main_screen_instance.dialogs_container.show_message("错误", "CSV数据加载失败: " + result.message)

# itch.io导入按钮被按下
func _on_itch_io_button_pressed():
	main_screen_instance.dialogs_container.show_jam_id_dialog()

# 权重设置按钮被按下
func _on_filter_button_pressed():
	main_screen_instance.dialogs_container.show_weight_dialog(config_manager)

# 重置抽奖按钮被按下 
func _on_reset_button_pressed():
	main_screen_instance.dialogs_container.show_confirmation(
		"重置确认", 
		"确定要重置抽奖结果吗？所有获奖者将被清空。",
		func(): raffle_manager.reset_raffle()
	)

# 添加奖项请求
func _on_add_prize_requested():
	main_screen_instance.dialogs_container.show_prize_dialog()

# 抽奖开始事件
func _on_raffle_started():
	# 可以在这里处理全局的抽奖开始事件
	print("抽奖开始")

# 抽奖完成事件
func _on_raffle_completed(winner, prize):
	# 可以在这里处理全局的抽奖完成事件
	print("抽奖完成: " + winner.title + " 获得 " + prize.name)

# 导出结果按钮被按下
func _on_export_requested():
	main_screen_instance.dialogs_container.show_save_file_dialog()

# 文件被选择（加载数据）
func _on_file_selected(path):
	var result = data_manager.fetch_data("local_file", {"path": path})
	if result.success:
		ui_manager.update_all_ui()
		main_screen_instance.dialogs_container.show_message("成功", "数据加载成功，共加载 " + str(raffle_manager.entries.size()) + " 个参赛作品。")
	else:
		main_screen_instance.dialogs_container.show_message("错误", "加载数据失败: " + result.message)

# GameJam ID 确认
func _on_jam_id_confirmed(jam_id):
	var result = data_manager.fetch_data("itch_io", {"jam_id": jam_id})
	if result.success:
		ui_manager.update_all_ui()
		main_screen_instance.dialogs_container.show_message("成功", "数据加载成功，共加载 " + str(raffle_manager.entries.size()) + " 个参赛作品。")
	else:
		main_screen_instance.dialogs_container.show_message("错误", "加载数据失败: " + result.message)

# 奖项添加
func _on_prize_added(prize_name, count):
	var result = raffle_manager.add_prize(prize_name, count)
	if result.success:
		ui_manager.update_prizes_list()
	else:
		main_screen_instance.dialogs_container.show_message("错误", result.message)

# 保存文件被选择（导出结果）
func _on_save_file_selected(path):
	var result = data_manager.export_winners(path)
	if result.success:
		main_screen_instance.dialogs_container.show_message("成功", "获奖结果已导出到: " + path)
	else:
		main_screen_instance.dialogs_container.show_message("错误", "导出结果失败: " + result.message)
