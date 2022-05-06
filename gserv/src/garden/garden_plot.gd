extends RefCounted

class_name GardenPlot

# Detail
var uid: int
var in_use: bool

# State
var slot
var slot_state: Array[int]
var slot_age: Array[float]
var slot_hp: Array[int]
var slot_corrupt: Array[float]
var cockroach_slot: int
