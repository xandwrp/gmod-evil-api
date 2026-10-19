if Evil and Evil.LOADED then return end

Evil = Evil or {}
Evil.VERSION = 1
Evil.MENU_TAB = "Utilities"
Evil.MENU_CATEGORY = "Syhgma's Evil Entities"

if SERVER then
	AddCSLuaFile()
	AddCSLuaFile("evil_api/sh_settings.lua")
	AddCSLuaFile("evil_api/cl_settings.lua")
end

include("evil_api/sh_settings.lua")
if CLIENT then include("evil_api/cl_settings.lua") end

Evil.LOADED = true
