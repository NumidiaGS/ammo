# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, June 2022

extends ColorRect

class_name StockpileInterface

########################################
############## Operations ##############
########################################

func display(stockpile_uid: int):
	visible = true
#	Server.request_stockpile_pricelist(stockpile_uid)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_close_button_pressed():
	hide()
