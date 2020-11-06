
local THINK_INTERVAL = 1
local DECAY_TIME = 60
local DAMAGE_MIN = 2
local DAMAGE_MAX = 50
local DAMAGE_MAXVEL = 300
local STILL_TRACE_END = 4
local DRAG_TORQUE_FACTOR = 0.025

local user = nil
local tracing = false
local decay = true
local carrier = nil
local hasBeenPickedUp = false
local stillTime = 0

function GetCarryingPlayer()
	return carrier
end

function Activate()
	local arrowColors =
	{
		{255, 0, 0},
		{0, 127, 255},
		{127, 255, 0},
		{255, 216, 51},
		{230, 0, 179},
		{0, 255, 255}
	}

	local color = arrowColors[RandomInt(1, #arrowColors)]
	thisEntity:SetRenderColor(color[1], color[2], color[3])

	thisEntity:RedirectOutput("OnPlayerPickup", "OnPickedUp", thisEntity)
end

function EnableDamage(usingPlayer)
	user = usingPlayer
	tracing = true
	thisEntity:SetThink(ArrowDecay, "decay", DECAY_TIME)
	thisEntity:SetThink(ArrowThink, "think", FrameTime() * THINK_INTERVAL)
	ArrowThink(thisEntity, true)
end

function ArrowThink(ent, ignoreSpeed)

	if not tracing then return end
	
	local deltaT = FrameTime() * THINK_INTERVAL

	local idx = thisEntity:ScriptLookupAttachment("tip")
	local tipOrigin = thisEntity:GetAttachmentOrigin(idx)
	local tipDir = thisEntity:GetAttachmentForward(idx)

	local velocity = GetPhysVelocity(thisEntity)
	local speed = velocity:Dot(tipDir)

	if not ignoreSpeed and speed < 10
	then
		if stillTime == 0 then stillTime = Time() end
		
		if Time() > stillTime + STILL_TRACE_END then
		
			tracing = false
			return nil
		end
	elseif stillTime > 0 then
		stillTime = 0
	end

	local traceTable =
	{
		startpos = tipOrigin ;
		endpos = tipOrigin + velocity * deltaT * 1.5;
		ignore = thisEntity

	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 0, 255, 0, false, 30)

	TraceLine(traceTable)

	if traceTable.hit and tipDir:Dot(-traceTable.normal) > 0.5
	then
		if traceTable.enthit and traceTable.enthit:GetEntityIndex() > 0
		then
			local damageDone = RemapValClamped(speed, 0, DAMAGE_MAXVEL, DAMAGE_MIN, DAMAGE_MAX)

			local dmg = CreateDamageInfo(thisEntity, user, velocity * thisEntity:GetMass(), traceTable.pos, damageDone, DMG_BULLET )
			dmg:SetStabilityDamage(damageDone)
			dmg:SetReportedPosition(traceTable.pos)
			traceTable.enthit:TakeDamage(dmg)

			DestroyDamageInfo(dmg)
			if IsValidEntity(traceTable.enthit) and traceTable.enthit:IsAlive()
			then
				thisEntity:SetAbsOrigin(thisEntity:GetAbsOrigin() + tipDir * traceTable.fraction * speed * deltaT * 1.5 + tipDir * 5)
				thisEntity:SetParent(traceTable.enthit, CheckParentAttachment(traceTable.enthit))
			else
				thisEntity:ApplyAbsVelocityImpulse(-velocity * thisEntity:GetMass())
				tracing = false
				thisEntity:SetThink(ArrowDecay, "decay", DECAY_TIME)
				return nil
			end
		else
			thisEntity:SetAbsOrigin(thisEntity:GetAbsOrigin() + tipDir * traceTable.fraction * speed * deltaT * 1.5 + tipDir * 5)
			EntFireByHandle(thisEntity, thisEntity, "Sleep")
		end
		--thisEntity:SetAbsOrigin(thisEntity:GetAbsOrigin() + tipDir * traceTable.fraction * speed * deltaT * 1.5 + tipDir * 5)

		StartSoundEvent("Custom_Weapon.Bow_Arrow_Impact", thisEntity)
		tracing = false
		thisEntity:SetThink(ArrowDecay, "decay", DECAY_TIME)
		return nil
	end
	
	-- Simuate drag from tumbling
	if speed > 2 then
		local forwardFactor = RemapVal(velocity:Dot(tipDir), 0, 1, 1, 0) / speed
		local torqueAxis = velocity:Cross(tipDir)

		--DebugDrawLine(tipOrigin, tipOrigin + torqueAxis * forwardFactor *100, 0, 255, 0, false, deltaT)
		
		SetPhysAngularVelocity(thisEntity, GetPhysAngularVelocity(thisEntity) + torqueAxis * forwardFactor * deltaT * DRAG_TORQUE_FACTOR)
	end

	return deltaT
end

function ArrowDecay()
	if decay and not hasBeenPickedUp
	then
		thisEntity:Kill()
	end
end

function CheckParentAttachment(ent)
	if ent:GetName() == "Target"
	then
		return "target"
	end
	return ""
end

function OnPickedUp(params)
	tracing = false
	decay = false
	hasBeenPickedUp = true
	carrier = params.activator
	thisEntity:SetParent(nil, nil)
	DoEntFireByInstanceHandle(thisEntity, "enablemotion", "", 0 , thisEntity, thisEntity)
end
