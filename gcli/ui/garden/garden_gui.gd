extends Node

var time_since_queue_info_request = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	$QueueInfo.visible = false
	$StatusRect.visible = false
	
	assert(Server.connect("garden_queue_info_received", on_garden_queue_info_received) == OK,\
		"Server::garden_queue_info_received")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if $QueueInfo.visible:
		time_since_queue_info_request += delta
		if time_since_queue_info_request >= 1.0:
			# Re-request the queue info from the server
			Server.request_garden_queue_info()
			time_since_queue_info_request = 0.0

##################################
########### Callbacks ############
##################################

func on_garden_queue_info_received(info: PackedByteArray) -> void:
	# Compile Queue Info from packed byte array
	# Queue Size
	var is_queued: bool = info.decode_s8(0) != 0
	var queue_possize: int = info.decode_s16(1)
	var est_time_secs: int = info.decode_s32(3)
	
	if is_queued:
		var desc = "You are currently "
		if queue_possize == 0:
			desc += "next "
		else:
			desc += str(queue_possize)
		desc += " in line. You will be called upon to plough your fields in approximately " \
			+ str(est_time_secs) + " seconds."
			
		$QueueInfo/InfoLabel.text = desc
		$QueueInfo/QueueButton.visible = false
	else:
		$QueueInfo/InfoLabel.text = "There are currently " + str(queue_possize) \
			+ " fellow heroes in queue. If you queue now then you will be called upon " \
			+ " in an estimated " + str(est_time_secs) + " seconds to plough your fields."
		$QueueInfo/QueueButton.visible = true

func show_queue_info():
	$QueueInfo.visible = true
	$StatusRect.visible = false
	
	$QueueInfo/InfoLabel.text = "Getting queue info..."
	$QueueInfo/QueueButton.visible = false
	
	# Request the queue info from the server
	Server.request_garden_queue_info()
	time_since_queue_info_request = 0.0

func begin_event_for_player():
	$QueueInfo.visible = false
	$StatusRect.visible = true
	
	$StatusRect/StatusLabel.text = "getting data..."

func update_garden_status(garden_state: int, garden_time: float) -> void:
	$StatusRect/StatusLabel.text = "state:%d time:%.2f" % [garden_state, garden_time]

func _on_queue_info_exit_pressed():
	$QueueInfo.visible = false

func _on_queue_button_pressed():
	Server.enqueue_garden_event()
