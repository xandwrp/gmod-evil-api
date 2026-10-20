Evil.PresenceSettings = Evil.Settings({
	id = "evil_presence", title = "Evil presence",
	rows = {
		{ name = "fear", default = 1, min = 0, max = 5, decimals = 2, label = "NPC fear",
			help = "How easily NPCs get scared of anything evil, and how long it stays with them. At 0 nothing scares them" },
		{ name = "flee", default = 1, min = 0, max = 1, label = "Scared NPCs run",
			help = "Scared NPCs run from anything evil that gets close. At 0 they stay put but still remember being scared" },
	},
})

if CLIENT then return end

local UPDATE = 0.5
local FULL = 90
local FLEE_DIST = 400
local FLEE_AGAIN = 1.5
local SHY = 0.5
local DREAD_SIGHT = 3000
local COWED_PRIORITY = 3

local presences = Evil.Presences or {}
Evil.Presences = presences
local afraid = Evil.Afraids or {}
Evil.Afraids = afraid

local function Setting(name)
	return Evil.PresenceSettings:Get(name)
end

local function Creature(ent)
	return IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) and ent:GetClass() ~= "npc_bullseye"
end

local function Busy(ent)
	return Evil.Owner(ent) ~= nil or ent:IsEFlagSet(EFL_NO_THINK_FUNCTION) or ent:Health() <= 0
end

function Evil.Presence(ent, opts)
	opts = opts or {}
	presences[ent] = {
		reach = opts.reach or 500, dread = opts.dread or 0, near = opts.near, target = opts.target,
	}
end

function Evil.Absent(ent)
	presences[ent] = nil
end

function Evil.Afraid(ent)
	return IsValid(ent) and CurTime() < (ent.EvilFearUntil or 0)
end

function Evil.Fear(ent)
	if not IsValid(ent) then return 0 end
	return math.Clamp(((ent.EvilFearUntil or 0) - CurTime()) / FULL, 0, 1)
end

function Evil.Scare(ent, seconds)
	if not IsValid(ent) or (not Creature(ent) and not ent:IsPlayer()) then return end
	seconds = seconds * Setting("fear")
	if seconds <= 0 then return end
	local now = CurTime()
	ent.EvilFearUntil = math.min(math.max(ent.EvilFearUntil or 0, now) + seconds, now + FULL * Setting("fear"))
	afraid[ent] = true
	hook.Run("EvilScared", ent, seconds)
end

local function Point(p, ent, pos)
	if p.near then return p.near(ent, pos) end
	return ent:GetPos()
end

local function Cow(npc, p, ent)
	if not npc.IsDrGNextbot or not npc.SetEntityRelationship then return end
	local target = IsValid(p.target) and p.target or ent
	npc.EvilCowed = npc.EvilCowed or {}
	if npc.EvilCowed[target] then return end
	npc.EvilCowed[target] = true
	npc:SetEntityRelationship(target, D_FR, COWED_PRIORITY)
end

local function Calm(npc)
	local cowed = npc.EvilCowed
	npc.EvilCowed = nil
	if not cowed or not npc.SetEntityRelationship then return end
	for target in pairs(cowed) do
		if IsValid(target) then npc:SetEntityRelationship(target, D_NU, 1) end
	end
end

local function Run(npc, from, now)
	npc.EvilFleeAt = now + FLEE_AGAIN
	local pos = npc:GetPos()
	local away = pos - from
	away.z = 0
	if away:LengthSqr() < 1 then
		away = VectorRand()
		away.z = 0
	end
	away:Normalize()
	local to = pos + away * FLEE_DIST
	if npc.IsVJBaseSNPC then
		npc:SetEnemy(NULL)
		npc.TakingCoverT = now + FLEE_AGAIN
		npc:SetLastPosition(to)
		if npc.SCHEDULE_GOTO_POSITION then
			npc:SCHEDULE_GOTO_POSITION("TASK_RUN_PATH")
		elseif npc.SCHEDULE_COVER_ORIGIN then
			npc:SCHEDULE_COVER_ORIGIN("TASK_RUN_PATH")
		end
	elseif npc:IsNPC() then
		npc:SetLastPosition(to)
		npc:SetSchedule(SCHED_FORCED_GO_RUN)
	end
	hook.Run("EvilFled", npc, from, to)
end

function Evil.Flee(npc, from)
	if not Creature(npc) or Busy(npc) then return end
	Run(npc, from, CurTime())
end

function Evil.Frighten(pos, radius, seconds, flee)
	local r2 = radius * radius
	for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
		if Creature(ent) and ent:GetPos():DistToSqr(pos) <= r2 and not Busy(ent) then
			Evil.Scare(ent, seconds)
			if flee and Setting("flee") > 0 and Evil.Afraid(ent) then Run(ent, pos, CurTime()) end
		end
	end
end

local function Sees(npc, ent, point)
	local tr = util.TraceLine({
		start = npc:EyePos(), endpos = point, mask = MASK_BLOCKLOS,
		filter = function(e) return e ~= npc and e ~= ent and e.EvilHitboxOwner ~= ent end,
	})
	return not tr.Hit
end

local function Dread(dt)
	for ent, p in pairs(presences) do
		if not IsValid(ent) then
			presences[ent] = nil
		elseif p.dread > 0 then
			for _, npc in ipairs(ents.FindInSphere(ent:GetPos(), DREAD_SIGHT)) do
				if Creature(npc) and npc ~= ent and not Busy(npc) then
					local pos = npc:GetPos()
					local point = Point(p, ent, pos)
					if point and pos:Distance(point) <= p.reach and Sees(npc, ent, point) then
						Evil.Scare(npc, p.dread * dt)
					end
				end
			end
		end
	end
end

local function Nearest(npc, fear)
	local pos = npc:GetPos()
	local best, bestDist, bestP, bestEnt
	for ent, p in pairs(presences) do
		if IsValid(ent) and ent ~= npc then
			local point = Point(p, ent, pos)
			if point then
				local d = pos:Distance(point)
				if d <= p.reach * Lerp(fear, SHY, 1) and (not bestDist or d < bestDist) then
					best, bestDist, bestP, bestEnt = point, d, p, ent
				end
			end
		end
	end
	return best, bestP, bestEnt
end

local function Scatter(now)
	local flee = Setting("flee") > 0
	for ent in pairs(afraid) do
		if not IsValid(ent) or (ent:IsPlayer() and not ent:Alive()) then
			afraid[ent] = nil
		elseif now >= (ent.EvilFearUntil or 0) then
			afraid[ent] = nil
			Calm(ent)
		elseif flee and Creature(ent) and not Busy(ent) and now >= (ent.EvilFleeAt or 0) then
			local from, p, source = Nearest(ent, Evil.Fear(ent))
			if from then
				Cow(ent, p, source)
				Run(ent, from, now)
			end
		end
	end
end

local nextUpdate = 0

hook.Add("Think", "EvilPresence", function()
	local now = CurTime()
	if now < nextUpdate then return end
	nextUpdate = now + UPDATE
	if Setting("fear") <= 0 then return end
	Dread(UPDATE)
	Scatter(now)
end)

hook.Add("EntityRemoved", "EvilPresence", function(ent)
	presences[ent] = nil
	afraid[ent] = nil
end)

hook.Add("PlayerSpawn", "EvilPresence", function(ply)
	ply.EvilFearUntil = nil
	afraid[ply] = nil
end)
