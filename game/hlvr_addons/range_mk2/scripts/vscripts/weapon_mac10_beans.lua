
local ACTION_HAND_CURL = 0
local ACTION_TRIGGER_PULL = 1
local ACTION_TRIGGER = 7
local ACTION_INVENTORY = 5
local ACTION_EJECT = 10


local CYCLE_INTERVAL = 0.046
local SHOOT_DISTANCE = 2500
local BULLET_DAMAGE = 0
local BULLET_IMPULSE = 15
local RECOIL_IMPULSE = 10
local TORQUE_FACTOR = 0.005
local BULLET_SPREAD_RADIUS = 0.5 -- In degrees

local INTERVAL = 1

local held = false
local usingHand = nil
local player = nil
local triggerHeld = false
local cocked = false
local useCurl = false
local handOffset = nil


local magazineLoaded = true
local ammoCount = 30
local lastFireTime = 0

local animParts = nil
local chargeHandle = nil

local MUZZLEFLASH_EFFECT = "particles/weapons/bean_muzzle_flash.vpcf"
local TRACER_EFFECT = "particles/weapons/bean_tracer.vpcf"



local partsKeyvals =
{
	{
		classname = "prop_dynamic";
		model = "models/weapons/mac10/mac10_anim.vmdl";
		targetname = "mac10_anim";
		DefaultAnim = "bolt_forward"; -- Starting an animation is required for the animgraph to work
		use_animgraph = 1;
	},
	--[[{
		classname = "prop_animinteractable";
		model = "models/weapons/mac10/mac10_charge.vmdl";
		InteractionBoneName = "bolt";
		targetname = "mac10_charge";
		UpdateChildModels = 1;
		ChildModelAnimgraphParameter = "charge_pos";
		NormalizeChildModelUpdates = 1;
	},]]
}

function Precache(context)

	PrecacheResource("particle", "particles/weapons/bean_splatter_dynamic.vpcf", context)
	PrecacheResource("particle", MUZZLEFLASH_EFFECT, context)
	PrecacheResource("particle", TRACER_EFFECT, context)

	PrecacheEntityListFromTable(partsKeyvals, context) 
	
	for _, keyvals in pairs(partsKeyvals) do
		PrecacheResource("model", keyvals.model, context)
	end
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
		g_PropCarryManager.RegisterPickupCallback(thisEntity, function(playerEnt, hand, prop) CheckPickedUp(playerEnt, hand, prop) end )
		g_PropCarryManager.RegisterDropCallback(thisEntity, function(playerEnt, hand, prop) CheckDropped(playerEnt, hand, prop) end )
	
		SpawnEntityListFromTableAsynchronous(partsKeyvals, OnPartsSpawned)
	end
end


function RestoreState()
	
	local children = thisEntity:GetChildren()
	for idx, child in pairs(children) do
		if child:GetName() == "mac10_anim" then
		
			animParts  = child
		end
	end
	
	g_PropCarryManager.RegisterPickupCallback(thisEntity, function(playerEnt, hand, prop) CheckPickedUp(playerEnt, hand, prop) end )
	g_PropCarryManager.RegisterDropCallback(thisEntity, function(playerEnt, hand, prop) CheckDropped(playerEnt, hand, prop) end )
end


function OnPartsSpawned(entList)

	for _, ent in pairs(entList) do
		if ent:GetName() == "mac10_anim" then
			animParts = ent
		--elseif ent:GetName() == "mac10_charge" then
			--chargeHandle = ent
		end
	end

	if animParts then

		animParts:SetParent(thisEntity, "")
		animParts:SetLocalOrigin(Vector(0,0,0))
		animParts:SetLocalAngles(0,0,0)

		animParts:SetGraphParameterBool("bolt_back", true)
	else
		Warning("MAC10: Failed spawning gun parts!\n")
	end
end



function CheckPickedUp(playerEnt, hand, prop)

	if prop == thisEntity then
	
		if not held then
			player = playerEnt
			held = true
			usingHand = hand
			
			local handType = usingHand:GetLiteralHandType()
			local handCurl = player:GetAnalogActionPositionForHand(handType, ACTION_HAND_CURL).x
			
			if handCurl > 0.3 then
				useCurl = true
			else
				useCurl = false
			end
			
			thisEntity:SetParent(nil, "")
			thisEntity:SetThink(DelayGetOffset, "offset_delay", 0.5)
			thisEntity:SetThink(Think, "think", FrameTime() * INTERVAL)
		else
			thisEntity:SetParent(nil, "")
		end
	end
