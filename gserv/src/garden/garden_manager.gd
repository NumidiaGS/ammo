extends Node

signal garden_event_awaiting_player(player_peer_id)
signal garden_event_begun()

var broadcast_state: bool = false

var player_queue_peer_id: Array[int] = []

const placement_position: Vector3 = Vector3(-32.5, 0.0, -14.0)
const placement_rotation: float = -PI / 2.0

# Garden State
enum GardenState { Idle, AwaitingHero, Prep, Active }
enum GardenSlotState { Empty, Seeded, Growing, Harvestable, Ruined }
var garden_state: GardenState = GardenState.Idle
var garden_hero: PlayerAccount = null
var garden_time: float = 0.0
var garden_notify: float = 0.0
var garden_slot_state: Array[int]
var garden_slot_time: Array[float]
var garden_slot_hp: Array[int]
var garden_slot_corrupt: Array[float]
var garden_cockroach_slot: int
var garden_cockroach_left: float

# Called when the node enters the scene tree for the first time.
func _ready():
	_init_garden_state()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	match garden_state:
		GardenState.Idle:
			if player_queue_peer_id.size() > 0:
				# Initiate the preparation phase
				garden_time = 15.0
				garden_state = GardenState.AwaitingHero
				call_deferred("emit_signal", "garden_event_awaiting_player", \
					player_queue_peer_id[0])
		GardenState.AwaitingHero:
			pass
		_:
			_update_garden(delta)
	

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

func begin_awaitened_garden_event(player_acc: PlayerAccount) -> void:
	print("begin_awaitened_garden_event")
	garden_state = GardenState.Prep
	garden_time = 8.0
	for i in range(0, 9):
		garden_slot_state[i] = GardenSlotState.Empty
		garden_slot_time[i] = 0.0
		garden_slot_hp[i] = 0
		garden_slot_corrupt[i] = -1.0
	garden_cockroach_slot = -1
	garden_cockroach_left = -15.0
	garden_hero = player_acc
	
	broadcast_state = true

func compile_garden_state() -> PackedByteArray:
	# Compile Garden State into packed byte array
	var pba: PackedByteArray = []
	pba.resize(256)
	var iof = 0
	
	pba.encode_u8(iof, garden_state)
	iof += 1
	pba.encode_s64(iof, garden_hero.hero.uid)
	iof += 8
	pba.encode_float(iof, garden_time)
	iof += 4
	pba.encode_float(iof, garden_notify)
	iof += 4
	for i in range(0, 9):
		pba.encode_u8(iof, garden_slot_state[i])
		iof += 1
		pba.encode_float(iof, garden_slot_time[i])
		iof += 4
		pba.encode_u8(iof, garden_slot_hp[i])
		iof += 1
		pba.encode_float(iof, garden_slot_corrupt[i])
		iof += 4
	pba.encode_u8(iof, garden_cockroach_slot)
	iof += 1
	pba.encode_float(iof, garden_cockroach_left)
	iof += 4
#	print("Garden Packet Size:", iof)
	
	return pba

var time_since_garden_report: float = 0.0
func _update_garden(delta: float) -> void:
	garden_time -= delta
	
	time_since_garden_report += delta
	broadcast_state = delta >= 0.2
	
	# Prep
	if garden_state == GardenState.Prep:
		if garden_time <= 0.0:
			# Advance the state
			garden_state = GardenState.Active
			garden_time = 4 * 60.0
	else:
		# Finished
		if garden_time < 0.0:
			garden_state = GardenState.Idle
			broadcast_state = true
		
		# Cockroach
		garden_cockroach_left -= delta
		if garden_cockroach_left <= 0.0:
			garden_cockroach_slot = randi_range(0, 8)
			print("garden_cockroach_slot:", garden_cockroach_slot)
			garden_cockroach_left = 4.0
			garden_slot_hp[garden_cockroach_slot] -= 1
			if garden_slot_state[garden_cockroach_slot] != GardenSlotState.Empty and \
				garden_slot_hp[garden_cockroach_slot] <= 0:
				garden_slot_state[garden_cockroach_slot] = GardenSlotState.Ruined
			broadcast_state = true
		
		# Active
		for i in range(0, 9):
			garden_slot_time[i] -= delta
			
			# Garden Slot State
			match garden_slot_state[i]:
				GardenSlotState.Empty:
					pass
				GardenSlotState.Seeded:
					if garden_slot_time[i] <= 0.0:
						garden_slot_state[i] = GardenSlotState.Growing
						garden_slot_time[i] = 48.0
				GardenSlotState.Growing:
					if garden_slot_time[i] <= 0.0:
						garden_slot_state[i] = GardenSlotState.Harvestable
						garden_slot_time[i] = 8.0
				GardenSlotState.Harvestable:
					if garden_slot_time[i] <= 0.0:
						garden_slot_state[i] = GardenSlotState.Ruined
				GardenSlotState.Ruined:
					pass
			
			# Corruption
			if garden_slot_corrupt[i] >= 0.0:
				garden_slot_corrupt[i] -= delta
				if garden_slot_corrupt[i] <= 0.0:
					# Spread
					for x in range(-1, 2, 2):
						for y in range(-1, 2, 2):
							var idx = i + y * 3 + x
							if idx < 0 or idx >= 9:
								continue
							if garden_slot_corrupt[idx] >= 0.0 and randf() >= 0.7:
								garden_slot_corrupt[idx] = 4.5
				broadcast_state = true

func update_state_broadcasted() -> void:
	broadcast_state = false
	time_since_garden_report = 0.0

func get_queue_info(querying_peer_id: int) -> PackedByteArray:
	var pba: PackedByteArray = []
	
	# Find the querying player in the user queue
	var idx = player_queue_peer_id.size() - 1
	while idx >= 0:
		if player_queue_peer_id[idx] == querying_peer_id:
			break
	
	# Send 
	pba.resize(1 + 2 + 4)
	
	# Potential/Existing Queue Position
	if idx < 0:
		# Player Not Yet Queued
		pba.encode_u8(0, 0)
		pba.encode_s16(1, player_queue_peer_id.size())
		var expected_delay: int = player_queue_peer_id.size() * 8 * 60
		if garden_state == GardenState.Prep:
			expected_delay += 8 - int(garden_time) + 8 * 60
		if garden_state == GardenState.Active:
			expected_delay += 8 * 60 - int(garden_time)
		pba.encode_s32(3, expected_delay)
	else:
		# Player Already Queued
		pba.encode_u8(0, 1)
		pba.encode_s16(1, idx)
		var expected_delay: int = idx * 8 * 60
		if idx > 0:
			if garden_state == GardenState.Prep:
				expected_delay += 8 - int(garden_time) + 8 * 60
			if garden_state == GardenState.Active:
				expected_delay += 8 * 60 - int(garden_time)
		pba.encode_s32(3, expected_delay)
	
	return pba

func enqueue_player(player_peer_id: int) -> void:
	# Find the querying player in the user queue
	var idx = player_queue_peer_id.size() - 1
	while idx >= 0:
		if player_queue_peer_id[idx] == player_peer_id:
			print("[Error] GardenManager::enqueue_player = Player already queued")
			break
	
	player_queue_peer_id.append(player_peer_id)
	
	
