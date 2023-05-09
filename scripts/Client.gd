extends Node

@onready var Multiplayer = get_parent().get_parent()
var oldStateTime:int = 0
var worldStateBuffer:Array = []

var cLatency:int
var clientClock:int 
var deltaLatency:int = 0
var decimalCollector:float = 0
var latencyArray:Array = []

const INTERP_OFFSET = 100

func _process(_delta):
	Multiplayer._send_p2p_packet("host", Steam.P2P_SEND_UNRELIABLE, Multiplayer.Packet.PLAYERSTATE, WorldState.PlayerState)

func update_worldstate(newState):
	if newState["T"] > oldStateTime:
		oldStateTime = newState["T"]
		worldStateBuffer.append(newState)

# [older past worldstate (extrapolation), most recent past worldstate, nearest future world state, any other future world state]
func _physics_process(delta):
	
	# clock synchronization; delta ~= 0.01667 (if 60 fps)
	# when we turn the seconds into miliseconds (multiply by 1000)
	# we are going to lose the 67 (last two decimals)
	# as such, we collect them and when they go over 1 integer,
	# we can add the to the clock to keep synchronized
	clientClock += int(delta * 1000) + deltaLatency
	deltaLatency = 0
	decimalCollector += (delta*1000) - int(delta*1000)
	if decimalCollector >= 1.0:
		clientClock += 1
		decimalCollector -= 1.0
	
	#var renderTime = Time.get_ticks_msec() - INTERP_OFFSET
	var renderTime = clientClock - INTERP_OFFSET
	if worldStateBuffer.size() > 1:
		while worldStateBuffer.size() > 2 and renderTime > worldStateBuffer[2]["T"]:
			worldStateBuffer.pop_at(0)
		if worldStateBuffer.size() > 2:
			var interpolationFactor = float(renderTime - worldStateBuffer[1]["T"]) / float(worldStateBuffer[2]["T"] - worldStateBuffer[1]["T"])
			for playerID in worldStateBuffer[2].keys():
				if str(playerID) == "T":
					# its the timestamp of the worldstate (one of the dict entries)
					continue
				if playerID == Global.gSteamID:
					# we just found ourselves in the worldstate, we dont care about this!
					continue
				if not worldStateBuffer[1].has(playerID):
					# the player doesnt have a PAST worldstate, we wait a bit until one is generated
					continue
				if(Multiplayer.get_node("OtherPlayers")).has_node(str(playerID)):
					var newPos:Vector2 = lerp(worldStateBuffer[1][playerID]["P"], worldStateBuffer[2][playerID]["P"], interpolationFactor)
		#			print(worldStateBuffer[0][playerID]["P"], worldStateBuffer[1][playerID]["P"], interpolationFactor, newPos, renderTime)
					Multiplayer.get_node("OtherPlayers/" + str(playerID)).remote_movement(newPos)
				else:
					WorldState.add_remote_player(str(playerID), worldStateBuffer[2][playerID]["P"])
		elif renderTime > worldStateBuffer[1].T:
			var extrapolationFactor = float(renderTime - worldStateBuffer[0]["T"]) / float(worldStateBuffer[1]["T"] - worldStateBuffer[0]["T"]) - 1.0
			for playerID in worldStateBuffer[1].keys():
				if str(playerID) == "T":
					continue
				if playerID == Global.gSteamID:
					continue
				if not worldStateBuffer[1].has(playerID):
					continue
				if(Multiplayer.get_node("OtherPlayers")).has_node(str(playerID)):
					var positionDelta = worldStateBuffer[1][playerID]["P"] - worldStateBuffer[0][playerID]["P"]
					var newPos:Vector2 = worldStateBuffer[1][playerID]["P"] + (positionDelta * extrapolationFactor)
					Multiplayer.get_node("OtherPlayers/" + str(playerID)).remote_movement(newPos)

func start_clock_sync():
	var pTime:Dictionary = {"T": Time.get_ticks_msec()}# .get_system_time_msecs()}
	Multiplayer._send_p2p_packet("host", Steam.P2P_SEND_RELIABLE, Multiplayer.Packet.GET_SERVERTIME, pTime)
	
	var clockTimer = Timer.new()
	clockTimer.wait_time = 0.5
	clockTimer.autostart = true
	clockTimer.timeout.connect(update_latency)
	self.add_child(clockTimer)

func update_latency():
	var pTime:Dictionary = {"T": Time.get_ticks_msec()}
	Multiplayer._send_p2p_packet("host", Steam.P2P_SEND_RELIABLE, Multiplayer.Packet.GET_SERVERTIME, pTime)

func update_clock_latency(sTimes:Dictionary):
	latencyArray.append((Time.get_ticks_msec() - sTimes.C) / 2)
	if latencyArray.size() == 9:
		var totalLatency = 0
		latencyArray.sort()
		var median = latencyArray[4]
		for i in range(latencyArray.size()-1, -1, -1):
			if latencyArray[i] > median * 2 and latencyArray[i] > 20:
				latencyArray.pop_at(i)
			else:
				totalLatency += latencyArray[i]
		deltaLatency = (totalLatency / latencyArray.size()) - cLatency
		cLatency = totalLatency / latencyArray.size()
		print("New latency: ", cLatency)
		print("Delta: ", deltaLatency)
		latencyArray.clear()

func set_server_time(sTimes:Dictionary):
	cLatency = (Time.get_ticks_msec() - sTimes.C) / 2
	clientClock = sTimes.S + cLatency

func spawn_player(pSteamID:String, pPos:Vector2):
	WorldState.add_remote_player(pSteamID, pPos)
	
func despawn_player(pSteamID:String):
	WorldState.remove_remote_player(pSteamID)
