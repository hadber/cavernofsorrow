extends Node2D

#enum PacketTarget {HOST, ALL}

enum Packet {HANDSHAKE, SPAWN_PLAYER, WORLDSTATE, PLAYERSTATE, GET_SERVERTIME,
				SET_SERVERTIME, LATENCY_REQUEST, UPDATE_LATENCY}

@onready var button_host = $UI/Side/MarginContainer/VBoxContainer/HostCont/ButtonHost
@onready var refresh_button = $UI/Side/MarginContainer/VBoxContainer/RoomsButtonsCont/HBoxContainer/ButtonRefresh
@onready var button_join = $UI/Side/MarginContainer/VBoxContainer/RoomsButtonsCont/HBoxContainer/ButtonJoin 
@onready var lobby_status = $UI/Side/MarginContainer/VBoxContainer/LobbyCont 
@onready var join_lobby_id = $UI/Side/MarginContainer/VBoxContainer/JoinLobbyID

var host_steam_id: int = 0
var lobby_members:Array = []

const LOBBY_ID_HEX_PREFIX = "186000"

func i_am_host() -> bool:
	return Steam.getSteamID() == host_steam_id

# Called when the node enters the scene tree for the first time.
func _ready():
	button_host.pressed.connect(_create_lobby)
	button_join.pressed.connect(_join_lobby)
	lobby_status.visible = false
	
	_setup_steam()
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.p2p_session_request.connect(_on_p2p_session_request)
	Steam.p2p_session_connect_fail.connect(_on_p2p_session_connect_fail)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)

	WorldState.world_root = self

func _setup_steam():
	Steam.steamInit()
	
	var isRunning: bool = Steam.isSteamRunning()
	if (!isRunning):
		print("Steam is not running. No point in playing this game without Steam. Exiting...")
		return
	
	print("Steam is running.")
	var my_steam_id = Steam.getSteamID()
	Global.my_steam_id = Steam.getSteamID()
	var my_steam_name = Steam.getFriendPersonaName(my_steam_id)
	print("Your Steam name is: " + str(my_steam_name))
	
	$UI/Side/MarginContainer/VBoxContainer/SteamUsername.text = "Username: " + my_steam_name
	$UI/Side/MarginContainer/VBoxContainer/SteamID.text = "SteamID: " + str(my_steam_id)

func _create_lobby():
	print("Attempting to create a lobby...")
	button_host.disabled = true
	if Global.steam_lobby_id == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_INVISIBLE, 4)
	else:
		print("Already in a lobby! Can't create a new one.")

func _join_lobby():
	print("Attempting to join a lobby...")
	var lobby_id_str: String = LOBBY_ID_HEX_PREFIX + join_lobby_id.text
	var lobby_id: int = lobby_id_str.hex_to_int()
	Steam.joinLobby(lobby_id)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	Steam.run_callbacks()
	
	var packet = Steam.getAvailableP2PPacketSize(0)
	for pack in packet:
		_read_p2p_packet()

func _on_lobby_created(connection_result: int, lobby_id: int):
	match connection_result:
		1:
			print("SUCCESS: The lobby was successfully created. (ID: ", lobby_id ,")")
			Global.steam_lobby_id = lobby_id
			host_steam_id = Global.my_steam_id
			
			var allowRelay = Steam.allowP2PPacketRelay(true)
			print("Allowing P2P packet relay: " + str(allowRelay))

			Steam.setLobbyData(lobby_id, "type", "cavern_lobby")
			var lobby_id_hex: String = ("%X" % lobby_id).substr(LOBBY_ID_HEX_PREFIX.length())
			lobby_status.get_child(1).text = lobby_id_hex
			lobby_status.visible = true
		2: # k_EResultFail - The server responded, but with an unknown internal error.
			print("ERROR: The server responded, but with an unknown internal error.")
		16: # k_EResultTimeout - The message was sent to the Steam servers, but it didn't respond.
			print("ERROR: The message was sent to the Steam servers, but it didn't respond.")
		25: # k_EResultLimitExceeded - Your game client has created too many lobbies and is being rate limited.
			print("ERROR: Your game client has created too many lobbies and is being rate limited.")
		15: # k_EResultAccessDenied - Your game isn't set to allow lobbies, or your client does haven't rights to play the game
			print("ERROR: Your game isn't set to allow lobbies, or your client does haven't rights to play the game")
		3: # k_EResultNoConnection - Your Steam client doesn't have a connection to the back-end.
			print("ERROR: Your Steam client doesn't have a connection to the back-end.")

