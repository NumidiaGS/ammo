# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, February 2022

extends RefCounted

class_name HeroData

# Hero Input Mask Values
# TODO Keep this Synchronized with server: /gserv/src/players/hero_data.gd
const HERO_INPUT_MoveForward: int = 1
const HERO_INPUT_MoveBackward: int = 2
const HERO_INPUT_RotateLeft: int = 4
const HERO_INPUT_RotateRight: int = 8
const HERO_INPUT_StrafeLeft: int = 16
const HERO_INPUT_StrafeRight: int = 32
const HERO_INPUT_Jump: int = 64

# Summary
var uid: int
var nickname: String = "null"

# Input
var input_serv_time: int = 0
var input_client_time: int = 0

var position: Vector3 = Vector3.ZERO
var yaw: float = PI / 2.0

# Client Movement Report
var cmr_client_time: int = 0
var cmr_server_time: int = 0
var cmr_position: Vector3 = Vector3.ZERO
var cmr_yaw: float = 0.0
var cmr_vertical_velocity: float = 0.0
var cmr_input_mask: int = 0
var cmr_modified: bool = true

# Server Cache
var sc_lumber_tree_anchor_pos: Vector2 = Vector2(99999, 99999)
var sc_lumber_tree_server_time: int = 0

# Attributes
var dead: float = 0.0
var level: int = 1
var max_light: int = 100
var max_satiation: int = 100
var max_digestion: int = 100

# State
var light: int
var resource_inventory: Enums.InventoryItemType
var hitpoints: int

# Statuses
var satiation: float

# Serializes the hero summary (uid, name)
func serialize_summary() -> String:
#	print("uid=", uid)
#	print("nickname=", nickname)
	var result: String = "%d:%s" % [uid, nickname]
#	print("serialize:", result)
	return result
