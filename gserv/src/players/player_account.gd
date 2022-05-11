# Copyright (C) Numidia Game Studios, Inc - All Rights Reserved
# Unauthorized copying of this file, via any medium is strictly prohibited
# Proprietary souce code for the Augustine MMO project.
# Created by Adam Rasburn <AdamRasburn@proton.me>, January 2022

extends RefCounted

class_name PlayerAccount

var peer_id: int = 0
var username: String = "null"
var password: String = "null"
var auth_token: String = "null"
var hero: HeroData
