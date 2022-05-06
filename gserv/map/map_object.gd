extends Node3D

# words
class_name MapObject
# after


####################################################
# ALERT Keep updated with gcli/map/map_object.gd
#  AND consistent with below exported enums
####################################################
var object_uid: int

# ? Values are permitted for 2 bytes (u16) so between 0 to 65,535
enum ObjectType {   NULL = 0,
					ServerOnly = 10,
					KingdomHolding = 20,
					StaticSolid = 30,
					StaticInteractable = 35,
					LightPickup = 50,
					Relic = 55, }
@export var object_type: ObjectType

# ? Values are permitted for 2 bytes (u16) so between 0 to 65,535
enum InteractionBehaviour { NULL = 0,
							NotApplicable = 1,
							LumberTree = 5,
							FlaxBush = 10,
							BerryBush = 11,
							FarmDirtPatch = 15,
							BulletinBoard = 20,
							Stick = 30,
							StoneShard = 31,
							Flint = 32, }
@export var interaction_behaviour: InteractionBehaviour

# ? Values are permitted for 2 bytes (u16) so between 0 to 65,535
enum ResourceIdentity { NULL = 0,
						NotApplicable = 1,
						GreenGrid = 5,
						GreyGrid = 6,
						TealGrid = 7,
						LumberTree = 20,
						FlaxBush = 25,
						BerryBush = 26,
						WaterCell = 30,
						FarmDirtPatch = 40,
						BulletinBoard = 50,
						SmallGeneric = 60, }
@export var resource_id: ResourceIdentity
####################################################
####################################################
