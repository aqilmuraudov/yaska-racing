class_name ItemSystem
extends Node3D
## Item boxes, item rolls, activation and pooled road traps.
##
## Rules (also covered by tests):
## - One inventory slot. A box gives an item only if the slot is empty.
## - Rolls are position-weighted (data/items/items.json) and take roll_time.
## - Turbo: KartBoost item boost (same stacking caps as every boost).
## - Shield: blocks exactly one damaging hit or expires after its duration.
## - Road trap: dropped behind the owner, armed after arm_time, ignores its
##   owner for owner_grace seconds, removed on contact or after lifetime.
##   A shielded kart consumes the trap without being hit.
## - Recently hit / respawned karts are immune (KartController timers).

signal item_used(kart: KartController, item: StringName)
signal trap_triggered(kart: KartController, landed: bool)

const TRAP_POOL := 16
const BOX_SPACING := 3.6

var track: TrackData
var config: Dictionary = {}
var rng := RandomNumberGenerator.new()
var enabled := true
var racers_provider: Callable # returns Array of {kart, place}
var _boxes: Array[Dictionary] = [] # {node, area, respawn, base}
var _traps: Array[Dictionary] = [] # {node, area, active, owner, age}
var _time := 0.0
var _box_mesh: Mesh
var _box_mat: StandardMaterial3D
var _trap_mesh_root: PackedScene


func setup(p_track: TrackData, items_enabled: bool, seed_value: int) -> void:
	track = p_track
	enabled = items_enabled
	rng.seed = seed_value
	config = load_config()
	_box_mat = StandardMaterial3D.new()
	_box_mat.albedo_color = Color(0.25, 0.85, 0.9, 0.55)
	_box_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box_mat.emission_enabled = true
	_box_mat.emission = Color(0.2, 0.75, 0.85)
	_box_mat.emission_energy_multiplier = 0.5
	_box_mat.roughness = 0.15
	_box_mat.rim_enabled = true
	_box_mat.rim = 1.0
	_box_mesh = ShapeKit.superellipsoid(Vector3(1.1, 1.1, 1.1), 0.3, 0.3)
	if enabled:
		_build_boxes()
	_build_trap_pool()


static func load_config() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json"))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# --- Pure rules -------------------------------------------------------------

static func bucket_for(place: int, count: int) -> String:
	if place <= 1:
		return "front"
	if place > count - maxi(1, count / 3):
		return "back"
	return "middle"


static func roll_item(table: Dictionary, r: float) -> StringName:
	var total := 0.0
	for k in table.keys():
		total += maxf(float(table[k]), 0.0)
	if total <= 0.0:
		return &"turbo"
	var x := r * total
	var acc := 0.0
	for k in table.keys():
		acc += maxf(float(table[k]), 0.0)
		if x < acc:
			return StringName(k)
	return StringName(table.keys()[table.size() - 1])


## Whether a trap may affect `kart` right now.
static func trap_can_hit(trap_owner: Object, trap_age: float, kart: Object, arm_time: float, owner_grace: float) -> bool:
	if trap_age < arm_time:
		return false
	if kart == trap_owner and trap_age < owner_grace:
		return false
	return true


# --- Boxes ------------------------------------------------------------------

func _build_boxes() -> void:
	for row in track.item_rows:
		var count: int = row.count
		var s: float = row.s
		var hw := track.main.half_width_at(s)
		var spacing := minf(BOX_SPACING, (hw * 2.0 - 2.0) / maxf(count - 1, 1))
		for k in count:
			var lat := (k - (count - 1) * 0.5) * spacing
			var pos := track.main.position_at(s) + track.main.right_at(s) * lat + Vector3.UP * 1.0
			_spawn_box(pos)


