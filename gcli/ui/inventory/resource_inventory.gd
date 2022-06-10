# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, June 2022

extends CenterContainer

# The lowest period between resource inventory updates allowed
const ResourceUpdateFailsafePeriod: float = 10.0

var _elapsed_since_resource_update: float = ResourceUpdateFailsafePeriod - 0.5
var _icons: CompressedTexture2D
var _icon_atlas: Dictionary

func _add_icon_atlas_texture(item_type: Enums.InventoryItemType, row: int, col: int) -> void:
	var atx: AtlasTexture = AtlasTexture.new()
	atx.atlas = _icons
	atx.filter_clip = true
	atx.region = Rect2(col * 64, row * 64, 64, 64)
	_icon_atlas[item_type] = atx

# Called when the node enters the scene tree for the first time.
func _ready():
	assert(Server.connect("resource_inventory_update", _on_resource_inventory_update) == OK,\
		"PlayerHero connect to Server::resource_inventory_update")
		
	_icons = preload("res://ui/inventory/resource_inventory_icons.png")
	
	_add_icon_atlas_texture(Enums.InventoryItemType.RedBerry, 0, 0)
	_add_icon_atlas_texture(Enums.InventoryItemType.WoodLog, 0, 1)
	
	$TextureRect.visible = false

func _on_resource_inventory_update(new_state: Enums.InventoryItemType):
#	print("resource_inventory_update:", new_state)
	if new_state == Enums.InventoryItemType.Empty:
		$TextureRect.visible = false
		return
	
	if _icon_atlas.has(new_state):
		$TextureRect.visible = true
		$TextureRect.texture = _icon_atlas[new_state]
	else:
		print("No texture icon for resource inventory item: ", new_state)

func _process(delta):
	_elapsed_since_resource_update += delta
	if _elapsed_since_resource_update >= ResourceUpdateFailsafePeriod:
		_elapsed_since_resource_update = 0.0
		Server.request_resource_inventory_update()
