--[[
	Bow entity script

	Copyright (c) 2017-2019 Rectus

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
]]--

local playerEnt = nil
local usingHand = nil
local otherHand = nil
local handID = 0

local FIRE_RUMBLE_INTERVAL = 0.02
local FIRE_RUMBLE_TIME = 0.1
local THINK_INTERVAL = 1
local DRAW_FIRE_DELAY = 0.1
local FIRE_THINK_DELAY = 0.2
local GRAB_DISTANCE_MAX = 7
local NOCK_EDGE_OFFSET = 0.25

local bowView = nil
local drawGuide = nil
local bowString = nil
local stringGrabPos = Vector(0,0,0)
local arrowNocked = false
local releasingArrow = false
local customArrow = false
local customArrowHandReleased = false
local arrow = nil
local drawFrac = 0
local drawTime = 0
local otherHandProp = nil
local nockGuideParticle = -1
local rumbleDrawLength = 0
local fireRumbleElapsed = 0
local dropGuard = nil


local BOW_VIEW_KEYVALS = {
	classname = "prop_dynamic";
	targetname = "bow_view";
	model = "models/weapons/bow_dyn.vmdl";
	solid = "0";
	disablelowviolence = "0";
	DefaultAnim = "undrawn";
	LagCompensate = "0";
	AnimateOnServer = "1";
	ScriptedMovement = "0";
	updatechildren = "1";
	use_animgraph = "1";
	CreateNavObstacle = "0";
	forcenpcexclude = "0";
	StartDisabled = "0";
	clothScale = "1";
}

local STRING_KEYVALS = {
	classname = "prop_animinteractable";
	StartDisabled = "0";
	model = "models/weapons/bow_string_interact.vmdl";
	InitialCompletionAmount = "0";
	TargetCompletionValueA = "1";
	TargetCompletionValueB = "-1";
	TargetCompletionValueC = "-1";
	TargetCompletionValueD = "-1";
	TargetCompletionValueE = "-1";
	TargetCompletionValueF = "-1";
	TargetCompletionThreshold = "0.1";
	ObjectRequirement = "";
	OnlyRunForward = "0";
	OnlyRunBackward = "0";
	LimitForward = "1";
	LimitBackward = "0";
	LimitStop = "-1";
	StartLocked = "0";
	LimitLocked = "0";
	ReturnToCompletion = "1";
	ReturnToCompletionAmount = "0";
	ReturnToCompletionThreshold = "-1";
	ReturnToCompletionDelay = "0";
	AnimationDuration = "0.01";
	StartSound = "";
	MoveSound = "";
	StopSound = "";
	OpenCompleteSound = "";
	CloseCompleteSound = "";
	BounceSound = "";
	LockedSound = "";
	ReturnForwardMoveSound = "";
	ReturnBackwardMoveSound = "";
	InteractionBoneName = "interact";
	ReturnToCompletionStyle = "4";
	AllowGravityGunPull = "0";
	RetainVelocity = "0";
	ReactToDynamicPhysics = "0";
	IgnoreHandRotation = "1";
	IgnoreHandPosition = "0";
	DoHapticsOnBothHands = "0";
	PositiveResistance = "1";
	UpdateChildModels = "0";
	NormalizeChildModelUpdates = "0";
	ChildModelAnimgraphParameter = "";
	SetNavIgnore = "1";
	CreateNavObstacle = "0";
	ReleaseOnPlayerDamage = "0";
	BehaveAsPropPhysics = "0";
	AddToSpatialPartition = "0";
	interactAs = "";
	targetname = "bow_string";
}

local ARROW_KEYVALS = {
	classname = "prop_physics";
	targetname = "arrow";
	model = "models/weapons/arrow.vmdl";
	vscripts = "tool_bow_arrow"
}

function Precache(context)
	PrecacheModel(STRING_KEYVALS.model, context)
	PrecacheModel(ARROW_KEYVALS.model, context)
	PrecacheModel(BOW_VIEW_KEYVALS.model, context)
	PrecacheModel("models/weapons/bow_dropguard.vmdl", context)
end

