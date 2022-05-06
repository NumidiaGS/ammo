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
