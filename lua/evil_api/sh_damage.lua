Evil.DAMAGE_KINDS = {
	{ name = "explosive", label = "Explosions", bits = bit.bor(DMG_BLAST, DMG_BLAST_SURFACE, DMG_MISSILEDEFENSE) },
	{ name = "bullet", label = "Bullets", bits = bit.bor(DMG_BULLET, DMG_BUCKSHOT, DMG_SNIPER, DMG_AIRBOAT) },
	{ name = "melee", label = "Melee", bits = bit.bor(DMG_CLUB, DMG_SLASH) },
	{ name = "fire", label = "Fire", bits = bit.bor(DMG_BURN, DMG_SLOWBURN) },
	{ name = "energy", label = "Energy and shock", bits = bit.bor(DMG_SHOCK, DMG_ENERGYBEAM, DMG_PLASMA, DMG_DISSOLVE, DMG_SONIC) },
	{ name = "toxic", label = "Acid, poison and radiation",
		bits = bit.bor(DMG_ACID, DMG_POISON, DMG_NERVEGAS, DMG_RADIATION, DMG_PARALYZE, DMG_DROWN) },
	{ name = "crush", label = "Crushing and impacts", bits = bit.bor(DMG_CRUSH, DMG_VEHICLE, DMG_FALL, DMG_PHYSGUN) },
	{ name = "other", label = "Everything else", bits = 0 },
}

local AREA = bit.bor(DMG_BLAST, DMG_BLAST_SURFACE, DMG_BURN, DMG_SLOWBURN, DMG_SHOCK, DMG_SONIC, DMG_ACID, DMG_POISON,
	DMG_NERVEGAS, DMG_RADIATION, DMG_PARALYZE, DMG_DROWN)

function Evil.DamageKind(dmg)
	local t = dmg:GetDamageType()
	for _, k in ipairs(Evil.DAMAGE_KINDS) do
		if bit.band(t, k.bits) ~= 0 then return k.name end
	end
	return "other"
end

function Evil.AreaDamage(dmg)
	return bit.band(dmg:GetDamageType(), AREA) ~= 0
end

function Evil.DamageRows(defaults, max)
	defaults = defaults or {}
	local rows = {}
	for _, k in ipairs(Evil.DAMAGE_KINDS) do
		rows[#rows + 1] = {
			name = "dmg_" .. k.name, default = defaults[k.name] or 1, min = 0, max = max or 5, decimals = 2, label = k.label,
			help = "How much it gets hurt by " .. string.lower(k.label) .. ". At 0 it ignores them",
		}
	end
	return rows
end

function Evil.DamageScale(settings, dmg)
	return settings:Get("dmg_" .. Evil.DamageKind(dmg))
end

function Evil.Attacker(dmg)
	local a = dmg:GetAttacker()
	if not IsValid(a) then return "world", a end
	if a:IsPlayer() then return "player", a end
	if a:IsNPC() or a:IsNextBot() then return "npc", a end
	if a:IsVehicle() and IsValid(a:GetDriver()) then return "player", a:GetDriver() end
	return "world", a
end
