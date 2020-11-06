
local THINK_INTERVAL = 0.1

local SHOT_DISTANCE = 2500
local SHOT_DAMAGE = 15
local SHOT_IMPULSE = 150
local RECOIL_IMPULSE = 400
local TORQUE_FACTOR = 0.025

local CENTER_SPREAD_RADIUS = 3 -- In degrees
local SHOT_SPREAD_RADIUS = 4
local NUM_SHOT = 12
local SHOT_SECTOR_SIZE = 360 / 6
local MAX_PENETRATIONS = 2
local MAX_PENETRATION_DISTANCE = 512.0
local PENETRATION_DAMAGE_FACTOR = 0.5
local PENETRATION_OFFSET = 32

local DROP_SAFETY_VELOCITY = 1000

local GUN_STATE = 
{
	UNLOADED_CLOSED = 1,
	UNLOADED_OPEN = 2,
	LOADED_CLOSED = 3,
	LOADED_OPEN = 4,
	FIRED = 5
}

local gunState = GUN_STATE.UNLOADED_CLOSED
local user = nil
local usingHand = nil
local held = false
local loadedShellPower = 1.0

local loadedShellEnt = nil
local boltEnt = nil
local triggerEnt = nil
local dropGuard = nil
local buttonEnt = nil

local lightEnt = nil
local lightOn = false

local lastVel = nil


local SHELL_PROPS = 
{
	["models/weapons/pipe_shotgun/shell.vmdl"] = 1.0,
	["models/weapons/vr_shotgun/shell_hand.vmdl"] = 0.7,
	["models/weapons/vr_shotgun/vr_shotgun_shell.vmdl"] = 0.7,
	["models/weapons/vr_shotgun/vr_shotgun_shell_lhand.vmdl"] = 0.7,
}

local REPLACE_SHELL_PROPS = 
{
	["models/weapons/vr_shotgun/vr_shotgun_shell.vmdl"] = "models/weapons/vr_shotgun/shell_hand.vmdl",
	["models/weapons/vr_shotgun/vr_shotgun_shell_lhand.vmdl"] = "models/weapons/vr_shotgun/shell_hand.vmdl",
}

local SHELL_EJECT_MODEL =
{
	["models/weapons/pipe_shotgun/shell.vmdl"] = "models/weapons/pipe_shotgun/shell_spent.vmdl",
	["models/weapons/vr_shotgun/shell_hand.vmdl"] = "models/weapons/vr_shotgun/shotgun_shell_ejected.vmdl",
}

local MUZZLEFLASH_EFFECT = "particles/weapon_fx/muzzleflash_heavy_shotgun.vpcf"
local TRACER_EFFECT = "particles/fx/fx_tracer.vpcf"


local BOLT_KEYVALS =
{
	rendercolor = "255 255 255",
	StartDisabled = "0",
	model = "models/weapons/pipe_shotgun/pipe_shotgun_bolt.vmdl",
	InitialCompletionAmount = "0",
	TargetCompletionValueA = "1",
	TargetCompletionValueB = "-1",
	TargetCompletionValueC = "-1",
	TargetCompletionValueD = "-1",
	TargetCompletionValueE = "-1",
	TargetCompletionValueF = "-1",
	TargetCompletionThreshold = "0.1",
	ObjectRequirement = "",
	OnlyRunForward = "0",
	OnlyRunBackward = "0",
	LimitForward = "1",
	LimitBackward = "0",
	LimitStop = "-1",
	StartLocked = "0",
	LimitLocked = "0",
	ReturnToCompletion = "0",
	ReturnToCompletionAmount = "0",
	ReturnToCompletionThreshold = "-1",
	ReturnToCompletionDelay = "0",
	AnimationDuration = "5",
	StartSound = "Anim_Frankenswitch.Grab",
	MoveSound = "Custom_Weapon.Pipe_Shotgun_Slide_Loop", --"Anim_Frankenswitch.MoveLp",
	StopSound = "",
	--OpenCompleteSound = "Shotgun.SlidebackEmpty",
	--CloseCompleteSound = "Shotgun.Slideback",
	BounceSound = "Anim_Frankenswitch.Bounce_Return",
	LockedSound = "",
	ReturnForwardMoveSound = "",
	ReturnBackwardMoveSound = "",
	InteractionBoneName = "bolt",
	ReturnToCompletionStyle = "3",
	AllowGravityGunPull = "0",
	RetainVelocity = "0",
	ReactToDynamicPhysics = "1",
	IgnoreHandRotation = "0",
	IgnoreHandPosition = "0",
	DoHapticsOnBothHands = "0",
	PositiveResistance = "1",
	UpdateChildModels = "0",
	NormalizeChildModelUpdates = "0",
	ChildModelAnimgraphParameter = "",
	SetNavIgnore = "0",
	CreateNavObstacle = "0",
	ReleaseOnPlayerDamage = "0",
	BehaveAsPropPhysics = "0",
	AddToSpatialPartition = "0",
	interactAs = "",
	targetname = "pipe_shotgun_bolt",
	classname = "prop_animinteractable",
}


