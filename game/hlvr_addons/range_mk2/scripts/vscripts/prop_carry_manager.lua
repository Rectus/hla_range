
local UPDATE_INTERVAL = 0.1
local EVENT_MAX_PENDING = 0.1

local PHYS_ENTITIES = {
	prop_physics = true;
	prop_physics_override = true;
	prop_ragdoll = true;
	prop_ragdoll_override = true;
	item_hlvr_grenade_frag = true;
	item_healthvial = true;
	
}

local APPROX_ENTITIES = {
	prop_ragdoll = true;
	prop_ragdoll_override = true;
	item_hlvr_clip_shotgun_single = true;
	item_hlvr_clip_shotgun_shellgroup = true;
}

local debugEnabled = false

local propList = {}
local playerList = {}
local pendingEvents = {}

local pickupCallbacks = {}
local dropCallbacks = {}



function RegisterPickupCallback(entity, func)
	pickupCallbacks[entity] = func
end

function RemovePickupCallback(entity)
	pickupCallbacks[entity] = nil
end


function RegisterDropCallback(entity, func)
	dropCallbacks[entity] = func
end

function RemoveDropCallback(entity)
	dropCallbacks[entity] = nil
end


function GetHandHoldingProp(prop)
	if propList[prop] and propList[prop].carried then
		return propList[prop].hand
	else
		return nil
	end
end


function GetPlayerHoldingProp(prop)
	if propList[prop] and propList[prop].carried then
		return propList[prop].player
	else
		return nil
	end
end


function IsPropCarried(prop)
	if propList[prop] and propList[prop].carried then
		return true
	else
		return false
	end
end


function GetPropInHand(player, hand)
	if playerList[player] and playerList[player][hand] then
		return playerList[player][hand]
	else
		return nil
	end
end


function GetAllHeldProps()

	local props = {}

	for player, hands in pairs(playerList) do
		for _, prop in pairs(hands) do
			table.insert(props, prop)
		end
	end
	
	return props
end



function Activate(aType)

	_G.g_PropCarryManager = {}
	_G.g_PropCarryManager.RegisterPickupCallback = function(entity, func) RegisterPickupCallback(entity, func) end
	_G.g_PropCarryManager.RemovePickupCallback = function(entity) RemovePickupCallback(entity) end
	_G.g_PropCarryManager.RegisterDropCallback = function(entity, func) RegisterDropCallback(entity, func) end
	_G.g_PropCarryManager.RemoveDropCallback = function(entity) RemoveDropCallback(entity) end

	_G.g_PropCarryManager.GetHandHoldingProp = function(prop) return GetHandHoldingProp(prop) end
	_G.g_PropCarryManager.GetPlayerHoldingProp = function(prop) return GetPlayerHoldingProp(prop) end
	_G.g_PropCarryManager.IsPropCarried = function(prop) return IsPropCarried(prop) end
	_G.g_PropCarryManager.GetPropInHand = function(player, hand) return GetPropInHand(player, hand) end
	_G.g_PropCarryManager.GetAllHeldProps = function(player, hand) return GetAllHeldProps() end

	-- Hack to properly handle restoration from saves, 
	-- since think calls by Activate() on restore break.
	EntFireByHandle(thisEntity, thisEntity, "CallScriptFunction", "SetupState")
end


function SetupState()
	

	Convars:RegisterCommand("prop_carry_debug", ToggleDebug, "Toggle debug display of the custom prop carry manager.", 0)

	ListenToGameEvent("item_pickup", PropPickedUpEvent, thisEntity)
	ListenToGameEvent("item_released", PropDropped, thisEntity)
	thisEntity:SetThink(Update, "update", 0)
end


function ToggleDebug()

	debugEnabled = not debugEnabled

	if debugEnabled then
		thisEntity:SetThink(DebugUpdate, "debug", 0)
	end
end


function PropPickedUpInput(params)

	local prop = params.caller
	local playerEnt = params.activator
	if not prop or not PHYS_ENTITIES[prop:GetClassname()] or not playerEnt then return end
	
	if not playerEnt:GetHMDAvatar() then
		Warning("prop_carry_manager: Player without HMD Avatar!\n")
		return
	end

	for idx, event in ipairs(pendingEvents) do
		if Time() > event.time + EVENT_MAX_PENDING then
			table.remove(pendingEvents, idx)

		elseif not event.prop and event.player == playerEnt then
			PropPickedUp(prop, playerEnt, event.hand)
			table.remove(pendingEvents, idx)
			return
		end
	end

	table.insert(pendingEvents, {time = Time(), player = playerEnt, prop = prop})
end


