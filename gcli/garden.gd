extends Node3D

# Garden State
enum GardenState { Idle, Prep, Active }
enum GardenSlotState { Empty, Seeded, Growing, Harvestable, Ruined }
var garden_state: GardenState = GardenState.Idle
var garden_hero_uid: int = 0
var garden_time: float = 0.0
var garden_notify: float = 0.0
var garden_slot_state: Array[int]
var garden_slot_time: Array[float]
var garden_slot_hp: Array[int]
var garden_slot_corrupt: Array[float]
var garden_cockroach_slot: int
var garden_cockroach_left: float

@onready var gui_garden: Control = get_node("/root/Game/GUI/Garden")

##################################
######### Initialization #########
##################################

# Called when the node enters the scene tree for the first time.
func _ready():
	_init_garden_state()
	assert($CrateMesh/StaticBody3D.connect("input_event", crate_clicked) == OK,\
		"Crate Click Connect")
	assert(Server.connect("garden_state_received", on_garden_state_received) == OK,\
		"Server::on_garden_state_received")
	assert(Server.connect("garden_event_begun_for_player", on_garden_event_begun_for_player) == OK,\
		"Server::on_garden_event_begun_for_player")

func _init_garden_state() -> void:
	garden_slot_state = []
	garden_slot_time = []
	garden_slot_hp = []
	garden_slot_corrupt = []
	
	for i in range(0, 9):
		garden_slot_state.append(0)
		garden_slot_time.append(0.0)
		garden_slot_hp.append(0)
		garden_slot_corrupt.append(0.0)

##################################
########### Callbacks ############
##################################

func crate_clicked(camera: Node, event: InputEvent, position: Vector3, normal: Vector3, \
	shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Display the queue info gui panel
			gui_garden.show_queue_info()

func on_garden_event_begun_for_player() -> void:
	gui_garden.begin_event_for_player()

func on_garden_state_received(state: PackedByteArray) -> void:
	# Decompile Garden State from packed byte array
	var iof = 0
	
	garden_state = state.decode_s8(iof)
	iof += 1
	garden_hero_uid = state.decode_s64(iof)
	iof += 8
	garden_time = state.decode_float(iof)
	iof += 4
	garden_notify = state.decode_float(iof)
	iof += 4
	for i in range(0, 9):
		garden_slot_state[i] = state.decode_s8(iof)
		iof += 1
		garden_slot_time[i] = state.decode_float(iof)
		iof += 4
		garden_slot_hp[i] = state.decode_s8(iof)
		iof += 1
		garden_slot_corrupt[i] = state.decode_float(iof)
		iof += 4
	garden_cockroach_slot = state.decode_u8(iof)
	iof += 1
	garden_cockroach_left = state.decode_float(iof)
	iof += 4
	
#	print("pba:", state)
	
#	print("garden_cockroach_slot:", garden_cockroach_slot)
	
	# Update Visuals
	if garden_cockroach_slot < 0:
		$Cockroach.visible = false
	else:
		$Cockroach.visible = true
		$Cockroach.position = Vector3(-3.9 + int(garden_cockroach_slot / 3) * 2.0, 0.6,\
			-0.2 - garden_cockroach_slot % 3 * 2.0)
	
	# Update GUI
	gui_garden.update_garden_status(garden_state, garden_time)

##################################
############ Process #############
##################################

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