local TRIGGER_KEYVALS =
{
	rendercolor = "255 255 255",
	StartDisabled = "0",
	model = "models/weapons/pipe_shotgun/pipe_shotgun_trigger.vmdl",
	InitialCompletionAmount = "0.9",
	TargetCompletionValueA = "1",
	TargetCompletionValueB = "-1",
	TargetCompletionValueC = "-1",
	TargetCompletionValueD = "-1",
	TargetCompletionValueE = "-1",
	TargetCompletionValueF = "-1",
	TargetCompletionThreshold = "0.1",
	ObjectRequirement = "",
	OnlyRunForward = "0",
	OnlyRunBackward = "0",
	LimitForward = "1",
	LimitBackward = "0.9",
	LimitStop = "-1",
	StartLocked = "0",
	LimitLocked = "0",
	ReturnToCompletion = "0",
	ReturnToCompletionAmount = "0.9",
	ReturnToCompletionThreshold = "-1",
	ReturnToCompletionDelay = "0",
	AnimationDuration = "0.5",
	StartSound = "Anim_Frankenswitch.Grab",
	--MoveSound = "Custom_Weapon.Pipe_Shotgun_Slide_Loop", --"Anim_Frankenswitch.MoveLp",
	StopSound = "",
	--OpenCompleteSound = "Pistol.NoAmmo",
	--CloseCompleteSound = "Pistol.NoAmmo",
	BounceSound = "Anim_Int_Shared.Locked",
	LockedSound = "",
	ReturnForwardMoveSound = "",
	ReturnBackwardMoveSound = "",
	InteractionBoneName = "trigger",
	ReturnToCompletionStyle = "0",
	AllowGravityGunPull = "0",
	RetainVelocity = "1",
	ReactToDynamicPhysics = "1",
	IgnoreHandRotation = "1",
	IgnoreHandPosition = "0",
	DoHapticsOnBothHands = "0",
	PositiveResistance = "1",
	UpdateChildModels = "0",
	NormalizeChildModelUpdates = "0",
	ChildModelAnimgraphParameter = "",
	SetNavIgnore = "0",
	CreateNavObstacle = "0",
	ReleaseOnPlayerDamage = "0",
	BehaveAsPropPhysics = "0",
	AddToSpatialPartition = "0",
	interactAs = "physics_prop",
	targetname = "pipe_shotgun_trigger",
	classname = "prop_animinteractable",
}


