local BACK = 110
local HULL = Vector(4, 4, 4)

local function Where(ent)
	if not ent:GetNW2Bool("EvilPosed") then return end
	local owner = Evil.Owner(ent)
	if owner and owner.EvilPose then return owner:EvilPose(ent) end
end

local function Draw(ent, flags)
	local pos, ang, clipNormal, clipDist = Where(ent)
	if not pos then
		ent:DrawModel(flags)
		return
	end
	local was = ent:GetRenderAngles()
	ent:SetRenderOrigin(pos)
	ent:SetRenderAngles(ang or was)
	ent:InvalidateBoneCache()
	ent:SetupBones()
	if clipNormal then
		local clip = render.EnableClipping(true)
		render.PushCustomClipPlane(clipNormal, clipDist)
		ent:DrawModel(flags)
		render.PopCustomClipPlane()
		render.EnableClipping(clip)
	else
		ent:DrawModel(flags)
	end
	ent:SetRenderOrigin(nil)
	ent:SetRenderAngles(was)
	ent:InvalidateBoneCache()
end

local function Attach(ent, on)
	if on then
		if ent.RenderOverride ~= Draw then
			ent.EvilPoseOverride = ent.RenderOverride
			ent.RenderOverride = Draw
		end
	elseif ent.RenderOverride == Draw then
		ent.RenderOverride = ent.EvilPoseOverride
		ent.EvilPoseOverride = nil
	end
end

hook.Add("EntityNetworkedVarChanged", "EvilPose", function(ent, name, _, new)
	if name == "EvilPosed" and IsValid(ent) then Attach(ent, new) end
end)

hook.Add("NetworkEntityCreated", "EvilPose", function(ent)
	if ent:GetNW2Bool("EvilPosed") then Attach(ent, true) end
end)

hook.Add("CalcView", "EvilPose", function(ply, _, angles, fov)
	if not ply:Alive() or not ply:GetNW2Bool("EvilPosed") then return end
	local center = (Where(ply) or ply:GetPos()) + ply:OBBCenter()
	local tr = util.TraceHull({
		start = center, endpos = center - angles:Forward() * BACK,
		mins = -HULL, maxs = HULL, mask = MASK_SOLID_BRUSHONLY,
	})
	return { origin = tr.HitPos, angles = angles, fov = fov, drawviewer = true }
end)
