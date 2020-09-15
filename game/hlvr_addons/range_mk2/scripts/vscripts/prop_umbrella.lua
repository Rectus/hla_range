
function Precache(context)

	PrecacheModel("models/props_toys/umbrella_dyn.vmdl", context)
end

function Activate(aType)

	if aType == ACTIVATE_TYPE_INITIAL_CREATION then 
		
		local keyvals =
		{
			model = "models/props_toys/umbrella_dyn.vmdl",
			InitialCompletionAmount = "0",
			TargetCompletionValueA = "0.88",
			TargetCompletionThreshold = "0.07",
			ObjectRequirement = "",
			OnlyRunForward = "0",
			OnlyRunBackward = "0",
			LimitForward = "0.88",
			LimitBackward = "0",
			LimitStop = "-1",
			StartLocked = "0",
			LimitLocked = "0",
			ReturnToCompletion = "1",
			ReturnToCompletionAmount = "0",
			ReturnToCompletionThreshold = "-1",
			ReturnToCompletionDelay = "0",
			AnimationDuration = "3",
			StartSound = "",
			MoveSound = "Prop.Writing_Marker",
			StopSound = "",
			OpenCompleteSound = "",
			CloseCompleteSound = "",
			BounceSound = "",
			LockedSound = "",
			ReturnForwardMoveSound = "",
			ReturnBackwardMoveSound = "",
			InteractionBoneName = "grip",
			ReturnToCompletionStyle = "2",
			AllowGravityGunPull = "0",
			RetainVelocity = "1",
			ReactToDynamicPhysics = "1",
			IgnoreHandRotation = "1",
			IgnoreHandPosition = "0",
			DoHapticsOnBothHands = "0",
			PositiveResistance = "0.5",
			UpdateChildModels = "0",
			NormalizeChildModelUpdates = "0",
			ChildModelAnimgraphParameter = "",
			SetNavIgnore = "0",
			CreateNavObstacle = "0",
			ReleaseOnPlayerDamage = "0",
			BehaveAsPropPhysics = "0",
			AddToSpatialPartition = "0",
			interactAs = "physics_prop",
			targetname = "umbrella_dyn",
		}
		local ent = SpawnEntityFromTableSynchronous("prop_animinteractable", keyvals)
		ent:SetParent(thisEntity, "")
		ent:SetLocalOrigin(Vector(0,0,0))
		ent:SetLocalAngles(0,0,0)
		EntFireByHandle(ent, ent, "AddOutput", "OnCompletionA_Forward>!self>setreturntocompletionamount>1.0>0>-1") 
		EntFireByHandle(ent, ent, "AddOutput", "OnCompletionExitA>!self>setreturntocompletionamount>0.0>0>-1") 
		
	end
end