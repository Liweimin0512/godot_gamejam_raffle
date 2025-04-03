extends Window
# 奖项添加/编辑对话框

signal prize_confirmed(prize_data)

# UI 引用
@onready var name_edit = %NameEdit
@onready var count_spinbox = %CountSpinBox
@onready var priority_spinbox = %PrioritySpinBox
@onready var description_edit = %DescriptionEdit
@onready var duplicate_checkbox = %DuplicateCheckBox
@onready var is_active_checkbox = %IsActiveCheckBox

var editing_prize = null  # 当前编辑的奖项，为null表示新建

func _ready():
	# 设置默认值
	reset_form()

# 重置表单
func reset_form():
	name_edit.text = ""
	count_spinbox.value = 1
	priority_spinbox.value = 0
	description_edit.text = ""
	duplicate_checkbox.button_pressed = false
	is_active_checkbox.button_pressed = true
	editing_prize = null
	title = "添加奖项"

# 设置编辑模式
func edit_prize(prize):
	editing_prize = prize
	
	# 填充表单
	name_edit.text = prize.name
	count_spinbox.value = prize.count
	priority_spinbox.value = prize.priority
	description_edit.text = prize.description
	duplicate_checkbox.button_pressed = prize.allow_duplicate_winners
	is_active_checkbox.button_pressed = prize.is_active
	
	title = "编辑奖项"

# 收集表单数据
func collect_form_data() -> Dictionary:
	var prize_data = {}
	
	# 如果是编辑模式，保留原ID
	if editing_prize:
		prize_data["id"] = editing_prize.id
	else:
		prize_data["id"] = str(randi())
	
	prize_data["name"] = name_edit.text
	prize_data["count"] = int(count_spinbox.value)
	prize_data["priority"] = int(priority_spinbox.value)
	prize_data["description"] = description_edit.text
	prize_data["allow_duplicate_winners"] = duplicate_checkbox.button_pressed
	prize_data["is_active"] = is_active_checkbox.button_pressed
	
	return prize_data

# 验证表单数据
func validate_form() -> bool:
	if name_edit.text.strip_edges().is_empty():
		OS.alert("请输入奖项名称", "提示")
		return false
	
	if count_spinbox.value < 1:
		OS.alert("奖项数量必须大于0", "提示")
		return false
	
	return true

# 确认按钮被按下
func _on_confirm_button_pressed():
	if validate_form():
		prize_confirmed.emit(collect_form_data())
		reset_form()
		hide()

# 取消按钮被按下
func _on_cancel_button_pressed():
	reset_form()
	hide()

# 窗口关闭请求
func _on_close_requested():
	reset_form()
	hide()
