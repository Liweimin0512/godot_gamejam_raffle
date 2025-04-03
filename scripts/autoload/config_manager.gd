extends Node
# 配置管理器 - 单例模式
# 负责处理应用配置和奖项管理

signal config_changed
signal prizes_changed

# 程序配置
var config = {
	"animation_speed": 0.05,
	"animation_duration": 3.0,
	"effect_duration": 2.0,
	"theme": "default",
	"last_jam_id": "",
	"last_data_provider": "itchio"
}

# 可用的抽奖策略
var raffle_strategies = {
	"weighted": "基于权重",
	"random": "完全随机"
}

# 当前使用的抽奖策略
var current_strategy = "weighted"

func _ready():
	# 加载已保存的配置
	load_config()

# 保存配置到文件
func save_config():
	var config_file = FileAccess.open("user://raffle_config.json", FileAccess.WRITE)
	if config_file:
		config_file.store_string(JSON.stringify(config, "\t"))
		config_file.close()
		config_changed.emit()

# 从文件加载配置
func load_config():
	if FileAccess.file_exists("user://raffle_config.json"):
		var config_file = FileAccess.open("user://raffle_config.json", FileAccess.READ)
		if config_file:
			var json = JSON.new()
			var error = json.parse(config_file.get_as_text())
			config_file.close()
			
			if error == OK:
				var loaded_config = json.get_data()
				# 合并加载的配置和默认配置
				for key in loaded_config:
					if config.has(key):
						config[key] = loaded_config[key]
				
				config_changed.emit()

# 更新配置
func update_config(key, value):
	if config.has(key) and config[key] != value:
		config[key] = value
		save_config()

# 设置抽奖策略
func set_raffle_strategy(strategy):
	if raffle_strategies.has(strategy) and current_strategy != strategy:
		current_strategy = strategy
		config_changed.emit()
