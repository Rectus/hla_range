--[[
	Rocket script.

	Copyright (c) 2016 Rectus

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


local ROCKET_INITVELOCITY = 6000
local fireTime = 0
local ARM_DELAY = 0.05
local user = nil

local EXPLOSION_RANGE = 500
local EXPLOSION_MAX_IMPULSE = 5000
local DIRECT_HIT_DAMAGE = 1000
local DIRECT_HIT_IMPULSE = 5000
local DRAG_TORQUE_FACTOR = 0.05

local exploded = false

local explosionKeyvals =
{
	explosion_custom_effect = "particles/entity/env_explosion/explosion_grenade.vpcf";
	ignoredEntity = thisEntity;
	iMagnitude = "150";
}


function Precache(context)

	PrecacheResource("particle", "particles/weapons/law_rocket_smoke.vpcf", context)

end

function EnableDamage(usingPlayer)
	Fire(usingPlayer)
end


function Fire(player)
	user = player
	thisEntity:ApplyAbsVelocityImpulse(thisEntity:GetAngles():Forward() * ROCKET_INITVELOCITY)
	thisEntity:ApplyLocalAngularVelocityImpulse(Vector(1000, 0, 0))


	local smoke = ParticleManager:CreateParticle("particles/weapons/law_rocket_smoke.vpcf",
			PATTACH_ABSORIGIN, thisEntity)
		ParticleManager:SetParticleControlEnt(smoke,
			0, thisEntity, PATTACH_POINT_FOLLOW, "exhaust", Vector(0, 0, 0), false)

	fireTime = Time()
	thisEntity:SetThink(Think, "ent_think", 0)
end

function Think()
	if exploded or not IsValidEntity(thisEntity)
	then
		return false
	end

	if Time() >= fireTime + ARM_DELAY
	then
		if TraceDirectHit() then return nil end
	end

	local forwardDir = thisEntity:GetForwardVector()
	local velocity = GetPhysVelocity(thisEntity)
	local speed = velocity:Length()

	-- Simuate drag from tumbling
	if speed > 2 then
		
		local forwardFactor = RemapVal(velocity:Dot(forwardDir) / speed, 0, 1, 1, 0) 
		local torqueAxis = velocity:Cross(forwardDir)
		
		SetPhysAngularVelocity(thisEntity, GetPhysAngularVelocity(thisEntity) + torqueAxis * forwardFactor * FrameTime() * DRAG_TORQUE_FACTOR)
	end


	return FrameTime()
end

function TraceDirectHit()

	local attachment = thisEntity:ScriptLookupAttachment("hit_trace")
	local traceDir = thisEntity:GetAttachmentForward(attachment)
	local tracePos = thisEntity:GetAttachmentOrigin(attachment)

	local traceTable =
	{
		startpos = tracePos;
		endpos = tracePos + traceDir * GetPhysVelocity(thisEntity) * FrameTime();
		ignore = thisEntity;
		min = Vector(-1, -1, -1);
		max = Vector(1, 1, 1);
	}
	--DebugDrawLine(traceTable.startpos, traceTable.endpos, 0, 255, 0, false, 0.11)
	TraceHull(traceTable)

	if traceTable.hit
	then
		Explode(traceTable.enthit)
		return true
	end
	return false
end

function Explode(hitEnt)

	if exploded then return end
	exploded = true

	local attachment = thisEntity:ScriptLookupAttachment("hit_trace")
	local hitDir = thisEntity:GetAttachmentForward(attachment)
	local hitPos = thisEntity:GetAttachmentOrigin(attachment)

	if IsValidEntity(hitEnt) and hitEnt:IsAlive() and dmgEnt ~= thisEntity then
		local dmg = CreateDamageInfo(thisEntity, user, hitDir * DIRECT_HIT_IMPULSE, hitPos, DIRECT_HIT_DAMAGE, DMG_BLAST)
		hitEnt:TakeDamage(dmg)
		DestroyDamageInfo(dmg)
	end

	explosionKeyvals.origin = hitPos
	local expl = SpawnEntityFromTableSynchronous("env_explosion", explosionKeyvals)
	EntFireByHandle(thisEntity, expl, "Explode", "", 0, user)
	EntFireByHandle(thisEntity, expl, "Kill", "", 5, user)

	thisEntity:Kill()
end

function OnBreak(inflictor)
	user = inflictor
	print(inflictor:GetDebugName())

	Explode(nil)
end
