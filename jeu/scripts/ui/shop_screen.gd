class_name ShopScreen
extends ItemList2
## Boutique : acheter des objets.

var stock: Array = []
var _money: Label
var _desc: Label
var _icon: TextureRect
var _busy := false


func _ready() -> void:
	size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("88b0e0")
	bg.size = Vector2(480, 320)
	add_child(bg)
	var mp := Kit.panel(self, Rect2(6, 6, 160, 40))
	_money = Kit.label(mp, "", Vector2(10, 4))
	_icon = TextureRect.new()
	_icon.position = Vector2(50, 90)
	_icon.size = Vector2(64, 64)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_icon)
	var dp := Kit.panel(self, Rect2(6, 240, 468, 76))
	_desc = Kit.label(dp, "", Vector2(10, 6), 14)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.size = Vector2(448, 64)
	_update_money()
	build_list(Rect2(176, 6, 298, 228))


func _update_money() -> void:
	_money.text = "%d ₽" % Game.money


func price(id: String) -> int:
	var p: int = Data.items[id]["price"]
	return p if p > 0 else 1000


func row_count() -> int:
	return stock.size() + 1


func row_text(i: int) -> String:
	return "QUITTER" if i >= stock.size() else Data.item_name(stock[i])


func row_right(i: int) -> String:
	return "" if i >= stock.size() else "%d ₽" % price(stock[i])


func on_change(i: int) -> void:
	if i >= stock.size():
		_desc.text = "Quitter la boutique."
		_icon.texture = null
		return
	var id: String = stock[i]
	var own := Game.item_count(id)
	_desc.text = Data.items[id]["desc"] + ("\nEn stock dans le sac : %d" % own if own > 0 else "")
	var icon_name := id
	if ItemUse.is_tm(id):
		icon_name = "tm-" + Data.moves[Data.items[id]["move"]]["type"]
	Sprites.apply(_icon, "item", icon_name)


func _process(delta: float) -> void:
	if _busy:
		return
	super._process(delta)


func on_select(i: int) -> void:
	if i >= stock.size():
		finish(null)
		return
	var id: String = stock[i]
	var p := price(id)
	if ItemUse.is_tm(id) and Game.item_count(id) > 0:
		_busy = true
		await Game.ui.say("Vous avez déjà cette CT. Elle est réutilisable !")
		_busy = false
		return
	var max_n := mini(99, Game.money / p)
	if max_n <= 0:
		_busy = true
		await Game.ui.say("Vous n'avez pas assez d'argent.")
		_busy = false
		return
	var opts := []
	for n in [1, 5, 10, 20, 50, 99]:
		if n <= max_n and (n == 1 or not ItemUse.is_tm(id)):
			opts.append("x%d — %d ₽" % [n, n * p])
	_busy = true
	var c: int = await Game.ui.ask("%s ? Combien ?" % Data.item_name(id), opts)
	if c >= 0:
		var n: int = int(opts[c].split(" ")[0].substr(1))
		Game.money -= n * p
		Game.add_item(id, n)
		if id == "poke-ball" and n >= 10:
			Game.add_item("premier-ball")
			await Game.ui.say(["Et voilà ! Merci !", "En bonus, voici une Honor Ball !"])
		else:
			await Game.ui.say("Et voilà ! Merci !")
		_update_money()
		refresh_list()
	_busy = false
