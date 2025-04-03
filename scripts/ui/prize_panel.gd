extends Panel
# 奖项管理面板

signal add_prize_requested
signal edit_prize_requested(prize)

# 节点引用
@onready var prizes_list = $VBoxContainer/PrizesContainer/PrizesList

# 管理器引用
var raffle_manager

func _ready():
	# 获取管理器引用
	raffle_manager = get_node("/root/RaffleManager")
	
	# 连接信号
	raffle_manager.connect("raffle_completed", _on_raffle_completed)
	raffle_manager.connect("raffle_reset", _on_raffle_reset)
	raffle_manager.connect("prizes_changed", _on_prizes_changed)
	
	update_prizes_list()

# 更新奖项列表
func update_prizes_list():
	# 清空列表
	for child in prizes_list.get_children():
		child.queue_free()
	
	# 显示所有奖项
	for prize in raffle_manager.prizes:
		var prize_item = preload("res://scenes/ui/prize_list_item.tscn").instantiate()
		prize_item.setup(prize)
		prize_item.connect("delete_requested", _on_prize_delete_requested)
		prize_item.connect("edit_requested", _on_prize_edit_requested)
		prizes_list.add_child(prize_item)

# 添加奖项按钮被按下
func _on_add_prize_button_pressed():
	add_prize_requested.emit()

# 处理删除奖项请求
func _on_prize_delete_requested(prize):
	raffle_manager.remove_prize(prize.id)
	update_prizes_list()

# 处理编辑奖项请求
func _on_prize_edit_requested(prize):
	edit_prize_requested.emit(prize)

# 抽奖完成时更新列表
func _on_raffle_completed(_winner, _prize):
	update_prizes_list()

# 重置抽奖时更新列表
func _on_raffle_reset():
	update_prizes_list()

# 奖项列表变化时更新
func _on_prizes_changed():
	update_prizes_list()