function Activate(activateType)

	if not g_PropCarryManager then
		SpawnEntityFromTableSynchronous("logic_script", {vscripts = "prop_carry_manager"})
	end

	


	if activateType == ACTIVATE_TYPE_ONRESTORE -- on game load
	then		
		-- Hack to properly handle restoration from saves, 
		-- since variables written by Activate() on restore don't end up in the script scope.
		EntFireByHandle(thisEntity, thisEntity, "CallScriptFunction", "RestoreState")
	
	else
		g_PropCarryManager.RegisterPickupCallback(thisEntity, function(playerEnt, usingHand, prop) CheckPickedUp(playerEnt, usingHand, prop) end )
		g_PropCarryManager.RegisterDropCallback(thisEntity, function(playerEnt, usingHand, prop) CheckDropped(playerEnt, usingHand, prop) end )

		local entKeyvals =
		{
			model = "models/weapons/bow_dropguard.vmdl";
			interactAs = "player";
			solid = 6;
			origin = thisEntity:GetAbsOrigin();
			angles = thisEntity:GetAngles();
			targetname = "bow_dropguard";
		}
		
		dropGuard = SpawnEntityFromTableSynchronous("prop_dynamic", entKeyvals)
		dropGuard:SetParent(thisEntity, "")
		dropGuard:SetAbsScale(0.01)
	end

end


function RestoreState()

	local children = thisEntity:GetChildren()
	for idx, child in pairs(children) do
		if child:GetName() == "bow_dropguard" then
			dropGuard = child
		
		else
			child:Kill()
		end
	end
	
	thisEntity:RemoveEffects(32) --EF_NODRAW
	
	g_PropCarryManager.RegisterPickupCallback(thisEntity, function(playerEnt, usingHand, prop) CheckPickedUp(playerEnt, usingHand, prop) end )
	g_PropCarryManager.RegisterDropCallback(thisEntity, function(playerEnt, usingHand, prop) CheckDropped(playerEnt, usingHand, prop) end )
end


function CheckPickedUp(player, hand, prop)

	if prop == thisEntity then
		OnPickedUp(player, hand)
	else
		if held and hand ~= usingHand and player == playerEnt then
			otherHandProp = prop
		end
	end
end


function OnPickedUp(player, hand)
	held = true
	playerEnt = player
	usingHand = hand
	otherHand = playerEnt:GetHMDAvatar():GetVRHand(usingHand:GetHandID() == 0 and 1 or 0)
	handID = usingHand:GetHandID()
	dropGuard:SetAbsScale(1)

	if not bowView then
		SpawnViewModel()
		SpawnStringGrab()

		local paintColor = thisEntity:GetRenderColor()
		bowView:SetRenderColor(paintColor.x, paintColor.y, paintColor.z)

		thisEntity:AddEffects(32) --EF_NODRAW
		bowView:RegisterAnimTagListener(OnAnimTag)
	end
	bowString:RemoveEffects(32) --EF_NODRAW

	thisEntity:SetThink(BowThink, "bow_think", 0)
end


--[[function OnAnimTag(tagName, status)
	if tagName == "arrowRelease" and status < 2 and releasingArrow then
		releasingArrow = false
		FireArrow()
		
	end
end]]


function CheckDropped(player, hand, prop)

	if held and prop == thisEntity and player == playerEnt and hand == usingHand then
		OnDropped()
	end
end


function OnDropped()

	playerEnt = nil
	usingHand = nil
	handID = -1
	held = false
	dropGuard:SetAbsScale(0.01)

	bowString:AddEffects(32) --EF_NODRAW

	return true
end


function OnStringGrabbed(params)

	if params.caller ~= bowString then return end

	bowString:AddEffects(32) --EF_NODRAW

	drawPulling = true
	drawTime = Time()

	if not arrowNocked then
		SpawnArrow()
		customArrow = false
		arrowNocked = true
	end

	if IsValidEntity(otherHand) then
		local idx = bowString:ScriptLookupAttachment("grab_pos")
		local grabPos = bowString:GetAttachmentOrigin(idx)
		stringGrabPos = otherHand:TransformPointWorldToEntity(grabPos)
	else
		stringGrabPos = Vector(0,0,0)
	end
