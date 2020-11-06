

local SHOT_DISTANCE = 10000
local SHOT_DAMAGE = 8
local SHOT_IMPULSE = 150
local RECOIL_IMPULSE = 15
local TORQUE_FACTOR = 0.01

local SHOT_SPREAD_RADIUS = 0.5 -- In degrees
local MAX_PENETRATIONS = 2
local MAX_PENETRATION_DISTANCE = 512.0
local PENETRATION_DAMAGE_FACTOR = 0.5
local PENETRATION_OFFSET = 32

local BARREL_FIRE_ANGLE = 195
local BARREL_LOAD_ANGLE = 46
local BARREL_DROP_ANGLE = 267

local BARREL_MAX_SPEED  = 5
local BARREL_CRANK_RATIO = 4
local CRANK_THINK_INTERVAL = 4


local enabled = false
local forceRotate = false
local user = nil
local usingHand = nil
local held = false
local crankHeld = false

local crankEnt = nil
local barrelEnt = nil
local hingeEnt = nil
local dropGuard = nil

local lightEnt = nil
local lightOn = false

local lastVel = nil

local crankLastCycle = 0
local crankLastTime = 0
local lastBarrelAng = 0

local barrels = {}

local BARREL_STATE = 
{
	EMPTY = 1,
	LOADED = 2,
	FIRED = 3
}

local MUZZLEFLASH_EFFECT = "particles/weapon_fx/muzzleflash_pistol_small.vpcf"
local TRACER_EFFECT = "particles/tracer_fx/pistol_tracer.vpcf"
local BULLET_MODEL = "models/weapons/gatling_gun/bullet_9mm.vmdl"
local CASING_MODEL = "models/weapons/gatling_gun/bullet_9mm_casing.vmdl"


local partsKeyvals = 
{
	{
		classname = "prop_physics";
		model = "models/weapons/gatling_gun/gatling_gun_barrel_phys.vmdl";
		targetname = "gatling_gun_barrel";
		CollisionGroupOverride = "14";
	},
	{
		classname = "prop_animinteractable";
		model = "models/weapons/gatling_gun/gatling_gun_interact.vmdl";
		InitialCompletionAmount = "0";
		TargetCompletionValueA = "1";
		TargetCompletionValueB = "0";
		TargetCompletionValueC = "-1";
		TargetCompletionValueD = "-1";
		TargetCompletionValueE = "-1";
		TargetCompletionValueF = "-1";
		TargetCompletionThreshold = "0.01";
		ObjectRequirement = "";
		OnlyRunForward = "0";
		OnlyRunBackward = "0";
		LimitForward = "999999";
		LimitBackward = "-999999";
		LimitStop = "-1";
		StartLocked = "0";
		LimitLocked = "0";
		ReturnToCompletion = "0";
		ReturnToCompletionAmount = "0";
		ReturnToCompletionThreshold = "-1";
		ReturnToCompletionDelay = "0";
		AnimationDuration = "5";
		StartSound = "";
		MoveSound = "";
		StopSound = "";
		OpenCompleteSound = "";
		CloseCompleteSound = "";
		BounceSound = "";
		LockedSound = "";
		ReturnForwardMoveSound = "";
		ReturnBackwardMoveSound = "";
		InteractionBoneName = "crank_handle";
		ReturnToCompletionStyle = "0";
		AllowGravityGunPull = "0";
		RetainVelocity = "1";
		ReactToDynamicPhysics = "1";
		IgnoreHandRotation = "1";
		IgnoreHandPosition = "0";
		DoHapticsOnBothHands = "0";
		PositiveResistance = "0.1";
		UpdateChildModels = "0";
		NormalizeChildModelUpdates = "0";
		ChildModelAnimgraphParameter = "";
		SetNavIgnore = "1";
		CreateNavObstacle = "0";
		ReleaseOnPlayerDamage = "0";
		BehaveAsPropPhysics = "0";
		AddToSpatialPartition = "0";
		targetname = "gatling_gun_crank";
	},
	{
		classname = "logic_collision_pair";
		attach1 = "";
		attach2 = "";
		StartDisabled = "1";
		targetname = "gatling_gun_collisionpair_1";
	},
	{
		classname = "logic_collision_pair";
		attach1 = "";
		attach2 = "";
		StartDisabled = "1";
		targetname = "gatling_gun_collisionpair_2";
	},
	{
		classname = "phys_hinge";
		attach1 = "";
		attach2 = "";
		hingefriction = "0.1";
		hingeaxis = "0 0 0";
		targetname = "gatling_gun_hinge";

		["spawnflags#0"] = "1";
	},
	{
		classname = "prop_dynamic";
		model = "models/weapons/gatling_gun/gatling_gun_dropguard.vmdl";
		interactAs = "player";
		solid = 6;
		targetname = "gatling_gun_dropguard";
	}
}

