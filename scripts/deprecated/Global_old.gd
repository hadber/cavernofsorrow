extends Node

var gSteamID:int
var gSteamUsername:String

var in_dialogue:bool = false
var steamLobbyID:int = 0
var version = 'ver 0.1.7a'
var isPlayerHost:bool = true

#const lobby_room = preload("res://Scenes/RoomTypes/LobbyRoom.tscn")

func _ready():
	var SteamInit = Steam.steamInit()
	print("Steam init: " + str(SteamInit))
		
	gSteamID = Steam.getSteamID()
	gSteamUsername = Steam.getFriendPersonaName(gSteamID)
	
	if SteamInit['status'] != 1:
		print("Failed to initialize Steam. Reason: " + str(SteamInit['verbal']))
	else:
		if Steam.isSubscribed() == false: #game is not owned
			print("Player might have the game pirated, do something funny here")
			# give him a clown mask :D
	
	Steam.join_requested.connect(_on_lobby_join_requested)

func _process(_delta):
	Steam.run_callbacks()

func _on_lobby_join_requested(lobbyID:int, friendID:int):
	isPlayerHost = false
	# triggered if the player is already in game and accepts a steam invite
	# or clicks 'join game' in the friendlist to join a friend's game
	print("Joining %s's lobby" % Steam.getFriendPersonaName(friendID))
	#var _ret = get_tree().change_scene_to(lobby_room) # test scene
	# wait a tiny bit for the scene to load
	# doesnt seem to work without this for whatever reason
	await get_tree().create_timer(1.0)
	var mp_loader = get_tree().root.get_node("LobbyRoom/MultiplayerLoader")
	mp_loader.add_multiplayer_scene(false)
	var mp_node = get_tree().get_root().get_node("Multiplayer")
	mp_node._join_lobby(lobbyID)
	
	# generate the random spawn ?
