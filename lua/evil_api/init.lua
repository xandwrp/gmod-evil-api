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
end

include("evil_api/sh_settings.lua")
include("evil_api/sh_claim.lua")
include("evil_api/sh_freeze.lua")
if SERVER then
	include("evil_api/sv_down.lua")
else
	include("evil_api/cl_settings.lua")
	include("evil_api/cl_down.lua")
end

Evil.LOADED = true
