extends Panel
# 获奖名单面板

signal export_requested

# 节点引用
@onready var winners_list = $VBoxContainer/WinnersContainer/WinnersList

# 管理器引用
var raffle_manager

func _ready():
	# 获取管理器引用
	raffle_manager = get_node("/root/RaffleManager")
	
	# 连接信号
	raffle_manager.connect("raffle_completed", _on_raffle_completed)
	raffle_manager.connect("raffle_reset", _on_raffle_reset)
	
	update_winners_list()

# 更新获奖者列表
func update_winners_list():
	# 清空列表
	for child in winners_list.get_children():
		child.queue_free()
	
	# 显示所有获奖者
	for prize_name in raffle_manager.winners:
		var winners = raffle_manager.winners[prize_name]
		if winners.size() > 0:
			var prize_label = Label.new()
			prize_label.text = prize_name + ":"
			prize_label.add_theme_font_size_override("font_size", 16)
			prize_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.2))
			winners_list.add_child(prize_label)
			
			for winner in winners:
				var winner_item = preload("res://scenes/ui/winner_list_item.tscn").instantiate()
				winner_item.setup(winner)
				winners_list.add_child(winner_item)

# 抽奖完成时更新列表
func _on_raffle_completed(_winner, _prize):
	update_winners_list()

# 重置抽奖时更新列表
func _on_raffle_reset():
	update_winners_list()

# 导出按钮被按下
func _on_export_button_pressed():
	export_requested.emit()
