local FLAGS = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)

local Settings = Evil.SettingsMeta or {}
Settings.__index = Settings
Evil.SettingsMeta = Settings

local byConVar = Evil.SettingsByConVar or {}
Evil.SettingsByConVar = byConVar

function Evil.Settings(def)
	local self = setmetatable({
		id = def.id, title = def.title, rows = def.rows, presets = def.presets or {},
		fill = def.fill, reset = def.reset ~= false, top = def.top, extra = def.extra, convars = {},
	}, Settings)
	for _, s in ipairs(self.rows) do
		s.convar = self.id .. "_" .. s.name
		self.convars[s.name] = CreateConVar(s.convar, tostring(s.default), FLAGS, s.help or "", s.min, s.max)
		byConVar[s.convar] = s
	end
	if SERVER then
		self:Commands()
	else
		self:Menu()
	end
	return self
end

function Settings:Get(name)
	return self.convars[name]:GetFloat()
end

function Settings:Color(name)
	local v = self.convars[name]:GetInt()
	return bit.rshift(v, 16), bit.band(bit.rshift(v, 8), 255), bit.band(v, 255)
end

function Settings:Find(name)
	for _, preset in ipairs(self.presets) do
		if preset.name == name then return preset end
	end
end

function Settings:PresetValue(preset, s)
	local v = preset.values[s.name]
	if v == nil and self.fill and not s.keep then v = s.default end
	return v
end

function Settings:PresetActive(preset)
	for _, s in ipairs(self.rows) do
		local v = self:PresetValue(preset, s)
		if v and math.abs(self.convars[s.name]:GetFloat() - v) > 1e-3 then return false end
	end
	return true
end

if CLIENT then return end

util.AddNetworkString("EvilSetting")

net.Receive("EvilSetting", function(_, ply)
	local s = byConVar[net.ReadString()]
	local value = tonumber(net.ReadString())
	if not s or not value or not IsValid(ply) or not ply:IsSuperAdmin() then return end
	RunConsoleCommand(s.convar, tostring(math.Clamp(value, s.min, s.max)))
end)

function Settings:Commands()
	if #self.presets == 0 then return end
	local cmd = self.id .. "_preset"
	local names = {}
	for _, preset in ipairs(self.presets) do names[#names + 1] = preset.name end
	concommand.Add(cmd, function(ply, _, args)
		if IsValid(ply) and not ply:IsSuperAdmin() then return end
		local preset = self:Find(string.lower(args[1] or ""))
		if preset then
			for _, s in ipairs(self.rows) do
				local v = self:PresetValue(preset, s)
				if v then RunConsoleCommand(s.convar, tostring(v)) end
			end
			return
		end
		local msg = cmd .. " " .. table.concat(names, "|")
		if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
	end, function(c)
		local list = {}
		for _, name in ipairs(names) do list[#list + 1] = c .. " " .. name end
		return list
	end, "Apply a preset: " .. table.concat(names, "|"))
end
