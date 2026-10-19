# Syhgma's Evil API

> My personal API I use across all mods in my Evil* suite.

Every feature of this API is as isolated as possible, and the goal is to make the API as extendable as the mods I hope to build using it.

## Features

- Settings: declare a table of rows and presets, get archived replicated convars, a superadmin-gated spawnmenu panel and a preset command
- An easy way to ragdoll somebody without killing them, and let them stand back up from where they rest at any time
- Procedural mesh helpers for building dynamic runtime bodies
- A hackable stomach API that maintains an append-only list of previously-consumed entities, which can be used to drive all sorts of cool behavioral systems based on victim composition, including a reusable context menu plugin to visualize the contents of an entity's stomach in-game

## Using it

Include it at the top of your mod's autorun:

```lua
if not file.Exists("evil_api/init.lua", "LUA") then return ErrorNoHalt("My mod needs Syhgma's Evil API\n") end
include("evil_api/init.lua")
```

### Settings

```lua
local settings = Evil.Settings({
	id = "evil_thing",
	title = "Evil thing",
	rows = {
		{ name = "speed", default = 100, min = 0, max = 500, decimals = 0, label = "Speed", help = "How fast it goes" },
		{ name = "hunts", default = 1, min = 0, max = 1, label = "Hunts" },
		{ name = "color", default = 9858664, min = 0, max = 16777215, color = true, label = "Colour" },
		{ name = "carried", default = 1, min = 0, max = 1, label = "Carried", needs = "EvilCrawler" },
	},
	presets = {
		{ name = "chill", label = "Chill", values = { speed = 40 } },
	},
})

settings:Get("speed")
settings:Color("color")
```

Each row becomes the convar `<id>_<name>`. A max of 1 with no decimals is a checkbox, `color` is a colour mixer, anything else is a slider. `needs` hides the row unless that global exists.

Optional fields: `fill = true` makes presets put anything they leave out back to its default, `reset = false` drops the reset button, and `top` / `extra = function(panel) end` add your own controls above or below the rest.
