

local items =
{
	weapon_law =
	{
		classname = "prop_physics";
		vscripts = "weapon_law_interactive";
		model = "models/weapons/law_weapon_base.vmdl";
		targetname = "law";
	};

	weapon_bow =
	{
		classname = "prop_physics";
		vscripts = "tool_bow";
		model = "models/weapons/bow.vmdl";
		targetname = "bow";
		angle_offset = QAngle(0, 90, 90);
	};

	weapon_bow_arrow =
	{
		classname = "prop_physics";
		vscripts = "tool_bow_arrow";
		model = "models/weapons/arrow.vmdl";
		targetname = "arrow";
	};

	tool_gravity_gun =
	{
		classname = "prop_physics";
		vscripts = "tool_gravity_gun";
		model = "models/tools/gravity_gun/gravity_gun_body.vmdl";
		targetname = "grav_gun";
	};

	weapon_squirt_gun =
	{
		classname = "prop_physics";
		vscripts = "prop_squirtgun_squeeze";
		model = "models/props_toys/squirtgun.vmdl";
		targetname = "squirtgun";
	};


	prop_rubber_chicken =
	{
		classname = "prop_ragdoll";
		model = "models/props_toys/rubber_chicken.vmdl";
		targetname = "chicken";
	};
	
	prop_paper_plane =
	{
		classname = "prop_physics";
		vscripts = "prop_paper_plane";
		model = "models/props_toys/paper_plane1.vmdl";
		targetname = "paper_plane";
	};
	
	prop_diamond =
	{
		classname = "prop_physics";
		model = "models/props_toys/diamond_brilliant.vmdl";
		targetname = "diamond";
	};
}


function Precache(context)

	PrecacheResource("soundfile", "soundevents/range_mk2_soundevents.vsndevts", context)


	for _, item in pairs(items) do
		PrecacheModel(item.model, context)
		
		if item.vscripts then
			local scope = {}
			
			setmetatable(scope, {__index = getfenv(0)})
			pcall(DoIncludeScript, item.vscripts, scope)
			
			if scope.Precache then 
				pcall(scope.Precache, context) 
			end
		end
	end
end


function SpawnItem(itemName)

	if not items[itemName] then
		return
	end



	local spawnOrigin = thisEntity:GetAbsOrigin()

	local trace =
	{
		startpos = thisEntity:GetAbsOrigin();
		endpos = thisEntity:GetAbsOrigin() + Vector(0, 0, -64);
		ignore = Entities:GetLocalPlayer();
		min = Vector(-4, -4, -4);
		max = Vector(4, 4, 4);
	}
	TraceHull(trace)

	if trace.hit
	then
		if trace.startsolid then
			trace.startpos = thisEntity:GetAbsOrigin() + Vector(0, 0, 128)
			TraceHull(trace)

			if trace.hit then
				spawnOrigin = trace.pos
			end

		else
			spawnOrigin = trace.pos
		end
	end

	local keyvals = items[itemName]

	keyvals.origin = spawnOrigin
	
	if keyvals.angle_offset then
		keyvals.angles = RotateOrientation(thisEntity:GetAngles(), keyvals.angle_offset)
	else
		keyvals.angles = thisEntity:GetAngles()
	end

	SpawnEntityFromTableAsynchronous(keyvals.classname, keyvals, nil, nil)
end


function SpawnEnemy(enemyID)

	if enemyID == "combine_squad" then

		EntFire(thisEntity, "combine_spawner1", "ForceSpawn")
		
	elseif enemyID == "antlion_squad" then

		EntFire(thisEntity, "antlion_spawner1", "ForceSpawn")
	
	end
end