local LIGHT_BUTTON_KEYVALS =
{
	rendercolor = "255 255 255",
	StartDisabled = "0",
	model = "models/weapons/pipe_shotgun/pipe_shotgun_button.vmdl",
	InitialCompletionAmount = "0",
	TargetCompletionValueA = "1",
	TargetCompletionValueB = "-1",
	TargetCompletionValueC = "-1",
	TargetCompletionValueD = "-1",
	TargetCompletionValueE = "-1",
	TargetCompletionValueF = "-1",
	TargetCompletionThreshold = "0.4",
	ObjectRequirement = "",
	OnlyRunForward = "0",
	OnlyRunBackward = "0",
	LimitForward = "1",
	LimitBackward = "0",
	LimitStop = "-1",
	StartLocked = "0",
	LimitLocked = "0",
	ReturnToCompletion = "1",
	ReturnToCompletionAmount = "0",
	ReturnToCompletionThreshold = "-1",
	ReturnToCompletionDelay = "0",
	AnimationDuration = "0.1",
	StartSound = "",
	MoveSound = "",
	StopSound = "",
	OpenCompleteSound = "",
	CloseCompleteSound = "",
	BounceSound = "",
	LockedSound = "",
	ReturnForwardMoveSound = "",
	ReturnBackwardMoveSound = "",
	InteractionBoneName = "flashlight_button",
	ReturnToCompletionStyle = "3",
	AllowGravityGunPull = "0",
	RetainVelocity = "0",
	ReactToDynamicPhysics = "1",
	IgnoreHandRotation = "1",
	IgnoreHandPosition = "0",
	DoHapticsOnBothHands = "0",
	PositiveResistance = "1",
	UpdateChildModels = "0",
	NormalizeChildModelUpdates = "0",
	ChildModelAnimgraphParameter = "",
	SetNavIgnore = "0",
	CreateNavObstacle = "0",
	ReleaseOnPlayerDamage = "0",
	BehaveAsPropPhysics = "0",
	AddToSpatialPartition = "0",
	interactAs = "",
	targetname = "pipe_shotgun_button",
	classname = "prop_animinteractable",
}



function Precache(context)
	PrecacheModel("models/weapons/pipe_shotgun/shell.vmdl", context)
	PrecacheModel("models/weapons/pipe_shotgun/shell_spent.vmdl", context)
	PrecacheModel("models/weapons/pipe_shotgun/shell_ruptured.vmdl", context)
	PrecacheModel("models/weapons/vr_shotgun/shotgun_shell_ejected.vmdl", context)
	
	PrecacheModel(BOLT_KEYVALS.model, context)
	PrecacheModel(TRIGGER_KEYVALS.model, context)
	PrecacheModel(LIGHT_BUTTON_KEYVALS.model, context)
	PrecacheModel("models/weapons/pipe_shotgun/pipe_shotgun_dropguard.vmdl", context)
	
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
	
		boltEnt = SpawnEntityFromTableSynchronous(BOLT_KEYVALS.classname, BOLT_KEYVALS)
		boltEnt:SetParent(thisEntity, "")
		boltEnt:SetLocalOrigin(Vector(0,0,0))
		boltEnt:SetLocalAngles(0,0,0)
		boltEnt:RedirectOutput("Position", "UpdateBolt", thisEntity)
		
		triggerEnt = SpawnEntityFromTableSynchronous(TRIGGER_KEYVALS.classname, TRIGGER_KEYVALS)
		triggerEnt:SetParent(thisEntity, "")
		triggerEnt:SetLocalOrigin(Vector(0,0,0))
		triggerEnt:SetLocalAngles(0,0,0)
		triggerEnt:RedirectOutput("OnCompletionA_Forward", "OnTrigger", thisEntity)
		
		buttonEnt = SpawnEntityFromTableSynchronous(LIGHT_BUTTON_KEYVALS.classname, LIGHT_BUTTON_KEYVALS)
		buttonEnt:SetParent(thisEntity, "")
		buttonEnt:SetLocalOrigin(Vector(0,0,0))
		buttonEnt:SetLocalAngles(0,0,0)
		buttonEnt:RedirectOutput("OnCompletionA_Forward", "ToggleLight", thisEntity)
		
		local entKeyvals =
		{
			model = "models/weapons/pipe_shotgun/pipe_shotgun_dropguard.vmdl";
			interactAs = "player";
			solid = 6;
			origin = thisEntity:GetAbsOrigin();
			angles = thisEntity:GetAngles();
			targetname = "pipe_shotgun_dropguard";
		}
		
		dropGuard = SpawnEntityFromTableSynchronous("prop_dynamic", entKeyvals)
		dropGuard:SetParent(thisEntity, "")
		dropGuard:SetAbsScale(0.01)
	end
