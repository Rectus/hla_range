
local safety = true
local extended = false
local fired = false

local animParts = nil
local tubeEnt = nil
local dropGuard = nil
local safetyEnt = nil

local rocketKeyvals =
{
	targetname = "rocket";
	--model = "models/props_toys/rubber_chicken.vmdl";
	model = "models/weapons/law_rocket.vmdl";
	vscripts = "law_rocket"
}

local physTubeKeyVals =
{
	classname = "prop_physics_override";
	targetname = "law_tube_phys";
	model = "models/weapons/law_weapon_tube.vmdl";
}

local partsKeyVals =
{
	{
		classname = "prop_dynamic";
		targetname = "law_details";
		model = "models/weapons/law_weapon_details.vmdl";
		solid = "6";
		disablelowviolence = "0";
		DefaultAnim = "folded";
		LagCompensate = "0";
		AnimateOnServer = "0";
		ScriptedMovement = "0";
		updatechildren = "0";
		use_animgraph = "1";
		CreateNavObstacle = "0";
		forcenpcexclude = "0";
		StartDisabled = "0";
		clothScale = "1";
	},
	{	classname = "prop_animinteractable";
		targetname = "law_pin";
		StartDisabled = "0";
		model = "models/weapons/law_weapon_pin.vmdl";
		InitialCompletionAmount = "0";
		TargetCompletionValueA = "1";
		TargetCompletionThreshold = "0.1";
		AnimationDuration = "0.5";
		StartSound = "Grenade.PinPull";
		MoveSound = "";
		StopSound = "";
		OpenCompleteSound = "Grenade.HandlePop";
		CloseCompleteSound = "";
		BounceSound = "";
		LockedSound = "";
		ReturnForwardMoveSound = "";
		ReturnBackwardMoveSound = "";
		InteractionBoneName = "pin";
		ReturnToCompletionStyle = "0";
		AllowGravityGunPull = "1";
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
	},
	{
		classname = "prop_animinteractable";
		targetname = "law_tube";
		StartDisabled = "0";
		model = "models/weapons/law_weapon_tube.vmdl";
		InitialCompletionAmount = "0";
		TargetCompletionValueA = "1";
		TargetCompletionValueB = "0.2";
		TargetCompletionThreshold = "0.01";
		LimitLocked = "0";
		StartLocked = "1";
		AnimationDuration = "5";
		StartSound = "";
		MoveSound = "AnimLever.MoveLp";
		StopSound = "";
		OpenCompleteSound = "Shotgun.Slideforward";
		CloseCompleteSound = "Shotgun.Slideforward";
		BounceSound = "";
		LockedSound = "";
		ReturnForwardMoveSound = "";
		ReturnBackwardMoveSound = "";
		InteractionBoneName = "extension";
		ReturnToCompletionStyle = "0";
		AllowGravityGunPull = "1";
		RetainVelocity = "0";
		ReactToDynamicPhysics = "1";
		IgnoreHandRotation = "1";
		IgnoreHandPosition = "0";
		DoHapticsOnBothHands = "0";
		PositiveResistance = "0.7";
		UpdateChildModels = "0";
		NormalizeChildModelUpdates = "0";
		ChildModelAnimgraphParameter = "";
		SetNavIgnore = "1";
		CreateNavObstacle = "0";
		ReleaseOnPlayerDamage = "0";
		BehaveAsPropPhysics = "0";
		AddToSpatialPartition = "0";
		interactAs = "";
	},
	{
		classname = "prop_animinteractable";
		targetname = "law_trigger";
		StartDisabled = "0";
		model = "models/weapons/law_weapon_trigger.vmdl";
		InitialCompletionAmount = "0";
		TargetCompletionValueA = "1";
		TargetCompletionThreshold = "0.1";
		AnimationDuration = "0.3";
		StartSound = "";
		MoveSound = "";
		StopSound = "Pistol.NoAmmo";
		OpenCompleteSound = "Pistol.NoAmmo";
		CloseCompleteSound = "";
		BounceSound = "";
		LockedSound = "";
		ReturnForwardMoveSound = "";
		ReturnBackwardMoveSound = "";
		InteractionBoneName = "trigger";
		ReturnToCompletionStyle = "3";
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

	},
	{
		classname = "prop_animinteractable";
		targetname = "law_safety";
		StartDisabled = "0";
		model = "models/weapons/law_weapon_safety.vmdl";
		InitialCompletionAmount = "0";
		TargetCompletionValueA = "1";
		TargetCompletionValueB = "0.8";
		TargetCompletionThreshold = "0.1";
		AnimationDuration = "0.5";
		StartSound = "Grenade.PinPull";
		MoveSound = "";
		StopSound = "Shotgun.Slideback";
		OpenCompleteSound = "";
		CloseCompleteSound = "";
		BounceSound = "";
		LockedSound = "";
		ReturnForwardMoveSound = "";
		ReturnBackwardMoveSound = "";
		InteractionBoneName = "safety";
		ReturnToCompletionStyle = "0";
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
	}
}

