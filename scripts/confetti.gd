extends CPUParticles2D

func _ready():
	# 让粒子效果自动释放
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = lifetime * 1.5  # 等待比粒子生命周期稍长的时间
	timer.one_shot = true
	timer.timeout.connect(queue_free)
	timer.start()
