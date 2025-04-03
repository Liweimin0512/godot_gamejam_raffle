extends Node
# 特效管理器 - 单例模式
# 负责管理和播放视觉特效

# 特效场景
var confetti_scene
var fireworks_scene

# 配置引用
var config_manager

func _ready():
	# 加载特效场景
	confetti_scene = load("res://scenes/effects/confetti.tscn")
	
	# 尝试加载可选的烟花特效
	if ResourceLoader.exists("res://scenes/effects/fireworks.tscn"):
		fireworks_scene = load("res://scenes/effects/fireworks.tscn")
	
	# 获取配置管理器引用
	config_manager = get_node_or_null("/root/ConfigManager")

# 播放胜利特效
func play_win_effect(parent_node, effect_type = "confetti"):
	if not parent_node:
		push_error("特效需要一个父节点")
		return
	
	match effect_type:
		"confetti":
			_play_confetti_effect(parent_node)
		"fireworks":
			if fireworks_scene:
				_play_fireworks_effect(parent_node)
			else:
				_play_confetti_effect(parent_node)
		_:
			_play_confetti_effect(parent_node)

# 播放彩带特效
func _play_confetti_effect(parent_node):
	var particles_container = parent_node.find_child("ParticlesContainer", true, false)
	if not particles_container:
		push_error("无法找到粒子容器节点")
		return
	
	# 创建彩带特效
	var confetti = confetti_scene.instantiate()
	particles_container.add_child(confetti)
	
	# 设置特效位置
	confetti.position = Vector2(particles_container.size.x / 2, 0)
	
	# 播放特效
	confetti.emitting = true
	
	# 设置自动清理
	var effect_duration = 2.0
	if config_manager:
		effect_duration = config_manager.config.effect_duration
	
	var timer = Timer.new()
	parent_node.add_child(timer)
	timer.wait_time = effect_duration
	timer.one_shot = true
	timer.timeout.connect(func(): confetti.queue_free(); timer.queue_free())
	timer.start()

# 播放烟花特效
func _play_fireworks_effect(parent_node):
	var particles_container = parent_node.find_child("ParticlesContainer", true, false)
	if not particles_container:
		push_error("无法找到粒子容器节点")
		return
	
	# 创建烟花特效
	var fireworks = fireworks_scene.instantiate()
	particles_container.add_child(fireworks)
	
	# 设置特效位置
	fireworks.position = Vector2(particles_container.size.x / 2, particles_container.size.y / 2)
	
	# 播放特效
	fireworks.start()
	
	# 设置自动清理
	var effect_duration = 3.0
	if config_manager:
		effect_duration = config_manager.config.effect_duration
	
	var timer = Timer.new()
	parent_node.add_child(timer)
	timer.wait_time = effect_duration
	timer.one_shot = true
	timer.timeout.connect(func(): fireworks.queue_free(); timer.queue_free())
	timer.start()
