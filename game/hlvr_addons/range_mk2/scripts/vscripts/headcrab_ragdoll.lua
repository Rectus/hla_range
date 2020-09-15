
function Activate(aType)

	if aType == ACTIVATE_TYPE_INITIAL_CREATION then 
		EntFireByHandle(thisEntity, thisEntity, "BecomeTemporaryRagdoll")
		EntFireByHandle(thisEntity, thisEntity, "StopTemporaryRagdoll", "", 3)
	end
end