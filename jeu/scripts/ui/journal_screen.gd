class_name JournalScreen
extends Screen
## Journal : objectif principal et quêtes secondaires.


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("e8e0c8")
	bg.size = size
	add_child(bg)
	Kit.label(self, "JOURNAL", Vector2(14, 6), 20, Color("806040"), false)
	Kit.label(self, "Badges : %d / 8" % Game.badge_count(), Vector2(330, 10), 16, Color("806040"), false)
	var main := Kit.panel(self, Rect2(8, 38, 464, 92), Color("fff8e8"), Color("c09048"))
	Kit.label(main, "★ HISTOIRE", Vector2(10, 2), 15, Color("c06020"))
	var stage: int = int(Game.quests.get("main", 0))
	var stages: Array = Game.quest_defs["main"]["stages"]
	var t := Kit.label(main, "", Vector2(10, 24), 15)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size = Vector2(440, 60)
	t.text = stages[clampi(stage, 0, stages.size() - 1)]
	var side := Kit.panel(self, Rect2(8, 136, 464, 176), Color("fff8e8"), Color("c09048"))
	Kit.label(side, "QUÊTES SECONDAIRES", Vector2(10, 2), 15, Color("3070a0"))
	var y := 26
	var any := false
	for q in Game.quest_defs:
		if q == "main" or not Game.quests.has(q):
			continue
		var st: int = int(Game.quests[q])
		var qd: Dictionary = Game.quest_defs[q]
		var done: bool = st >= qd["stages"].size() - 1
		Kit.label(side, ("✓ " if done else "• ") + qd["title"], Vector2(10, y), 14, Color("40a040") if done else Kit.INK)
		var d := Kit.label(side, "", Vector2(30, y + 18), 12, Color("605040"))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size = Vector2(420, 20)
		d.text = qd["stages"][clampi(st, 0, qd["stages"].size() - 1)]
		y += 40
		any = true
	if not any:
		Kit.label(side, "Parle aux habitants pour découvrir des quêtes !", Vector2(10, 30), 14, Color("807060"))


func _process(_d: float) -> void:
	if act("a") or act("b"):
		finish()
