local stores = Evil.SoulStores or {}
Evil.SoulStores = stores

local Souls = {}
Souls.__index = Souls
Evil.Souls = Souls

local function Key(ply)
	return ply:IsBot() and "bot " .. ply:Nick() or ply:SteamID64()
end

function Evil.SoulDigestion(opts)
	local s = stores[opts.id]
	if not s then
		s = setmetatable({ id = opts.id, profiles = {} }, Souls)
		stores[opts.id] = s
	end
	s.tricks = opts.tricks or {}
	return s
end

function Souls:Profile(ply)
	local key = Key(ply)
	local p = self.profiles[key]
	if not p then
		p = { did = {}, at = {} }
		self.profiles[key] = p
	end
	return p
end

local function Of(self, who)
	if istable(who) then return who end
	if IsValid(who) and who:IsPlayer() then return self:Profile(who) end
end

function Souls:Watch(ply, trick, amount)
	if not self.tricks[trick] or not IsValid(ply) or not ply:IsPlayer() then return false end
	local p = self:Profile(ply)
	local now = CurTime()
	if p.at[trick] == now then return false end
	p.at[trick] = now
	p.did[trick] = (p.did[trick] or 0) + (amount or 1)
	hook.Run("EvilSoulWatched", self.id, ply, trick, p.did[trick])
	return true
end

function Souls:Did(who, trick)
	local p = Of(self, who)
	return p and p.did[trick] or 0
end

function Souls:Skill(who, trick)
	local full = self.tricks[trick]
	if not full then return 0 end
	return math.min(1, self:Did(who, trick) / full)
end

function Souls:Skills(who)
	local skills
	for trick in pairs(self.tricks) do
		local k = self:Skill(who, trick)
		if k > 0 then
			skills = skills or {}
			skills[trick] = k
		end
	end
	return skills
end

function Souls:Worth(who)
	local worth = 0
	for trick in pairs(self.tricks) do worth = worth + self:Skill(who, trick) end
	return worth
end

function Souls:Forget(who)
	local p = Of(self, who)
	if not p then return end
	p.did, p.at = {}, {}
end

function Souls:Digest(who)
	local p = Of(self, who)
	if not p then return end
	local skills = self:Skills(p)
	self:Forget(p)
	hook.Run("EvilSoulDigested", self.id, who, skills)
	return skills
end