end


function RestoreState()

	local children = thisEntity:GetChildren()
	for idx, child in pairs(children) do
		if child:GetName() == "pipe_shotgun_bolt" then
			boltEnt = child
			
		elseif child:GetName() == "pipe_shotgun_trigger" then
			triggerEnt = child
			
		elseif child:GetName() == "pipe_shotgun_light" then
			lightEnt = child
			
		elseif child:GetName() == "pipe_shotgun_dropguard" then
			dropGuard = child
			
		elseif child:GetName() == "pipe_shotgun_button" then
			buttonEnt = child
			
		else
			child:Kill()
		end
	end
	
	g_PropCarryManager.RegisterPickupCallback(thisEntity, function(playerEnt, usingHand, prop) CheckPickedUp(playerEnt, usingHand, prop) end )
	g_PropCarryManager.RegisterDropCallback(thisEntity, function(playerEnt, usingHand, prop) CheckDropped(playerEnt, usingHand, prop) end )
end


function CheckPickedUp(player, hand, prop)

	if prop == thisEntity then
		OnPickedUp(player, hand)
	else
		if not held or (hand ~= usingHand and player == user) then
			thisEntity:SetThink(CheckLoad, "load", 0)
		end
	end
end


function OnPickedUp(player, hand)
	user = player
	usingHand = hand
	held = true
	dropGuard:SetAbsScale(1)
	
	thisEntity:SetThink(CheckLoad, "load", 0)
end

function CheckDropped(player, hand, prop)

	if held and prop == thisEntity and player == user then
		OnDropped()
	end
end


function OnDropped()

	dropGuard:SetAbsScale(0.01)

	user = nil
	usingHand = nil
	held = false
	thisEntity:SetThink(CheckDropSafety, "drop", THINK_INTERVAL)
end



function ToggleLight(params)

	if lightOn then
	
		ParticleManager:DestroyParticle(flashlightParticle, true)
	
		EmitSoundOn("NPC_Combine.Flashlight_Off", params.caller) 
	
		thisEntity:SetMaterialGroup("default") 
		EntFireByHandle(thisEntity, lightEnt, "TurnOff") 
		lightOn = false
	else
	
		if not IsValidEntity(lightEnt) then
	
			local keyvals = 
			{
				color = "197 218 254 255",
				brightness = "1.5",
				range = "1500",
				bouncescale = "1.0",
				renderdiffuse = "1",
				renderspecular = "1",
				rendertransmissive = "1",
				directlight = "2",
				indirectlight = "0",
				attenuation1 = "0.0",
				attenuation2 = "0.7",
				lightsourceradius = "0.7",
				lightcookie = "flashlight",
				falloff = "1",
				innerconeangle = "42",
				outerconeangle = "45",
				shadowfademindist = "700",
				shadowfademaxdist = "1000",
				fogcontributionstrength = "1",
				fog_lighting = "2",
				baked_light_indexing = "0",
				castshadows = 1,
				nearclipplane = 0.5,
				pvs_modify_entity = 1,
				enabled = "1",
				targetname = "pipe_shotgun_light",
			}
			lightEnt = SpawnEntityFromTableSynchronous("light_spot", keyvals)
			lightEnt:SetParent(thisEntity, "flashlight")
			lightEnt:SetLocalOrigin(Vector(0,0,0))
			lightEnt:SetLocalAngles(0,0,0)
		end

		thisEntity:SetMaterialGroup("flashlight_on") 
		flashlightParticle = ParticleManager:CreateParticle("particles/weapon_fx/vr_flashlight.vpcf", PATTACH_POINT_FOLLOW, thisEntity)
		ParticleManager:SetParticleControlEnt(flashlightParticle, 0, thisEntity, PATTACH_POINT_FOLLOW, "flashlight", Vector(0,0,0), false)
		EmitSoundOn("NPC_Combine.Flashlight_On", params.caller) 

		print("on")
		EntFireByHandle(thisEntity, lightEnt, "TurnOn") 
		lightOn = true
	end