end


function OnStringReleased(params)
	drawPulling = false

	if bowView then
		bowView:SetGraphParameterBool("isDrawing", false)
		bowView:SetLocalOrigin(Vector(0,0,0))
		bowView:SetLocalAngles(0, 0, 0)
	end

	if arrowNocked
	then
		if Time() > drawTime + DRAW_FIRE_DELAY
		then
			releasingArrow = true
			StartSoundEvent("Custom_Weapon.Bow_String", thisEntity)
			EntFireByHandle(thisEntity, bowString, "Disable")
			thisEntity:SetThink(FireArrow, "fire", FrameTime() * 3)
			thisEntity:SetThink(OnDoneFiring, "done_firing", 0.5)
		else
			if not customArrow then
				arrow:Kill()
			elseif arrow:GetMoveParent() == bowView then
				arrow:SetParent(nil, nil)
			end
			arrow = nil
			OnDoneFiring()
		end
		arrowNocked = false

	else
		OnDoneFiring()
	end
end


function OnDoneFiring()

	--[[if releasingArrow then -- Failed to release arrow on anim tag
		print("Failed to release arrow in time.")
		releasingArrow = false
		FireArrow()
	end]]

	bowString:RemoveEffects(32) --EF_NODRAW
	EntFireByHandle(thisEntity, bowString, "Enable")

	local idx = thisEntity:ScriptLookupAttachment("arrow_back")
	local stringPos = thisEntity:GetAttachmentOrigin(idx)
	bowString:SetAbsOrigin(stringPos)

	bowView:SetGraphParameterFloat("drawFactor", 0)

end


function BowThink()

	if not held then return nil end

	if not arrowNocked and not drawPulling then
		CheckArrows()
	end

	if drawPulling
	then
		local idx = thisEntity:ScriptLookupAttachment("pivot")
		local pivotOrigin = thisEntity:GetAttachmentOrigin(idx)
		local grabPos = otherHand:TransformPointEntityToWorld(stringGrabPos)

		--DebugDrawLine(pivotOrigin, grabPos, 0, 255, 0, false, FrameTime() * THINK_INTERVAL)

		local drawVec = (pivotOrigin - grabPos)
		local drawLength = drawVec:Length()

		if drawLength < 10
		then
			drawLength = 0
		else
			drawLength = drawLength - 10
		end

		drawFrac = abs(drawLength / 20.5)

		if drawLength > 0
		then
			bowView:SetGraphParameterFloat("drawFactor", drawFrac)
			bowView:SetGraphParameterBool("isDrawing", true)
			bowView:SetGraphLookTarget(grabPos)
		else
			bowView:SetGraphParameterFloat("drawFactor", 0)
			bowView:SetGraphParameterBool("isDrawing", true)
			local idx = thisEntity:ScriptLookupAttachment("arrow_back")
			bowView:SetGraphLookTarget(thisEntity:GetAttachmentOrigin(idx))
		end

		if abs(drawLength - rumbleDrawLength) > 0.5 then
			otherHand:FireHapticPulse(1)
			usingHand:FireHapticPulse(0)
			rumbleDrawLength = drawLength
		end
	end

	return FrameTime() * THINK_INTERVAL
end


