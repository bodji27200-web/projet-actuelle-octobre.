extends Node
## Point d'entrée : écran titre, introduction du Prof. Chen, puis le monde.

var world: Node2D


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	world = Node2D.new()
	world.set_script(load("res://scripts/world/overworld.gd"))
	add_child(world)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var ui := Control.new()
	ui.set_script(load("res://scripts/ui/ui_root.gd"))
	layer.add_child(ui)
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var mm := Control.new()
	mm.set_script(load("res://scripts/ui/minimap.gd"))
	hud.add_child(mm)
	Net.message.connect(func(t): Game.ui.toast(t))
	await get_tree().process_frame
	Audio.play_music("title")
	var choice: String = await Game.ui.open(TitleScreen.new())
	if choice == "continue" and Game.load_game():
		world.load_map(Game.map_id, Game.pos, Game.facing)
		await Game.ui.say("Bon retour, %s !" % Game.player_name)
		return
	Game.new_game()
	await _intro()
	world.load_map("maison", Vector2i(4, 3), "down")
	await Game.ui.fade(false, 0.4)


func _intro() -> void:
	var holder := Control.new()
	holder.size = Vector2(480, 320)
	var bg := ColorRect.new()
	bg.color = Color("101820")
	bg.size = Vector2(480, 320)
	holder.add_child(bg)
	var chen := TextureRect.new()
	chen.texture = PixelArt.character("chen", "down", 0)
	chen.position = Vector2(200, 50)
	chen.size = Vector2(80, 80)
	chen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(chen)
	var pika := TextureRect.new()
	pika.position = Vector2(300, 90)
	pika.size = Vector2(110, 110)
	pika.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pika.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pika.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pika.visible = false
	Sprites.apply(pika, "front", 25)
	holder.add_child(pika)
	Game.ui.add_child(holder)
	Game.ui.move_child(holder, 0)
	await Game.ui.say(["Bonjour ! Bienvenue dans le monde des Pokémon !", "Je m'appelle Chen. Mais tout le monde m'appelle le Professeur Pokémon !"])
	pika.visible = true
	await Game.ui.say(["Ce monde est peuplé de créatures appelées Pokémon.",
		"Certains vivent avec les humains, d'autres se battent à leurs côtés.",
		"Moi, j'étudie les Pokémon. C'est ma profession."])
	pika.visible = false
	var g: int = await Game.ui.ask("Mais d'abord, dis-moi... Es-tu un garçon ou une fille ?", ["GARÇON", "FILLE"], false)
	Game.gender = maxi(0, g)
	chen.texture = PixelArt.character(Game.look(), "down", 0)
	await Game.ui.say("Et comment t'appelles-tu ?")
	Game.player_name = await Game.ui.enter_name("Ton nom :", "Sacha" if Game.gender == 0 else "Ondine", 10)
	await Game.ui.say("Très bien, %s !" % Game.player_name)
	chen.texture = PixelArt.character("rival", "down", 0)
	await Game.ui.say(["Et voici mon petit-fils, Régis. Vous êtes rivaux depuis que vous êtes tout petits !",
		"%s ! Ta propre aventure Pokémon va commencer !" % Game.player_name,
		"Un monde de rêves et d'aventures t'attend ! Allons-y !"])
	await Game.ui.fade(true, 0.5)
	holder.queue_free()