func _on_lobby_joined(lobby_id:int, _permissions:int, _locked:bool, response:int):
	if response == 1: # k_EChatRoomEnterResponseSuccess - the lobby was successfully joined
		# knowing that we joined a lobby we also know that
		# we are not the host player, instead we are a client player
		
		print("Successfully joined lobby (ID: %s)" % str(lobby_id)) 
		Global.steam_lobby_id = lobby_id
		host_steam_id = Steam.getLobbyOwner(lobby_id)
		_get_lobby_members()
		$MP/Client.start_clock_sync()
		
		for member in lobby_members:
			if(member.steam_id == Global.my_steam_id):
				continue
			var session:Dictionary = Steam.getP2PSessionState(member.steam_id)
			if(session == {}): # session does not exist
				_make_p2p_handshake()
			spawn_on_remote(member.steam_id, WorldState.Player1.position.x, WorldState.Player1.position.y)
		# if there is a connection active, we will get a dictionary that is populated with
		# all sorts of things (check steam documentations to find out
		# otherwise, we will get an empty dicitonary
		
	elif response == 5: # k_EChatRoomEnterResponseError - the lobby join was unsuccesful
		print("Failed joining lobby")

func _get_lobby_members():
	# clear the lobby members, we're in a new lobby now
	lobby_members.clear()
	var total_members:int = Steam.getNumLobbyMembers(Global.steam_lobby_id)
	for member in range(0, total_members):
		var member_steam_id:int = Steam.getLobbyMemberByIndex(Global.steam_lobby_id, member)
		var member_steam_name:String = Steam.getFriendPersonaName(member_steam_id)
		# append them to the lobby members array
		lobby_members.append({"steam_id": member_steam_id, "steam_name": member_steam_name})

func _make_p2p_handshake():
	print("Sending a p2p handshake request to the lobby...")
	_send_p2p_packet("host", Steam.P2P_SEND_RELIABLE, Packet.HANDSHAKE, {"message":"handshake", "from":Global.my_steam_id}) # needs a bit of fixing later

func _read_p2p_packet():
	var packetSize:int = Steam.getAvailableP2PPacketSize(0)
	
	if packetSize > 0:
		
		# read the packet
		var packet:Dictionary = Steam.readP2PPacket(packetSize, 0)
		
		# it shouldn't be empty if the size is nonzero!
		if packet.is_empty():
			print("EPIC FAIL: read an empty packet with non-zero size.")
		
		# remote sender information
		var senderID:String = str(packet.steam_id_remote)
		var packetCode:int = packet.data[0]
		
		var packetRead:Dictionary = bytes_to_var(packet.data.slice(1, packetSize))
		
		match packetCode:
			Packet.HANDSHAKE: # first packet sent to establish connection
				print("Got a handshake request from: ", senderID)
				print(Steam.getP2PSessionState(int(senderID)))
			Packet.WORLDSTATE: # worldstate update
				#print("Got a new worldstate update, please do something with this!")
				$MP/Client.update_worldstate(packetRead)
			Packet.PLAYERSTATE:
				$MP/Server.update_remote_playerstate(packetRead, packet.steam_id_remote)
			Packet.SPAWN_PLAYER:
				print("Trying to spawn player on: ", packetRead)
				WorldState.add_remote_player(senderID, Vector2(packetRead.x, packetRead.y))
			Packet.GET_SERVERTIME:
				var sTimes:Dictionary = {"S": Time.get_ticks_msec(), "C": packetRead.T}
				_send_p2p_packet(senderID, Steam.P2P_SEND_RELIABLE, Packet.SET_SERVERTIME, sTimes)
			Packet.SET_SERVERTIME:
				$MP/Client.set_server_time(packetRead)
			Packet.LATENCY_REQUEST:
				var sTimes:Dictionary = {"S": Time.get_ticks_msec(), "C": packetRead.T}
				_send_p2p_packet(senderID, Steam.P2P_SEND_RELIABLE, Packet.UPDATE_LATENCY, sTimes)
			Packet.UPDATE_LATENCY:
				$MP/Client.update_clock_latency(packetRead)
			_:
				print("[NET] Unknown: ", packetCode)
#		print("Read packet data: ", str(packetRead))