function PropPickedUpEvent(ent, params)

	if not PHYS_ENTITIES[params.item] then
		return
	end


	local playerEnt = PlayerInstanceFromIndex(params.userid)
	
	if not playerEnt:GetHMDAvatar() then
		Warning("prop_carry_manager: Player without HMD Avatar!\n")
		return
	end

	local hand = nil

	-- The hand IDs seem to match tip attachments 1 and 2 repectively
	if params.vr_tip_attachment == 1 then
	
		hand = playerEnt:GetHMDAvatar():GetVRHand(1)
	
	elseif params.vr_tip_attachment == 2 then
	
		hand = playerEnt:GetHMDAvatar():GetVRHand(0)
	end

	if not hand then
		
		local conType = playerEnt:GetVRControllerType()
	
		local text = "prop_carry_manager: Player hand entity not found! Controller type: " 
			.. tostring(conType) .. ", Tip attachment: " .. tostring(params.vr_tip_attachment) .. "\n"
		Warning(text)
		DebugDrawText(playerEnt:GetHMDAvatar():GetVRHand(0):GetAbsOrigin(), text, false, 10)
		return
	end

	if debugEnabled then
		local handSide = (hand:GetHandID() == 1) and "Right" or "Left"
		local text = "item_pickup:\nplayer: " .. playerEnt:GetUserID() .. 
			"\nhand: " .. handSide .. " (" .. hand:GetHandID() .. 
			")\nhand type: " .. hand:GetLiteralHandType() .. "\n\n" 

		for k, v in pairs(params) do 
			text = text .. k .. ": " .. tostring(v) .. "\n" 
		end
		
		DebugDrawText(hand:GetAbsOrigin(), text, false, 10)
	end

	-- No outputs on ragdolls, so approximate
	if APPROX_ENTITIES[params.item] then
		local ent = Entities:FindByClassnameNearest(params.item, hand:GetAbsOrigin(), 32)
		if ent then
			PropPickedUp(ent, playerEnt, hand)
		end
		return
	end

	for idx, event in ipairs(pendingEvents) do
		if Time() > event.time + EVENT_MAX_PENDING then
			table.remove(pendingEvents, idx)

		elseif not event.hand and event.player == playerEnt then
			PropPickedUp(event.prop, playerEnt, hand)
			table.remove(pendingEvents, idx)
			return
		end
	end

	table.insert(pendingEvents, {time = Time(), player = playerEnt, hand = hand})
end


function PropPickedUp(prop, playerEnt, usingHand)

	if propList[prop] and propList[prop].carried and propList[prop].hand ~= usingHand then

		propList[prop] = {carried = true; player = playerEnt; hand = usingHand, bothHands = true}
	else
		propList[prop] = {carried = true; player = playerEnt; hand = usingHand, bothHands = false}
	end

	if not playerList[playerEnt] then
		playerList[playerEnt] = {}
	end

	playerList[playerEnt][usingHand] = prop

	for ent, func in pairs(pickupCallbacks) do
		if IsValidEntity(ent) then func(playerEnt, usingHand, prop) end
	end
	
	--local data = {player = playerEnt,hand = usingHand, prop = prop}
	--CustomGameEventManager:Send_ServerToAllClients("prop_carry_manager_pickup", data)
end


function PropDropped(ent, params)

	local playerEnt = PlayerInstanceFromIndex(params.userid)

	if not playerEnt then return end
	
	if not playerEnt:GetHMDAvatar() then
		Warning("prop_carry_manager: Player without HMD Avatar!\n")
		return
	end

	local hand = nil

	-- The hand IDs seem to match tip attachments 1 and 2 repectively
	if params.vr_tip_attachment == 1 then
	
		hand = playerEnt:GetHMDAvatar():GetVRHand(1)
	
	elseif params.vr_tip_attachment == 2 then
	
		hand = playerEnt:GetHMDAvatar():GetVRHand(0)
	end

	if not hand then
		
		local conType = playerEnt:GetVRControllerType()
	
		Warning("prop_carry_manager: Player hand entity not found! Controller type: " 
			.. conType .. ", Tip attachment: " .. params.vr_tip_attachment .. "\n")
		return
	end

	if playerList[playerEnt] and playerList[playerEnt][hand] then
		local prop = playerList[playerEnt][hand]

		--Only drop if not held by both hands
		if propList[prop] and propList[prop].bothHands then
			propList[prop].bothHands = false

			if propList[prop].hand == hand then
				local otherHand = playerEnt:GetHMDAvatar():GetVRHand(hand:GetHandID() == 0 and 1 or 0)
				propList[prop].hand = otherHand
			end

		else
			propList[prop] = {carried = false; player = nil; hand = nil; bothHands = false}

			for ent, func in pairs(dropCallbacks) do
				if IsValidEntity(ent) then func(playerEnt, hand, prop) end
			end
		end

		playerList[playerEnt][hand] = nil
	end
end


function Update()

	for prop, _ in pairs(propList) do
		if not IsValidEntity(prop) then
			propList[prop] = nil
		end
	end

	for entClass, _ in pairs(PHYS_ENTITIES) do

		for _, prop in pairs(Entities:FindAllByClassname(entClass)) do

			if not propList[prop] then
				propList[prop] = {carried = false; player = nil; hand = nil, bothHands = false}
				prop:RedirectOutput("OnPlayerPickup", "PropPickedUpInput", thisEntity)
			end
		end
	end

	return UPDATE_INTERVAL
end


function DebugUpdate()

	if not debugEnabled then return nil end

	local interval = FrameTime()

	for prop, status in pairs(propList) do

		if IsValidEntity(prop) then

			if status.carried then
			
				DebugDrawSphere(prop:GetAbsOrigin(), Vector(0, 255, 0), 255, 4, true, interval)
				DebugDrawLine(prop:GetAbsOrigin(), status.hand:GetAbsOrigin(), 0, 255, 0, true, interval)
				
				local handSide = (status.hand:GetHandID() == 1) and "Right" or "Left"
				local debugText = prop:GetClassname() .. ":" .. prop:GetName() .. "[" .. prop:GetEntityIndex()
					.. "]\nplayer: " .. status.player:GetUserID() .. "\nhand: " .. handSide .. " (" .. status.hand:GetHandID() .. ")"
					
				DebugDrawText(prop:GetAbsOrigin(), debugText, false, interval)

			else
				DebugDrawSphere(prop:GetAbsOrigin(), Vector(255, 0, 0), 255, 4, true, interval)
			end
		end
	end

	return interval
end
