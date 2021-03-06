--[[---------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
-----------------------------ZED MADE BY IZED ------ i-zed.net ----------------------------------
---------------------------------------------------------You are NOT allowed to change this file.
---------------------------------------------------------------------------------------------]]--

ZED = {}
ZED.Players = {} 
ZED.ScoreBoardTimer = 0
ZED.ScoreBoardUpdateInterval = 200
ZED.ScoreBoardCustomField = {}
ZED.ScoreBoardExtraField = {}
ZED.ScoreBoardButtons = {}
ZED.LastMessages = {}
	
function ZED.Init(t)
	
	for ply in Server:GetPlayers() do
		ZED:InitPlayer(ply)
	end
	
	Events:Fire("ZEDReady", ZED)
	
	ZED:UpdatePlayerList()
end
	

ZED.SendChatMessage = function(tbl, ply, ...)
        Network:Send( ply, "ZEDChat", {...} )
end
ZED.Broadcast = function(tbl, ...)
        Network:Broadcast( "ZEDChat", {...} )
end
ZED.Notify = function(tbl, args)
	if(args.player)then
		Network:Send(args.player, "Notify", args)
	else
		Network:Broadcast("Notify", args)
	end
end
ZED.SideNotify = function(tbl, args)
	if(args.player)then
		Network:Send(args.player, "SideNotify", args)
	else
		Network:Broadcast("SideNotify", args)
	end
end

Events:Subscribe("ZEDNotify", ZED.Notify)
Events:Subscribe("ZEDSideNotify", ZED.SideNotify)
Events:Subscribe( "ZEDSendChatMessage", function(args)
	Network:Send( args.player, "ZEDChat", args.message )
end)
Events:Subscribe( "ZEDBroadcast", function(args)
	Network:Broadcast( "ZEDChat", args )
end)
Events:Subscribe( "ZEDUpdateScoreboard", function(t)
	if(t.Columns)then
		for k,v in pairs(t.Columns) do
			ZED.ScoreBoardCustomField[k] = v
		end
	end
	if(t.Extra)then
		for k,v in pairs(t.Extra) do
			ZED.ScoreBoardExtraField[k] = v
		end
	end
	if(t.Buttons)then
		for k,v in pairs(t.Buttons) do
			ZED.ScoreBoardButtons[k] = v
		end
	end
	--Network:Broadcast( "ZEDUpdateBoard", t )
end)
Network:Subscribe("ZEDButtonClick", function(args)
	local cmd = args
	Events:Fire("ZEDExecuteCommand", {player=args.player, cmd=cmd})
	print(args.player:GetName() .. " pressed button: " .. string.lower(args.text))
	return false
end)
Events:Subscribe("PlayerDeath", function(args)
	if args.killer then		
		if(PData:Get(args.killer).kills)then
			PData:Set(args.killer, {kills=PData:Get(args.killer).kills+1})
		else
			PData:Set(args.killer, {kills=1})
		end
	end
	if(PData:Get(args.player).deaths)then
		PData:Set(args.player, {deaths=PData:Get(args.player).deaths+1})
	else
		PData:Set(args.player, {deaths=1})
	end
	Events:Fire("ZEDPlayerDeath", {zed=ZED, args=args})
	ZED:UpdatePlayerList() 
end)
Events:Subscribe("PlayerChat", function(args)
	if( ZED.LastMessages[args.player:GetId()] )then
		--if( ZED:strEquals(msgData.msg, args.text) ) then
		if( ZED.LastMessages[args.player:GetId()].timer:GetSeconds() < 3 ) and Events:Fire("ZEDPlayerHasPermission", {player=args.player, permission="spambypass"}) then
			ZED:SendChatMessage(args.player, Color(200,0,0), "Please do not spam!")
			return false
		end
		--end
		ZED.LastMessages[args.player:GetId()].timer:Restart()
		ZED.LastMessages[args.player:GetId()].msg = args.text
	else
		ZED.LastMessages[args.player:GetId()] = {msg = args.text, timer = Timer()}
	end
	if (args.text:sub(1, 1) ~= '/') then
		Console:Print(args.player:GetName() .. ": " .. args.text)
		if not Events:Fire("ZEDAllowPlayerChat", args) then
			return false
		end
		if not Events:Fire("ZEDPlayerChat", args) then
			return false
		end
		ZED:Broadcast(args.player:GetColor(), args.player:GetName(), Color(150,150,150), ": ", args.text)
		return false
	end
	local str = string.sub(args.text, 2)
	local cmd = str:split(' ')
	if ZED:strEquals(cmd[1], "version") then
		ZED:SendChatMessage(args.player, Color(0,150,200),"This server is runnig ZED V2.0a", Color(0,150,200))
	else
		if( not ZED:PlayerHasPermission(args.player, string.lower(cmd[1])))then
			ZED:SendChatMessage(args.player, Color(200,0,0,255), "You have no access to this command: " .. string.lower(cmd[1]))
			print(args.player:GetName() .. " tried using command: " .. string.lower(args.text))
			return false
		end
		Events:Fire("ZEDExecuteCommand", {player=args.player, cmd=cmd})
	end
	print(args.player:GetName() .. " used command: " .. string.lower(args.text))
	return false
end)
Events:Subscribe("PlayerJoin", function(args)
	if Events:Fire("ZEDPlayerJoin", {zed=ZED, args=args}) then
		ZED:SideNotify({color=Color(0,200,200), text=args.player:GetName().." joined the server.", size=20})
	end
	ZED:InitPlayer(args.player)
	ZED:UpdatePlayerList()
end)
Events:Subscribe("PlayerQuit", function(args)
	if Events:Fire("ZEDPlayerQuit", {zed=ZED, args=args}) then
		ZED:SideNotify({color=Color(0,200,200), text=args.player:GetName().." left the server.", size=20})
	end
	ZED:UpdatePlayerList()
	PData:Save(args.player)
	PData:Delete(args.player)
	ZED.LastMessages[args.player:GetId()] = nil
end)
Events:Subscribe("PreTick", function()
	ZED.ScoreBoardTimer = ZED.ScoreBoardTimer + 1
	if(ZED.ScoreBoardTimer > ZED.ScoreBoardUpdateInterval)then
		ZED:UpdatePlayerList()
		ZED.ScoreBoardTimer = 0
	end
end)
Events:Subscribe( "ZEDPlayerHasPermission", function(args)
	if(PData:Get(args.player).permission)then
		for k,v in pairs(PData:Get(args.player).permission) do
			if(v == "*")then return true end
			if(string.lower(args.permission) == string.lower(v))then
				return false
			end
		end
	end
	return true
end)

