extends PanelContainer
# 奖项列表项

signal delete_requested(prize)
signal edit_requested(prize)

# 节点引用
@onready var prize_name_label = $MarginContainer/HBoxContainer/PrizeInfo/PrizeName
@onready var progress_label = $MarginContainer/HBoxContainer/PrizeInfo/ProgressLabel

# 奖项数据
var prize_data = null

func _ready():
	pass

# 设置奖项数据
func setup(data):
	prize_data = data
	update_display()

# 更新显示
func update_display():
	if prize_data:
		prize_name_label.text = prize_data.name
		progress_label.text = str(prize_data.count - prize_data.remaining_count) + "/" + str(prize_data.count)
		
		# 如果已经抽完或未激活，显示为灰色
		if prize_data.remaining_count <= 0 or not prize_data.is_active:
			modulate = Color(0.7, 0.7, 0.7, 1.0)
		else:
			modulate = Color(1, 1, 1, 1)

# 删除按钮被按下
func _on_delete_button_pressed():
	if prize_data:
		delete_requested.emit(prize_data)

# 编辑按钮被按下
func _on_edit_button_pressed():
	if prize_data:
		edit_requested.emit(prize_data)
