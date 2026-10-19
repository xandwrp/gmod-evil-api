local Settings = Evil.SettingsMeta

local SEND_DELAY = 0.25
local SETTLE = 1
local GAP = 4

local function Send(s, value)
	s.pending = RealTime() + SEND_DELAY + SETTLE
	timer.Create("EvilSetting_" .. s.convar, SEND_DELAY, 1, function()
		if math.abs(GetConVar(s.convar):GetFloat() - value) < 1e-3 then return end
		net.Start("EvilSetting")
		net.WriteString(s.convar)
		net.WriteString(tostring(value))
		net.SendToServer()
	end)
end

local function Settled(s)
	return RealTime() > (s.pending or 0)
end

local function Pack(c)
	return math.Round(c.r) * 65536 + math.Round(c.g) * 256 + math.Round(c.b)
end

local function Admin(control)
	local ply = LocalPlayer()
	local admin = IsValid(ply) and ply:IsSuperAdmin()
	if control:IsEnabled() ~= admin then control:SetEnabled(admin) end
end

function Settings:Presets(panel)
	if #self.presets == 0 then return end
	local row = vgui.Create("DPanel")
	row:SetPaintBackground(false)
	row:SetTall(24)
	panel:AddItem(row)
	local buttons = {}
	for _, preset in ipairs(self.presets) do
		local b = vgui.Create("DButton", row)
		b:SetText(preset.label)
		b.DoClick = function()
			for _, s in ipairs(self.rows) do
				if self:PresetValue(preset, s) then
					s.pending = nil
					timer.Remove("EvilSetting_" .. s.convar)
				end
			end
			RunConsoleCommand(self.id .. "_preset", preset.name)
		end
		b.Think = function(btn)
			Admin(btn)
			local on = self:PresetActive(preset)
			if btn:GetToggle() ~= on then btn:SetToggle(on) end
		end
		buttons[#buttons + 1] = b
	end
	row.PerformLayout = function(_, w, h)
		local bw = (w - GAP * (#buttons - 1)) / #buttons
		for i, b in ipairs(buttons) do
			b:SetPos(math.Round((i - 1) * (bw + GAP)), 0)
			b:SetSize(math.Round(bw), h)
		end
	end
end

function Settings:Row(panel, s)
	local cv = GetConVar(s.convar)
	local control
	if s.color then
		local function Current() return Color(self:Color(s.name)) end
		panel:Help(s.label)
		control = vgui.Create("DColorMixer")
		control:SetAlphaBar(false)
		control:SetTall(180)
		panel:AddItem(control)
		control:SetColor(Current())
		control.ValueChanged = function(_, c) Send(s, Pack(c)) end
		control.Think = function(mixer)
			local ply = LocalPlayer()
			mixer:SetMouseInputEnabled(IsValid(ply) and ply:IsSuperAdmin())
			if Settled(s) and Pack(mixer:GetColor()) ~= cv:GetInt() then mixer:SetColor(Current()) end
		end
	elseif s.max == 1 and not s.decimals then
		control = panel:CheckBox(s.label)
		control:SetChecked(cv:GetBool())
		control.OnChange = function(_, on) Send(s, on and 1 or 0) end
		control.Think = function(box)
			Admin(box)
			if Settled(s) and box:GetChecked() ~= cv:GetBool() then box:SetChecked(cv:GetBool()) end
		end
	else
		control = panel:NumSlider(s.label, nil, s.min, s.max, s.decimals)
		control:SetValue(cv:GetFloat())
		control.OnValueChanged = function(_, value) Send(s, value) end
		control.Think = function(slider)
			Admin(slider)
			if Settled(s) and not slider:IsEditing() and math.abs(slider:GetValue() - cv:GetFloat()) > 1e-3 then
				slider:SetValue(cv:GetFloat())
			end
		end
	end
	if s.help then control:SetTooltip(s.help) end
end

function Settings:Build(panel)
	self:Presets(panel)
	for _, s in ipairs(self.rows) do
		if not s.needs or _G[s.needs] then self:Row(panel, s) end
	end
	if self.reset then
		local reset = panel:Button("Reset to defaults")
		reset.DoClick = function()
			for _, s in ipairs(self.rows) do Send(s, s.default) end
		end
		reset.Think = Admin
	end
	if self.extra then self.extra(panel) end
end

function Settings:Menu()
	hook.Add("PopulateToolMenu", "EvilSettings_" .. self.id, function()
		spawnmenu.AddToolMenuOption(Evil.MENU_TAB, Evil.MENU_CATEGORY, self.id .. "_settings", self.title, "", "", function(panel)
			self:Build(panel)
		end)
	end)
end
