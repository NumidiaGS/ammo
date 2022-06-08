# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, June 2022

extends Object

class_name Enums

# ? Values are permitted for 1 byte (u8) so between 0 to 255
enum InventoryItemType {
	NULL = 0,
	Empty = 1,
	OversizeOccupied = 2,
	RedBerry = 8,
	WoodLog,
}
