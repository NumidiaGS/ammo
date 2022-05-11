# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, February 2022

extends RefCounted

class_name KingdomPropertyInfo

const KDPROPERTY_Farm: int = 1
const KDPROPERTY_Kitchen: int = 2
enum KingdomPropertyType { NULL, Farm, Kitchen }

var anchor_x: int
var anchor_z: int
var width: int
var depth: int
var property_type: KingdomPropertyType = KingdomPropertyType.NULL
