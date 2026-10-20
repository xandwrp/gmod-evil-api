Evil.MASH_BINDS = {
	[IN_JUMP] = "+jump", [IN_USE] = "+use", [IN_ATTACK] = "+attack", [IN_ATTACK2] = "+attack2",
	[IN_RELOAD] = "+reload", [IN_DUCK] = "+duck", [IN_SPEED] = "+speed", [IN_WALK] = "+walk",
	[IN_FORWARD] = "+forward", [IN_BACK] = "+back", [IN_MOVELEFT] = "+moveleft", [IN_MOVERIGHT] = "+moveright",
}

local GAIN = 0.1
local DECAY = 0.15
local RATE = 10
local BURST = 3
local SYNC = 0.005

function Evil.Mashing(ply)
	if SERVER then return ply.EvilMash end
	return ply:GetNW2Int("EvilMashKey", 0) ~= 0
end

function Evil.MashInput(ply, cmd)
	local key
	if SERVER then
		key = ply.EvilMash and ply.EvilMash.key or 0
	else
		key = ply:GetNW2Int("EvilMashKey", 0)
	end
	if key == 0 then
		ply.EvilMashHeld = nil
		return
	end
	local down = cmd:KeyDown(key)
	if down and not ply.EvilMashHeld then
		if SERVER then
			Evil.MashPress(ply)
		else
			ply.EvilMashPressed = RealTime()
		end
	end
	ply.EvilMashHeld = down
	if CLIENT then return down and key or nil end
	if ply:GetNW2Bool("EvilMashBlock") then cmd:RemoveKey(key) end
end

hook.Add("StartCommand", "EvilMash", function(ply, cmd)
	if not Evil.Frozen(ply) then Evil.MashInput(ply, cmd) end
end)

if CLIENT then return end

local function Sync(ply, m, force)
	if force or math.abs(m.progress - (m.sent or -1)) > SYNC or m.progress == 0 then
		m.sent = m.progress
		ply:SetNW2Float("EvilMash", m.progress)
	end
end

local function Clear(ply)
	ply.EvilMash = nil
	ply:SetNW2Int("EvilMashKey", 0)
	ply:SetNW2Float("EvilMash", 0)
	ply:SetNW2Float("EvilMashUntil", 0)
end

function Evil.Mash(ply, source, opts)
	if not IsValid(ply) or not ply:IsPlayer() then return end
	opts = opts or {}
	local now = CurTime()
	local m = {
		source = source, key = opts.key or IN_JUMP, gain = opts.gain or GAIN, decay = opts.decay or DECAY,
		rate = opts.rate or RATE, burst = opts.burst or BURST, progress = opts.start or 0,
		deadline = opts.time and now + opts.time, press = opts.press, done = opts.done, fail = opts.fail,
	}
	m.credit, m.pressed = m.burst, now
	ply.EvilMash = m
	ply.EvilMashHeld = true
	ply:SetNW2Int("EvilMashKey", m.key)
	ply:SetNW2Bool("EvilMashBlock", opts.block ~= false)
	ply:SetNW2Bool("EvilMashPrompt", opts.prompt ~= false)
	ply:SetNW2Float("EvilMashStart", now)
	ply:SetNW2Float("EvilMashUntil", m.deadline or 0)
	Sync(ply, m, true)
	return m
end

function Evil.StopMash(ply)
	if IsValid(ply) and ply.EvilMash then Clear(ply) end
end

local function Finish(ply, m, won)
	Clear(ply)
	if won then
		if m.done then m.done(ply, m.source) end
		hook.Run("EvilMashDone", ply, m.source)
	else
		if m.fail then m.fail(ply, m.source) end
		hook.Run("EvilMashFailed", ply, m.source)
	end
end

function Evil.MashPress(ply)
	local m = ply.EvilMash
	if not m then return end
	local now = CurTime()
	local credit = math.min(m.burst, m.credit + (now - m.pressed) * m.rate)
	m.pressed = now
	m.credit = math.max(0, credit - 1)
	if credit < 1 then return end
	m.progress = math.min(1, m.progress + m.gain)
	Sync(ply, m)
	if m.press then m.press(ply, m.progress, m.source) end
	hook.Run("EvilMashed", ply, m.source, m.progress)
	if ply.EvilMash == m and m.progress >= 1 then Finish(ply, m, true) end
end

hook.Add("Think", "EvilMash", function()
	local now, dt = CurTime(), FrameTime()
	for _, ply in ipairs(player.GetAll()) do
		local m = ply.EvilMash
		if m then
			if not ply:Alive() or (m.source ~= nil and not IsValid(m.source)) then
				Clear(ply)
			elseif m.deadline and now >= m.deadline then
				Finish(ply, m, false)
			elseif m.decay > 0 and m.progress > 0 then
				m.progress = math.max(0, m.progress - m.decay * dt)
				Sync(ply, m)
			end
		end
	end
end)

hook.Add("PlayerSpawn", "EvilMash", Evil.StopMash)
