local GAP = 0.1
local CHUNK = 64

local Stomach = Evil.StomachMeta or {}
Stomach.__index = Stomach
Evil.StomachMeta = Stomach

local function Name(ent)
	if ent:IsPlayer() then return ent:Nick() end
	if ent:IsRagdoll() then return string.StripExtension(string.GetFileFromFilename(ent:GetModel() or "")) end
	local name = ent:GetName()
	return name ~= "" and name or ent:GetClass()
end

function Evil.Describe(ent)
	local player = ent:IsPlayer()
	local wep = ent.GetActiveWeapon and ent:GetActiveWeapon()
	local health = ent:GetMaxHealth()
	return {
		class = ent:GetClass(), name = Name(ent), model = ent:GetModel(), player = player,
		steamid = player and ent:SteamID64() or nil,
		kind = player and "player" or (ent:IsNPC() or ent:IsNextBot()) and "npc" or "thing",
		weapon = IsValid(wep) and wep:GetClass() or nil, health = health > 0 and health or nil,
	}
end

function Evil.Stomach(owner)
	local st = setmetatable({ owner = owner, victims = {}, rev = 0 }, Stomach)
	owner.EvilStomach = st
	return st
end

function Stomach:Add(v)
	v.n = #self.victims + 1
	v.at = v.at or CurTime()
	v.kind = v.kind or "thing"
	v.digested = v.digested or false
	self.victims[v.n] = v
	hook.Run("EvilSwallowed", self.owner, v)
	return v
end

function Stomach:Eat(ent, extra)
	local v = Evil.Describe(ent)
	for k, x in pairs(extra or {}) do v[k] = x end
	return self:Add(v)
end

function Stomach:Settle(v)
	if v.digested then return end
	v.digested = CurTime()
	if self.onDigest then self.onDigest(v) end
	hook.Run("EvilDigested", self.owner, v)
end

function Stomach:Count()
	return #self.victims
end

function Stomach:Changed()
	self.rev = (self.rev + 1) % 65536
end

util.AddNetworkString("EvilStomach")

local function Plain(x)
	if isnumber(x) then return math.Round(x, 4) end
	if isstring(x) or isbool(x) then return x end
end

local function Record(v)
	local out = {}
	for k, x in pairs(v) do
		if istable(x) then
			local t = {}
			for k2, x2 in pairs(x) do t[k2] = Plain(x2) end
			out[k] = t
		else
			out[k] = Plain(x)
		end
	end
	return out
end

net.Receive("EvilStomach", function(_, ply)
	local ent = net.ReadEntity()
	local rev = net.ReadUInt(16)
	local have = net.ReadUInt(16)
	local pending = {}
	for i = 1, net.ReadUInt(8) do pending[i] = net.ReadUInt(16) end
	local st = IsValid(ent) and ent.EvilStomach
	if not st then return end
	local now = RealTime()
	if now < (ply.EvilStomachAsk or 0) then return end
	ply.EvilStomachAsk = now + GAP

	local victims = st.victims
	if rev ~= st.rev then have, pending = 0, {} end
	have = math.min(have, #victims)

	local fresh = {}
	for n = have + 1, math.min(#victims, have + CHUNK) do fresh[#fresh + 1] = Record(victims[n]) end
	local updates = {}
	for _, n in ipairs(pending) do
		local v = n <= have and victims[n]
		if v and v.digested then updates[#updates + 1] = Record(v) end
	end

	local data = util.Compress(util.TableToJSON({
		rev = st.rev, count = #victims, victims = fresh, updates = updates,
		summary = ent.EvilStomachSummary and ent:EvilStomachSummary() or nil,
		progress = ent.EvilStomachProgress and ent:EvilStomachProgress() or nil,
	}))
	net.Start("EvilStomach")
	net.WriteEntity(ent)
	net.WriteUInt(#data, 16)
	net.WriteData(data, #data)
	net.Send(ply)
end)