-- START ZEDTunnel
Events:Subscribe("ZEDTunnel", function( args)
	if(args.type == "Broadcast")then
			ZED:Broadcast(args.color, args.text)
	end
	if(args.type == "Send")then
			ZED:SendChatMessage(args.player, args.color, args.text)
	end
end)
-- END ZEDTunnel
	

ZED.file_exists =  function (t, name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end
ZED.strEquals = function(t, v1, v2)
	if(string.lower(tostring(v1)) == string.lower(tostring(v2)))then
		return true
	else
		return false
	end
end
ZED.strFind = function(t, v1, v2)
	if(string.find(string.lower(tostring(v1)), string.lower(tostring(v2))))then
		return true
	else
		return false
	end
end
ZED.GetLuminance = function(t, col)
	return (0.2126*col.r)+(0.7152*col.g)+(0.0722*col.b)
end	


ZED.PlayerHasPermission = function(t, ply, str)
	if not Events:Fire("ZEDPlayerHasPermission", {player=ply, permission=str}) then
		return true
	end
	return false
end
ZED.InitPlayer = function(tbl, ply)
	PData:Load(ply, {permission={},kills=0,deaths=0})
	Events:Fire("ZEDPlayerInit", {player=ply})
end
ZED.UpdatePlayerList = function(tbl)
	if Events:Fire("ZEDScoreboardUpdate", true) then
		local t = {}
		t.players = {}
		t.name = Config:GetValue("Server", "Name")
		t.maxplayers = Config:GetValue("Server", "MaxPlayers")
		t.header = {"#","Name", "Kills", "Deaths"}
		--for i = 0, 144, 1 do
			for v in Server:GetPlayers() do
				local fgColor = Color(0,0,0)
				local bgColor = v:GetColor()
				if ZED:GetLuminance(bgColor) < 130 then
					fgColor = Color(255,255,255)
				end
				local p = {v:GetId(),v:GetName(),BGColor=bgColor,FGColor=fgColor,PData:Get(v).kills,PData:Get(v).deaths}
				for k,i in pairs(ZED.ScoreBoardCustomField) do
					if k == "BGColor" or k == "FGColor" then
						p[k] = i[v:GetId()]
					else
						table.insert(p, i[v:GetId()])
						local found = false
						for g,h in pairs(t.header) do
							if(h == k)then
								found = true
							end
						end
						if not found then
							table.insert(t.header, k)
						end
					end
				end
				p.ExtraInfo = {}
				p.Buttons = {}
				for k,i in pairs(ZED.ScoreBoardExtraField) do
					p.ExtraInfo[k] = i[v:GetId()]
				end
				for k,i in pairs(ZED.ScoreBoardButtons) do
					p.Buttons[k] = i[v:GetId()]
				end
				table.insert(p, v:GetPing())
				table.insert(t.players,p)
			end
		--end
		table.insert(t.header, "Ping")
		Network:Broadcast( "ZEDUpdateBoard", t )
	end
end
ZED.GetPlayer = function(tbl, str)
	for player in Server:GetPlayers() do
		if(string.find(string.lower(player:GetName()), string.lower(str)))then
			return player
		end
	end
end

local initialized = false
Events:Subscribe("ModulesLoad", function(args)
	if not initalized then
		ZED:Init()
	end
end)
