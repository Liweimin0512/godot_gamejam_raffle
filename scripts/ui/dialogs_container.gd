extends Control
# 对话框容器，管理所有弹出对话框

signal prize_added(name, count)
signal file_selected(path)
signal save_file_selected(path)
signal jam_id_confirmed(jam_id)

# 节点引用
@onready var prize_dialog = $PrizeDialog
@onready var prize_name_input = $PrizeDialog/VBoxContainer/PrizeNameContainer/PrizeName
@onready var prize_count_input = $PrizeDialog/VBoxContainer/PrizeCountContainer/PrizeCount
@onready var prize_dialog_error = $PrizeDialog/VBoxContainer/ErrorLabel

@onready var file_dialog = $FileDialog
@onready var save_file_dialog = $SaveFileDialog
@onready var message_dialog = $MessageDialog
@onready var jam_id_input_dialog = $JamIdInputDialog
@onready var jam_id_input = $JamIdInputDialog/VBoxContainer/JamIdInput
@onready var filter_dialog = $FilterDialog

# 管理器引用
var raffle_manager

func _ready():
	# 获取管理器引用
	raffle_manager = get_node("/root/RaffleManager")

# 显示添加奖项对话框
func show_prize_dialog():
	prize_dialog_error.text = ""
	prize_dialog.popup_centered()

# 显示打开文件对话框
func show_file_dialog():
	file_dialog.popup_centered()

# 显示保存文件对话框
func show_save_file_dialog():
	save_file_dialog.popup_centered()

# 显示消息对话框
func show_message(title, message):
	message_dialog.title = title
	message_dialog.dialog_text = message
	message_dialog.popup_centered()

# 显示GameJam ID输入对话框
func show_jam_id_input_dialog():
	jam_id_input_dialog.popup_centered()

# 显示筛选对话框
func show_filter_dialog():
	filter_dialog.setup(raffle_manager)
	filter_dialog.popup_centered()

# 奖项对话框即将弹出
func _on_prize_dialog_about_to_popup():
	prize_name_input.text = ""
	prize_count_input.value = 1
	prize_dialog_error.text = ""

# 奖项对话框确认
func _on_prize_dialog_confirmed():
	var prize_name = prize_name_input.text.strip_edges()
	var prize_count = int(prize_count_input.value)
	
	if prize_name.is_empty():
		prize_dialog_error.text = "请输入奖项名称"
		prize_dialog.rejected.emit()
		return
	
	prize_added.emit(prize_name, prize_count)

# 文件对话框选择文件
func _on_file_dialog_file_selected(path):
	file_selected.emit(path)

# 保存文件对话框选择文件
func _on_save_file_dialog_file_selected(path):
	save_file_selected.emit(path)

# GameJam ID输入对话框确认
func _on_jam_id_input_dialog_confirmed():
	var jam_id = jam_id_input.text.strip_edges()
	if not jam_id.is_empty():
		jam_id_confirmed.emit(jam_id)
