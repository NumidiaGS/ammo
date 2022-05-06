extends ColorRect

var fps: int = 50
var period: float = 0.0
var period_count: int = 0
var max2: float = 0.0
var max5: float = 0.0
var time_since_max2: float = 0.0
var time_since_max5: float = 0.0

func _process(delta: float) -> void:
	period += delta
	period_count += 1
	
	time_since_max2 += delta
	time_since_max5 += delta
	if delta > max5:
		if delta > max2:
			if max2 > max5:
				max5 = max2
				time_since_max5 = time_since_max2
			max2 = delta
			time_since_max2 = 0.0
		else:
			max5 = delta
			time_since_max5 = 0.0
			
	if time_since_max2 > 2.0:
		if max2 > max5 or time_since_max5 > 4.0:
			max5 = max2
			time_since_max5 = time_since_max2
		max2 = delta
		time_since_max2 = 0.0
	if time_since_max5 > 5.0:
		max5 = max2
		time_since_max5 = time_since_max2
	
	while period >= 0.5:
		period -= 0.5
		var fpsf: float = (2.0 * fps + 2.0 * period_count) / 3.0
		fps = fpsf as int
		if fps >= 55 and period_count == 60:
			fps = min(fps + 1, 60)
		period_count = 0
		
		# Display FPS in the label
		var max_frame = max2
		if max5 > max2:
			max_frame = max5
		$FPSLabel.text = str(int(fps)) + " FPS (L:%d P:%dms)" % [int(1.0 / max_frame),
			Server.game_server_latency]