end



function CheckLoad()

	if gunState ~= GUN_STATE.UNLOADED_OPEN then
		return THINK_INTERVAL
	end

	local props = g_PropCarryManager.GetAllHeldProps()

	if #props < 1 then return nil end

	for _, prop in pairs(props) do
		-- Check if prop is in the list of shell models
		local power = SHELL_PROPS[prop:GetModelName()]
		if power then

			local idx = prop:ScriptLookupAttachment("tip")
			local shellPos = prop:GetAttachmentOrigin(idx)
			local idx = thisEntity:ScriptLookupAttachment("shell_insert")
			local insertPos = thisEntity:GetAttachmentOrigin(idx)

			--DebugDrawLine(shellPos, insertPos, 0, 0, 255, false, THINK_INTERVAL)

			local propDist = (shellPos - insertPos):Length()
			
			if REPLACE_SHELL_PROPS[prop:GetModelName()] then
				--TODO
			end

			if propDist < 2 then
			
				local idx = thisEntity:ScriptLookupAttachment("shell")
				local loadPos = thisEntity:GetAttachmentOrigin(idx)
				local loadAngVec = thisEntity:GetAttachmentAngles(idx)

				local modelName = prop:GetModelName()
				loadedShellPower = power
				
				if REPLACE_SHELL_PROPS[prop:GetModelName()] then
					modelName = REPLACE_SHELL_PROPS[prop:GetModelName()]
					
					SpawnEntityFromTableSynchronous("item_hlvr_clip_shotgun_single", {origin = prop:GetAbsOrigin()})	
				end
				
				StartSoundEventFromPosition("Shotgun.LoadShell", insertPos) 
				
				prop:Kill()
				
				local keyvals =
				{
					model = modelName,
					origin = loadPos,
					angles = loadAngVec,
					solid = 0,
				}
				loadedShellEnt = SpawnEntityFromTableSynchronous("prop_dynamic_override", keyvals)
				loadedShellEnt:SetParent(thisEntity, "shell")
				
				gunState = GUN_STATE.LOADED_OPEN
				return nil
			end
		end
	end
	
	return THINK_INTERVAL
end


function CheckDropSafety()

	if held or gunState ~= GUN_STATE.LOADED_OPEN and gunState ~= GUN_STATE.LOADED_CLOSED then
		lastVel = nil
		return nil
	end
	
	if triggerEnt:GetCycle() < 0.89 then return THINK_INTERVAL end

	local vel = GetPhysVelocity(thisEntity)
	
	if lastVel and vel:Dot(lastVel) < -RandomInt(DROP_SAFETY_VELOCITY / 2, DROP_SAFETY_VELOCITY * 2) then

		OnTrigger()
		lastVel = nil
		return nil
	end
	
	lastVel = vel
	return THINK_INTERVAL
end


function UpdateBolt(params)

	if not boltEnt then boltEnt = params.caller end
	
	local animCycle = boltEnt:GetCycle()
	
	if IsValidEntity(triggerEnt) then
		local limit = RemapValClamped(animCycle, 0.58, 1, 1, 0.1)
		EntFireByHandle(thisEntity, triggerEnt, "SetLimitForward", tostring(limit)) 
		
		local limit = RemapValClamped(animCycle, 0.50, 0.92, 0.9, 0)
		EntFireByHandle(thisEntity, triggerEnt, "SetLimitBackward", tostring(limit)) 
	end
	
	if animCycle <= 0.35 then
	
		if gunState == GUN_STATE.LOADED_OPEN then 
			gunState = GUN_STATE.LOADED_CLOSED
			
		elseif gunState == GUN_STATE.UNLOADED_OPEN then 
			gunState = GUN_STATE.UNLOADED_CLOSED
		end
		
	elseif animCycle > 0.95 then
		if gunState == GUN_STATE.LOADED_CLOSED then
			gunState = GUN_STATE.LOADED_OPEN
			
		elseif gunState == GUN_STATE.FIRED then
			ShellEject()
			thisEntity:SetThink(CheckLoad, "load", 0)
			gunState = GUN_STATE.UNLOADED_OPEN
			
		elseif gunState == GUN_STATE.UNLOADED_CLOSED then 
			thisEntity:SetThink(CheckLoad, "load", 0)
			gunState = GUN_STATE.UNLOADED_OPEN
		end
		
	elseif animCycle > 0.35 then
		if gunState == GUN_STATE.LOADED_CLOSED then
			gunState = GUN_STATE.LOADED_OPEN
		
		elseif gunState == GUN_STATE.UNLOADED_CLOSED then 
			thisEntity:SetThink(CheckLoad, "load", 0)
			gunState = GUN_STATE.UNLOADED_OPEN
		end
	end