end


function DelayGetOffset()

	-- Get gun offset from hand for reparenting 
	if held then	
		handOffset = usingHand:TransformPointWorldToEntity(thisEntity:GetAbsOrigin())
	end
end



function CheckDropped(playerEnt, hand, prop)

	if prop == thisEntity and player == playerEnt and hand == usingHand then
	
		-- Parent to keep prop in hand
		if held then
			thisEntity:SetParent(usingHand, "vr_palm")
			
			if handOffset then		
				thisEntity:SetAbsOrigin(usingHand:TransformPointEntityToWorld(handOffset))
			end
		end
	end
end


function Think()

	if not held or not player or not usingHand then

		return nil	
	end

	local handType = usingHand:GetLiteralHandType()

	local trigger = player:GetAnalogActionPositionForHand(handType, ACTION_TRIGGER_PULL).x
	local handCurl = player:GetAnalogActionPositionForHand(handType, ACTION_HAND_CURL).x
	local fireButton = player:IsDigitalActionOnForHand(handType, ACTION_EJECT)

	animParts:SetGraphParameterFloat("trigger", trigger)

	if not triggerHeld and (fireButton or trigger > 0.8) then

		animParts:SetGraphParameterFloat("trigger", max(trigger, 0.8))
		animParts:SetGraphParameterBool("firing", true)
		triggerHeld = true
		Fire()
		lastFireTime = Time()

	elseif triggerHeld and not fireButton and trigger < 0.6 then

		animParts:SetGraphParameterBool("firing", false)
		triggerHeld = false
		
	elseif triggerHeld and Time() >= lastFireTime + CYCLE_INTERVAL then
		
		lastFireTime = Time()
		Fire()
	end

	if player:IsDigitalActionOnForHand(handType, ACTION_INVENTORY) or (useCurl and handCurl < 0.3) then
		
		if held then
		
			thisEntity:SetParent(nil, "")	
			handOffset = nil
		
			player = nil
			held = false
			usingHand = nil
			
			return nil
		end

	end

	return FrameTime() * INTERVAL
end



function Fire()
	
	local idx = thisEntity:ScriptLookupAttachment("muzzle")
	local muzzleOrigin = thisEntity:GetAttachmentOrigin(idx)
	local muzzleAngVec = thisEntity:GetAttachmentAngles(idx)
	local muzzleAng = QAngle(muzzleAngVec.x, muzzleAngVec.y, muzzleAngVec.z)
	
	local idx = thisEntity:ScriptLookupAttachment("bullet_origin")
	local bulletOrigin = thisEntity:GetAttachmentOrigin(idx)
	local bulletAngVec = thisEntity:GetAttachmentAngles(idx)
	local bulletAng = QAngle(bulletAngVec.x, bulletAngVec.y, bulletAngVec.z)
	
	
	TraceBullet(bulletOrigin, bulletAng)
	
	StartSoundEventFromPosition("Headcrab_Reviver.Host_Abandon_Gore_Crack", muzzleOrigin) 
	--AlyxPistol.Fire
	
	local particle = ParticleManager:CreateParticle(MUZZLEFLASH_EFFECT, PATTACH_POINT, thisEntity)
	ParticleManager:SetParticleControlEnt(particle, 0, thisEntity, PATTACH_POINT, "muzzle", Vector(0,0,0), false)
	ParticleManager:ReleaseParticleIndex(particle)
	
	
	thisEntity:ApplyAbsVelocityImpulse(muzzleAng:Forward() * -RECOIL_IMPULSE)
	
	local torqueOffset = muzzleOrigin - thisEntity:GetCenter()
	local torque = muzzleAng:Forward():Cross(torqueOffset) * RECOIL_IMPULSE	 * TORQUE_FACTOR
	SetPhysAngularVelocity(thisEntity, GetPhysAngularVelocity(thisEntity) + torque)
end


