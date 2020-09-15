
local lastVel = Vector(0,0,0)
local nextShell = 0

function Activate(aType)
	lastVel = GetPhysVelocity(thisEntity)
	thisEntity:SetThink(Think, "think", 0.1)
end


function Think()
	local vel = GetPhysVelocity(thisEntity)
	
	local idx = thisEntity:ScriptLookupAttachment("opening")
	local ang = thisEntity:GetAttachmentForward(idx)
	
	if ang:Dot(Vector(0,0,-1)) > 0.3 then
	
		if vel:Dot(lastVel) < -10 and Time() > nextShell then
	
			local idx = thisEntity:ScriptLookupAttachment("shell_spawn")
	
			local keyvals =
			{
				model = "models/weapons/pipe_shotgun/shell.vmdl",
				origin = thisEntity:GetAttachmentOrigin(idx),
				angles = thisEntity:GetAttachmentAngles(idx),
			}
			SpawnEntityFromTableAsynchronous("prop_physics_override", keyvals, nil, nil)
	
			nextShell = Time() + RandomFloat(0.3, 1.2) * RemapVal(vel:Dot(lastVel), -10, -5000, 1, 0.2)
		end
	end
	
	lastVel = vel
	return 0.1
end