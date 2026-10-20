if Evil and Evil.LOADED then return end

Evil = Evil or {}
Evil.VERSION = 1
Evil.MENU_TAB = "Utilities"
Evil.MENU_CATEGORY = "Syhgma's Evil Entities"

if SERVER then
	AddCSLuaFile()
	AddCSLuaFile("evil_api/sh_settings.lua")
	AddCSLuaFile("evil_api/cl_settings.lua")
	AddCSLuaFile("evil_api/sh_claim.lua")
	AddCSLuaFile("evil_api/sh_freeze.lua")
	AddCSLuaFile("evil_api/cl_down.lua")
	AddCSLuaFile("evil_api/sh_mash.lua")
	AddCSLuaFile("evil_api/cl_mash.lua")
	AddCSLuaFile("evil_api/sh_pose.lua")
	AddCSLuaFile("evil_api/cl_pose.lua")
	AddCSLuaFile("evil_api/sh_presence.lua")
	AddCSLuaFile("evil_api/sh_damage.lua")
end

include("evil_api/sh_settings.lua")
if CLIENT then include("evil_api/cl_settings.lua") end
include("evil_api/sh_claim.lua")
include("evil_api/sh_freeze.lua")
include("evil_api/sh_mash.lua")
include("evil_api/sh_pose.lua")
include("evil_api/sh_presence.lua")
include("evil_api/sh_damage.lua")
if SERVER then
	include("evil_api/sv_down.lua")
	include("evil_api/sv_soul.lua")
	include("evil_api/sv_hitbox.lua")
else
	include("evil_api/cl_down.lua")
	include("evil_api/cl_mash.lua")
	include("evil_api/cl_pose.lua")
end

Evil.LOADED = true
