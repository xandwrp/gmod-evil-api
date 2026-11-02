local views = {}

function Evil.View(name, active, calc, stop)
	hook.Remove("CalcView", name)
	views[name] = { active = active, calc = calc, stop = stop, on = false }
end

hook.Add("Think", "EvilView", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	for name, v in pairs(views) do
		local on = v.active(ply) and true or false
		if on ~= v.on then
			v.on = on
			if on then
				hook.Add("CalcView", name, v.calc)
			else
				hook.Remove("CalcView", name)
				if v.stop then v.stop() end
			end
		end
	end
end)
