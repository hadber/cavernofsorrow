extends Node

enum PACKETS {
	HANDSHAKE, # 0
	SPAWN_PLAYER, # 1
	WORLDSTATE, # 2
	PLAYERSTATE,
	GET_SERVERTIME,
	SET_SERVERTIME,
	LATENCY_REQUEST,
	UPDATE_LATENCY
	}

enum SENDTYPES {
	UNRELIABLE,
	UNRELIABLE_NO_DELAY,
	RELIABLE,
	RELIABLE_BUFFERING
}

# is player host is basically hostSteamID == Global.gSteamID
var hostSteamID:int
var mpWorker:Object = null

var membersDownloaded:int = 0
var lChanged:float = false

var lobbyMembers:Array = []

signal playerlist_update

func _ready() -> void:
	Steam.steamInit()
	Steam.lobby_created.connect(_on_lobby_created)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.p2p_session_request.connect(_on_p2p_session_request)
	Steam.p2p_session_connect_fail.connect(_on_p2p_session_connect_fail)
	Steam.avatar_loaded.connect(_on_loaded_avatar)
	#Steam.connect("lobby_created", self, "_on_lobby_created")
	#Steam.connect("lobby_joined", self, "_on_lobby_joined")
	#Steam.connect("lobby_chat_update", self, "_on_lobby_chat_update")
#	Steam.connect("lobby_message", self, "_on_Lobby_Message") # a chat message has been sent
#	Steam.connect("lobby_data_update", self, "_on_Lobby_Data_Update") # the lobby metadata has changed
#	Steam.connect("lobby_invite", self, "_on_Lobby_Invite") # get invited to lobby (steam UI takes care of it)
	#Steam.connect("p2p_session_request", self, "_on_p2p_session_request")
	#Steam.connect("p2p_session_connect_fail", self, "_on_p2p_session_connect_fail")
	#Steam.connect("avatar_loaded", self, "_on_loaded_avatar")
	
	_check_command_line()

func _check_command_line(): 
	# checks for command line arguments
	# example: when you click "join lobby" in the steam friendslist
	# it will launch the game with the command line argument "+connect_lobby lobbyid"
	# we need to catch that case and process it 
	var args = OS.get_cmdline_args()
	var argLobbyInv:bool = false
	
	if args.size() > 0: # there are arguments to process
		for arg in args:
			print("cmdline arg: " + str(arg))
			
			if argLobbyInv:
				_join_lobby(int(arg))
			
			if arg == "+connect_lobby":
				argLobbyInv = true

func _process(_delta):
	var packet = Steam.getAvailableP2PPacketSize(0)
	
	for pack in packet:
		_read_p2p_packet()

func _create_lobby():
	if Global.steamLobbyID == 0:
		Steam.createLobby(1, 2)
	else: 
		print("ERROR: Failed to create lobby. Lobby already exists (ID: ", Global.steamLobbyID, ")")

func _on_lobby_created(connect: int, lobbyID: int):
	
	if connect == 1: # k_EResultOK - The lobby was successfully created.
		print("SUCCESS: The lobby was successfully created. (ID: ", lobbyID ,")")
		Global.steamLobbyID = lobbyID
		hostSteamID = Global.gSteamID
		
		mpWorker = $Client
		
		#Setting lobby data
		Steam.setLobbyData(lobbyID, "title", "Meta Dungeon (%s) test lobby" % Global.version)
		
		var allowRelay = Steam.allowP2PPacketRelay(true)
		print("Allowing P2P packet relay: " + str(allowRelay))
		
	elif connect == 2: # k_EResultFail - The server responded, but with an unknown internal error.
		print("ERROR: The server responded, but with an unknown internal error.")
	elif connect == 16: # k_EResultTimeout - The message was sent to the Steam servers, but it didn't respond.
		print("ERROR: The message was sent to the Steam servers, but it didn't respond.")
	elif connect == 25: # k_EResultLimitExceeded - Your game client has created too many lobbies and is being rate limited.
		print("ERROR: Your game client has created too many lobbies and is being rate limited.")
	elif connect == 15: # k_EResultAccessDenied - Your game isn't set to allow lobbies, or your client does haven't rights to play the game
		print("ERROR: Your game isn't set to allow lobbies, or your client does haven't rights to play the game")
	elif connect == 3: # k_EResultNoConnection - Your Steam client doesn't have a connection to the back-end.
		print("ERROR: Your Steam client doesn't have a connection to the back-end.")