function Precache(context)
	
	PrecacheEntityListFromTable(partsKeyvals, context) 
	
	for _, keyvals in pairs(partsKeyvals) do
		PrecacheModel(keyvals.model, context)
	end
	
	PrecacheModel(BULLET_MODEL, context)
	PrecacheModel(CASING_MODEL, context)
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
	
		user = Entities:GetLocalPlayer()
	
		--SpawnParts()
		thisEntity:SetThink(SpawnParts, "spawnparts",  0)
	end
end


function RestoreState()

	user = Entities:GetLocalPlayer()
	
	barrelEnt = Entities:FindByName(nil, thisEntity:GetName() .. "_barrel")
	crankEnt = Entities:FindByName(nil, thisEntity:GetName() .. "_crank")
	dropGuard = Entities:FindByName(nil, thisEntity:GetName() .. "_dropguard")
	hingeEnt = Entities:FindByName(nil, thisEntity:GetName() .. "_hinge")
	
	g_PropCarryManager.RegisterPickupCallback(thisEntity, function(playerEnt, hand, prop) CheckPickedUp(playerEnt, hand, prop) end )
	g_PropCarryManager.RegisterDropCallback(thisEntity, function(playerEnt, hand, prop) CheckDropped(playerEnt, hand, prop) end )
end


function SpawnParts()
	local entName = UniqueString(thisEntity:GetName())
	thisEntity:SetEntityName(entName)
	
	
	for _, ent in pairs(partsKeyvals) do
		ent.origin = thisEntity:GetAbsOrigin()
		ent.angles = thisEntity:GetAngles()
		
		if ent.targetname == "gatling_gun_barrel" then
			ent.targetname = entName .. "_barrel"
			
		elseif ent.targetname == "gatling_gun_crank" then
			ent.targetname = entName .. "_crank"
			ent.parentname = entName
			
		elseif ent.targetname == "gatling_gun_dropguard" then
			ent.targetname = entName .. "_dropguard"
			ent.parentname = entName
		
		elseif ent.targetname == "gatling_gun_hinge" then
			ent.targetname = entName .. "_hinge"
		
			ent.attach1 = entName
			ent.attach2 = entName .. "_barrel"
			local hingeAxis = thisEntity:GetAbsOrigin() + thisEntity:GetAngles():Forward() * 14
			ent.hingeaxis = tostring(hingeAxis.x) .. " " .. tostring(hingeAxis.y) .. " " .. tostring(hingeAxis.z)
			ent.origin = thisEntity:GetAbsOrigin() + thisEntity:GetAngles():Forward() * -4
			
		elseif ent.targetname == "gatling_gun_collisionpair_1" then
			ent.targetname = entName.. "_collisionpair_1"
			ent.attach1 = entName
			ent.attach2 = entName .. "_barrel"
			
		elseif ent.targetname == "gatling_gun_collisionpair_2" then
			ent.targetname = entName .. "_collisionpair_2"
			ent.attach1 = entName .. "_dropguard"
			ent.attach2 = entName .. "_barrel"
		
		end
	end
	
	--SpawnEntityListFromTableAsynchronous(partsKeyvals, OnPartsSpawned)
	local ents = SpawnEntityListFromTableSynchronous(partsKeyvals)
	
	OnPartsSpawned(ents)
end


