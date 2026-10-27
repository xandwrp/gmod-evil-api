local function Dead(owner)
	return owner:IsPlayer() and not owner:Alive() or owner:IsNPC() and owner:Health() <= 0
end

function Evil.Owner(ent)
	if not IsValid(ent) then return end
	local owner
	if SERVER then
		local c = ent.EvilClaim
		owner = c and c.owner
		if IsValid(owner) and Dead(owner) then return end
	else
		owner = ent:GetNW2Entity("EvilOwner")
	end
	if IsValid(owner) then return owner end
end

if CLIENT then return end

function Evil.Claimable(ent, by)
	if not IsValid(ent) then return false end
	local c = ent.EvilClaim
	return not c or not IsValid(c.owner) or Dead(c.owner) or c.owner == by or c.loose
end

function Evil.Claim(ent, owner, opts)
	if not Evil.Claimable(ent, owner) then return false end
	local c = ent.EvilClaim
	if c and IsValid(c.owner) and c.owner ~= owner then
		ent.EvilClaim = nil
		ent:SetNW2Entity("EvilOwner", NULL)
		if c.release then c.release(ent, owner) end
		hook.Run("EvilUnclaimed", ent, c.owner, owner)
	end
	ent.EvilClaim = { owner = owner, loose = opts and opts.loose or false, release = opts and opts.release }
	ent:SetNW2Entity("EvilOwner", owner)
	hook.Run("EvilClaimed", ent, owner)
	return true
end

function Evil.Unclaim(ent, owner)
	local c = IsValid(ent) and ent.EvilClaim
	if not c or (owner ~= nil and c.owner ~= owner) then return end
	ent.EvilClaim = nil
	ent:SetNW2Entity("EvilOwner", NULL)
	hook.Run("EvilUnclaimed", ent, c.owner)
end

hook.Add("PlayerSpawn", "EvilClaim", function(ply)
	Evil.Unclaim(ply)
end)
