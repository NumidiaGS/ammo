extends Node3D

class_name KingdomHolding

####################################################
# ALERT Keep updated with gcli/map/kingdom_holding.gd
####################################################

const EncodedByteSize: int = 4 + 1 + 4 * 4

var holding_uid: int

enum HoldingType {  NULL = 0,
					NodeGrouping = 1,
					Farm = 30, }
@export var holding_type: HoldingType

var area: Rect2i

# Assumes HoldingType values do not exceed 255 (1 byte allocation)
func encode_to_byte_array() -> PackedByteArray:
	var pba: PackedByteArray = PackedByteArray()
	pba.resize(4 + 1 + 4 * 4)
	
	var pba_offset: int = 0
	pba.encode_u32(pba_offset, holding_uid)
	pba_offset += 4
	
	pba.encode_u8(pba_offset, holding_type)
	pba_offset += 1
	
	pba.encode_s32(pba_offset, area.position.x)
	pba_offset += 4
	pba.encode_s32(pba_offset, area.position.y)
	pba_offset += 4
	pba.encode_s32(pba_offset, area.size.x)
	pba_offset += 4
	pba.encode_s32(pba_offset, area.size.y)
	pba_offset += 4
	
	return pba

static func decode_from_byte_array(pba: PackedByteArray, pba_offset: int) -> KingdomHolding:
	var kh: KingdomHolding = KingdomHolding.new()
	
	kh.holding_uid = pba.decode_u32(pba_offset)
	pba_offset += 4
	
	kh.holding_type = pba.decode_u8(pba_offset) as HoldingType
	pba_offset += 4
	
	var x: int = pba.decode_s32(pba_offset)
	pba_offset += 4
	var y: int = pba.decode_s32(pba_offset)
	pba_offset += 4
	var width: int = pba.decode_s32(pba_offset)
	pba_offset += 4
	var height: int = pba.decode_s32(pba_offset)
	pba_offset += 4
	kh.area = Rect2i(x, y, width, height)
	
	return 
####################################################
####################################################
