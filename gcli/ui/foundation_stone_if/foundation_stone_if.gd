# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, June 2022

extends ColorRect

class_name FoundationStoneIF

########################################
############## Operations ##############
########################################

func display(foundation_stone_uid: int):
	show()
	Server.request_foundation_stone_info(foundation_stone_uid)

func _on_close_button_pressed():
	hide()