func _join_lobby(lobbyID:int):
	print("Joining lobby " + str(lobbyID))
	
	# just in case, clear previous members list
	# if it just so happens this is not your first lobby
	lobbyMembers.clear()
	mpWorker = $Server
	
	# request to join the lobby
	# calls _on_lobby_joined() on success
	Steam.joinLobby(lobbyID)

func _leave_lobby():
	if Global.steamLobbyID != 0: # player is currently in a lobby
		
		Steam.leaveLobby(Global.steamLobbyID)
		Global.steamLobbyID = 0
		
		for member in lobbyMembers:
			Steam.closeP2PSessionWithUser(member['steam_id'])
		
		lobbyMembers.clear()
	else: # player is not part of any lobby - how did we get to this point?
		print("What are you trying to do? You are not part of any lobby! (perhaps an error occured?)")

func _on_lobby_joined(lobbyID:int, _permissions:int, _locked:bool, _response:int):
	if _response == 1: # k_EChatRoomEnterResponseSuccess - the lobby was successfully joined
		print("Successfully joined lobby (ID: %s)" % str(lobbyID)) 
		Global.steamLobbyID = lobbyID
		hostSteamID = Steam.getLobbyOwner(lobbyID)
		_get_lobby_members()
		$Client.start_clock_sync()
		
		# change the player's node name to their steam id
		gWorld.Player1.name = str(Global.gSteamID)
		
		for member in lobbyMembers:
			if(member.steam_id == Global.gSteamID):
				continue
			var session:Dictionary = Steam.getP2PSessionState(member.steam_id)
			if(session == {}): # session does not exist
				_make_p2p_handshake()
			spawn_on_remote(member.steam_id, gWorld.Player1.position.x, gWorld.Player1.position.y)
		# if there is a connection active, we will get a dictionary that is populated with
		# all sorts of things (check steam documentations to find out
		# otherwise, we will get an empty dicitonary
		
	elif _response == 5: # k_EChatRoomEnterResponseError - the lobby join was unsuccesful
		print("Failed joining lobby")

func _get_lobby_members():
	# clear the lobby members, we're in a new lobby now
	lobbyMembers.clear()
	
	# get the number of lobby members
	var totalMembers:int = Steam.getNumLobbyMembers(Global.steamLobbyID)
	
	# get the data on each of the members
	for member in range(0, totalMembers):
		# get their steam ID
		var memberSteamID:int = Steam.getLobbyMemberByIndex(Global.steamLobbyID, member)
		# get their steam name
		var memberSteamName:String = Steam.getFriendPersonaName(memberSteamID)
		# append them to the lobby members array
		lobbyMembers.append({"steam_id": memberSteamID, "steam_name": memberSteamName})
		Steam.getPlayerAvatar(1, memberSteamID)
		# steam_id 		int
		# steam_name	string
		
	lChanged = true

func _make_p2p_handshake():
	print("Sending a p2p handshake request to the lobby...")
	_send_p2p_packet("host", SENDTYPES.RELIABLE, PACKETS.HANDSHAKE, {"message":"handshake", "from":Global.gSteamID}) # needs a bit of fixing later