function Precache(context)
	PrecacheModel(rocketKeyvals.model, context)
	--PrecacheModel("models/weapons/law_weapon_base_extended.vmdl", context)
	
	PrecacheEntityListFromTable(partsKeyVals, context)

	for _, keyVals in pairs(partsKeyVals) do
		if keyVals.model then
			PrecacheModel(keyVals.model, context)
		end
	end

	PrecacheResource("particle", "particles/weapons/law_backblast_smoke.vpcf", context)
	PrecacheResource("particle", "particles/weapons/law_rocket_smoke.vpcf", context)
	PrecacheResource("model", "models/weapons/law_weapon_dropguard.vmdl", context)
	
end


function Activate(activateType)

	--thisEntity:SetEntityName(UniqueString("law"))


	if activateType == ACTIVATE_TYPE_ONRESTORE -- on game load
	then		
		-- Hack to properly handle restoration from saves, 
		-- since variables written by Activate() on restore don't end up in the script scope.
		EntFireByHandle(thisEntity, thisEntity, "CallScriptFunction", "RestoreState")
	
	else

		for _, keyVals in pairs(partsKeyVals) do

			keyVals.origin = thisEntity:GetAbsOrigin()
			keyVals.angles = thisEntity:GetAngles()
			local scale = thisEntity:GetAbsScale()
			keyVals.scales = Vector(scale, scale, scale)

		end

		SpawnEntityListFromTableAsynchronous(partsKeyVals, OnPartsSpawned)

		local entKeyvals =
		{
			model = "models/weapons/law_weapon_dropguard.vmdl";
			interactAs = "player";
			solid = 6;
			origin = thisEntity:GetAbsOrigin();
			angles = thisEntity:GetAngles();
			targetname = "law_dropguard";
		}
		
		dropGuard = SpawnEntityFromTableSynchronous("prop_dynamic", entKeyvals)
		dropGuard:SetParent(thisEntity, "")
		dropGuard:SetAbsScale(0.01)
	end

end


function RestoreState()

	local children = thisEntity:GetChildren()
	for idx, child in pairs(children) do
		if child:GetName() == "law_details" then
			animParts = child
			
		elseif child:GetName() == "law_tube" then
			tubeEnt = child
			
			if tubeEnt:GetCycle() > 0.99 then
				extended = true
			end
			
		elseif child:GetName() == "law_dropguard" then
			dropGuard = child
		
		elseif child:GetName() == "law_safety" then
			safetyEnt = child
			
			if safetyEnt:GetCycle() > 0.99 then
				safety = false
			end
		end
	end
	
	if thisEntity:Attribute_GetIntValue("fired", 0) == 1 then
		fired = true
		if animParts then
			animParts:SetBodygroupByName("rocket", 1)
		end
	end
end


function OnPartsSpawned(partList)
	for _, ent in pairs(partList) do

		ent:SetParent(thisEntity, "!bonemerge")

		if ent:GetName() == "law_details" then
			animParts = ent

		elseif ent:GetName() == "law_pin" then
			ent:RedirectOutput("OnCompletionA", "OnPinPulled", thisEntity)

		elseif ent:GetName() == "law_tube" then

			tubeEnt = ent
			--ent:SetEntityName(UniqueString("law_tube"))
			ent:RedirectOutput("OnCompletionA", "OnExtended", thisEntity)
			ent:RedirectOutput("OnCompletionB", "OnSightsOpen", thisEntity)
			ent:RedirectOutput("Position", "OnExtendMove", thisEntity)


		elseif ent:GetName() == "law_trigger" then
			ent:RedirectOutput("OnCompletionA", "OnTriggerPulled", thisEntity)

		elseif ent:GetName() == "law_safety" then
			safetyEnt = ent
			ent:RedirectOutput("OnCompletionA", "SafetyDisengaged", thisEntity)
			ent:RedirectOutput("OnCompletionB", "SafetyEngaged", thisEntity)

		end
	end