end


function ShellEject()

	if IsValidEntity(loadedShellEnt) then
				
		local keyvals =
		{
			model = loadedShellEnt:GetModelName(),
			origin = loadedShellEnt:GetAbsOrigin(),
			angles = loadedShellEnt:GetAngles(),
		}
		
		loadedShellEnt:Kill()
		
		local shell = SpawnEntityFromTableSynchronous("prop_physics_override", keyvals)
		EntFireByHandle(thisEntity, shell, "Kill", "", 30)
	end
end


function OnTrigger(params)

	--if not triggerEnt then triggerEnt = params.caller end

	if gunState == GUN_STATE.LOADED_CLOSED then
	
		FireShotgun()
		
		if not Convars:GetBool("sv_infinite_ammo") then
			gunState = GUN_STATE.FIRED
			
			if loadedShellEnt then
				if SHELL_EJECT_MODEL[loadedShellEnt:GetModelName()] then
					loadedShellEnt:SetModel(SHELL_EJECT_MODEL[loadedShellEnt:GetModelName()])
				else
					loadedShellEnt:SetModel("models/weapons/pipe_shotgun/shell_spent.vmdl")
				end
				
				if boltEnt then
					loadedShellEnt:SetParent(boltEnt, "shell")
				end
			end
		end
	elseif gunState == GUN_STATE.LOADED_OPEN then
	
		FireOutOfBattery()
		
		if not Convars:GetBool("sv_infinite_ammo") then
			gunState = GUN_STATE.FIRED
		end
		
		if loadedShellEnt then
			loadedShellEnt:SetModel("models/weapons/pipe_shotgun/shell_ruptured.vmdl")
			
			if boltEnt then
				loadedShellEnt:SetParent(boltEnt, "shell")
			end
		end

		if IsValidEntity(boltEnt) then
			EntFireByHandle(thisEntity, boltEnt, "SetCompletionValue", "0.9") 
		end
	end
end


function FireOutOfBattery()
	
	local idx = thisEntity:ScriptLookupAttachment("muzzle")
	local shotOrigin = thisEntity:GetAttachmentOrigin(idx)
	local muzzleAngVec = thisEntity:GetAttachmentAngles(idx)
	local muzzleAng = QAngle(muzzleAngVec.x, muzzleAngVec.y, muzzleAngVec.z)
	

	local ang = RandomFloat(0, 360)
	local radius = CENTER_SPREAD_RADIUS * math.sqrt(RandomFloat(0, 1))
	local spreadCenter = RotateOrientation(muzzleAng, QAngle(radius * math.sin(ang), radius * math.cos(ang)) )
	
	TraceShot(shotOrigin, spreadCenter, NUM_SHOT / 2)
	
	StartSoundEventFromPosition("Shotgun.Fire", shotOrigin) 
	
	local particle = ParticleManager:CreateParticle(MUZZLEFLASH_EFFECT, PATTACH_POINT, thisEntity)
	ParticleManager:SetParticleControlEnt(particle, 0, thisEntity, PATTACH_POINT, "muzzle", Vector(0,0,0), false)
	ParticleManager:ReleaseParticleIndex(particle)
	
	local idx = thisEntity:ScriptLookupAttachment("breach")
	local breechOrigin = thisEntity:GetAttachmentOrigin(idx)
	
	local explosionKeyvals =
	{
		explosion_custom_effect = "particles/weapon_fx/muzzleflash_heavy_shotgun.vpcf";
		--"particles/entity/env_explosion/explosion_grenade.vpcf";
		--ignoredEntity = thisEntity;
		explosion_type = "shrapnel";
		iMagnitude = "30";
		iRadiusOverride = "40";
		origin = breechOrigin;
	}
	local expl = SpawnEntityFromTableSynchronous("env_explosion", explosionKeyvals)
	EntFireByHandle(thisEntity, expl, "Explode", "", 0, user)
	EntFireByHandle(thisEntity, expl, "Kill", "", 5, user)
	
	
	thisEntity:ApplyAbsVelocityImpulse(muzzleAng:Forward() * -RECOIL_IMPULSE / 2)
	
	local torqueOffset = shotOrigin - thisEntity:GetCenter()
	local torque = muzzleAng:Forward():Cross(torqueOffset) * RECOIL_IMPULSE * TORQUE_FACTOR	/ 2
	SetPhysAngularVelocity(thisEntity, GetPhysAngularVelocity(thisEntity) + torque)
