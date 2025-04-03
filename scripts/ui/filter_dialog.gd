extends AcceptDialog
# 筛选对话框，用于管理抽奖权重设置

# 节点引用
@onready var weight_all_value = $VBoxContainer/WeightAllContainer/WeightAllValue

# 管理器引用
var raffle_manager

# 设置对话框
func setup(manager):
	raffle_manager = manager

# 应用按钮被按下，设置所有参赛作品的权重
func _on_apply_button_pressed():
	if raffle_manager:
		var weight = weight_all_value.value
		raffle_manager.set_all_weights(weight)

# 随机按钮被按下，随机设置所有参赛作品的权重
func _on_randomize_button_pressed():
	if raffle_manager:
		raffle_manager.randomize_weights()

# 重置按钮被按下，将所有参赛作品的权重重置为1
func _on_reset_button_pressed():
	if raffle_manager:
		raffle_manager.reset_weights()