func _read_p2p_packet():
	var packetSize:int = Steam.getAvailableP2PPacketSize(0)
	
	if packetSize > 0:
		
		# read the packet
		var packet:Dictionary = Steam.readP2PPacket(packetSize, 0)
		
		# it shouldn't be empty if the size is nonzero!
		if packet.is_empty():
			print("EPIC FAIL: read an empty packet with non-zero size.")
		
		# remote sender information
		var senderID:String = str(packet.steamIDRemote)
		var packetCode:int = packet.data[0]
		
		var packetRead:Dictionary = bytes_to_var(packet.data.subarray(1, packetSize-1))
		
		match packetCode:
			PACKETS.HANDSHAKE: # first packet sent to establish connection
				print("Got a handshake request from: ", senderID)
				print(Steam.getP2PSessionState(int(senderID)))
					# if there 
				#spawn_on_remote(gWorld.Player1.position.x, gWorld.Player1.position.y)
			PACKETS.WORLDSTATE: # worldstate update
				#print("Got a new worldstate update, please do something with this!")
				#print(packetRead)
				$Client.update_worldstate(packetRead)
			PACKETS.PLAYERSTATE:
				$Server.update_remote_playerstate(packetRead, packet.steamIDRemote)
			PACKETS.SPAWN_PLAYER:
				print("Trying to spawn player on: ", packetRead)
				gWorld.add_remote_player(senderID, Vector2(packetRead.x, packetRead.y))
			PACKETS.GET_SERVERTIME:
				var sTimes:Dictionary = {"S": Time.get_ticks_msec(), "C": packetRead.T}
				_send_p2p_packet(senderID, SENDTYPES.RELIABLE, PACKETS.SET_SERVERTIME, sTimes)
			PACKETS.SET_SERVERTIME:
				$Client.set_server_time(packetRead)
			PACKETS.LATENCY_REQUEST:
				var sTimes:Dictionary = {"S": Time.get_ticks_msec(), "C": packetRead.T}
				_send_p2p_packet(senderID, SENDTYPES.RELIABLE, PACKETS.UPDATE_LATENCY, sTimes)
			PACKETS.UPDATE_LATENCY:
				$Client.update_clock_latency(packetRead)
			_:
				print("[NET] Unknown: ", packetCode)
#		print("Read packet data: ", str(packetRead))

func _send_p2p_packet(target:String, sendType:int, packetType:int, sendDict:Dictionary):
	# send types
	# 0 - unreliable, basic UDP send
	# 1 - unreliable no delay, drop packets if no connection exists
	# 2 - reliable message send, up to 1MB in a single message
	# 3 - reliable with buffering (nagle algorithm)
	
	var data:PackedByteArray = PackedByteArray()
	data.append(packetType)
	data.append_array(var_to_bytes(sendDict))
	
	# maybe add a check as to whether player is host aswell?
	# probably do
	if target == "all": # broadcast to all members
		if lobbyMembers.size() > 1:
			for member in lobbyMembers:
				if member['steam_id'] != Global.gSteamID:
					Steam.sendP2PPacket(member['steam_id'], data, sendType, 0)
		if hostSteamID == Global.gSteamID:
			if packetType == PACKETS.WORLDSTATE:
				$Client.update_worldstate(sendDict)
	elif target == "host":
		if hostSteamID == Global.gSteamID:
			if packetType == PACKETS.PLAYERSTATE:
				$Server.update_remote_playerstate(sendDict, Global.gSteamID)
			elif packetType == PACKETS.GET_SERVERTIME:
				var sTimes:Dictionary = {"S": Time.get_ticks_msec(), "C": sendDict.T}
				$Client.set_server_time(sTimes)
			elif packetType == PACKETS.LATENCY_REQUEST:
				var sTimes:Dictionary = {"S": Time.get_ticks_msec(), "C": sendDict.T}
				$Client.update_clock_latency(sTimes)
			#print("Can't send a package to yourself!") 
			# alternatively, this is probably a worldstate 
			# so you might want to interpret it
		else:
			Steam.sendP2PPacket(hostSteamID, data, sendType, 0)
	else:
		Steam.sendP2PPacket(int(target), data, sendType, 0)

func _on_lobby_chat_update(_lobbyID:int, _changedID:int, _makingChangeID:int, chatState:int):
	var changerName:String = Steam.getFriendPersonaName(_changedID)
	
	if chatState == 1: # player has joined the lobby
		spawn_on_remote(_makingChangeID, gWorld.Player1.position.x, gWorld.Player1.position.y)
		print(changerName, " has joined the game.")
	elif chatState == 2: # player has left the lobby
		print(changerName, " has left the game.")
	elif chatState == 8: # player has been kicked? - tbh this isnt even implemented in the steamworks backend
		print(changerName, " has been kicked from the game.")
	elif chatState == 16: # player has been banned
		print(changerName, " has been banned from the game.")
	else: # unknown thing happened to player
		print("Unknown change has occured for ", changerName)
	
	_lobby_members_change(_changedID, chatState)