func _spawn_box(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = "ItemBox"
	root.position = pos
	add_child(root)
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh
	mi.material_override = _box_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var label := Label3D.new()
	label.text = "?"
	label.font = UITheme.heading_font()
	label.font_size = 96
	label.pixel_size = 0.008
	label.outline_size = 18
	label.modulate = Color("ffc93c")
	label.outline_modulate = Color("1b2a4a")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	root.add_child(label)
	var area := Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 2
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.1
	cs.shape = sh
	area.add_child(cs)
	root.add_child(area)
	var entry := {"node": root, "area": area, "respawn": 0.0, "base": pos, "mesh": mi}
	area.body_entered.connect(_on_box_body.bind(entry))
	_boxes.append(entry)


func _on_box_body(body: Node, entry: Dictionary) -> void:
	if not (body is KartController) or entry.respawn > 0.0:
		return
	var kart: KartController = body
	if kart.state == KartController.State.RECOVER:
		return
	entry.respawn = float(config.get("box_respawn", 2.5))
	entry.node.visible = false
	if kart.item == &"" and enabled:
		var place := 1
		var count := 1
		if racers_provider.is_valid():
			var info: Dictionary = racers_provider.call(kart)
			place = info.place
			count = info.count
		var table: Dictionary = config.probabilities[bucket_for(place, count)]
		var it := roll_item(table, rng.randf())
		kart.give_item(it, float(config.get("roll_time", 1.0)))
	if kart.is_player:
		AudioManager.play("pickup", -2.0)


# --- Use ----------------------------------------------------------------------

func use_item(kart: KartController) -> void:
	if not kart.can_use_item():
		return
	var it := kart.take_item()
	match it:
		&"turbo":
			kart.apply_item_boost()
		&"shield":
			kart.give_shield(float(config.items.shield.get("duration", 8.0)))
			_sfx("shield_up", kart)
		&"trap":
			_drop_trap(kart)
	item_used.emit(kart, it)


func _sfx(clip: String, kart: KartController) -> void:
	if kart.is_player:
		AudioManager.play(clip, -1.0)
	else:
		AudioManager.play_at(clip, kart.global_position, -3.0)


# --- Traps (pooled) -------------------------------------------------------------

func _build_trap_pool() -> void:
	var body_mat := ShapeKit.mat(Color("e0344b"), 0.4, 0.2)
	var spike_mat := ShapeKit.mat(Color("ffc93c"), 0.35, 0.5)
	var band_mat := ShapeKit.mat(Color("2a2d36"), 0.6)
	for i in TRAP_POOL:
		var root := Node3D.new()
		root.name = "Trap%d" % i
		root.visible = false
		add_child(root)
		ShapeKit.add_mesh(root, ShapeKit.superellipsoid(Vector3(1.0, 0.32, 1.0), 0.5, 1.0), body_mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.16, 0)))
		ShapeKit.add_mesh(root, ShapeKit.superellipsoid(Vector3(1.06, 0.08, 1.06), 0.3, 1.0), band_mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)))
		for k in 6:
			var a := TAU * k / 6.0
			var p := Vector3(cos(a) * 0.38, 0.34, sin(a) * 0.38)
			ShapeKit.add_mesh(root, ShapeKit.cone(0.09, 0.0, 0.24, 6), spike_mat, Transform3D(Basis.IDENTITY, p))
		ShapeKit.add_mesh(root, ShapeKit.cone(0.12, 0.0, 0.32, 8), spike_mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.46, 0)))
		var area := Area3D.new()
		area.collision_layer = 4
		area.collision_mask = 2
		area.monitorable = false
		area.monitoring = false
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = float(config.items.trap.get("radius", 0.95)) if config.has("items") else 0.95
		cs.shape = sh
		cs.position = Vector3(0, 0.4, 0)
		area.add_child(cs)
		root.add_child(area)
		var entry := {"node": root, "area": area, "active": false, "owner": null, "age": 0.0}
		area.body_entered.connect(_on_trap_body.bind(entry))
		_traps.append(entry)


func _drop_trap(kart: KartController) -> void:
	var entry: Dictionary = {}
	var oldest_age := -1.0
	for t in _traps:
		if not t.active:
			entry = t
			break
		if t.age > oldest_age:
			oldest_age = t.age
			entry = t
	_deactivate_trap(entry)
	var pos := kart.global_position - kart.forward_dir() * 2.4
	# Snap to the ground below.
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 2.0, pos + Vector3.DOWN * 6.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		pos = hit.position
	entry.node.global_position = pos
	entry.node.rotation.y = randf() * TAU
	entry.node.visible = true
	entry.node.scale = Vector3.ONE * 0.3
	entry.active = true
	entry.owner = kart
	entry.age = 0.0
	entry.area.set_deferred("monitoring", true)
	_sfx("trap_drop", kart)


func _on_trap_body(body: Node, entry: Dictionary) -> void:
	if not entry.active or not (body is KartController):
		return
	var kart: KartController = body
	var tcfg: Dictionary = config.items.trap
	if not trap_can_hit(entry.owner, entry.age, kart, float(tcfg.arm_time), float(tcfg.owner_grace)):
		return
	if kart.is_invulnerable() and not kart.has_shield():
		return # pass through while protected; trap stays
	var landed := kart.apply_hit(&"trap")
	trap_triggered.emit(kart, landed)
	AudioManager.play_at("trap_hit", entry.node.global_position, 0.0, 1.0, 2)
	_deactivate_trap(entry)


func _deactivate_trap(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	entry.active = false
	entry.owner = null
	entry.node.visible = false
	entry.area.set_deferred("monitoring", false)


func hazards_near(pos: Vector3, radius: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var r2 := radius * radius
	for t in _traps:
		if t.active and t.node.global_position.distance_squared_to(pos) < r2:
			out.append(t.node.global_position)
	return out


func threat_near(kart: KartController) -> bool:
	var fwd := kart.forward_dir()
	for t in _traps:
		if not t.active:
			continue
		var rel: Vector3 = t.node.global_position - kart.global_position
		var ahead := rel.dot(fwd)
		if ahead > 2.0 and ahead < 15.0 and absf(rel.dot(kart.right_dir())) < 2.0:
			return true
	return false


func active_trap_count() -> int:
	var n := 0
	for t in _traps:
		if t.active:
			n += 1
	return n


func reset() -> void:
	for t in _traps:
		_deactivate_trap(t)
	for b in _boxes:
		b.respawn = 0.0
		b.node.visible = true
		b.node.scale = Vector3.ONE
	_time = 0.0


func _physics_process(delta: float) -> void:
	var _pt := Time.get_ticks_usec()
	_phys_tick(delta)
	Prof.add(&"items", _pt)


func _phys_tick(delta: float) -> void:
	_time += delta
	var lifetime: float = float(config.items.trap.get("lifetime", 20.0)) if config.has("items") else 20.0
	for t in _traps:
		if not t.active:
			continue
		t.age += delta
		var sc := minf(1.0, 0.3 + t.age * 4.0)
		t.node.scale = Vector3.ONE * sc
		if t.age >= lifetime:
			_deactivate_trap(t)
	for b in _boxes:
		var n: Node3D = b.node
		if b.respawn > 0.0:
			b.respawn -= delta
			if b.respawn <= 0.0:
				n.visible = true
				n.scale = Vector3.ONE * 0.2
		else:
			n.scale = n.scale.lerp(Vector3.ONE, 1.0 - exp(-8.0 * delta))
		b.mesh.rotation = Vector3(_time * 0.7, _time * 1.3, 0.0)
		n.position.y = b.base.y + sin(_time * 2.0 + b.base.x) * 0.12