function OnPartsSpawned(entList)

	for _, ent in pairs(entList) do
		if ent:GetName() == thisEntity:GetName() .. "_barrel" then
			barrelEnt = ent
			
		elseif ent:GetName() == thisEntity:GetName() .. "_crank" then
			crankEnt = ent
			crankEnt:RedirectOutput("OnInteractStart", "CrankGrabbed", thisEntity)
			crankEnt:RedirectOutput("OnInteractStop", "CrankDropped", thisEntity)
			
		elseif ent:GetName() == thisEntity:GetName() .. "_dropguard" then
			dropGuard = ent
			dropGuard:SetAbsScale(0.01)
			
		elseif ent:GetName() == thisEntity:GetName() .. "_hinge" then
			hingeEnt = ent
		end
	end
	
	lastBarrelAng = VectorAnglePlaneDelta(thisEntity:GetRightVector(), barrelEnt:GetRightVector(), thisEntity:GetForwardVector())
	crankLastCycle = crankEnt:GetCycle()
end




function CheckPickedUp(playerEnt, hand, prop)

	if prop == thisEntity then
	
		held = true
		dropGuard:SetAbsScale(1)
	end
end


function CheckDropped(playerEnt, hand, prop)

	if prop == thisEntity then
	
		held = false
		dropGuard:SetAbsScale(0.01)
	end
end


function CrankGrabbed()

	enabled = true
	crankHeld = true
	 
	thisEntity:SetThink(UpdateBarrel, "barrel", 0)
end

function CrankDropped()

	crankHeld = false
end


function EjectCasing(loaded)

	local idx = thisEntity:ScriptLookupAttachment("shell_eject")
	local ejectOrigin = thisEntity:GetAttachmentOrigin(idx)
	local ejectAngVec = thisEntity:GetAttachmentAngles(idx)
	local ejectAng = QAngle(ejectAngVec.x, ejectAngVec.y, ejectAngVec.z)

	local entKeyvals =
	{
		classname = "prop_physics_override";
		model = CASING_MODEL;
		interactAs = "debris";
		origin = ejectOrigin;
		angles = ejectAngVec;
	}
	
	if loaded then
		entKeyvals.model = BULLET_MODEL
	end

	local callback = function(_, ent)

		ent:ApplyAbsVelocityImpulse(ejectAng:Up() * -100 * RandomFloat(0.3, 1))
		local torque = ejectAng:Left() * -200 * RandomFloat(0.3, 1)
		SetPhysAngularVelocity(ent, GetPhysAngularVelocity(ent) + torque)
		
		EntFireByHandle(thisEntity, ent, "Kill", "", 30) 
	end

	SpawnEntityFromTableAsynchronous("prop_physics_override", entKeyvals, callback, thisEntity)
end


function SetBarrelSpeed(speed)

	enabled = true
	forceRotate = true
	EntFireByHandle(thisEntity, hingeEnt, "setangularvelocity", tostring(speed * BARREL_CRANK_RATIO * 130))
	
	thisEntity:SetThink(UpdateBarrel, "barrel", 0)
end


