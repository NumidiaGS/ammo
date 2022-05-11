# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, February 2022

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