function CheckArrows()

	if not otherHandProp then return end

	local carriedProp = g_PropCarryManager.GetPropInHand(playerEnt, otherHand)

	if not IsValidEntity(otherHandProp) or carriedProp ~= otherHandProp then

		ParticleManager:DestroyParticle(nockGuideParticle, true)
		nockGuideParticle = -1

		if carriedProp then
			otherHandProp = carriedProp
		else
			otherHandProp = nil
			return
		end
	end

	local propNockOrigin = GetNockPoint(otherHandProp)
	local idx = bowView:ScriptLookupAttachment("arrow_back")
	local stringPos = bowView:GetAttachmentOrigin(idx)

	--DebugDrawLine(propNockOrigin, stringPos, 0, 0, 255, false, FrameTime() * THINK_INTERVAL)

	local propDist = (stringPos - propNockOrigin):Length()

	if propDist > 16 and nockGuideParticle ~= -1 then
		ParticleManager:DestroyParticle(nockGuideParticle, true)
		nockGuideParticle = -1

	elseif propDist > 2 then

		if nockGuideParticle == -1 then
			nockGuideParticle = ParticleManager:CreateParticle("particles/tools/bow_nock_guide.vpcf",
				PATTACH_CUSTOMORIGIN, bowView)
			ParticleManager:SetParticleControlEnt(nockGuideParticle, 0, bowView,
				PATTACH_POINT_FOLLOW , "arrow_back", Vector(0,0,0), true)

			ParticleManager:SetParticleControl(nockGuideParticle, 3, Vector(1, 0.6, 0))
		end

		ParticleManager:SetParticleControl(nockGuideParticle, 1, propNockOrigin)

	else
		ParticleManager:DestroyParticle(nockGuideParticle, true)
		nockGuideParticle = -1
		NockProp(otherHandProp)
		thisEntity:SetThink(AdjustNockedProp, "nock_adjust", 0.05)
	end
end


function NockProp(prop)

	if arrow and IsValidEntity(arrow) then
		arrow:SetParent(nil, nil)
	end

	arrow = prop

	arrow:SetParent(bowView, "arrow_back")
	arrow:SetLocalOrigin(Vector(0,0,0))
	arrow:SetLocalAngles(0, 0, 0)

	local nockOrigin, nockAngles = GetNockPoint(arrow)

	--DebugDrawLine(arrow:GetCenter(), arrow:TransformPointEntityToWorld(nockOrigin), 0, 255, 0, false, 20)
	--DebugDrawLine(arrow:TransformPointEntityToWorld(nockOrigin), arrow:TransformPointEntityToWorld(nockOrigin) + nockAngles:Forward() * 10, 255, 255, 0, false, 20)

	arrow:SetLocalOrigin(-(arrow:TransformPointWorldToEntity(nockOrigin)))
	arrow:SetLocalAngles(nockAngles.x, nockAngles.y, nockAngles.z)

	arrowNocked = true
	customArrow = true

end


function AdjustNockedProp()

	if not arrowNocked or not IsValidEntity(arrow) then return nil end

	local nockOrigin, nockAngles = GetNockPoint(arrow)
	arrow:SetLocalOrigin(-(arrow:TransformPointWorldToEntity(nockOrigin)))
	arrow:SetLocalAngles(nockAngles.x, nockAngles.y, nockAngles.z)

	if g_PropCarryManager.GetPropInHand(playerEnt, otherHand) == arrow then
		return 0.05

	elseif customArrowHandReleased then
		customArrowHandReleased = false
		return nil
	else
		customArrowHandReleased = true
		return 0.05
	end
end


function GetNockPoint(entity)

	local attachIndex = entity:ScriptLookupAttachment("arrow_nock")

	if attachIndex > 0 then

		local nockOrigin = entity:GetAttachmentOrigin(attachIndex)
		local ang = entity:GetAttachmentAngles(attachIndex)
		local nockAngles = RotationDelta(entity:GetAngles(), QAngle(ang.x, ang.y, ang.z))

		return nockOrigin, nockAngles
	end

	-- Approximate if no attachment point is available on the entity

	local boundMin = entity:GetBoundingMins() * entity:GetAbsScale()
	local boundMax = entity:GetBoundingMaxs() * entity:GetAbsScale()

	local xBounds = abs(boundMax.x - boundMin.x)
	local yBounds = abs(boundMax.y - boundMin.y)
	local zBounds = abs(boundMax.z - boundMin.z)

	local offset = nil
	local angles = nil

	if xBounds > max(yBounds, zBounds) then

		offset = Vector(-xBounds / 2, -(yBounds / 2 - NOCK_EDGE_OFFSET), -(zBounds / 2 - NOCK_EDGE_OFFSET))
		angles = QAngle(0, 0, 0)

	elseif yBounds > zBounds then

		offset = Vector(-(xBounds / 2 - NOCK_EDGE_OFFSET), -yBounds / 2, -(zBounds / 2 - NOCK_EDGE_OFFSET))
		angles = QAngle(0, 90, 0)
	else
		offset = Vector(-(xBounds / 2 - NOCK_EDGE_OFFSET), -(yBounds / 2 - NOCK_EDGE_OFFSET), -zBounds / 2)
		angles = QAngle(90, 0, 0)
	end

	local point = entity:GetCenter() + RotatePosition(Vector(0,0,0), entity:GetAngles(), offset)
	return point, angles
