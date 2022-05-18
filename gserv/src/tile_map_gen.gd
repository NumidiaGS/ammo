extends Object

class_name TileMapGenerator

const Extents: int = 50
const Height: int = 20
	
static func generate() -> Array[int]:
	var _map : Array[int] = Array()
	_map.resize(Extents * Extents * Height)
	_map.fill(0)
	
	var tiles = [[1], [5], [6]]
	
	var rng_range: int = Extents * floor(sqrt(Extents))
	for r in range(0, rng_range):
		var ri = randi() % (100 * 100)
		
		if _map[ri] == 0:
			_map[ri] = randi() % 3
	for r in range(0, Extents):
		for c in range(0, Extents):
			if _map[r * Extents + c] == 0:
				_map[r * Extents + c] = randi() % 3
			
#	for level in range(1, Height):
	return _map
