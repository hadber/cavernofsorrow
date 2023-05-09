extends Node2D

const PlayerScene = preload("res://scenes/Player.tscn")
var Player1
var spawn_side:Vector2 = Vector2(450, 260)
var last_world_state = 0
var PlayerState:Dictionary = {}
var remotePlayers:Array = []
@onready var world_root: Node2D

func _ready():
	pass

func add_local_player():
	Player1 = PlayerScene.instantiate()
	Player1.set_color(get_random_color())
	Player1.spawn_me(Vector2(215, 460))
	world_root.get_node("TileMap").add_sibling(Player1)
#	Player1.get_node("CenterContainer/Name").text = Steam.getFriendPersonaName(Global.gSteamID)

func get_random_color():
	const COOL_COLORS: Array = [Color.AQUAMARINE, Color.BURLYWOOD, Color.CHOCOLATE, Color.DARK_OLIVE_GREEN,
			Color.DARK_SLATE_BLUE, Color.GOLDENROD, Color.INDIAN_RED, Color.LIGHT_GREEN, Color.MEDIUM_PURPLE,
			Color.ORANGE, Color.ROYAL_BLUE, Color.PLUM, Color.YELLOW_GREEN, Color.WHITE_SMOKE]
	randomize()
	return COOL_COLORS[randi() % COOL_COLORS.size()]

func add_remote_player(pSteamID:String, pPos:Vector2, my_color: Color = Color.AZURE):
	var remotePlayer = PlayerScene.instantiate()
	if not remotePlayers.has(pSteamID):
		remotePlayer.networked = true
		#remotePlayer.get_node("CenterContainer/Name").text = Steam.getFriendPersonaName(int(pSteamID))
		remotePlayer.name = pSteamID
		remotePlayer.spawn_me(pPos)
		remotePlayer.modulate = my_color #get_random_color()
		world_root.get_node("OtherPlayers").add_child(remotePlayer)
		remotePlayers.append(remotePlayer)

func remove_remote_player(pSteamID:String):
	for player in remotePlayers:
		if player.name == pSteamID:
			remotePlayers.erase(player)
			if world_root.get_node("OtherPlayers").has_node(pSteamID):
				world_root.get_node("OtherPlayers").get_node(pSteamID).queue_free()

func add_player_state(pState:Dictionary):
	PlayerState = pState
