extends Node2D

@onready var button_host = $UI/Side/MarginContainer/VBoxContainer/HostCont/ButtonHost
@onready var refresh_button = $UI/Side/MarginContainer/VBoxContainer/RoomsButtonsCont/HBoxContainer/ButtonRefresh
@onready var button_join = $UI/Side/MarginContainer/VBoxContainer/RoomsButtonsCont/HBoxContainer/ButtonJoin 
@onready var lobby_status = $UI/Side/MarginContainer/VBoxContainer/LobbyCont 
@onready var join_lobby_id = $UI/Side/MarginContainer/VBoxContainer/JoinLobbyID

const LOBBY_ID_HEX_PREFIX = "1860000"

# Called when the node enters the scene tree for the first time.
func _ready():
	button_host.pressed.connect(_create_lobby)
	button_join.pressed.connect(_join_lobby)
	lobby_status.visible = false

	_setup_steam()
	Steam.lobby_created.connect(_on_lobby_created)

func _setup_steam():
	Steam.steamInit()

	var isRunning: bool = Steam.isSteamRunning()
	if (!isRunning):
		print("Steam is not running. No point in playing this game without Steam. Exiting...")
		return
	
	print("Steam is running.")
	var my_steam_id = Steam.getSteamID()
	var my_steam_name = Steam.getFriendPersonaName(my_steam_id)
	print("Your Steam name is: " + str(my_steam_name))
	
	$UI/Side/MarginContainer/VBoxContainer/SteamUsername.text = "Username: " + my_steam_name
	$UI/Side/MarginContainer/VBoxContainer/SteamID.text = "SteamID: " + str(my_steam_id)
	
func _create_lobby():
	print("Attempting to create a lobby...")
	button_host.disabled = true
	Steam.createLobby(Steam.LOBBY_TYPE_INVISIBLE, 2)

func _join_lobby():
	var lobby_id: String = LOBBY_ID_HEX_PREFIX + join_lobby_id.text

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	Steam.run_callbacks()

func _on_lobby_created(_connection_result: int, lobby_id: int):
	print("Lobby created!")
	Steam.setLobbyData(lobby_id, "type", "cavern_lobby")
	var lobby_id_hex: String = ("%X" % lobby_id).substr(LOBBY_ID_HEX_PREFIX.length())
	lobby_status.get_child(1).text = lobby_id_hex
	lobby_status.visible = true
	

func _on_lobby_joined():
	# when we create a lobby, we automatically join it, so this doesn't seem to be triggered anymore
	print("Joined lobby!")
