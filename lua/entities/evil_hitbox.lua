ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Evil hitbox"
ENT.Spawnable = false
ENT.DoNotDuplicate = true
ENT.DisableDuplicator = true
ENT.PhysgunDisabled = true
ENT.m_tblToolsAllowed = {}

if CLIENT then return end

function ENT:Initialize()
	self:SetModel("models/hunter/blocks/cube025x025x025.mdl")
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	self:DrawShadow(false)
	self:SetNoDraw(true)
end

function ENT:UpdateTransmitState()
	return TRANSMIT_NEVER
end

function ENT:OnTakeDamage(dmg)
	local box = self.EvilHitbox
	if box then box:Forward(dmg, self) end
end