func _lobby_members_change(changedID:int, chatState:int):
	if(chatState == 1):
		var memberSteamName:String = Steam.getFriendPersonaName(changedID)
		lobbyMembers.append({"steam_id": changedID, "steam_name": memberSteamName})
		Steam.getPlayerAvatar(1, changedID)
		lChanged = true
		# when a new member joins the lobby, we trick the callback into thinking
		# it has already downloaded the avatars for lobbyMembers size - 1
		# so when the callback triggers, it thinks it loaded all the avatars
		# which it tehnically did, since we only want it to load 1 avatar
		# this is filthy and i dont like that i have to do this
		membersDownloaded = lobbyMembers.size() - 1
	elif(chatState in [2, 8, 16]):
		if hostSteamID == Global.gSteamID: 
			# if a player disconnects or is kicked
			# make sure to remove them from the playerstate collection.
			$Server.pStates.erase(changedID)
		for member in lobbyMembers:
			if member.steam_id == changedID:
				lobbyMembers.erase(member)
				gWorld.remove_remote_player(str(changedID))
	else:
		_get_lobby_members()

func _on_p2p_session_request(remoteID:int):
	# name of player requesting peer to peer session
	var _remoteName:String = Steam.getFriendPersonaName(remoteID)
	
	print("Got a P2P session request, sending one back...")
	# accept it, logic to deny in here aswell - perhaps if he is not in the lobby?
	#print(lobbyMembers)
	for member in lobbyMembers:
		if(member.steam_id == remoteID):
			Steam.acceptP2PSessionWithUser(remoteID)
			_make_p2p_handshake() # acknowledge the session request, accept it and then send a handshake back

func _on_p2p_session_connect_fail(lobbyID:int, session_error:int):
	# List of possible errors returned by SendP2PPacket
	if session_error == 0: # k_EP2PSessionErrorNone - no error
		print("Session failure with %s [no error given.]" % str(lobbyID))
	elif session_error == 1: # k_EP2PSessionErrorNotRunningApp - player is not running the same game
		print("Session failure with %s [not running the same game.]" % str(lobbyID))
	elif session_error == 2: # k_EP2PSessionErrorNoRightsToApp - player doesnt own the game
		print("Session failure with %s [player doesn't own the game.]" % str(lobbyID))
	elif session_error == 3: # k_EP2PSessionErrorDestinationNotLoggedIn - player isn't connected to steam
		print("Session failure with %s [player isn't connected to Steam.]" % str(lobbyID))
	elif session_error == 4: # k_EP2PSessionErrorTimeout - connection timed out
		print("Session failure with %s [connection timed out.]" % str(lobbyID))
	elif session_error == 5: # k_EP2PSessionErrorMax - unused
		print("Session failure with %s [unused]" % str(lobbyID))
	else: # unknown error happened 
		print("Session failure with %s [unknown error]" % str(lobbyID))

func spawn_on_remote(targetID:int, posx:float, posy:float):
	_send_p2p_packet(str(targetID), SENDTYPES.RELIABLE, PACKETS.SPAWN_PLAYER, {"x": posx, "y": posy})

func _on_loaded_avatar(playerID:int, size:int, buffer:PackedByteArray):
	print("loaded avatar triggered")
	var pAvatar = Image.new()
	var pAvatarTexture = ImageTexture.new()
	pAvatar.create(size, size, false, Image.FORMAT_RGBAF)

	pAvatar.lock()
	for y in range(0, size):
		for x in range(0, size):
			var pixel = 4 * (x + y * size)
			var r = float(buffer[pixel]) / 255
			var g = float(buffer[pixel+1]) / 255
			var b = float(buffer[pixel+2]) / 255
			var a = float(buffer[pixel+3]) / 255
			pAvatar.set_pixel(x, y, Color(r, g, b, a)) 
	pAvatar.unlock()

	pAvatarTexture.create_from_image(pAvatar)
	
	for member in lobbyMembers:
		if member['steam_id'] == playerID:
			member['avatar'] = pAvatarTexture
	
	# just to be safe in the future, we don't know if we'll need the avatar for other
	# things in the networking side and we don't want to update it every time we get a new
	# avatar
	membersDownloaded += 1
	if lChanged && membersDownloaded == len(lobbyMembers):
		membersDownloaded = 0
		lChanged = false
		emit_signal("playerlist_update")
