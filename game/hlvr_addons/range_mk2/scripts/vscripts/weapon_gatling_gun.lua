

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

local BARREL_MAX_SPEED  = 5
local BARREL_CRANK_RATIO = 4
local CRANK_THINK_INTERVAL = FrameTime() * 8


local enabled = false
local user = nil
local usingHand = nil
local held = false
local crankHeld = false

local crankEnt = nil
local animEnt = nil
local dropGuard = nil

local lightEnt = nil
local lightOn = false

local lastVel = nil

local crankLastCycle = 0
local crankLastTime = 0

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
		classname = "prop_dynamic";
		model = "models/weapons/gatling_gun/gatling_gun_anim.vmdl";
		--solid = "6";
		DefaultAnim = "idle";
		use_animgraph = "1";
		CreateNavObstacle = "0";
		forcenpcexclude = "1";
		AnimateOnServer = "1";
		targetname = "gatling_gun_anim";
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
		targetname = "gatling_gun_interact";
	},
	{
		classname = "prop_dynamic";
		model = "models/weapons/gatling_gun/gatling_gun_dropguard.vmdl";
		interactAs = "player";
		solid = 6;
		targetname = "gatling_dropguard";
	}
}

function Precache(context)
	PrecacheModel("models/weapons/gatling_gun/gatling_gun_dropguard.vmdl", context)
	
	for _, keyvals in pairs(partsKeyvals) do
		PrecacheModel(keyvals.model, context)
	end
	
	PrecacheModel(BULLET_MODEL, context)
	PrecacheModel(CASING_MODEL, context)
end


function Activate(aType)

	if not g_PropCarryManager then
		SpawnEntityFromTableSynchronous("logic_script", {vscripts = "prop_carry_manager"})
	end

	g_PropCarryManager.RegisterPickupCallback(thisEntity, function(playerEnt, hand, prop) CheckPickedUp(playerEnt, hand, prop) end )
	g_PropCarryManager.RegisterDropCallback(thisEntity, function(playerEnt, hand, prop) CheckDropped(playerEnt, hand, prop) end )

	SpawnEntityListFromTableAsynchronous(partsKeyvals, OnPartsSpawned)

	user = Entities:GetLocalPlayer()
end


function OnPartsSpawned(entList)

	for _, ent in pairs(entList) do
		if ent:GetName() == "gatling_gun_anim" then
			animEnt = ent
		elseif ent:GetName() == "gatling_gun_interact" then
			crankEnt = ent
		elseif ent:GetName() == "gatling_dropguard" then
			dropGuard = ent
		end
	end

	if animEnt and crankEnt and dropGuard then
	
		crankEnt:SetParent(thisEntity, "")
		crankEnt:SetLocalOrigin(Vector(0,0,0))
		crankEnt:SetLocalAngles(0,0,0)
		crankEnt:RedirectOutput("OnInteractStart", "CrankGrabbed", thisEntity)
		crankEnt:RedirectOutput("OnInteractStop", "CrankDropped", thisEntity)
		
		
		animEnt:SetParent(thisEntity, "")
		animEnt:SetLocalOrigin(Vector(0,0,0))
		animEnt:SetLocalAngles(0,0,0)		
		animEnt:RegisterAnimTagListener(OnAnimTag)

		dropGuard:SetParent(thisEntity, "")
		dropGuard:SetAbsScale(0.01)
	else
		Warning("Gatling gun: Failed spawning gun parts!\n")
	end
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


function OnAnimTag(tagName, status)

	if not enabled then return end

	if vlua.find(tagName, "fire") ~= nil and status < 2 then
		
		local barrel = tonumber(vlua.slice(tagName, 5))

		if barrels[barrel] == BARREL_STATE.LOADED then
		
			FireGun()
			barrels[barrel] = BARREL_STATE.FIRED
		else
			EmitSoundOn("Custom_Weapon.Gatling_Pin", thisEntity) 
		end

	elseif vlua.find(tagName, "load") ~= nil and status < 2 then
	
		local barrel = tonumber(vlua.slice(tagName, 5))
		
		if barrels[barrel] == BARREL_STATE.EMPTY or barrels[barrel] == nil then

			EmitSoundOn("Custom_Weapon.Gatling_Load", thisEntity) 
			barrels[barrel] = BARREL_STATE.LOADED
		end
	
	elseif vlua.find(tagName, "drop") ~= nil and status < 2 then
	
		local barrel = tonumber(vlua.slice(tagName, 5))
		
		if barrels[barrel] == BARREL_STATE.LOADED then

			EjectCasing(true)

			barrels[barrel] = BARREL_STATE.EMPTY
			
		elseif barrels[barrel] == BARREL_STATE.FIRED then
		
			EjectCasing(false)
		
			barrels[barrel] = BARREL_STATE.EMPTY
		end
		
		EmitSoundOn("Custom_Weapon.Gatling_Eject", thisEntity) 
	end
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
	animEnt:SetGraphParameterFloat("flGunspeed", abs(speed * BARREL_CRANK_RATIO)) 
	animEnt:SetGraphParameterBool("bForward", speed >= 0) 
end


function UpdateBarrel()

	local crankCycle = crankEnt:GetCycle()	
	
	local crankSpeed = Clamp((crankCycle % 1 - crankLastCycle % 1) / (Time() - crankLastTime), -BARREL_MAX_SPEED, BARREL_MAX_SPEED)
	--print(crankSpeed)
	
	crankLastCycle = crankCycle
	crankLastTime = Time()
	
	
	animEnt:SetGraphParameterFloat("flGunspeed", abs(crankSpeed * BARREL_CRANK_RATIO)) 
	animEnt:SetGraphParameterBool("bForward", crankSpeed >= 0)
	
	if not crankHeld and abs(crankSpeed) < 0.001 then
		animEnt:SetGraphParameterFloat("flGunspeed", 0) 
		enabled = false
		return nil
	end
	
	return CRANK_THINK_INTERVAL
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