end


function OnPinPulled(params)

	local pin = params.caller

	if IsValidEntity(pin) then
		EntFireByHandle(thisEntity, pin, "TurnIntoPhysicsProp")
		EntFireByHandle(thisEntity, pin, "setsequence", "pin_pull")
		EntFireByHandle(thisEntity, pin, "setplaybackrate", "0")
	end

	if IsValidEntity(tubeEnt) then
		EntFireByHandle(thisEntity, tubeEnt, "Unlock")
	end

	if IsValidEntity(animParts) then
		animParts:SetGraphParameterFloat("extend", 0.02)
	end
end


function OnExtendMove(params)

	if animParts then
		local cycle = params.caller:GetCycle()
		animParts:SetGraphParameterFloat("extend", cycle)
	end
end


function OnSightsOpen(params)

	if IsValidEntity(tubeEnt) then
		EntFireByHandle(thisEntity, tubeEnt, "SetLimitBackward", "0.05")
	end
end


function OnExtended(params)

	print("Extended")
	extended = true

	if IsValidEntity(tubeEnt) then
		--tubeEnt:Kill()
		EntFireByHandle(thisEntity, tubeEnt, "Lock")
	end
	
	dropGuard:SetAbsScale(1)

	--thisEntity:SetModel("models/weapons/law_weapon_base_extended.vmdl")

		--[[physTubeKeyVals.origin = thisEntity:GetAbsOrigin()
		physTubeKeyVals.angles = thisEntity:GetAngles()
		physTubeKeyVals.targetname = UniqueString("law_tube")
		tubeEnt = SpawnEntityFromTableSynchronous(physTubeKeyVals.classname, physTubeKeyVals)

		print(thisEntity:GetName())
		print(tubeEnt:GetName())
		local con = SpawnEntityFromTableSynchronous("phys_constraint", {targetname = "con"; attach1 = thisEntity:GetName(); attach2 = tubeEnt:GetName();
		enableangularconstraint = "1";
		enablelinearconstraint = "1";
	})
		EntFireByHandle(thisEntity, con, "TurnOn")
		--EntFireByHandle(thisEntity, tubeEnt, "TurnIntoPhysicsProp")
	end]]
	if IsValidEntity(animParts) then
		animParts:SetGraphParameterFloat("extend", 1.0)
	end
end

function SafetyDisengaged()
	print("Safety disengaged")
	safety = false
end

function SafetyEngaged()
	print("Safety engaged")
	safety = true
end

function OnTriggerPulled(params)

	if not safety and extended and not fired then
		print("Fire")
		Fire(params.activator)
		fired = true
	else
		print("Click")
	end
end


function Fire(user)

	StartSoundEventFromPosition("Shotgun.Fire", thisEntity:GetCenter())

	local backblast = ParticleManager:CreateParticle("particles/weapons/law_backblast.vpcf",
		PATTACH_POINT, thisEntity)
	ParticleManager:SetParticleControlEnt(backblast,
		0, thisEntity, PATTACH_POINT, "backblast", Vector(0, 0, 0), true)

	if animParts then
		animParts:SetBodygroupByName("rocket", 1)
	end
	
	thisEntity:Attribute_SetIntValue("fired", 1)

	local attachment = thisEntity:ScriptLookupAttachment("rocket_spawn")
	local fireDir = thisEntity:GetAttachmentForward(attachment)
	rocketKeyvals.origin = thisEntity:GetAttachmentOrigin(attachment) + fireDir * 16
	rocketKeyvals.angles = thisEntity:GetAttachmentAngles(attachment)

	StartSoundEventFromPosition("Shotgun.Fire", rocketKeyvals.origin)
	local rocket = SpawnEntityFromTableSynchronous("prop_physics", rocketKeyvals)

	local scope = rocket:GetOrCreatePrivateScriptScope()
	if scope.Fire then
		scope.Fire(user)
	end

	--rocket:ApplyAbsVelocityImpulse(fireDir * 1000)
end
