

local triggerHeld = false

local waterLevel = 0.7
local DRAIN_SPEED = 0.02

local triggerHeld = false
local triggerLevel = 0.0
local firing = false

local PUMP_RATE = 1.0
local streamParticle = -1

local FIRE_THINK_INTERVAL = 1
local STREAM_TRACE_DURATION = 2
local STREAM_SPEED = 200
local STREAM_GRAVITY = Vector(0, 0, -100)
local STREAM_INTERVAL = 0.05
local STREAM_IMPULSE = 40
local STREAM_TORQUE_FACTOR = 0.2

local lastStreamTime = 0
local streams = {}
local numStreams = 0

function Precache(context)

	PrecacheResource("particle", "particles/weapons/squirtgun_single_stream.vpcf", context)
end


function Activate(atype)

	-- Hack to properly handle restoration from saves, 
	-- since variables written by Activate() on restore don't end up in the script scope.
	EntFireByHandle(thisEntity, thisEntity, "CallScriptFunction", "SetupState")	
end


function SetupState()

	SetWaterLevel(waterLevel)
	thisEntity:RegisterAnimTagListener(TagHandler)
end


function TagHandler(tagName, status)

	if tagName == "IsSqueezing" then
		if status == 1 then
			thisEntity:SetThink(TriggerThink, "trigger", 0)
			triggerHeld = true
		else
			triggerHeld = false
			triggerLevel = 0.0
		end
	end
end


function TriggerThink()

	if not triggerHeld then return nil end

	local squeeze = thisEntity:GetGraphParameter("f_Squeeze")

	if triggerLevel < squeeze and squeeze > 0.2 and waterLevel > 0 then
		if not firing then
			StartFiring()
		end
		triggerLevel = min(triggerLevel + FrameTime() * PUMP_RATE, squeeze)
		waterLevel = waterLevel - DRAIN_SPEED * FrameTime()
		SetWaterLevel(waterLevel)

	else
		triggerLevel = squeeze
		if firing then
			EndFiring()
		end
	end

	return FrameTime()
end



function SetWaterLevel(level)
	EntFireByHandle(thisEntity, thisEntity, "setrenderattribute", "level=" .. tostring(waterLevel))
end


function StartFiring()
	firing = true

	--streamParticle = ParticleManager:CreateParticle("particles/weapons/squirtgun_continuous.vpcf",
		--PATTACH_POINT_FOLLOW, thisEntity)
	--ParticleManager:SetParticleControlEnt(streamParticle, 0, thisEntity, PATTACH_POINT_FOLLOW , "nozzle", Vector(0,0,0), false)
	thisEntity:SetThink(FireThink, "fire", 0)
end


function EndFiring()
	firing = false

	--if streamParticle > -1 then
		--ParticleManager:DestroyParticle(streamParticle, false)
		--streamParticle = -1
	--end
end


function FireThink()
	if numStreams <= 0 and not firing then return nil end

	if firing and Time() > lastStreamTime + STREAM_INTERVAL then
	
		local particle = ParticleManager:CreateParticle("particles/weapons/squirtgun_single_stream.vpcf",PATTACH_POINT_FOLLOW, thisEntity)
		ParticleManager:SetParticleControlEnt(particle, 0, thisEntity, PATTACH_POINT_FOLLOW , "nozzle", Vector(0,0,0), false)
	
		streams[NewStream()] = particle
		lastStreamTime = Time()
		numStreams = numStreams + 1
	end

	for stream, particle in pairs(streams) do
		if StreamTrace(stream, FrameTime() * FIRE_THINK_INTERVAL) then
			ParticleManager:DestroyParticle(particle, false)
			streams[stream] = nil
			numStreams = numStreams - 1
		end
	end

	return FrameTime() * FIRE_THINK_INTERVAL
end


function NewStream()

	local idx = thisEntity:ScriptLookupAttachment("nozzle")
	local nozzlePos = thisEntity:GetAttachmentOrigin(idx)
	local nozzleFwd = thisEntity:GetAttachmentForward(idx)

	local stream = {
		start = Time();
		pos = nozzlePos;
		vel = nozzleFwd * STREAM_SPEED;
	}
	return stream
end


function StreamTrace(stream, interval)

	local startTime = Time() - stream.start
	local endTime = startTime + interval

	function GetPos(pos, vel, time)
		return pos + vel * time + STREAM_GRAVITY * time ^ 2 * 0.5
	end

	local trace =
	{
		startpos = GetPos(stream.pos, stream.vel, startTime);
		endpos = GetPos(stream.pos, stream.vel, endTime);
		ignore = thisEntity;
	}

	--DebugDrawLine(trace.startpos, trace.endpos, 255, 0, 0, true, 2)

	TraceLine(trace)

	if trace.hit then

		if IsValidEntity(trace.enthit) and trace.enthit:GetEntityIndex() > 0 then
			local massFac = RemapVal(trace.enthit:GetMass(), 0, 1, 0.2, 1)
			local hitDir = (trace.pos - stream.pos):Normalized()
			local force = hitDir * STREAM_IMPULSE * STREAM_INTERVAL / massFac
			trace.enthit:ApplyAbsVelocityImpulse(force)

			-- Torque
			local pivotOffsetVec = trace.pos - trace.enthit:GetCenter()
			local torque = hitDir:Cross(-pivotOffsetVec) * STREAM_IMPULSE * STREAM_INTERVAL * STREAM_TORQUE_FACTOR / massFac
			SetPhysAngularVelocity(trace.enthit, GetPhysAngularVelocity(trace.enthit) + torque)
		end

		return true

	elseif endTime > STREAM_TRACE_DURATION then
		return true
	end

	return false
end
