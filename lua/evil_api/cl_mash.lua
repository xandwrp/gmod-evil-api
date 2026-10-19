local KEY_SIZE = { 150, 44 }
local KEY_Y = 0.7
local BAR_SIZE = { 220, 6 }
local BAR_GAP = 14
local PULSE_TIME = 0.12
local SHAKE = 1
local PANIC = 3
local EASE = 15

local BONE = Color(170, 160, 145)
local KEY_BG = Color(10, 8, 9, 200)
local BAR_BG = Color(255, 255, 255, 25)

local cv_prompt = CreateClientConVar("evil_mash_prompt", "1", true, false, "Show the key to mash when something grabs you")

surface.CreateFont("EvilMashKey", { font = "Roboto", size = 26, weight = 800 })

local shown = 0

hook.Add("HUDPaint", "EvilMash", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local key = ply:GetNW2Int("EvilMashKey", 0)
	if key == 0 or not ply:Alive() then
		shown = 0
		return
	end
	if not cv_prompt:GetBool() or not ply:GetNW2Bool("EvilMashPrompt") then return end

	shown = Lerp(math.min(1, FrameTime() * EASE), shown, ply:GetNW2Float("EvilMash", 0))
	local start, deadline = ply:GetNW2Float("EvilMashStart", 0), ply:GetNW2Float("EvilMashUntil", 0)
	local k = deadline > start and math.Clamp((CurTime() - start) / (deadline - start), 0, 1) or 0
	local pulse = math.Clamp(1 - (RealTime() - (ply.EvilMashPressed or 0)) / PULSE_TIME, 0, 1)
	local shake = SHAKE + PANIC * k

	local cx = ScrW() * 0.5 + math.Rand(-shake, shake)
	local cy = ScrH() * KEY_Y + math.Rand(-shake, shake) + 3 * pulse
	local kw, kh = KEY_SIZE[1], KEY_SIZE[2]
	local x, y = cx - kw * 0.5, cy - kh * 0.5

	draw.RoundedBox(6, x, y, kw, kh, KEY_BG)
	local lit = Lerp(pulse, 0, 85)
	local c = Color(math.min(255, BONE.r + lit), math.min(255, BONE.g + lit), math.min(255, BONE.b + lit))
	surface.SetDrawColor(c)
	surface.DrawOutlinedRect(x, y, kw, kh, 2)
	local name = input.LookupBinding(Evil.MASH_BINDS[key] or "+jump") or "?"
	draw.SimpleText(name:upper(), "EvilMashKey", cx, cy, c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local bw, bh = BAR_SIZE[1], BAR_SIZE[2]
	local bx, by = cx - bw * 0.5, y + kh + BAR_GAP
	surface.SetDrawColor(BAR_BG)
	surface.DrawRect(bx, by, bw, bh)
	surface.SetDrawColor(BONE)
	surface.DrawRect(bx, by, bw * math.Clamp(shown, 0, 1), bh)
end)
