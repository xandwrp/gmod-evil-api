local PLAYER_COLOR = Vector(62 / 255, 88 / 255, 106 / 255)
local BACK = 100
local LIFT = Vector(0, 0, 8)
local HULL = Vector(4, 4, 4)
local HIDE = { CHudCrosshair = true, CHudWeaponSelection = true }

local function PlayerColor(self)
	return self:GetNW2Vector("EvilColor", PLAYER_COLOR)
end

hook.Add("OnEntityCreated", "EvilDown", function(ent)
	if ent:GetClass() == "prop_ragdoll" and not ent.GetPlayerColor then ent.GetPlayerColor = PlayerColor end
end)

hook.Add("CreateClientsideRagdoll", "EvilDown", function(ent, rag)
	if IsValid(ent) and ent:GetNW2Bool("EvilDown") then
		rag:SetNoDraw(true)
		SafeRemoveEntityDelayed(rag, 0)
	end
end)

hook.Add("CalcView", "EvilDown", function(ply, _, angles, fov)
	if not ply:Alive() or not ply:GetNW2Bool("EvilDown") then return end
	local rag = ply:GetNW2Entity("EvilRagdoll")
	if not IsValid(rag) then return end
	local center = rag:GetPos() + LIFT
	local tr = util.TraceHull({
		start = center, endpos = center - angles:Forward() * BACK,
		mins = -HULL, maxs = HULL, mask = MASK_SOLID_BRUSHONLY,
	})
	return { origin = tr.HitPos, angles = angles, fov = fov, drawviewer = false }
end)

hook.Add("HUDShouldDraw", "EvilDown", function(name)
	if not HIDE[name] then return end
	local ply = LocalPlayer()
	if IsValid(ply) and ply:GetNW2Bool("EvilDown") and ply:Alive() then return false end
end)
