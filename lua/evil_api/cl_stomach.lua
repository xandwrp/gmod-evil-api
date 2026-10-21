local REFRESH = 0.5
local CATCH_UP = 0.15
local TIMEOUT = 2
local ROW = 16
local FOV = 30
local FIT = 1.08
local TOP_TALL = 48
local MODEL_TALL = { 180, 360 }
local INFO_TALL = 390
local STATUS = 6

local TEXT = Color(230, 230, 230)
local DIM = Color(160, 160, 160)
local BACK = Color(0, 0, 0, 90)

local COLUMNS = { { "#", 40 }, { "Name" }, { "Kind", 80 }, { "Weapon", 100 }, { "Eaten", 64 }, { "Status", 70 } }

local views = Evil.StomachViews or {}
Evil.StomachViews = views

local function Title(s)
	return (s:gsub("_", " "):gsub("^%l", string.upper))
end

local function Phrase(id, prefix)
	local phrase = language.GetPhrase(id)
	if phrase ~= id then return phrase end
	return Title((id:gsub("^" .. prefix, "")))
end

local function Clock(t)
	local s = math.floor(math.max(t, 0))
	return ("%d:%02d:%02d"):format(math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end

local function Status(v, progress)
	if v.digested then return "digested", 2 end
	return ("%d%%"):format(math.floor(progress * 100)), progress
end

local View = {}
View.__index = View
View.Title = Title

local current

function View:Display(v)
	if v.steamid then return v.name end
	return Phrase(v.name or v.class or "?", "npc_")
end

function View:Share(v)
	if v.digested then return 1 end
	return self.progress[v.n] or 0
end

function View:Ask()
	self.nextAsk = RealTime() + TIMEOUT
	local pending = {}
	for n in pairs(self.pending) do pending[#pending + 1] = n end
	local count = math.min(#pending, 255)
	net.Start("EvilStomach")
	net.WriteEntity(self.ent)
	net.WriteUInt(self.rev, 16)
	net.WriteUInt(#self.victims, 16)
	net.WriteUInt(count, 8)
	for i = 1, count do net.WriteUInt(pending[i], 16) end
	net.SendToServer()
end

function View:Think()
	if not IsValid(self.ent) then
		if not self.gone then
			self.gone = true
			self.frame:SetTitle(self.def.title .. " (gone)")
		end
		return
	end
	if RealTime() >= self.nextAsk then self:Ask() end
end

function View:Row(v)
	local cells = { v.n, self:Display(v), Title(v.kind), v.weapon and Phrase(v.weapon, "weapon_") or "", Clock(v.at), "" }
	for _ in ipairs(self.def.columns or {}) do cells[#cells + 1] = "" end
	local line = self.list:AddLine(unpack(cells))
	line.n = v.n
	line.cache = {}
	line:SetSortValue(1, v.n)
	line:SetSortValue(5, v.at)
	self.lines[v.n] = line
end

local function Set(line, col, text, sort)
	if line.cache[col] == text then return end
	line.cache[col] = text
	line:SetColumnText(col, text)
	line:SetSortValue(col, sort)
end

function View:Take(d)
	if d.rev ~= self.rev then
		self.rev = d.rev
		self.victims, self.pending, self.lines = {}, {}, {}
		self.list:Clear()
	end
	for _, v in ipairs(d.victims or {}) do
		if v.n == #self.victims + 1 then
			self.victims[v.n] = v
			if not v.digested then self.pending[v.n] = true end
			self:Row(v)
		end
	end
	for _, u in ipairs(d.updates or {}) do
		if self.victims[u.n] then
			self.victims[u.n] = u
			self.pending[u.n] = nil
		end
	end
	self.progress = {}
	for _, t in ipairs(d.progress or {}) do self.progress[t[1]] = t[2] end
	self.summary, self.count = d.summary, d.count
	self:Contribute()
	self.nextAsk = RealTime() + (#self.victims < d.count and CATCH_UP or REFRESH)
end

function View:Contribute()
	local def = self.def
	if def.refresh then def.refresh(self) end
	local digested, eating = 0, 0
	local kinds = {}
	for n, v in ipairs(self.victims) do
		if v.digested then digested = digested + 1 else eating = eating + 1 end
		kinds[v.kind] = (kinds[v.kind] or 0) + 1
		local line = self.lines[n]
		Set(line, STATUS, Status(v, self:Share(v)))
		for i, c in ipairs(def.columns or {}) do Set(line, STATUS + i, c[3](v, self)) end
	end
	local ate = {}
	for kind, count in SortedPairsByValue(kinds, true) do ate[#ate + 1] = ("%s x%d"):format(Title(kind), count) end
	self.digested, self.eating, self.ate = digested, eating, table.concat(ate, ", ")
end

function View:PaintSummary(w, h)
	draw.RoundedBox(4, 0, 0, w, h, BACK)
	if not self.count then return end
	local loaded = #self.victims
	local head = loaded < self.count and ("%d eaten, loading %d"):format(self.count, loaded)
		or ("%d eaten, %d digested, %d going down"):format(self.count, self.digested, self.eating)
	draw.SimpleText(head, "DermaDefaultBold", 8, 6, TEXT)
	draw.SimpleText(self.ate, "DermaDefault", 8, 24, DIM)
	if self.def.summary and self.summary then self.def.summary(self, w, h) end
end

function View:Pair(label, value, color)
	draw.SimpleText(label, "DermaDefault", 0, self.y, DIM)
	draw.SimpleText(value, "DermaDefault", self.w, self.y, color or TEXT, TEXT_ALIGN_RIGHT)
	self.y = self.y + ROW
end

function View:Heading(text)
	self.y = self.y + 6
	draw.SimpleText(text, "DermaDefaultBold", 0, self.y, TEXT)
	self.y = self.y + ROW
end

function View:PaintInfo(w, h)
	local v = self.selected and self.victims[self.selected]
	if not v then return end
	draw.SimpleText(self:Display(v), "DermaDefaultBold", 0, 0, TEXT)
	self.y, self.w = ROW + 6, w
	self:Pair("Order", "#" .. v.n)
	self:Pair("Kind", Title(v.kind))
	self:Pair("Class", v.class or "")
	if v.steamid then self:Pair("SteamID", v.steamid) end
	if v.weapon then self:Pair("Weapon", Phrase(v.weapon, "weapon_")) end
	if v.health then self:Pair("Health", tostring(v.health)) end
	self:Pair("Eaten at", Clock(v.at))
	if v.digested then
		self:Pair("Digested", ("after %.1fs"):format(v.digested - v.at))
	else
		self:Pair("Going down", (Status(v, self:Share(v))))
	end
	if self.def.info then self.def.info(self, v) end
	if v.tricks and next(v.tricks) then
		self:Heading("Tricks")
		for trick, k in SortedPairs(v.tricks) do self:Pair(Title(trick), ("%.2f"):format(k)) end
	end
end

function View:Fit()
	local panel = self.model
	local e = panel.Entity
	if not IsValid(e) then return end
	local mn, mx = e:GetRenderBounds()
	local center = (mn + mx) * 0.5
	local height = mx.z - mn.z
	local width = math.sqrt((mx.x - mn.x) ^ 2 + (mx.y - mn.y) ^ 2)
	local w, h = math.max(panel:GetWide(), 1), math.max(panel:GetTall(), 1)
	local half = math.tan(math.rad(FOV / 2))
	local dist = math.max(height * 0.5 / (half * math.min(1, h / w)), width * 0.5 / (half * math.min(1, w / h))) * FIT
	panel:SetFOV(FOV)
	panel:SetLookAt(center)
	panel:SetCamPos(center + Vector(dist, 0, dist * 0.1))
end

function View:Select(n)
	self.selected = n
	local v = self.victims[n]
	local panel = self.model
	if not v or not v.model or not util.IsValidModel(v.model) then
		panel:SetVisible(false)
		return
	end
	panel:SetVisible(true)
	panel:SetModel(v.model)
	local e = panel.Entity
	if not IsValid(e) then return end
	local seq = e:LookupSequence("idle_all_01")
	if seq <= 0 then seq = e:SelectWeightedSequence(ACT_IDLE) end
	if seq > 0 then e:ResetSequence(seq) end
	self:Fit()
end

function Evil.StomachView(def)
	views[def.class] = def
end

function Evil.OpenStomach(ent)
	local def = IsValid(ent) and views[ent:GetClass()]
	if not def then return end
	if IsValid(current) then current:Remove() end
	local frame = vgui.Create("DFrame")
	current = frame
	frame:SetTitle(def.title)
	frame:SetSize(math.min(1040, ScrW() - 40), math.min(780, ScrH() - 40))
	frame:SetSizable(true)
	frame:SetMinWidth(720)
	frame:SetMinHeight(480)
	frame:Center()
	frame:MakePopup()

	local view = setmetatable({
		frame = frame, ent = ent, def = def, rev = 0, victims = {}, pending = {}, lines = {}, progress = {}, nextAsk = 0,
	}, View)
	frame.view = view

	local top = frame:Add("DPanel")
	top:Dock(TOP)
	top:SetTall(def.top or TOP_TALL)
	top:DockMargin(0, 0, 0, 4)
	top.Paint = function(_, w, h) view:PaintSummary(w, h) end
	top.Think = function() view:Think() end

	local side = frame:Add("DPanel")
	side:Dock(RIGHT)
	side:SetWide(280)
	side:DockMargin(4, 0, 0, 0)
	side.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, BACK) end

	local model = side:Add("DModelPanel")
	model:Dock(TOP)
	model:SetTall(MODEL_TALL[2])
	model:SetVisible(false)
	model.LayoutEntity = function(p, e)
		e:SetAngles(Angle(0, RealTime() * 30 % 360, 0))
		p:RunAnimation()
	end
	model.PerformLayout = function() view:Fit() end
	view.model = model
	side.PerformLayout = function(_, w, h)
		model:SetTall(math.Clamp(h - INFO_TALL, MODEL_TALL[1], MODEL_TALL[2]))
	end

	local info = side:Add("DPanel")
	info:Dock(FILL)
	info:DockMargin(10, 8, 10, 8)
	info.Paint = function(_, w, h) view:PaintInfo(w, h) end

	local list = frame:Add("DListView")
	list:Dock(FILL)
	list:SetMultiSelect(false)
	local columns = table.Add(table.Copy(COLUMNS), def.columns or {})
	for _, c in ipairs(columns) do
		local col = list:AddColumn(c[1])
		if c[2] then col:SetFixedWidth(c[2]) end
	end
	list.OnRowSelected = function(_, _, line) view:Select(line.n) end
	view.list = list
end

net.Receive("EvilStomach", function()
	local ent = net.ReadEntity()
	local raw = util.Decompress(net.ReadData(net.ReadUInt(32)))
	local data = raw and util.JSONToTable(raw)
	if not data or not IsValid(current) then return end
	local view = current.view
	if view and view.ent == ent then view:Take(data) end
end)

properties.Add("evil_stomach", {
	MenuLabel = "Stomach",
	MenuIcon = "icon16/table.png",
	Order = 1500,
	Filter = function(self, ent, ply)
		return IsValid(ent) and views[ent:GetClass()] ~= nil and gamemode.Call("CanProperty", ply, "evil_stomach", ent) ~= false
	end,
	Action = function(self, ent)
		Evil.OpenStomach(ent)
	end,
})
