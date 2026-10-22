extends TestCase
## Item ownership, shields, immunity and position-weighted rolls.

func _kart() -> KartController:
	var k := KartController.new()
	k.stats = KartFactory.load_stats("balanced")
	tree.root.add_child(k)
	k.controls_locked = false
	return k


func test_position_buckets() -> void:
	check_eq(ItemSystem.bucket_for(1, 6), "front", "leader is front")
	check_eq(ItemSystem.bucket_for(6, 6), "back", "last is back")
	check_eq(ItemSystem.bucket_for(5, 6), "back", "last third is back")
	check_eq(ItemSystem.bucket_for(3, 6), "middle", "mid-pack is middle")


func test_roll_distribution_follows_table() -> void:
	var cfg := ItemSystem.load_config()
	var table: Dictionary = cfg.probabilities.back
	var counts := {}
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for i in 4000:
		var it := ItemSystem.roll_item(table, r.randf())
		counts[it] = counts.get(it, 0) + 1
	var total := 0.0
	for k in table.keys():
		total += float(table[k])
	for k in table.keys():
		var expected: float = float(table[k]) / total
		var got: float = float(counts.get(StringName(k), 0)) / 4000.0
		check_near(got, expected, 0.04, "roll share for %s" % k)


func test_trap_ownership_and_arming() -> void:
	var owner := Object.new()
	var other := Object.new()
	check(not ItemSystem.trap_can_hit(owner, 0.1, other, 0.35, 1.0), "unarmed trap is harmless")
	check(not ItemSystem.trap_can_hit(owner, 0.6, owner, 0.35, 1.0), "owner protected during grace")
	check(ItemSystem.trap_can_hit(owner, 0.6, other, 0.35, 1.0), "armed trap hits other racers")
	check(ItemSystem.trap_can_hit(owner, 1.5, owner, 0.35, 1.0), "owner can hit own trap after grace")
	owner.free()
	other.free()


func test_shield_blocks_exactly_one_hit() -> void:
	var k := _kart()
	k.give_shield(8.0)
	check(not k.apply_hit(&"trap"), "shield blocks first hit")
	check(not k.has_shield(), "shield consumed")
	for i in 40:
		await tree.physics_frame
	check(k.apply_hit(&"trap"), "second hit lands once brief immunity ends")
	k.queue_free()


func test_hit_immunity_prevents_stun_chain() -> void:
	var k := _kart()
	check(k.apply_hit(&"trap"), "first hit lands")
	check(not k.apply_hit(&"trap"), "no re-hit while stunned")
	# Wait until the stun ends; immunity then protects briefly.
	for i in int((KartController.HIT_DURATION + 0.1) * 60):
		await tree.physics_frame
	check(k.is_invulnerable(), "post-hit immunity active")
	check(not k.apply_hit(&"trap"), "immune racer is not chained")
	for i in int((KartController.HIT_IMMUNITY + 0.1) * 60):
		await tree.physics_frame
	check(k.apply_hit(&"trap"), "hit lands again after immunity")
	k.queue_free()


func test_single_inventory_slot() -> void:
	var td := circle_track()
	var items := ItemSystem.new()
	tree.root.add_child(items)
	items.setup(td, true, 5)
	var k := _kart()
	var entry := {"node": Node3D.new(), "respawn": 0.0}
	items.add_child(entry.node)
	items._on_box_body(k, entry)
	check(k.item != &"", "empty slot receives an item")
	var first := k.item
	entry.respawn = 0.0
	items._on_box_body(k, entry)
	check_eq(k.item, first, "held item is not replaced")
	# Item can only be used after the roll animation.
	check(not k.can_use_item(), "cannot use while rolling")
	for i in 70:
		await tree.physics_frame
	check(k.can_use_item(), "usable after roll")
	items.use_item(k)
	check_eq(k.item, &"", "slot empty after use")
	k.queue_free()
	items.queue_free()


func test_items_disabled_in_time_trial() -> void:
	var td := circle_track()
	var items := ItemSystem.new()
	tree.root.add_child(items)
	td.item_rows.append({"s": 10.0, "count": 4})
	items.setup(td, false, 1)
	check_eq(items._boxes.size(), 0, "no item boxes when items are disabled")
	items.queue_free()
