local function Frozen(ply)
	return ply:GetNW2Bool("EvilFrozen") and ply:Alive()
end

function Evil.Frozen(ent)
	if SERVER then return IsValid(ent) and ent.EvilFrozen ~= nil end
	return IsValid(ent) and ent:GetNW2Bool("EvilFrozen")
end

hook.Add("StartCommand", "EvilFreeze", function(ply, cmd)
	if Frozen(ply) then
		cmd:ClearButtons()
		cmd:ClearMovement()
	end
end)

hook.Add("PlayerNoClip", "EvilFreeze", function(ply)
	if Frozen(ply) then return false end
end)

hook.Add("PlayerSwitchWeapon", "EvilFreeze", function(ply)
	if Frozen(ply) then return true end
end)

if CLIENT then return end

function Evil.Freeze(ent, hide)
	if not IsValid(ent) then return end
	local f = ent.EvilFrozen
	if not f then
		local player = ent:IsPlayer()
		if player and ent:InVehicle() then ent:ExitVehicle() end
		local wep = ent.GetActiveWeapon and ent:GetActiveWeapon()
		f = {
			move = ent:GetMoveType(), solid = ent:IsSolid(), shadow = not ent:IsEffectActive(EF_NOSHADOW),
			draw = not ent:GetNoDraw(), notarget = ent:IsFlagSet(FL_NOTARGET),
			think = not ent:IsEFlagSet(EFL_NO_THINK_FUNCTION), weapon = IsValid(wep) and wep or nil,
		}
		ent.EvilFrozen = f
		ent:SetMoveType(MOVETYPE_NONE)
		ent:SetNotSolid(true)
		ent:DrawShadow(false)
		ent:AddFlags(FL_NOTARGET)
		if player then
			if ent:FlashlightIsOn() then ent:Flashlight(false) end
			ent:DrawViewModel(false)
			ent:DrawWorldModel(false)
			ent:SetNW2Bool("EvilFrozen", true)
		else
			ent:AddEFlags(EFL_NO_THINK_FUNCTION)
			if f.weapon then f.weapon:SetNoDraw(true) end
		end
	end
	ent:SetNoDraw(hide or not f.draw)
end

function Evil.Thaw(ent, keepMove)
	local f = IsValid(ent) and ent.EvilFrozen
	if not f then return end
	ent.EvilFrozen = nil
	if not keepMove then ent:SetMoveType(f.move) end
	ent:SetNotSolid(not f.solid)
	ent:DrawShadow(f.shadow)
	ent:SetNoDraw(not f.draw)
	if not f.notarget then ent:RemoveFlags(FL_NOTARGET) end
	if ent:IsPlayer() then
		ent:DrawViewModel(true)
		ent:DrawWorldModel(true)
		ent:SetNW2Bool("EvilFrozen", false)
	else
		if f.think then ent:RemoveEFlags(EFL_NO_THINK_FUNCTION) end
		if IsValid(f.weapon) then f.weapon:SetNoDraw(false) end
	end
end

hook.Add("OnNPCKilled", "EvilFreeze", function(npc)
	local f = npc.EvilFrozen
	if not f then return end
	npc.EvilFrozen = nil
	if f.think then npc:RemoveEFlags(EFL_NO_THINK_FUNCTION) end
	if IsValid(f.weapon) then f.weapon:SetNoDraw(false) end
end)

hook.Add("PlayerSpawn", "EvilFreeze", function(ply)
	Evil.Thaw(ply, true)
end)

local function Block(ply)
	if ply.EvilFrozen then return false end
end

hook.Add("PlayerUse", "EvilFreeze", Block)
hook.Add("CanPlayerEnterVehicle", "EvilFreeze", Block)
hook.Add("PlayerCanPickupWeapon", "EvilFreeze", Block)
hook.Add("PlayerCanPickupItem", "EvilFreeze", Block)
