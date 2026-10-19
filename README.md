# Syhgma's Evil API

> My personal API I use across all mods in my Evil* suite.

Every feature of this API is as isolated as possible, and the goal is to make the API as extendable as the mods I hope to build using it.

## Features

- Settings: declare a table of rows and presets, get archived replicated convars, a superadmin-gated spawnmenu panel and a preset command
- Claims and freezing, so mods can hold someone without fighting over them and let them go exactly as they were
- Mash prompts: make a player hammer a key to break free or trigger anything else
- Posing and gripping: hold someone half in a mouth for a cutscene, or drag their ragdoll by the foot
- Presence: one shared source of NPC fear, so anything scared by one evil thing runs from all of them
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

Optional fields: `fill = true` makes presets put anything they leave out back to its default, `reset = false` drops the reset button, and `top` / `extra = function(panel) end` add your own controls above or below the rest. `Evil.AdminOnly` as a control's Think greys it out for anyone but superadmins.

### Claims

One answer to who has someone right now, so mods don't grab each other's victims.

```lua
if Evil.Claim(victim, self) then ... end
Evil.Claim(victim, self, { loose = true, release = function(victim, taker) end })
Evil.Claimable(victim, self)
Evil.Owner(victim)
Evil.Unclaim(victim, self)
```

A `loose` claim can be taken by anyone else, and `release` runs on the old owner's side when that happens. Players lose their claim when they respawn. Hooks: `EvilClaimed(ent, owner)`, `EvilUnclaimed(ent, old, taker)`.

### Freezing

```lua
Evil.Freeze(ent, hide)
Evil.Thaw(ent)
Evil.Frozen(ent)
```

Stops an NPC or player where they are: no thinking, moving, collision, shadow, targeting or weapon. Players can't move, shoot, use, switch weapons, noclip, get in vehicles or pick things up. `hide` also stops them drawing. Thawing puts back exactly what was there before.

### Knockdown

```lua
Evil.Down(ent, push, seconds)
Evil.Up(ent)
Evil.Downed(ent)
```

Ragdolls an NPC or player without killing them. The ragdoll copies their pose, look and velocity plus `push`, and they get up from where it settles once the time is up. Players stay alive with the camera on their ragdoll, damage to the ragdoll goes to them, and if they die it stays as the corpse. A downed body is a loose claim, so another mod can claim it and they get straight up, unless it grips the body instead. Hooks: `EvilDown(ent, ragdoll)`, `EvilUp(ent)`. `evil_down [seconds]` knocks down who you're looking at.

### Mashing

Make a player mash a key to do something, like break free.

```lua
local m = Evil.Mash(ply, self, {
	key = IN_JUMP,
	gain = 0.1,
	decay = 0.15,
	time = 4,
	done = function(ply, source) end,
	fail = function(ply, source) end,
	press = function(ply, progress, source) end,
})
m.decay = 0.4
Evil.StopMash(ply)
Evil.Mashing(ply)
```

Each counted press adds `gain` towards 1 and progress drains by `decay` a second. Presses are capped at `rate` a second with a `burst` of spare ones, so macros don't win. Reaching 1 calls `done`. Running out of `time` calls `fail`, and without a `time` it goes on until you stop it. It also stops if the player dies or respawns, or if `source` stops existing. The returned table can be changed while it runs.

It works while the player is frozen. The key doesn't do its normal thing while mashing unless `block = false`. A prompt shows the player's bound key with a progress bar, unless `prompt = false` or they turn off `evil_mash_prompt`. Hooks: `EvilMashed(ply, source, progress)`, `EvilMashDone(ply, source)`, `EvilMashFailed(ply, source)`.

### Posing and gripping

Take someone you've grabbed and put them where you want, either stiff and animated or as a ragdoll you drag around. Either way the owner entity says where with one method, on whichever realms need it:

```lua
function ENT:EvilPose(victim)
	return pos, ang, clipNormal, clipDist
end
```

```lua
Evil.Pose(victim, self, { act = ACT_BARNACLE_PULL, rate = 1, loop = true })
Evil.Unpose(victim, self)
Evil.Posed(victim)
```

Posing claims and freezes them, plays the sequence or activity, and moves them to `EvilPose` every tick. On the client it draws them wherever the owner's client `EvilPose` says, so it can line up with clientside smoothing, and cuts off everything on the far side of the clip plane if one is given (half in a mouth). A posed player gets a third person camera on themselves. If the owner goes away they're let go where they are. Hooks: `EvilPosed(ent, owner)`, `EvilUnposed(ent, owner)`.

```lua
Evil.Grip(victim, self, { bone = "ValveBiped.Bip01_R_Foot", speed = 600, push = vector })
Evil.LetGo(victim, seconds)
```

Gripping knocks them down if they aren't already, claims the body and pulls that bone towards `EvilPose` with physics while the rest flops along. It never gets up on its own while held. Letting go, or the owner going away, leaves them downed for `seconds` before they get up. Hooks: `EvilGripped(ent, owner, ragdoll)`, `EvilLetGo(ent, owner)`.

### Presence

One source of NPC fear shared by every mod, so something scared by one evil thing runs from all of them.

```lua
Evil.Presence(self, { reach = 400, dread = 4, near = function(self, pos) return point end })
Evil.Absent(self)
Evil.Scare(npc, seconds)
Evil.Frighten(pos, radius, seconds, flee)
Evil.Flee(npc, from)
Evil.Afraid(ent)
Evil.Fear(ent)
```

- **Presences:** register an evil thing as a presence. `near` gives the closest point of it to a position, for things bigger than their origin like a long body or a fungus mat.
- **Running away:** scared NPCs run from the nearest presence they get within `reach` of. The more scared they are, the further out they start running.
- **Dread:** a presence with `dread` scares NPCs that can see it within `reach`, by that many seconds of fear for every second they look. At 0 it only scares NPCs that are already afraid of something.
- **Fear itself:** fear is counted in seconds and adds up to a cap. `Evil.Fear` gives it from 0 to 1.
  - `Scare` adds fear to one NPC or player.
  - `Frighten` scares every NPC in a radius, and with `flee` they all run from that spot straight away.
- **NPC support:** engine NPCs, VJ Base and DrGBase NPCs all run. DrGBase ones are set to fear the presence until they calm down.
- **Settings:** the Evil presence settings panel scales every mod's fear at once and can stop scared NPCs running.
- **Hooks:** `EvilScared(ent, seconds)`, `EvilFled(npc, from, to)`.
