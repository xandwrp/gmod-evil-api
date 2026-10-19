local DOWN_TIME = 5
local REST = 30
local LATE = 5
local RINGS = { 0, 20, 40, 64 }
local SPOKES = 8
local LIFTS = { 24, 4 }
local DROP = 64
local CORPSE = 30
local CORPSE_FADE = 2
local PUSH = 300
local PUSH_UP = 150
local GRIP_SPEED = 600
local GRIP_ARRIVE = 0.1
local GRIP_DAMP = 0.8

local downed = {}

local function Dress(rag, ent)
	rag:SetSkin(ent:GetSkin())
	for i = 0, ent:GetNumBodyGroups() - 1 do rag:SetBodygroup(i, ent:GetBodygroup(i)) end
	rag:SetMaterial(ent:GetMaterial())
	for i = 0, #ent:GetMaterials() - 1 do
		local m = ent:GetSubMaterial(i)
		if m ~= "" then rag:SetSubMaterial(i, m) end
	end
	rag:SetColor(ent:GetColor())
	rag:SetRenderMode(ent:GetRenderMode())
	if ent.GetPlayerColor then rag:SetNW2Vector("EvilColor", ent:GetPlayerColor()) end
end

local function Pose(rag, ent, vel)
	ent:SetupBones()
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			local m = ent:GetBoneMatrix(rag:TranslatePhysBoneToBone(i))
			if m then
				phys:SetPos(m:GetTranslation(), true)
				phys:SetAngles(m:GetAngles())
			end
			phys:SetVelocity(vel)
			phys:Wake()
		end
	end
end

local function Push(rag, vel)
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		if IsValid(phys) then
			phys:AddVelocity(vel)
			phys:Wake()
		end
	end
end

local function Stand(ent, from, filter, home)
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local mask = ent:IsPlayer() and MASK_PLAYERSOLID or MASK_NPCSOLID
	for _, r in ipairs(RINGS) do
		local spokes = r == 0 and 1 or SPOKES
		for s = 1, spokes do
			local a = s / spokes * math.pi * 2
			local at = from + Vector(math.cos(a) * r, math.sin(a) * r, 0)
			if not util.TraceLine({ start = from, endpos = at, mask = MASK_SOLID_BRUSHONLY }).Hit then
				for _, lift in ipairs(LIFTS) do
					local tr = util.TraceHull({
						start = at + Vector(0, 0, lift), endpos = at - Vector(0, 0, DROP),
						mins = mins, maxs = maxs, mask = mask, filter = filter,
					})
					if not tr.StartSolid then return tr.HitPos end
				end
			end
		end
	end
	return home
end

local function Mark(ent, rag)
	ent:SetNW2Bool("EvilDown", rag ~= nil)
	ent:SetNW2Entity("EvilRagdoll", rag or NULL)
end

local function Release(ent, taker)
	local d = downed[ent]
	if d and d.held == taker then return end
	Evil.Up(ent)
end

local function Loosen(ent, d, time)
	d.held, d.grip = nil, nil
	d.up = CurTime() + (time or DOWN_TIME)
	Evil.Claim(ent, d.rag, { loose = true, release = Release })
end

function Evil.Downed(ent)
	local d = downed[ent]
	return d and d.rag
end

function Evil.Down(ent, push, time)
	push = push or vector_origin
	time = time or DOWN_TIME
	if not IsValid(ent) then return end
	local d = downed[ent]
	if d then
		d.up = math.max(d.up, CurTime() + time)
		if IsValid(d.rag) then Push(d.rag, push) end
		return d.rag
	end
	if not (ent:IsPlayer() or ent:IsNPC()) or ent:Health() <= 0 or not Evil.Claimable(ent) then return end
	if ent:IsPlayer() and not ent:Alive() then return end
	local model = ent:GetModel()
	if not model or not util.IsValidRagdoll(model) then return end
	local rag = ents.Create("prop_ragdoll")
	if not IsValid(rag) then return end
	rag:SetModel(model)
	rag:SetPos(ent:GetPos())
	rag:SetAngles(ent:GetAngles())
	Dress(rag, ent)
	rag:Spawn()
	rag:Activate()
	if rag:GetPhysicsObjectCount() == 0 then
		rag:Remove()
		return
	end
	rag:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	Pose(rag, ent, ent:GetVelocity() + push)
	if not Evil.Claim(ent, rag, { loose = true, release = Release }) then
		rag:Remove()
		return
	end
	d = { rag = rag, up = CurTime() + time, home = ent:GetPos(), last = ent:GetPos() }
	downed[ent] = d
	rag.EvilDowned = ent
	Evil.Freeze(ent, true)
	Mark(ent, rag)
	hook.Run("EvilDown", ent, rag)
	return rag
end

function Evil.Up(ent)
	local d = downed[ent]
	if not d then return end
	downed[ent] = nil
	local rag = d.rag
	if IsValid(ent) then
		Mark(ent, nil)
		Evil.Unclaim(ent, d.held or rag)
		Evil.Thaw(ent)
		local from = IsValid(rag) and rag:GetPos() or d.last
		ent:SetPos(Stand(ent, from, IsValid(rag) and { ent, rag } or ent, d.home))
		if ent:IsPlayer() then ent:SetLocalVelocity(vector_origin) end
	end
	SafeRemoveEntity(rag)
	if IsValid(ent) then hook.Run("EvilUp", ent) end