function TraceBullet(origin, spreadDir)
	
	local ang = RandomFloat(0, 360)
	local radius = BULLET_SPREAD_RADIUS * math.sqrt(RandomFloat(0, 1))
	local shootAng = RotateOrientation(spreadDir, QAngle(radius * math.sin(ang), radius * math.cos(ang), 0) )
	local hitAng = RotateOrientation(shootAng, QAngle(0, 180, RandomInt(0, 360)))

	local traceParams =
	{
		startpos = origin,
		endpos = origin + shootAng:Forward() * SHOOT_DISTANCE,
		ignore = thisEntity,
	}
	
	TraceLine(traceParams) 
	
	if traceParams.hit then
	
		--DebugDrawLine(traceParams.startpos, traceParams.pos, 0, 255, 0, false, 7)
		
		if traceParams.enthit and traceParams.enthit:GetEntityIndex() > 0 then
			
			SpawnHitEffect(traceParams.startpos, traceParams.pos, traceParams.normal)
			
			traceParams.enthit:ApplyAbsVelocityImpulse(shootAng:Forward() * BULLET_IMPULSE)
			
			local pivotOffsetVec = traceParams.pos - traceParams.enthit:GetCenter()
			local torque = shootAng:Forward():Cross(-pivotOffsetVec) * BULLET_IMPULSE * TORQUE_FACTOR / traceParams.enthit:GetMass()
			SetPhysAngularVelocity(traceParams.enthit, GetPhysAngularVelocity(traceParams.enthit) + torque)
			
			if BULLET_DAMAGE > 0 then
			
				local dmg = CreateDamageInfo(thisEntity, player, spreadDir:Forward() * BULLET_IMPULSE * BULLET_DAMAGE, traceParams.pos, BULLET_DAMAGE, DMG_CLUB)
				traceParams.enthit:TakeDamage(dmg)
				DestroyDamageInfo(dmg)
			end	

		else  -- Hit world
			SpawnHitEffect(traceParams.startpos, traceParams.pos, traceParams.normal)
		end 
		

		
		local particle = ParticleManager:CreateParticle(TRACER_EFFECT, PATTACH_CUSTOMORIGIN, thisEntity)
		--ParticleManager:SetParticleControlEnt(particle, 0, thisEntity, PATTACH_POINT, "muzzle", Vector(0,0,0), false)
		ParticleManager:SetParticleControl(particle, 0, traceParams.startpos)
		ParticleManager:SetParticleControl(particle, 1, traceParams.pos)
		ParticleManager:ReleaseParticleIndex(particle)
		
	else
		--DebugDrawLine(traceParams.startpos, traceParams.endpos, 255, 0, 0, false, 5)
		
		local particle = ParticleManager:CreateParticle(TRACER_EFFECT, PATTACH_CUSTOMORIGIN, thisEntity)
		ParticleManager:SetParticleControl(particle, 0, traceParams.startpos)
		ParticleManager:SetParticleControl(particle, 1, traceParams.endpos)
		ParticleManager:ReleaseParticleIndex(particle)	
	end 
	
end 


function SpawnHitEffect(start, pos, normal)

	local ang = RotateOrientation(QAngle(0, 0, RandomFloat(0, 360)), VectorToAngles(pos - start))
	local offset = (pos - start):Normalized() * -0.5
	local scale = RandomFloat(0.7, 1.5)

	local entKeyvals =
	{
		{
			classname = "info_projecteddecal";
			texture = "materials/particle/food/bean_single_projected.vmat";
			Distance = 5;
			origin = pos + offset;
			angles = ang;
			targetname = "bean";
		},
		{
			classname = "info_projecteddecal";
			texture = "materials/particle/food/bean_splatter_projected.vmat";
			Distance = 5;
			origin = pos + offset;
			angles = ang;
			targetname = "bean";
		},
	}

	local callback = function(ents) 
		for _, ent in pairs(ents) do 
			EntFireByHandle(thisEntity, ent, "Activate") 
		end 
	end
	SpawnEntityListFromTableAsynchronous(entKeyvals, callback)


	local particle = ParticleManager:CreateParticle("particles/weapons/bean_splatter_dynamic.vpcf", PATTACH_CUSTOMORIGIN, thisEntity)
	
	ParticleManager:SetParticleControl(particle, 0, pos)
	--ParticleManager:SetParticleControlForward(particle, 0, start - pos)
	local inVec = (start - pos):Normalized()
	local reflAng = VectorToAngles(inVec:Dot(normal) * 2 * normal - inVec)
	ParticleManager:SetParticleControlOrientationFLU(particle, 0, reflAng:Forward(), reflAng:Left(), reflAng:Up())
	ParticleManager:ReleaseParticleIndex(particle)

end