end


function FireShotgun()
	
	local idx = thisEntity:ScriptLookupAttachment("muzzle")
	local shotOrigin = thisEntity:GetAttachmentOrigin(idx)
	local muzzleAngVec = thisEntity:GetAttachmentAngles(idx)
	local muzzleAng = QAngle(muzzleAngVec.x, muzzleAngVec.y, muzzleAngVec.z)
	

	local ang = RandomFloat(0, 360)
	local radius = CENTER_SPREAD_RADIUS * math.sqrt(RandomFloat(0, 1))
	local spreadCenter = RotateOrientation(muzzleAng, QAngle(radius * math.sin(ang), radius * math.cos(ang)) )
	
	TraceShot(shotOrigin, spreadCenter, NUM_SHOT)
	
	StartSoundEventFromPosition("Shotgun.Fire", shotOrigin) 
	
	local particle = ParticleManager:CreateParticle(MUZZLEFLASH_EFFECT, PATTACH_POINT, thisEntity)
	ParticleManager:SetParticleControlEnt(particle, 0, thisEntity, PATTACH_POINT, "muzzle", Vector(0,0,0), false)
	ParticleManager:ReleaseParticleIndex(particle)
	
	
	thisEntity:ApplyAbsVelocityImpulse(muzzleAng:Forward() * -RECOIL_IMPULSE)
	
	local torqueOffset = shotOrigin - thisEntity:GetCenter()
	local torque = muzzleAng:Forward():Cross(torqueOffset) * RECOIL_IMPULSE	 * TORQUE_FACTOR
	SetPhysAngularVelocity(thisEntity, GetPhysAngularVelocity(thisEntity) + torque)
end


function TraceShot(origin, spreadDir, numShot)

	local entDamage = {}
	local entHitPos = {}
	
	for i = 1, numShot do

		local penetrations = 0
		local ang = RandomFloat(SHOT_SECTOR_SIZE * i, SHOT_SECTOR_SIZE * (i + 1)) + 180 * i
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
				local entClass = traceParams.enthit:GetClassname()
				
				if not entDamage[traceParams.enthit] then
					entDamage[traceParams.enthit] = 0
					entHitPos[traceParams.enthit] = traceParams.pos
				end  		
				
				SpawnHitEffect(traceParams.startpos, traceParams.pos)
				
				entDamage[traceParams.enthit] = entDamage[traceParams.enthit] + SHOT_DAMAGE * penMultiplier * loadedShellPower

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
	
	for entity, damage in pairs(entDamage) do
		if damage > 0 and damage < 1 then damage = 1 end 
		
		local dmg = CreateDamageInfo(thisEntity, user, spreadDir:Forward() * SHOT_IMPULSE * damage, entHitPos[entity], damage, DMG_BUCKSHOT)

		entity:TakeDamage(dmg)

		DestroyDamageInfo(dmg)
	end 
	
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







