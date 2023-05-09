extends Node2D

const PlayerScene = preload("res://scenes/Player.tscn")
var Player1
var spawn_side:Vector2 = Vector2(450, 260)
var last_world_state = 0
var PlayerState:Dictionary = {}
var remotePlayers:Array = []
var currentRoom

func _ready():
	pass
	#Player1 = PlayerScene.instantiate()
#	Player1.get_node("CenterContainer/Name").text = Steam.getFriendPersonaName(Global.gSteamID)

func add_remote_player(pSteamID:String, pPos:Vector2):
	var remotePlayer = PlayerScene.instantiate()
	if not remotePlayers.has(pSteamID):
		remotePlayer.networked = true
		#remotePlayer.get_node("CenterContainer/Name").text = Steam.getFriendPersonaName(int(pSteamID))
		remotePlayer.name = pSteamID
		remotePlayer.spawn_me(pPos)
		currentRoom.get_node("OtherPlayers").add_child(remotePlayer)
		remotePlayers.append(remotePlayer)

func remove_remote_player(pSteamID:String):
	for player in remotePlayers:
		if player.name == pSteamID:
			remotePlayers.erase(player)
			if currentRoom.get_node("OtherPlayers").has_node(pSteamID):
				currentRoom.get_node("OtherPlayers").get_node(pSteamID).queue_free()

func add_player_state(pState:Dictionary):
	PlayerState = pState
