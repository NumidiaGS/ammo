# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, March 2022

extends Object

const SUMMARY_UID: int = 0
const SUMMARY_NAME: int = 1

# Deserializes the hero summary
# Returns an array containing, in order: { uid, hero_name }
static func deserialize_hero_summary(serialized_hero_summary: String) -> Array:
#	print("deserialize(%s)" % [serialized_hero_summary])
	var args = serialized_hero_summary.split(':', false)
	
	var uid = args[0].to_int()
	var hero_name = args[1]
	
	return [uid, hero_name]