func _send_p2p_packet(target:String, sendType:int, packet_type:Packet, sendDict:Dictionary):
	var data:PackedByteArray = PackedByteArray()
	data.append(packet_type)
	data.append_array(var_to_bytes(sendDict))
	
	# maybe add a check as to whether player is host aswell?
	# probably do
	if target == "all": # broadcast to all members
		if lobby_members.size() > 1:
			for member in lobby_members:
				if member['steam_id'] != Global.my_steam_id:
					Steam.sendP2PPacket(member['steam_id'], data, sendType, 0)
		if i_am_host():
			if packet_type == Packet.WORLDSTATE:
				$MP/Client.update_worldstate(sendDict)
	elif target == "host":
		if i_am_host():
			if packet_type == Packet.PLAYERSTATE:
				$MP/Server.update_remote_playerstate(sendDict, Global.my_steam_id)
			elif packet_type == Packet.GET_SERVERTIME:
				var sTimes:Dictionary = {"S": Time.get_ticks_msec(), "C": sendDict.T}
				$MP/Client.set_server_time(sTimes)
			elif packet_type == Packet.LATENCY_REQUEST:
				var sTimes:Dictionary = {"S": Time.get_ticks_msec(), "C": sendDict.T}
				$MP/Client.update_clock_latency(sTimes)
			#print("Can't send a package to yourself!") 
			# alternatively, this is probably a worldstate 
			# so you might want to interpret it
		else:
			Steam.sendP2PPacket(host_steam_id, data, sendType, 0)
	else:
		Steam.sendP2PPacket(int(target), data, sendType, 0)

func _on_lobby_chat_update(_lobby_id:int, changed_id:int, making_change_id:int, chat_state:int):
	var changer_name:String = Steam.getFriendPersonaName(changed_id)
	
	match chat_state:
		1: # player has joined the lobby
			spawn_on_remote(making_change_id, WorldState.Player1.position.x, WorldState.Player1.position.y)
			print(changer_name, " has joined the game.")
		2: # player has left the lobby
			print(changer_name, " has left the game.")
		8: # player has been kicked? - tbh this isnt even implemented in the steamworks backend
			print(changer_name, " has been kicked from the game.")
		16: # player has been banned
			print(changer_name, " has been banned from the game.")
		_: # unknown thing happened to player
			print("Unknown change has occured for ", changer_name)
	
	_lobby_members_change(changed_id, chat_state)

func _lobby_members_change(changed_id:int, chat_state:int):
	if(chat_state == 1):
		var member_steam_name: String = Steam.getFriendPersonaName(changed_id)
		lobby_members.append({"steam_id": changed_id, "steam_name": member_steam_name})
		
	elif(chat_state in [2, 8, 16]):
		if i_am_host(): 
			# if a player disconnects or is kicked
			# make sure to remove them from the playerstate collection.
			$MP/Server.pStates.erase(changed_id)
		for member in lobby_members:
			if member.steam_id == changed_id:
				lobby_members.erase(member)
				WorldState.remove_remote_player(str(changed_id))
	else:
		_get_lobby_members()

func _on_p2p_session_request(remote_id:int):
	print("Got a P2P session request, sending a handshake back...")
	# accept it, but also logic to deny in here aswell - perhaps if he is not in the lobby?
	for member in lobby_members:
		if(member.steam_id == remote_id):
			Steam.acceptP2PSessionWithUser(remote_id)
			_make_p2p_handshake() # acknowledge the session request, accept it and then send a handshake back

func _on_p2p_session_connect_fail(lobby_id:int, session_error:int):
	# List of possible errors returned by SendP2PPacket
	match session_error:
		0: # k_EP2PSessionErrorNone - no error
			print("Session failure with %s [no error given.]" % str(lobby_id))
		1: # k_EP2PSessionErrorNotRunningApp - player is not running the same game
			print("Session failure with %s [not running the same game.]" % str(lobby_id))
		2: # k_EP2PSessionErrorNoRightsToApp - player doesnt own the game
			print("Session failure with %s [player doesn't own the game.]" % str(lobby_id))
		3: # k_EP2PSessionErrorDestinationNotLoggedIn - player isn't connected to steam
			print("Session failure with %s [player isn't connected to Steam.]" % str(lobby_id))
		4: # k_EP2PSessionErrorTimeout - connection timed out
			print("Session failure with %s [connection timed out.]" % str(lobby_id))
		5: # k_EP2PSessionErrorMax - unused
			print("Session failure with %s [unused]" % str(lobby_id))
		_: # unknown error happened 
			print("Session failure with %s [unknown error]" % str(lobby_id))

func spawn_on_remote(targetID:int, posx:float, posy:float):
	_send_p2p_packet(str(targetID), Steam.P2P_SEND_RELIABLE, Packet.SPAWN_PLAYER, {"x": posx, "y": posy})
