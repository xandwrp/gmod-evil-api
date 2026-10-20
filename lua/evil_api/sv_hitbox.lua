local SWEEP = 0.1
local OVERLAP = 1.6
local MAX_BOXES = 48
local RESIZE = 0.5
local IMPACT_SPEED = 250
local IMPACT_SCALE = 1 / 200000
local IMPACT_AGAIN = 0.5
local BURN = 8

local Hitbox = Evil.HitboxMeta or {}
Hitbox.__index = Hitbox
Evil.HitboxMeta = Hitbox

function Evil.Hitbox(owner, opts)
	opts = opts or {}
	return setmetatable({
		owner = owner, ignite = opts.ignite, parts = {}, hits = {}, taken = {},
		bumped = setmetatable({}, { __mode = "k" }), next = 0,
	}, Hitbox)
end

function Evil.HitboxOwner(ent)
	return IsValid(ent) and ent.EvilHitboxOwner or nil
end

local function Key(dmg)
	local by = dmg:GetInflictor()
	if not IsValid(by) then by = dmg:GetAttacker() end
	return (IsValid(by) and by:EntIndex() or -1) .. ":" .. dmg:GetDamageType()
end

local function Copy(dmg)
	local c = DamageInfo()
	c:SetDamage(dmg:GetDamage())
	c:SetMaxDamage(dmg:GetMaxDamage())
	c:SetDamageType(dmg:GetDamageType())
	c:SetDamageForce(dmg:GetDamageForce())
	c:SetDamagePosition(dmg:GetDamagePosition())
	c:SetReportedPosition(dmg:GetReportedPosition())
	c:SetAmmoType(dmg:GetAmmoType())
	c:SetDamageCustom(dmg:GetDamageCustom())
	c:SetDamageBonus(dmg:GetDamageBonus())
	local world = game.GetWorld()
	local a, i = dmg:GetAttacker(), dmg:GetInflictor()
	if IsValid(a) or a == world then c:SetAttacker(a) end
	if IsValid(i) or i == world then c:SetInflictor(i) end
	if dmg.GetWeapon then
		local w = dmg:GetWeapon()
		if IsValid(w) then c:SetWeapon(w) end
	end
	return c
end

function Hitbox:Forward(dmg, part)
	local owner = self.owner
	if not IsValid(owner) or dmg:GetDamage() <= 0 then return end
	if Evil.AreaDamage(dmg) then
		local key, now = Key(dmg), CurTime()
		local last = self.hits[key]
		if last and last.at == now and last.amount >= dmg:GetDamage() then return end
		self.hits[key] = { at = now, amount = dmg:GetDamage() }
	end
	local prev = owner.EvilStruckPart
	owner.EvilStruckPart = part
	owner:TakeDamageInfo(Copy(dmg))
	owner.EvilStruckPart = prev
end

function Hitbox:Fresh(dmg)
	local amount = dmg:GetDamage()
	if not Evil.AreaDamage(dmg) then return amount end
	local key, now = Key(dmg), CurTime()
	local last = self.taken[key]
	if last and last.at == now then
		if amount <= last.amount then return 0 end
		local more = amount - last.amount
		last.amount = amount
		return more
	end
	self.taken[key] = { at = now, amount = amount }
	return amount
end

function Hitbox:Spawn()
	local part = ents.Create("evil_hitbox")
	part.EvilHitboxOwner = self.owner
	part.EvilHitbox = self
	part:SetPos(self.owner:GetPos())
	part:SetOwner(self.owner)
	part:Spawn()
	return part
end

local function Picks(points, R)
	local n = #points
	local link = math.max(n > 1 and points[1]:Distance(points[2]) or 1, 1)
	local picks = {}
	local i = 1
	while i <= n do
		picks[#picks + 1] = i
		i = i + math.max(1, math.floor(R(i) * OVERLAP / link))
	end
	if picks[#picks] ~= n then picks[#picks + 1] = n end
	if #picks <= MAX_BOXES then return picks, false end
	picks = {}
	for k = 1, MAX_BOXES do picks[k] = math.Round(1 + (k - 1) * (n - 1) / (MAX_BOXES - 1)) end
	return picks, true
end

function Hitbox:Place(points, radius)
	local R = isfunction(radius) and radius or function() return radius end
	local parts = self.parts
	local picks, sparse = Picks(points, R)
	for k, idx in ipairs(picks) do
		local part = parts[k]
		if not IsValid(part) then
			part = self:Spawn()
			parts[k] = part
		end
		local h = R(idx)
		if sparse then
			local nxt = points[picks[k + 1] or idx]
			h = math.max(h, points[idx]:Distance(nxt) * 0.5)
		end
		if math.abs((part.EvilSize or 0) - h) > RESIZE then
			part.EvilSize = h
			part:SetCollisionBounds(Vector(-h, -h, -h), Vector(h, h, h))
		end
		part:SetPos(points[idx])
		part.EvilIndex = idx
	end
	for k = #parts, #picks + 1, -1 do
		SafeRemoveEntity(parts[k])
		parts[k] = nil
	end
end

function Hitbox:Burn()
	if self.ignite then return self.ignite(BURN) end
	self.owner:Ignite(BURN)
end

function Hitbox:Bump(part, now)
	local h = part.EvilSize or 0
	local pos = part:GetPos()
	local pad = Vector(h, h, h)
	for _, ent in ipairs(ents.FindInBox(pos - pad, pos + pad)) do
		if ent ~= self.owner and not ent.EvilHitboxOwner and not ent:IsPlayer() and not ent:IsNPC()
			and now >= (self.bumped[ent] or 0) then
			local phys = ent:GetPhysicsObject()
			local vel = IsValid(phys) and phys:GetVelocity()
			local speed = vel and vel:Length() or 0
			if speed > IMPACT_SPEED then
				self.bumped[ent] = now + IMPACT_AGAIN
				local mass = phys:GetMass()
				local by = ent:IsVehicle() and ent:GetDriver() or ent:GetPhysicsAttacker(5)
				local dmg = DamageInfo()
				dmg:SetDamage(mass * (speed - IMPACT_SPEED) ^ 2 * IMPACT_SCALE)
				dmg:SetDamageType(ent:IsVehicle() and DMG_VEHICLE or DMG_CRUSH)
				dmg:SetAttacker(IsValid(by) and by or ent)
				dmg:SetInflictor(ent)
				dmg:SetDamagePosition(pos)
				dmg:SetDamageForce(vel * mass)
				self:Forward(dmg, part)
			end
		end
	end
end

local function Prune(list, now)
	for k, v in pairs(list) do
		if v.at < now then list[k] = nil end
	end
end

function Hitbox:Think(now)
	if now < self.next then return end
	self.next = now + SWEEP
	Prune(self.hits, now)
	Prune(self.taken, now)
	for _, part in ipairs(self.parts) do
		if IsValid(part) then
			if part:IsOnFire() then
				part:Extinguish()
				self:Burn()
			end
			self:Bump(part, now)
		end
	end
end

function Hitbox:Clear()
	for k, part in ipairs(self.parts) do
		SafeRemoveEntity(part)
		self.parts[k] = nil
	end
end

hook.Add("EntityTakeDamage", "EvilHitbox", function(ent, dmg)
	local box = ent.EvilHitbox
	if not box then return end
	box:Forward(dmg, ent)
	return true
end)
