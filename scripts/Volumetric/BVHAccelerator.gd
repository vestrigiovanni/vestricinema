extends RefCounted
class_name BVHAccelerator
## BVHAccelerator (Fase 8)
##
## Bounding Volume Hierarchy semplificata, interamente in GDScript, per query
## raggio-geometria in O(log n). NON gira sulla GPU: serve al picking della
## Fase 10 (trascinamento oggetti) e potra' accelerare il raymarcher CPU-side.
##
## L'albero e' binario: ogni nodo interno ha un AABB che racchiude i figli; ogni
## foglia referenzia un singolo oggetto. La suddivisione e' una SAH semplificata:
## si ordina sugli AABB lungo l'asse di estensione maggiore e si taglia a meta'.

## Nodo dell'albero. Interno: left/right validi. Foglia: object_index >= 0.
class BVHNode:
	var bounds: AABB
	var left: BVHNode = null
	var right: BVHNode = null
	var object_index: int = -1

	func is_leaf() -> bool:
		return object_index >= 0


var _root: BVHNode = null
# Copia degli oggetti indicizzati, con il loro AABB precalcolato.
var _objects: Array = []


## Costruisce la BVH sugli AABB degli oggetti del bagaglio.
## Ogni oggetto deve esporre il proprio AABB tramite una di queste forme:
##   - chiave "aabb": AABB gia' pronto;
##   - chiavi "center" (Vector3) + "size" (Vector3)  -> box;
##   - chiavi "center" (Vector3) + "radius" (float)  -> sfera.
func build(objects: Array) -> void:
	_objects.clear()
	_root = null
	if objects.is_empty():
		return

	var indices: Array[int] = []
	for i in objects.size():
		var obj: Dictionary = objects[i]
		_objects.append({
			"data": obj,
			"aabb": _aabb_of(obj),
		})
		indices.append(i)

	_root = _build_recursive(indices)


## Traversa la BVH e restituisce la prima intersezione lungo il raggio.
## Ritorna { "index": int, "t": float, "object": Dictionary } oppure {} se nessuna.
func query_ray(origin: Vector3, direction: Vector3) -> Dictionary:
	if _root == null:
		return {}
	var dir := direction.normalized()
	var best := { "t": INF, "index": -1 }
	_query_recursive(_root, origin, dir, best)
	if best.index < 0:
		return {}
	return {
		"index": best.index,
		"t": best.t,
		"object": _objects[best.index].data,
	}


# --- Costruzione ------------------------------------------------------------

func _build_recursive(indices: Array) -> BVHNode:
	var node := BVHNode.new()
	node.bounds = _bounds_of(indices)

	if indices.size() == 1:
		node.object_index = indices[0]
		return node

	# Asse con estensione maggiore (euristica SAH semplificata: split mediano).
	var size := node.bounds.size
	var axis := 0
	if size.y > size.x and size.y >= size.z:
		axis = 1
	elif size.z > size.x and size.z > size.y:
		axis = 2

	indices.sort_custom(func(a, b):
		return _objects[a].aabb.get_center()[axis] < _objects[b].aabb.get_center()[axis]
	)

	var mid := indices.size() / 2
	var left_indices := indices.slice(0, mid)
	var right_indices := indices.slice(mid)

	node.left = _build_recursive(left_indices)
	node.right = _build_recursive(right_indices)
	return node


func _bounds_of(indices: Array) -> AABB:
	var result: AABB = _objects[indices[0]].aabb
	for i in range(1, indices.size()):
		result = result.merge(_objects[indices[i]].aabb)
	return result


func _aabb_of(obj: Dictionary) -> AABB:
	if obj.has("aabb"):
		return obj["aabb"]
	var center: Vector3 = obj.get("center", Vector3.ZERO)
	if obj.has("radius"):
		var r: float = obj["radius"]
		return AABB(center - Vector3(r, r, r), Vector3(r, r, r) * 2.0)
	var half: Vector3 = obj.get("size", Vector3.ONE) * 0.5
	return AABB(center - half, half * 2.0)


# --- Query ------------------------------------------------------------------

func _query_recursive(node: BVHNode, origin: Vector3, dir: Vector3, best: Dictionary) -> void:
	var t_box := _ray_aabb(origin, dir, node.bounds)
	# Niente intersezione col box, o il box e' piu' lontano del miglior hit attuale.
	if t_box < 0.0 or t_box > best.t:
		return

	if node.is_leaf():
		# La foglia coincide col proprio AABB: ne usiamo l'ingresso come t.
		if t_box < best.t:
			best.t = t_box
			best.index = node.object_index
		return

	_query_recursive(node.left, origin, dir, best)
	_query_recursive(node.right, origin, dir, best)


## Intersezione raggio-AABB (slab method). Ritorna t d'ingresso (>=0) o -1.
func _ray_aabb(origin: Vector3, dir: Vector3, box: AABB) -> float:
	var box_min := box.position
	var box_max := box.position + box.size
	var t_min := 0.0
	var t_max := INF

	for axis in 3:
		if absf(dir[axis]) < 1e-8:
			# Raggio parallelo all'asse: deve gia' essere dentro lo slab.
			if origin[axis] < box_min[axis] or origin[axis] > box_max[axis]:
				return -1.0
		else:
			var inv := 1.0 / dir[axis]
			var t1 := (box_min[axis] - origin[axis]) * inv
			var t2 := (box_max[axis] - origin[axis]) * inv
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
			t_min = maxf(t_min, t1)
			t_max = minf(t_max, t2)
			if t_min > t_max:
				return -1.0

	return t_min
