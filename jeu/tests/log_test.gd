extends Node

func _ready() -> void:
	seed(7)
	var p := Pokemon.create(6, 36)
	var p2 := Pokemon.create(25, 30)
	var e := Pokemon.create(9, 36)
	var e2 := Pokemon.create(65, 34)
	var b := Battle.new([p, p2], [e, e2], false, {"name": "Topdresseur Hugo", "money": 999, "potions": 1})
	_print(b.start())
	for t in 14:
		if b.over:
			break
		if b.need_switch:
			_print(b.player_switch(b.first_alive(0)))
			continue
		var s := b.usable_slots(0)
		_print(b.play_turn({"type": "move", "slot": s[t % s.size()]}))
	var w := Battle.new([Pokemon.create(1, 20)], [Pokemon.create(16, 4)], true)
	_print(w.start())
	_print(w.play_turn({"type": "ball", "item": "ultra-ball"}))
	get_tree().quit()

func _print(evs: Array) -> void:
	for e in evs:
		if e["t"] == "msg":
			print("  ", e["text"])
		elif e["t"] in ["hp", "faint", "send", "exp", "level", "learn", "ball", "end"]:
			var d: Dictionary = e.duplicate()
			d.erase("mon")
			print("    [", d, "]")
