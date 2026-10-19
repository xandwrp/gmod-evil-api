function Evil.Posed(ent)
	return IsValid(ent) and ent:GetNW2Bool("EvilPosed")
end

hook.Add("CalcMainActivity", "EvilPose", function(ply)
	if not ply:GetNW2Bool("EvilPosed") then return end
	local seq = ply:GetNW2Int("EvilPoseSeq", -1)
	if seq >= 0 then return ACT_MP_STAND_IDLE, seq end
end)

if CLIENT then return end

local posed = {}

local function Place(ent, owner)
	if not owner.EvilPose then return end
	local pos, ang = owner:EvilPose(ent)
	if pos then ent:SetPos(pos) end
	if ang then ent:SetAngles(ang) end
end

function Evil.Pose(ent, owner, opts)
	opts = opts or {}
	if not IsValid(ent) or not IsValid(owner) or not Evil.Claim(ent, owner) then return false end
	Evil.Freeze(ent)
	local seq = opts.sequence
	if isstring(seq) then seq = ent:LookupSequence(seq) end
	if not seq and opts.act then seq = ent:SelectWeightedSequence(opts.act) end
	if seq and seq < 0 then seq = nil end
	if seq and not ent:IsPlayer() then
		ent:ResetSequence(seq)
		ent:SetCycle(0)
	end
	posed[ent] = { owner = owner, seq = seq, rate = opts.rate or 1, loop = opts.loop ~= false }
	ent:SetNW2Int("EvilPoseSeq", seq or -1)
	ent:SetNW2Bool("EvilPosed", true)
	Place(ent, owner)
	hook.Run("EvilPosed", ent, owner)
	return true
end

local function Drop(ent)
	posed[ent] = nil
	ent:SetNW2Bool("EvilPosed", false)
	ent:SetNW2Int("EvilPoseSeq", -1)
end

function Evil.Unpose(ent, owner)
	local p = posed[ent]
	if not p or (owner ~= nil and p.owner ~= owner) then return end
	Drop(ent)
	Evil.Unclaim(ent, p.owner)
	Evil.Thaw(ent)
	hook.Run("EvilUnposed", ent, p.owner)
end

hook.Add("Think", "EvilPose", function()
	local dt = FrameTime()
	for ent, p in pairs(posed) do
		if not IsValid(ent) then
			posed[ent] = nil
		elseif not IsValid(p.owner) then
			Evil.Unpose(ent)
		elseif Evil.Owner(ent) ~= p.owner then
			Drop(ent)
		else
			Place(ent, p.owner)
			if p.seq and not ent:IsPlayer() then
				local dur = ent:SequenceDuration()
				if dur > 0 then
					local c = ent:GetCycle() + dt * p.rate / dur
					ent:SetCycle(p.loop and c % 1 or math.min(c, 1))
				end
			end
		end
	end
end)

hook.Add("PlayerSpawn", "EvilPose", function(ply)
	if posed[ply] then Drop(ply) end
end)