end

function Evil.Grip(ent, owner, opts)
	opts = opts or {}
	if not IsValid(owner) then return end
	local rag = Evil.Downed(ent) or Evil.Down(ent, opts.push)
	local d = rag and downed[ent]
	if not d then return end
	local prev = d.held
	d.held = owner
	if not Evil.Claim(ent, owner) then
		d.held = prev
		return
	end
	local bone = opts.bone and rag:LookupBone(opts.bone)
	local phys = bone and rag:TranslateBoneToPhysBone(bone) or 0
	d.grip = { phys = phys >= 0 and phys or 0, speed = opts.speed or GRIP_SPEED }
	hook.Run("EvilGripped", ent, owner, rag)
	return rag
end

function Evil.LetGo(ent, time)
	local d = downed[ent]
	if not d or not d.held then return end
	local owner = d.held
	Evil.Unclaim(ent, owner)
	Loosen(ent, d, time)
	hook.Run("EvilLetGo", ent, owner)
end

local function Pull(ent, d, dt)
	local owner = d.held
	if not owner.EvilPose then return end
	local pos, ang = owner:EvilPose(ent)
	local phys = d.rag:GetPhysicsObjectNum(d.grip.phys)
	if not pos or not IsValid(phys) then return end
	phys:Wake()
	phys:ComputeShadowControl({
		secondstoarrive = GRIP_ARRIVE, pos = pos, angle = ang or phys:GetAngles(),
		maxspeed = d.grip.speed, maxspeeddamp = d.grip.speed * 2,
		maxangular = ang and d.grip.speed or 0, maxangulardamp = ang and d.grip.speed * 2 or 0,
		dampfactor = GRIP_DAMP, teleportdistance = 0, deltatime = dt,
	})
end

local function Corpse(ent)
	local d = downed[ent]
	if not d then return end
	downed[ent] = nil
	local rag = d.rag
	Evil.Unclaim(ent)
	if IsValid(rag) then
		rag.EvilDowned = nil
		rag:Fire("FadeAndRemove", tostring(CORPSE_FADE), CORPSE)
	end
end

local function Still(rag)
	local phys = rag:GetPhysicsObject()
	return not IsValid(phys) or phys:GetVelocity():Length() < REST
end

hook.Add("Think", "EvilDown", function()
	local now, dt = CurTime(), FrameTime()
	for ent, d in pairs(downed) do
		if not IsValid(ent) then
			downed[ent] = nil
			SafeRemoveEntity(d.rag)
		elseif not IsValid(d.rag) then
			Evil.Up(ent)
		else
			d.last = d.rag:GetPos()
			ent:SetPos(d.last)
			if d.held and Evil.Owner(ent) ~= d.held then Loosen(ent, d) end
			if d.held then
				Pull(ent, d, dt)
			elseif now >= d.up and (Still(d.rag) or now >= d.up + LATE) then Evil.Up(ent) end
		end
	end
end)

hook.Add("EntityTakeDamage", "EvilDown", function(target, dmg)
	local ent = target.EvilDowned
	if not IsValid(ent) or not downed[ent] then return end
	local attacker, inflictor = dmg:GetAttacker(), dmg:GetInflictor()
	if dmg:IsDamageType(DMG_CRUSH) and (not IsValid(attacker) or attacker:IsWorld() or attacker == target) then return end
	local d = DamageInfo()
	d:SetDamage(dmg:GetDamage())
	d:SetDamageType(dmg:GetDamageType())
	d:SetAttacker(IsValid(attacker) and attacker or game.GetWorld())
	d:SetInflictor(IsValid(inflictor) and inflictor or game.GetWorld())
	d:SetDamageForce(dmg:GetDamageForce())
	d:SetDamagePosition(dmg:GetDamagePosition())
	ent:TakeDamageInfo(d)
end)

hook.Add("OnNPCKilled", "EvilDown", Corpse)

hook.Add("PostPlayerDeath", "EvilDown", function(ply)
	if not downed[ply] then return end
	Corpse(ply)
	local own = ply:GetRagdollEntity()
	if IsValid(own) then own:Remove() end
end)

hook.Add("PlayerSpawn", "EvilDown", function(ply)
	local d = downed[ply]
	if d then
		downed[ply] = nil
		SafeRemoveEntity(d.rag)
	end
	Mark(ply, nil)
end)

hook.Add("CreateEntityRagdoll", "EvilDown", function(owner, rag)
	if IsValid(owner) and owner:GetNW2Bool("EvilDown") then
		rag:SetNoDraw(true)
		SafeRemoveEntityDelayed(rag, 0)
	end
end)

concommand.Add("evil_down", function(ply, _, args)
	if not IsValid(ply) or not ply:IsSuperAdmin() then return end
	local hit = ply:GetEyeTrace().Entity
	local target = IsValid(hit) and (hit:IsNPC() or hit:IsPlayer()) and hit or ply
	local aim = ply:GetAimVector()
	if target == ply then aim = -aim end
	Evil.Down(target, aim * PUSH + Vector(0, 0, PUSH_UP), tonumber(args[1]))
end, nil, "Knock down who you're looking at, or yourself: [seconds]")