end


function SpawnArrow()
	local keyvals = vlua.clone(ARROW_KEYVALS)
	keyvals.targetname = DoUniqueString(keyvals.targetname)
	arrow = SpawnEntityFromTableSynchronous(keyvals.classname, keyvals)
	arrow:SetParent(bowView, "arrow_back")
	arrow:SetLocalOrigin(Vector(0,0,0))
	arrow:SetLocalAngles(0, 0, 0)

end


function SpawnStringGrab()
	bowString = SpawnEntityFromTableSynchronous(STRING_KEYVALS.classname, STRING_KEYVALS)
	bowString:SetParent(bowView, "!bonemerge")
	bowString:SetLocalOrigin(Vector(0,0,0))
	bowString:SetLocalAngles(0, 0, 0)
	bowString:RedirectOutput("OnInteractStart", "OnStringGrabbed", thisEntity)
	bowString:RedirectOutput("OnInteractStop", "OnStringReleased", thisEntity)
end


function SpawnViewModel()
	bowView = SpawnEntityFromTableSynchronous(BOW_VIEW_KEYVALS.classname, BOW_VIEW_KEYVALS)
	bowView:SetParent(thisEntity, "")
	bowView:SetLocalOrigin(Vector(0,0,0))
	bowView:SetLocalAngles(0, 0, 0)
	bowView:SetGraphParameterFloat("drawFactor", 0)
	bowView:SetGraphParameterBool("isDrawing", false)
end


function FireArrow()

	if not arrow or not IsValidEntity(arrow) or arrow:GetMoveParent() ~= bowView then
		arrow = nil
		arrowNocked = false
		return
	end
	
	local massFac = 1

	local arrowMass = arrow:GetMass()
	if arrowMass > 1 then
		massFac = (1 - arrowMass * 0.5 / (arrowMass * 0.5 + 1))
	end

	if otherHand then
		otherHand:FireHapticPulse(2)
	end
	thisEntity:SetThink(FireRumble, "fire_rumble", 0.0)

	local idx = bowView:ScriptLookupAttachment("arrow_fire_pos")
	local fireDir = bowView:GetAttachmentForward(idx)
	local fireDirLocal = arrow:TransformPointWorldToEntity(fireDir)
	
	-- Use direction on arrow for fire direction if available.
	local idx = arrow:ScriptLookupAttachment("arrow_nock")

	if idx > 0 then
		fireDir = arrow:GetAttachmentForward(idx)
		fireDirLocal = arrow:TransformPointWorldToEntity(fireDir)
	end

	arrow:SetParent(nil, nil)
	
	arrow:ApplyAbsVelocityImpulse(fireDir * 3000  * drawFrac * massFac)
	--arrow:ApplyLocalAngularVelocityImpulse(fireDirLocal:Normalized() * 1000 * drawFrac)
	local scope = arrow:GetPrivateScriptScope()
	if scope then
		if scope.EnableDamage then
			arrow:GetOrCreatePrivateScriptScope():EnableDamage(playerEnt)
		end

		if scope.OnPickedUp and arrow:GetModelName() == "models/third_party/props/toys/neko_plushie.vmdl" then
			-- Faart!
			scope:OnPickedUp(nil, nil)
		end

	end

	if arrow:GetClassname() == "item_hlvr_grenade_frag" then
		EntFireByHandle(thisEntity, arrow, "ArmGrenade")
	end

	arrow = nil
end


function FireRumble(this)
	if usingHand
	then
		usingHand:FireHapticPulse(2)
	end

	fireRumbleElapsed = fireRumbleElapsed + FIRE_RUMBLE_INTERVAL
	if fireRumbleElapsed >= FIRE_RUMBLE_TIME
	then
		fireRumbleElapsed = 0
		return nil
	end

	return FIRE_RUMBLE_INTERVAL
end