function UpdateBarrel()

	if not enabled then return nil end

	local barrelAng = VectorAnglePlaneDelta(thisEntity:GetRightVector(), barrelEnt:GetRightVector(), thisEntity:GetForwardVector())
	
	--DebugDrawLine(thisEntity:GetAbsOrigin(), thisEntity:GetAbsOrigin() + barrelEnt:GetRightVector() * 5, 0, 255, 0, true, FrameTime() * CRANK_THINK_INTERVAL)

	for i = 0, 7 do
	
		local ang = (i * 45 + BARREL_FIRE_ANGLE) % 360
	
		if IsAnglePassed(ang, barrelAng, lastBarrelAng) then
		
			if barrels[i] == BARREL_STATE.LOADED then
		
				FireGun()
				barrels[i] = BARREL_STATE.FIRED
			else
				EmitSoundOn("Custom_Weapon.Gatling_Pin", thisEntity) 
			end
		end
		
		ang = (i * 45 + BARREL_LOAD_ANGLE) % 360
	
		if IsAnglePassed(ang, barrelAng, lastBarrelAng) then
		
			if barrels[i] == BARREL_STATE.EMPTY or barrels[i] == nil then

				EmitSoundOn("Custom_Weapon.Gatling_Load", thisEntity) 
				barrels[i] = BARREL_STATE.LOADED
			end
		end
		
		local ang = (i * 45 + BARREL_DROP_ANGLE) % 360
	
		if IsAnglePassed(ang, barrelAng, lastBarrelAng) then
		
			if barrels[i] == BARREL_STATE.LOADED then

				EjectCasing(true)

				barrels[i] = BARREL_STATE.EMPTY
				
			elseif barrels[i] == BARREL_STATE.FIRED then
			
				EjectCasing(false)
			
				barrels[i] = BARREL_STATE.EMPTY
			end
			
			EmitSoundOn("Custom_Weapon.Gatling_Eject", thisEntity) 
		end
	end

	local crankCycle = crankEnt:GetCycle()
	
	if crankCycle < 0.25 and crankLastCycle > 0.75 then
		crankLastCycle = (crankLastCycle % 1) - 1
	elseif crankCycle > 0.75 and crankLastCycle < 0.25 then
		crankLastCycle = (crankLastCycle % 1) + 1
	end
	
	local crankSpeed = Clamp((crankCycle - crankLastCycle) / (Time() - crankLastTime), -BARREL_MAX_SPEED, BARREL_MAX_SPEED)

	crankLastCycle = crankCycle
	crankLastTime = Time()
	
	if not crankHeld and abs(crankSpeed) < 0.001 and not forceRotate then
		--EntFireByHandle(thisEntity, hingeEnt, "setangularvelocity", tostring(0))
		EntFireByHandle(thisEntity, hingeEnt, "SetHingeFriction", tostring(0.1))
		
		if abs(lastBarrelAng - barrelAng) < 0.001 then
			lastBarrelAng = barrelAng
			return FrameTime() * CRANK_THINK_INTERVAL * 10
		end
	elseif not forceRotate then
		EntFireByHandle(thisEntity, hingeEnt, "setangularvelocity", tostring(crankSpeed * BARREL_CRANK_RATIO * 130))
	end
	
	lastBarrelAng = barrelAng
	
	return FrameTime() *CRANK_THINK_INTERVAL
end


function IsAnglePassed(angle, current, previous)

	if current < 180 and previous > 270 then
		previous = previous - 360
	elseif current > 270 and previous < 180 then
		current = current - 360
	end
	return (current - angle) * (previous - angle) < 0
end


function FireGun()
	
	local idx = thisEntity:ScriptLookupAttachment("muzzle")
	local muzzleOrigin = thisEntity:GetAttachmentOrigin(idx)
	local muzzleAngVec = thisEntity:GetAttachmentAngles(idx)
	local muzzleAng = QAngle(muzzleAngVec.x, muzzleAngVec.y, muzzleAngVec.z)
	
	local idx = thisEntity:ScriptLookupAttachment("bullet_origin")
	local bulletOrigin = thisEntity:GetAttachmentOrigin(idx)
	local bulletAngVec = thisEntity:GetAttachmentAngles(idx)
	local bulletAng = QAngle(bulletAngVec.x, bulletAngVec.y, bulletAngVec.z)
	
	
	TraceBullet(bulletOrigin, bulletAng)
	
	StartSoundEventFromPosition("AlyxPistol.Fire", muzzleOrigin) 
	
	local particle = ParticleManager:CreateParticle(MUZZLEFLASH_EFFECT, PATTACH_POINT, thisEntity)
	ParticleManager:SetParticleControlEnt(particle, 0, thisEntity, PATTACH_POINT, "muzzle", Vector(0,0,0), false)
	ParticleManager:ReleaseParticleIndex(particle)
	
	
	thisEntity:ApplyAbsVelocityImpulse(muzzleAng:Forward() * -RECOIL_IMPULSE)
	
	local torqueOffset = muzzleOrigin - thisEntity:GetCenter()
	local torque = muzzleAng:Forward():Cross(torqueOffset) * RECOIL_IMPULSE	 * TORQUE_FACTOR
	SetPhysAngularVelocity(thisEntity, GetPhysAngularVelocity(thisEntity) + torque)
