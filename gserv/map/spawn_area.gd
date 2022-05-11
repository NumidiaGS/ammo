# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, April 2022

extends Position3D

class_name SpawnArea

####################################################
# ALERT Keep updated with gcli/map/map_object.gd
#  AND consistent with below exported enums
####################################################
# ? Values are permitted for 2 bytes (s16) so between 0 to 65,535
enum ContentType {  NULL = 0,
					ServerOnly = 10,
					Forest = 20, }
@export var content: ContentType

####################################################
####################################################
