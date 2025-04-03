extends Panel
# 抽奖区域，实现扭蛋机效果

signal raffle_completed(winner)
signal raffle_started

# 节点引用
@onready var capsule = $CapsuleMachine/Capsule
@onready var capsule_label = $CapsuleMachine/Capsule/CapsuleLabel
@onready var current_prize_label = $CurrentPrizeLabel
@onready var winner_label = $WinnerLabel
@onready var particles_container = $ParticlesContainer
@onready var animation_player = $AnimationPlayer
@onready var draw_button = $Button
@onready var drum_roll_audio = $DrumRollAudio
@onready var capsule_open_audio = $CapsuleOpenAudio

# 管理器引用
var raffle_manager
var effect_manager
var config_manager

# 抽奖状态
var is_drawing = false
var current_entries = []
var selected_entry = null
var current_prize = null

# 随机扭蛋颜色
var capsule_colors = [
	Color(0.85, 0.24, 0.24, 1.0),  # 红色
	Color(0.24, 0.48, 0.85, 1.0),  # 蓝色
	Color(0.85, 0.73, 0.24, 1.0),  # 黄色
	Color(0.24, 0.85, 0.48, 1.0),  # 绿色
	Color(0.73, 0.24, 0.85, 1.0),  # 紫色
	Color(0.85, 0.48, 0.24, 1.0)   # 橙色
]

func _ready():
	# 获取管理器引用
	raffle_manager = get_node("/root/RaffleManager")
	effect_manager = get_node("/root/EffectManager")
	config_manager = get_node("/root/ConfigManager")
	
	# 初始化UI
	capsule.visible = false
	winner_label.text = ""
	update_draw_button()
	
	# 尝试加载音效
	_load_audio()

# 加载音效
func _load_audio():
	var drum_roll_path = "res://assets/audio/drum_roll.ogg"
	var capsule_open_path = "res://assets/audio/capsule_open.ogg"
	
	if ResourceLoader.exists(drum_roll_path):
		drum_roll_audio.stream = load(drum_roll_path)
	
	if ResourceLoader.exists(capsule_open_path):
		capsule_open_audio.stream = load(capsule_open_path)

# 更新抽奖按钮状态
func update_draw_button():
	var next_prize = raffle_manager.get_next_prize()
	var available_entries = raffle_manager.get_available_entries()
	
	draw_button.disabled = is_drawing or not next_prize or available_entries.size() == 0
	
	if next_prize:
		current_prize_label.text = "当前抽取: " + next_prize.name
	else:
		current_prize_label.text = "没有可用的奖项"

# 开始抽奖动画
func start_raffle_animation():
	if is_drawing:
		return
	
	# 获取当前可用奖项
	current_prize = raffle_manager.get_next_prize()
	if not current_prize:
		winner_label.text = "没有可用的奖项"
		return
	
	# 获取可用参赛者
	current_entries = raffle_manager.get_available_entries()
	if current_entries.size() == 0:
		winner_label.text = "没有可用的参赛者"
		return
	
	# 通知抽奖开始
	raffle_started.emit()
	
	# 开始抽奖动画
	is_drawing = true
	draw_button.disabled = true
	winner_label.text = "抽奖中..."
	
	# 显示扭蛋并设置随机颜色
	capsule.visible = true
	capsule.color = capsule_colors[randi() % capsule_colors.size()]
	capsule_label.text = "???"
	
	# 播放音效
	if drum_roll_audio.stream:
		drum_roll_audio.play()
	
	# 播放扭蛋动画
	animation_player.play("capsule_drop")

# 扭蛋动画结束
func _on_capsule_animation_finished():
	# 播放开启音效
	if capsule_open_audio.stream:
		capsule_open_audio.play()
	
	# 执行实际抽奖
	var result = raffle_manager.perform_raffle(config_manager.current_strategy)
	
	if result.success:
		selected_entry = result.winner
		
		# 更新扭蛋内容
		capsule_label.text = selected_entry.title
		
		# 更新获奖者显示
		winner_label.text = selected_entry.title + " - " + selected_entry.user
		
		# 播放胜利特效
		effect_manager.play_win_effect(self)
		
		# 通知抽奖完成
		raffle_completed.emit(selected_entry)
	else:
		winner_label.text = result.message
		capsule.visible = false
	
	# 重置状态
	is_drawing = false
	update_draw_button()

# 抽奖按钮被按下
func _on_button_pressed():
	start_raffle_animation()