end


function TraceBullet(origin, spreadDir)
	
	local penetrations = 0
	local ang = RandomFloat(0, 360)
	local radius = SHOT_SPREAD_RADIUS * math.sqrt(RandomFloat(0, 1))
	local shotAng = RotateOrientation(spreadDir, QAngle(radius * math.sin(ang), radius * math.cos(ang), 0) )
	local hitAng = RotateOrientation(shotAng, QAngle(0, 180, RandomInt(0, 360)))

	local traceParams =
	{
		startpos = origin,
		endpos = origin + shotAng:Forward() * SHOT_DISTANCE,
		ignore = thisEntity,
	}
	
	while TraceLine(traceParams) and traceParams.hit do
	
		local penMultiplier = (penetrations > 0 and PENETRATION_DAMAGE_FACTOR or 1)
	
		--DebugDrawLine(traceParams.startpos, traceParams.pos, 0, 255, 0, false, 7)
		
		if traceParams.enthit and traceParams.enthit:GetEntityIndex() > 0 then
			
			SpawnHitEffect(traceParams.startpos, traceParams.pos)
			
			local damage = SHOT_DAMAGE * penMultiplier
			
			if damage > 0 and damage < 1 then damage = 1 end 
			
			local dmg = CreateDamageInfo(thisEntity, user, spreadDir:Forward() * SHOT_IMPULSE * damage, traceParams.pos, damage, DMG_BULLET)
			traceParams.enthit:TakeDamage(dmg)
			DestroyDamageInfo(dmg)

			if penetrations == 0 then
				--traceParams.enthit:ApplyAbsVelocityImpulse(shotAng:Forward() * SHOT_IMPULSE)
			end 

		else  -- Hit world
			SpawnHitEffect(traceParams.startpos, traceParams.pos)
		end 
		
		penetrations = penetrations + 1
		
		if penetrations > MAX_PENETRATIONS or traceParams.fraction > MAX_PENETRATION_DISTANCE / SHOT_DISTANCE then
			break
		end 
		
		traceParams.startpos = traceParams.pos + shotAng:Forward() * PENETRATION_OFFSET
		
		if traceParams.enthit then
			traceParams.ignore = traceParams.enthit
		end 
	end 
	--DebugDrawLine(traceParams.startpos, traceParams.endpos, 255, 0, 0, false, 5)

	local particle = ParticleManager:CreateParticle(TRACER_EFFECT, PATTACH_POINT, thisEntity)
	ParticleManager:SetParticleControlEnt(particle, 0, thisEntity, PATTACH_POINT, "muzzle", Vector(0,0,0), false)
	ParticleManager:SetParticleControl(particle, 1, traceParams.endpos)
	ParticleManager:ReleaseParticleIndex(particle)
	
end 


function SpawnHitEffect(start, pos)

	local targetName = DoUniqueString(thisEntity:GetName() .. "_target")

	local entKeyvals =
	{
		{
			classname = "env_gunfire";
			shootsound = "";
			collisions = "1";
			bias = "1";
			spread = "0.1";
			rateoffire = "0";
			maxburstdelay = "1";
			minburstdelay = "1";
			maxburstsize = "1";
			minburstsize = "1";
			target = targetName;
			StartDisabled = "0";
			tracertype = "";
			origin = start;
			--angles = VectorToAngles(pos - start);
		},
		{
			classname = "info_target";
			origin = pos + (pos - start):Normalized() * 16;
			targetname = targetName;
			["spawnflags#0"] = "1";
			["spawnflags#1"] = "1";
		},
	}

	local callback = function(ents) 
		for _, ent in pairs(ents) do 
			EntFireByHandle(thisEntity, ent, "Kill", "", 0.1) 
		end 
	end

	SpawnEntityListFromTableAsynchronous(entKeyvals, callback)
end




function VectorAnglePlaneDelta(a, b, normal)

	return Rad2Deg(math.atan2(normal:Dot(a:Cross(b)), a:Dot(b))) % 360

end


