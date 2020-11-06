--[[
	Gravity gun script.

	Copyright (c) 2016-2020 Rectus

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


local PUNT_IMPULSE = 1000
local MAX_PULL_IMPULSE = 2500
local MAX_PULLED_VELOCITY = 500
local PULL_EASE_DISTANCE = 32.0
local CARRY_DISTANCE = 16
local CARRY_GLUE_DISTANCE = 6
local TRACE_DISTANCE = 1024
local TRACE_RADIUS = 3
local OBJECT_PULL_INTERVAL = 1
local BEAM_TRACE_INTERVAL = 1
local PUNT_DISTANCE = 512
local CLAMP_VEL_IMPULSE = 1
local COUNTER_IMPULSE_FACTOR = 0.1
local COUNTER_IMPULSE_FACTOR_CLOSE = 0.3
local ROTATION_DAMPING_FACTOR = 0.05
local GRAVITY_TORQUE_FACTOR = 0.3
local PULL_TORQUE_FACTOR = 1

local animEnt = nil
local gripEnt = nil
local playerEnt = nil
local dropGuard = nil
local handID = 1
local handEnt = nil
local pulledObject = nil
local pulledObjectLocalPos = Vector(0,0,0)
local pulledObjectInPuntRange = false
local isCarrying = false
local laserParticle = -1
local beamParticle = -1
local idleParticle = -1
local activateParticle = -1
local isTargeting = false
local showLaser = false
local laserButton = false
local clawsOpen = false
local clawSoundTime = 0
local secondHandGrabbing = false
local secondHandWasIdle = false

local pickupTime = 0

local rumbleDuration = 0
local rumbleInterval = 0
local rumbleIntensity = 0
local rumbleHand = nil


local gripPos = 0.5
local gripHeld = false
local GRIP_STATE_PULL = 1
local GRIP_STATE_NEUTRAL = 2
local GRIP_STATE_WAIT_DROP = 3
local GRIP_STATE_PUNT = 4
local gripState = GRIP_STATE_NEUTRAL
local gripZeroTime = 0
local GRIP_RELEASE_DELAY = 0.3


local pulledEntities =
{
	prop_physics = true;
	prop_physics_override = true;
	prop_physics_interactive = true;
	simple_physics_prop = true;
	prop_ragdoll = true;
	func_physbox = true;
	item_hlvr_grenade_frag = true;
	prop_door_rotating_physics = true;

}

local propClasses =
{
	prop_physics = true;
	prop_physics_override = true;
	prop_physics_interactive = true;
	simple_physics_prop = true;
	prop_ragdoll = true;
	prop_door_rotating_physics = true;
}


local ANIM_KEYVALS =
{
	classname = "prop_dynamic";
	model = "models/tools/gravity_gun/gravity_gun_body_anim.vmdl";
	DefaultAnim = "idle";
	use_animgraph = "1";
	targetname = "grav_gun_anim";
}

local GRIP_KEYVALS =
{
	classname = "prop_animinteractable";
	model = "models/tools/gravity_gun/gravity_gun_body_grip.vmdl";
	InitialCompletionAmount = ".5";
	TargetCompletionValueA = "1";
	TargetCompletionValueB = "0";
	TargetCompletionValueC = "-1";
	TargetCompletionValueD = "-1";
	TargetCompletionValueE = "-1";
	TargetCompletionValueF = "-1";
	TargetCompletionThreshold = "0.01";
	ReturnToCompletion = "1";
	ReturnToCompletionAmount = "0.5";
	ReturnToCompletionThreshold = "-1";
	ReturnToCompletionDelay = "0";
	AnimationDuration = "0.1";
	InteractionBoneName = "left_grip";
	ReturnToCompletionStyle = "0";
	AllowGravityGunPull = "0";
	RetainVelocity = "0";
	ReactToDynamicPhysics = "0";
	IgnoreHandRotation = "0";
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
	targetname = "grav_gun_grip";
}


function Precache(context)
	PrecacheResource("particle", "particles/tools/gravity_gun_laser_pointer.vpcf", context)
	PrecacheResource("particle", "particles/tools/gravity_gun_beam.vpcf", context)
	PrecacheResource("particle", "particles/tools/gravity_gun_punt.vpcf", context)
	PrecacheResource("particle", "particles/tools/gravity_gun_idle.vpcf", context)
	PrecacheResource("particle", "particles/tools/gravity_gun_activate.vpcf", context)
	
	PrecacheModel("models/tools/gravity_gun/gravity_gun_body_anim.vmdl", context)
	PrecacheModel("models/tools/gravity_gun/gravity_gun_body_grip.vmdl", context)
	PrecacheModel("models/tools/gravity_gun/gravity_gun_dropguard.vmdl", context)
	
end

function Activate(activateType)

	if activateType == ACTIVATE_TYPE_ONRESTORE -- on game load
	then	
		-- Make sure there aren't any old children left on load.
		for _, ent in pairs(thisEntity:GetChildren()) do
			ent:Kill()
		end
	end
	
	EntFireByHandle(thisEntity, thisEntity, "CallScriptFunction", "SpawnParts")
end


function SpawnParts()

	gripEnt = SpawnEntityFromTableSynchronous(GRIP_KEYVALS.classname, GRIP_KEYVALS)
	gripEnt:SetParent(thisEntity, "")
	gripEnt:SetLocalOrigin(Vector(0,0,0))
	gripEnt:SetLocalAngles(0,0,0)
	gripEnt:RedirectOutput("Position", "UpdateGrip", thisEntity)
	gripEnt:RedirectOutput("OnInteractStop", "OnHandleReleased", thisEntity)
	gripEnt:RedirectOutput("OnInteractStart", "OnHandleGrabbed", thisEntity)
	
	
	animEnt = SpawnEntityFromTableSynchronous(ANIM_KEYVALS.classname, ANIM_KEYVALS)
	animEnt:SetParent(thisEntity, "")
	animEnt:SetLocalOrigin(Vector(0,0,0))
	animEnt:SetLocalAngles(0,0,0)
	animEnt:SetSequence("idle")
	
	
	local entKeyvals =
	{
		model = "models/tools/gravity_gun/gravity_gun_dropguard.vmdl";
		interactAs = "player";
		solid = 6;
		origin = thisEntity:GetAbsOrigin();
		angles = thisEntity:GetAngles();
	}
	
	dropGuard = SpawnEntityFromTableSynchronous("prop_dynamic", entKeyvals)
	dropGuard:SetParent(thisEntity, "")
	dropGuard:SetAbsScale(0.01)
end


function UpdateGrip(params)

	if not playerEnt then
		playerEnt = Entities:GetLocalPlayer()
		if playerEnt:GetHMDAvatar() then
			handEnt = playerEnt:GetHMDAvatar():GetVRHand(1)
		end
	end

	local grip = params.caller
	local pos = grip:GetCycle()
	--DebugDrawText(thisEntity:GetAbsOrigin(), "pos: " .. tostring(pos), false, FrameTime())

	if gripHeld and ((gripPos < 0.65 and pos >= 0.65) or gripPos > 0.15 and pos <= 0.15) then
		playerEnt:GetHMDAvatar():GetVRHand(1):FireHapticPulse(2)
		playerEnt:GetHMDAvatar():GetVRHand(0):FireHapticPulse(2)
	end
	gripPos = pos

	if pos > 0.65 then
		if gripState ~= GRIP_STATE_PULL then
			if gripState ~= GRIP_RELEASE_DELAY then
				StartPull()
			end
			gripState = GRIP_STATE_PULL
		end

	elseif pos < 0.15 then
		if gripState ~= GRIP_STATE_PUNT then
			gripState = GRIP_STATE_PUNT
			Punt()
		end

	elseif gripState == GRIP_STATE_PULL and isCarrying then
		gripState = GRIP_STATE_WAIT_DROP
		gripZeroTime = Time()

	elseif gripState == GRIP_STATE_WAIT_DROP then
		if Time() > gripZeroTime + GRIP_RELEASE_DELAY then
			gripState = GRIP_STATE_NEUTRAL
			EndPull()
		end
	elseif gripState == GRIP_STATE_PULL or gripState == GRIP_STATE_PUNT then
		gripState = GRIP_STATE_NEUTRAL
		EndPull()
	end
	
	local handType = playerEnt:GetHMDAvatar():GetVRHand(0):GetLiteralHandType()

	local button = playerEnt:IsDigitalActionOnForHand(handType, 16)
	
	if button and not laserButton then
		if not showLaser then
			showLaser = true
			StartLaser()
		else
			showLaser = false
			StopLaser()
		end
	end
	laserButton = button
end


function OnHandleGrabbed()
	thisEntity:SetThink(UpdateCarriedIdle, "update_beam", FrameTime() * BEAM_TRACE_INTERVAL)
	isTargeting = true
	gripHeld = true
	StartLaser()
	dropGuard:SetAbsScale(1)
end


function OnHandleReleased()
	if not isCarrying then
		gripState = GRIP_STATE_NEUTRAL
		EndPull()
		animEnt:SetGraphParameterFloat("open", 0.0)
	end

	isTargeting = false
	gripHeld = false
	StopLaser()
	dropGuard:SetAbsScale(0.01)
end


function StartLaser()

	if laserParticle > -1 then
		ParticleManager:DestroyParticle(laserParticle, true)
		laserParticle = -1
	end

	if not showLaser then
		return
	end

	local beamPos = GetAttachment("beam")
	laserParticle = ParticleManager:CreateParticle("particles/tools/gravity_gun_laser_pointer.vpcf",
		PATTACH_CUSTOMORIGIN, thisEntity)
	ParticleManager:SetParticleControlEnt(laserParticle, 0, thisEntity,
		PATTACH_POINT_FOLLOW, "beam", Vector(0,0,0), false)
	ParticleManager:SetParticleControl(laserParticle, 1, beamPos)

	-- Control point 3 sets the color of the beam.
	ParticleManager:SetParticleControl(laserParticle, 3, Vector(0.5, 0.5, 0.8))
end

function StopLaser()

	if laserParticle > -1 then
		ParticleManager:DestroyParticle(laserParticle, true)
		laserParticle = -1
	end
end


function StartBeam(endpoint)

	if beamParticle > -1 then
		ParticleManager:DestroyParticle(beamParticle, false)
	end

	beamParticle = ParticleManager:CreateParticle("particles/tools/gravity_gun_beam.vpcf",
	PATTACH_CUSTOMORIGIN_FOLLOW, thisEntity)
	ParticleManager:SetParticleControlEnt(beamParticle, 0, animEnt,
		PATTACH_POINT_FOLLOW, "beam", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(beamParticle, 1, animEnt,
		PATTACH_POINT_FOLLOW, "muzzle", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(beamParticle, 2, animEnt,
		PATTACH_POINT_FOLLOW, "pull_pos", Vector(0,0,0), false)

	--ParticleManager:SetParticleControlEnt(beamParticle, 3, animEnt,
		--PATTACH_CUSTOMORIGIN_FOLLOW, nil, endpoint, false)
	ParticleManager:SetParticleControl(beamParticle, 3, endpoint)

	ParticleManager:SetParticleControlEnt(beamParticle, 4, animEnt,
		PATTACH_POINT_FOLLOW, "emitter_top", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(beamParticle, 5, animEnt,
		PATTACH_POINT_FOLLOW, "emitter_left", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(beamParticle, 6, animEnt,
		PATTACH_POINT_FOLLOW, "emitter_right", Vector(0,0,0), false)

end


function StopBeam()

	if beamParticle > -1 then
		ParticleManager:DestroyParticle(beamParticle, false)
		beamParticle = -1
	end
end


function StartPuntParticle(endpoint)

	local puntParticle = ParticleManager:CreateParticle("particles/tools/gravity_gun_punt.vpcf",
	PATTACH_ABSORIGIN, thisEntity)
	ParticleManager:SetParticleControlEnt(puntParticle, 0, animEnt,
		PATTACH_POINT_FOLLOW, "beam", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(puntParticle, 1, animEnt,
		PATTACH_POINT_FOLLOW, "muzzle", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(puntParticle, 2, animEnt,
		PATTACH_POINT_FOLLOW, "pull_pos", Vector(0,0,0), false)

	ParticleManager:SetParticleControl(puntParticle, 3, endpoint)

	ParticleManager:SetParticleControlEnt(puntParticle, 4, animEnt,
		PATTACH_POINT_FOLLOW, "emitter_top", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(puntParticle, 5, animEnt,
		PATTACH_POINT_FOLLOW, "emitter_left", Vector(0,0,0), false)
	ParticleManager:SetParticleControlEnt(puntParticle, 6, animEnt,
		PATTACH_POINT_FOLLOW, "emitter_right", Vector(0,0,0), false)
end


function StartPull()



	if activateParticle == -1 then
		activateParticle =  ParticleManager:CreateParticle("particles/tools/gravity_gun_activate.vpcf",
			PATTACH_POINT_FOLLOW, animEnt)
		ParticleManager:SetParticleControlEnt(activateParticle, 1, animEnt,
			PATTACH_POINT_FOLLOW, "muzzle", Vector(0,0,0), false)
	end

	local hitEnt, hitPos = TracePullables(TRACE_DISTANCE)

	if hitEnt
	then
		SetupPull(hitEnt, hitPos)
	else
		RumbleController(1, 0.2, 10, handEnt)
		StartSoundEvent("Physcannon.Dryfire", thisEntity)
		animEnt:SetGraphParameterFloat("pull", 0.8)
		thisEntity:SetThink(TryPull, "try_pull", 0.1)
	end
end


function TryPull()
	if gripState ~= GRIP_STATE_PULL or pulledObject then return nil end

	local hitEnt, hitPos = TracePullables(TRACE_DISTANCE)

	if hitEnt
	then
		SetupPull(hitEnt, hitPos)
		return nil
	end

	return 0.1
end


function SetupPull(hitEnt, hitPos)
	-- Trace a grab position on the surface of the entity
	local trace =
	{
		startpos = hitPos,
		endpos = hitEnt:GetCenter(),
		ent = hitEnt
	}
	TraceCollideable(trace)
	if trace.hit then
		hitPos = trace.pos
	end

	pulledObject = hitEnt
	pulledObjectLocalPos = hitEnt:TransformPointWorldToEntity(hitPos)

	print("Gravity gun grabbed entity: " .. hitEnt:GetDebugName())
	thisEntity:SetThink(PullObjectFrame, "gravitygun_pull", FrameTime() * OBJECT_PULL_INTERVAL)

	animEnt:SetGraphParameterFloat("open", 1)
	RumbleController(1, 0.3, 50, handEnt)
	StartSoundEvent("Physcannon.Charge", thisEntity)
	animEnt:SetGraphParameterFloat("strain", 0.5)
	StartBeam(hitPos)
	StopLaser()
end


function EndPull()

	if activateParticle > -1 then
		ParticleManager:DestroyParticle(activateParticle, false)
		activateParticle = -1
	end

	if pulledObject
	then
		pulledObject = nil
		StopSoundEvent("Physcannon.Charge", thisEntity)
		StopSoundEvent("Physcannon.HoldLoop", thisEntity)
		StartSoundEvent("Physcannon.Drop", thisEntity)
		animEnt:SetGraphParameterFloat("needle", 0)
		animEnt:SetGraphParameterFloat("strain", 0)
		animEnt:SetGraphParameterFloat("pull", 0)
		StopBeam()
		RumbleController(1, 0.15, 40, handEnt)
		thisEntity:SetThink(StartLaser, "laser_delay", 0.1)
		thisEntity:SetThink(UpdateCarriedIdle, "update_beam", FrameTime() * BEAM_TRACE_INTERVAL)
	end

	if isCarrying
	then
		isCarrying = false
		StartLaser()
	end
end


function Punt()
	local puntObject
	local puntPos
	if (isCarrying or pulledObjectInPuntRange) and pulledObject and IsValidEntity(pulledObject) then
		puntPos = pulledObject:TransformPointEntityToWorld(pulledObjectLocalPos)
		puntObject = pulledObject
		pulledObject = nil
		isCarrying = false
		StopSoundEvent("Physcannon.HoldLoop", thisEntity)
		thisEntity:SetThink(UpdateCarriedIdle, "update_beam", FrameTime() * BEAM_TRACE_INTERVAL)
		StopBeam()

	else
		local ent, pos = TracePullables(PUNT_DISTANCE, true)

		if ent and ent:GetClassname() ~= "worldent" then
			puntObject = ent
			puntPos = pos
			StartPuntParticle(pos)
		else
			RumbleController(1, 0.2, 10, handEnt)
			StartSoundEvent("Physcannon.Dryfire", thisEntity)
			return
		end
	end

	puntObject:ApplyAbsVelocityImpulse(thisEntity:GetAngles():Forward() * PUNT_IMPULSE)
	thisEntity:ApplyAbsVelocityImpulse(-(thisEntity:GetAngles():Forward() * PUNT_IMPULSE))

	if not pulledEntities[puntObject] then
		local damage = CreateDamageInfo(thisEntity, playerEnt, thisEntity:GetAngles():Forward() * 5, puntPos, 5, DMG_PHYSGUN)
		puntObject:TakeDamage(damage)
		DestroyDamageInfo(damage)
	end

	StartPuntParticle(puntPos)
	animEnt:SetGraphParameterFloat("needle", 0)
	animEnt:SetGraphParameterFloat("pull", 0)
	animEnt:SetGraphParameterFloat("open", 1)
	animEnt:SetGraphParameterFloat("strain", 0)
	animEnt:SetGraphParameterBool("punt", true)
	RumbleController(2, 0.4, 120, handEnt)
	StartSoundEvent("Physcannon.Launch", thisEntity)
	thisEntity:SetThink(StartLaser, "laser_delay", 0.3)

	if IsValidEntity(puntObject) and puntObject:GetPrivateScriptScope() then
		local scope = puntObject:GetPrivateScriptScope()
		if scope.EnableDamage then
			scope:EnableDamage(playerEnt)
		end
	end
end


function UpdateCarriedIdle()
	if (not isTargeting) or isCarrying or pulledObject
	then
		return nil
	end

	local ent, pos, beamHit = TracePullables(TRACE_DISTANCE)

	if beamHit then

		if ent then
			SetClawsOpen(true)
			
			local pullPos = GetAttachment("pull_pos")
			if (pos - pullPos):Length() <= PUNT_DISTANCE then
				ParticleManager:SetParticleControl(laserParticle, 3, Vector(0.8, 0.4, 0.25))
			else
				ParticleManager:SetParticleControl(laserParticle, 3, Vector(0.8, 0.8, 0.5))
			end
		else
			SetClawsOpen(false)
			ParticleManager:SetParticleControl(laserParticle, 3, Vector(0.5, 0.5, 0.8))
		end

		ParticleManager:SetParticleControl(laserParticle, 1, pos)

	else
		SetClawsOpen(false)
		ParticleManager:SetParticleControl(laserParticle, 3, Vector(0.4, 0.4, 0.6))
		ParticleManager:SetParticleControl(laserParticle, 1, pos)
	end

	return FrameTime() * BEAM_TRACE_INTERVAL
end


function SetClawsOpen(open)
	if open then
		animEnt:SetGraphParameterFloat("open", 0.5)
		if clawsOpen == false then

			if clawSoundTime + 0.5 < Time() then
				clawSoundTime = Time()
				clawsOpen = true
				RumbleControllerLowPriority(0, 0.4, 30, handEnt)
				StartSoundEvent("Physcannon.ClawsOpen", thisEntity)
			end
		end
	else
		animEnt:SetGraphParameterFloat("open", 0.0)
		if clawsOpen == true then

			if clawSoundTime + 0.5 < Time() then
				clawSoundTime = Time()
				clawsOpen = false
				RumbleControllerLowPriority(0, 0.4, 25, handEnt)
				StartSoundEvent("Physcannon.ClawsClose", thisEntity)
			end
		end
	end
end


function TracePullables(distance, allEnts)

	local muzzlePos, MuzzleAng = GetAttachment("muzzle")

	local traceTable =
	{
		startpos = muzzlePos + MuzzleAng:Forward() * TRACE_RADIUS * 2;
		endpos = muzzlePos + MuzzleAng:Forward() * distance;
		ignore = thisEntity;
		min = Vector(-TRACE_RADIUS, -TRACE_RADIUS, -TRACE_RADIUS);
		max = Vector(TRACE_RADIUS, TRACE_RADIUS, TRACE_RADIUS);
	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 255, 0, 0, false, 0.1)
	TraceHull(traceTable)

	if traceTable.hit
	then
		--DebugDrawLine(traceTable.startpos, GetMuzzlePos() + RotatePosition(Vector(0,0,0),
			--RotateOrientation(thisEntity:GetAngles(), MUZZLE_ANGLES_OFFSET), Vector(TONGUE_MAX_DISTANCE * traceTable.fraction, 0, 0)), 0, 255, 255, false, 0.5)

		if traceTable.enthit and traceTable.enthit ~= thisEntity then

			local ent = traceTable.enthit

			while ent:GetMoveParent() do
				ent = ent:GetMoveParent()
			end

			if allEnts or pulledEntities[ent:GetClassname()] ~= nil
			then
				return ent, traceTable.pos, true
			end
		end

		local entities = Entities:FindAllInSphere(traceTable.pos, TRACE_RADIUS * 2)
		for _, ent in pairs(entities)
		do
			if ent ~= thisEntity and (allEnts or pulledEntities[ent:GetClassname()] ~= nil)
			then
				return ent, traceTable.pos, true
			end
		end
	end

	traceTable =
	{
		startpos = muzzlePos;
		endpos = muzzlePos + MuzzleAng:Forward() * distance;
		ignore = thisEntity;
	}

	TraceLine(traceTable)

	if traceTable.hit
	then
		if traceTable.enthit and traceTable.enthit ~= thisEntity then

			local ent = traceTable.enthit

			while ent:GetMoveParent() do
				ent = ent:GetMoveParent()
			end

			if (allEnts or pulledEntities[ent:GetClassname()] ~= nil) then
				return ent, traceTable.pos, true
			end
		end

		local entities = Entities:FindAllInSphere(traceTable.pos, TRACE_RADIUS * 2)
		for _, ent in pairs(entities)
		do
			if ent ~= thisEntity and (allEnts or pulledEntities[ent:GetClassname()] ~= nil)
			then
				return ent, traceTable.pos, true
			end
		end

		return nil, traceTable.endpos, true
	end

	return nil, traceTable.endpos, false
end


function PullObjectFrame()

	if not pulledObject or not IsValidEntity(pulledObject)
	then
		if pulledObject then
			thisEntity:SetThink(TryPull, "try_pull", 0.1)
		end
		return nil
	end

	local deltaT = FrameTime() * OBJECT_PULL_INTERVAL
	local mass = RemapVal(pulledObject:GetMass(), 0, 100, 0, 1)

	local objectPos = pulledObject:TransformPointEntityToWorld(pulledObjectLocalPos / pulledObject:GetAbsScale())
	ParticleManager:SetParticleControl(beamParticle, 3, objectPos)


	local pullPos, pullAng = GetAttachment("pull_pos")
	pullPos = pullPos + pullAng:Forward() * GetMaxRadius(pulledObject)
	local pullVec = (pullPos - objectPos)
	local distance = pullVec:Length()
	local pullDir = pullVec:Normalized()

	local m = GetAttachment("muzzle")
	--DebugDrawLine(pullPos, objectPos, 255, 0, 255, true, deltaT)

	pulledObjectInPuntRange = distance >= PUNT_DISTANCE

	local pose = mass * RemapVal(distance, 0, TRACE_DISTANCE, 0, 1)
	animEnt:SetGraphParameterFloat("pull", pose)

	local rumbleFreq = RemapVal(distance, 0, TRACE_DISTANCE, 70, 20)
	if gripHeld and isCarrying then
		RumbleControllerLowPriority(0, 0.2, rumbleFreq + 20, handEnt)
	elseif gripHeld then
		RumbleControllerLowPriority(0, 0.2, rumbleFreq, handEnt)
	end

	if distance < CARRY_DISTANCE
	then
		if not isCarrying
		then
			isCarrying = true
			StartCarrying()
		end
	end

	local pullFactor = distance / PULL_EASE_DISTANCE
	local pullGravFactor = RemapValClamped(distance, TRACE_DISTANCE / 2, PULL_EASE_DISTANCE, 0, 1)

	local gravityAcc = Convars:GetInt("sv_gravity")
	local gravImpulse = Vector(0, 0, gravityAcc * pullGravFactor * deltaT)

	local pullMassFactor = RemapValClamped(pulledObject:GetMass(), 0, 100, 1, 0.1)

	local pullImpulse =  pullDir * MAX_PULL_IMPULSE * math.log(1 + pullFactor) * deltaT * pullMassFactor


	pulledObject:ApplyAbsVelocityImpulse(pullImpulse + gravImpulse)
	thisEntity:ApplyAbsVelocityImpulse(-pullImpulse * 0.5)

	local pose = RemapVal(MAX_PULL_IMPULSE * pullFactor * deltaT * mass, 0, 100, 0, 1)
	animEnt:SetGraphParameterFloat("needle", pose)
	animEnt:SetGraphParameterFloat("pull", pullFactor)

	-- Dampen object movement
	if distance < CARRY_GLUE_DISTANCE
	then
		pulledObject:ApplyAbsVelocityImpulse(GetPhysVelocity(pulledObject) * -COUNTER_IMPULSE_FACTOR_CLOSE)
	else
		pulledObject:ApplyAbsVelocityImpulse(GetPhysVelocity(pulledObject) * -COUNTER_IMPULSE_FACTOR)
	end

	-- Torque from grab point being offset from the center of mass
	local pivotOffsetVec = objectPos - pulledObject:GetCenter()
	local rotAngVel = pullDir:Cross(-pivotOffsetVec) * PULL_TORQUE_FACTOR

	local gravAngVel = gravImpulse:Cross(-pivotOffsetVec) * GRAVITY_TORQUE_FACTOR

	local carryAngvel = Vector(0,0,0)
	if propClasses[pulledObject:GetClassname()] then
		local idx = pulledObject:ScriptLookupAttachment("gravity_gun_carry")
		if idx > 0 then
			local vec = pulledObject:GetAttachmentAngles(idx)
			carryAngvel = RotationDeltaAsAngularVelocity(QAngle(vec.x, vec.y, vec.z), thisEntity:GetAngles())
		end
	end

	SetPhysAngularVelocity(pulledObject, (1 - ROTATION_DAMPING_FACTOR * deltaT) * GetPhysAngularVelocity(pulledObject) + (rotAngVel + gravAngVel) * deltaT * pullMassFactor + carryAngvel * deltaT)

	return deltaT
end


function StartCarrying()
	RumbleController(1, 0.3, 70, handEnt)
	StopSoundEvent("Physcannon.Charge", thisEntity)
	StartSoundEvent("Physcannon.Pickup", thisEntity)
	StartSoundEvent("Physcannon.HoldLoop", thisEntity)
	animEnt:SetGraphParameterFloat("strain", 1)
	animEnt:SetGraphParameterFloat("pull", -1)
	animEnt:SetGraphParameterFloat("open", 1)
end


function GetMaxRadius(entity)
	return entity:GetBoundingMaxs():Length() * entity:GetAbsScale()
end


function GetAttachment(name)
	local idx = thisEntity:ScriptLookupAttachment(name)
	local ang = thisEntity:GetAttachmentAngles(idx)
	return thisEntity:GetAttachmentOrigin(idx), QAngle(ang.x, ang.y, ang.z)
end


function RumbleController(intensity, duration, frequency, hand)
	if hand and IsValidEntity(hand)
	then
		rumbleDuration = duration
		rumbleInterval = 1 / frequency
		rumbleIntensity = intensity
		rumbleHand = hand

		rumbleHand:FireHapticPulse(rumbleIntensity)
		thisEntity:SetThink(RumblePulse, "rumble", rumbleInterval)
	end
end

function RumbleControllerLowPriority(intensity, duration, frequency, hand)
	if hand and IsValidEntity(hand)
	then
		if rumbleDuration > 0 then

			if intensity >= rumbleIntensity and rumbleHand == hand
			then
				rumbleDuration = duration
				rumbleInterval = 1 / frequency
				rumbleIntensity = intensity
			end
		else
			rumbleDuration = duration
			rumbleInterval = 1 / frequency
			rumbleIntensity = intensity
			rumbleHand = hand

			rumbleHand:FireHapticPulse(rumbleIntensity)
			thisEntity:SetThink(RumblePulse, "rumble", rumbleInterval)
		end
	end
end


function RumblePulse()
	if rumbleHand and IsValidEntity(rumbleHand)
	then
		rumbleHand:FireHapticPulse(rumbleIntensity)
		rumbleDuration = rumbleDuration - rumbleInterval
		if rumbleDuration >= rumbleInterval
		then
			return rumbleInterval
		end
	end
	rumbleDuration = 0
	return nil
end
