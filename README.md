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
- Soul digestion: keep track of how each player gets away from something, and hand it all over once it eats them
- Damage and hitboxes: let a body made of many pieces get hurt by bullets, explosions, fire, props and anything else, through the normal damage hooks, with per kind damage settings
- Stomachs: an append-only list of everything something has eaten, with a context menu to look inside it in game

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

### Soul digestion

Remember what each player did to get away from you, and take it off them when you eat them.

```lua
local souls = Evil.SoulDigestion({ id = "evil_thing", tricks = { slipped = 3, outran = 3, noclip = 30 } })
souls:Watch(ply, "outran")
souls:Watch(ply, "noclip", seconds)
souls:Skill(ply, "outran")
souls:Skills(ply)
souls:Worth(ply)
local learned = souls:Digest(ply)
souls:Forget(ply)
```

- **Tricks:** each one is a name and how much of it a player has to do before they're as good at it as they get.
- **Watching:** `Watch` adds to what that player has done, once a tick per trick however many things see it. `amount` defaults to 1, so count times or seconds, whichever fits.
- **Skill:** `Skill` is how good they are at one trick from 0 to 1, `Skills` gives every trick they've done any of, and `Worth` adds them up.
- **Digesting:** `Digest` returns their skills, or nil if they had none, and wipes the slate so they start over. It takes a player or a profile from `souls:Profile(ply)`, for when you kept the profile and the player is long gone.
- **Per mod:** each `id` keeps its own profiles, so getting away from one evil thing teaches nothing to another. Profiles go by SteamID, so they last through respawns and rejoins until the map changes.
- **Hooks:** `EvilSoulWatched(id, ply, trick, total)`, `EvilSoulDigested(id, who, skills)`.

### Damage and hitboxes

Make something with a body that isn't one solid entity, like a long chain, take damage from everything the way a normal entity does.

```lua
self.Hitbox = Evil.Hitbox(self, { ignite = function(seconds) end })
self.Hitbox:Place(points, radius)
self.Hitbox:Think(CurTime())
self.Hitbox:Clear()
local amount = self.Hitbox:Fresh(dmg)
Evil.HitboxOwner(ent)
```

- **Hitboxes:** `Place` puts invisible server side boxes along a list of points, overlapping so there are no gaps, and moves, resizes, adds or removes them as the points change. `radius` is a number or `function(i)` for the size at point `i`. It caps out at 48 boxes and spreads them out past that.
- **Damage:** anything that hits a box, whether it traces, finds entities in a sphere, explodes or burns, gets passed to the owner as a copy through `TakeDamageInfo`, so other mods' `EntityTakeDamage` hooks see the owner getting hurt and never see the boxes. `owner.EvilStruckPart` is the box that got hit while it runs.
- **Spread damage:** explosions, fire and gas that catch several boxes at once only count once, the biggest hit wins. Call `Fresh` in the owner's `OnTakeDamage` to get the amount to apply, so a blast catching the owner and a box doesn't count twice.
- **Impacts:** physics props and vehicles moving fast through a box hurt the owner with `DMG_CRUSH` or `DMG_VEHICLE`, credited to whoever threw or drove them.
- **Fire:** a box that gets set on fire puts itself out and sets the owner on fire instead, or calls `ignite`.
- **Traces:** boxes are debris, so players, NPCs and props walk through them, but traces hit them. Filter them out of your own traces with `Evil.HitboxOwner`.

```lua
Evil.DAMAGE_KINDS
Evil.DamageKind(dmg)
Evil.DamageRows(defaults, max)
Evil.DamageScale(settings, dmg)
Evil.AreaDamage(dmg)
Evil.Attacker(dmg)
```

- **Kinds:** every damage type falls into explosive, bullet, melee, fire, energy, toxic, crush or other. `DamageKind` says which.
- **Settings:** `DamageRows` gives a settings row per kind named `dmg_<kind>`, to drop into your own rows, and `DamageScale` reads the right one for a hit.
- **Attackers:** `Attacker` sorts who did it into player, npc or world, counting a vehicle's driver as the player.

### Stomachs

Keep a list of everything something has eaten, and let people right click it to see inside.

```lua
self.Stomach = Evil.Stomach(self)
self.Stomach.onDigest = function(v) end
local v = self.Stomach:Eat(victim, { size = 1.2 })
self.Stomach:Add({ kind = "corpse", name = "someone" })
self.Stomach:Settle(v)
self.Stomach:Count()
self.Stomach:Changed()
Evil.Describe(ent)
```

- **Victims:** `Eat` records who they were (name, class, model, SteamID, weapon, health and `kind` as player, npc or thing) plus anything in `extra`, and returns the record. `Add` takes a record you built yourself, like one from `Evil.Describe` you saved while they were still alive. The list only ever grows, each record keeps its place as `v.n`.
- **Digesting:** `Settle` marks a victim digested and calls `onDigest`. Call `Changed` if you rewrite the list so open menus reload it.
- **Menu:** register a view on the client and the owner gets a Stomach option in the context menu. It lists every victim with a model preview and details, and refreshes while it's open.

```lua
Evil.StomachView({
	class = "evil_thing",
	title = "Evil thing stomach",
	top = 96,
	columns = { { "Mass", 50, function(v, view) return ("%.2f"):format(v.mass), v.mass end } },
	refresh = function(view) end,
	summary = function(view, w, h) end,
	info = function(view, v) view:Pair("Mass", ("%.2f"):format(v.mass)) end,
})
```

- **Owner methods:** on the server, `ENT:EvilStomachSummary()` returns a table that reaches the client as `view.summary`, and `ENT:EvilStomachProgress()` returns `{ { n, 0 to 1 }, ... }` for victims still going down.
- **View:** `columns` are `{ name, width, function(v, view) return text, sort end }`. `refresh` runs before every redraw of the rows, `summary` draws below the header line (from y 42), `info` adds lines under the selected victim with `view:Pair(label, value, color)` and `view:Heading(text)`. `view:Share(v)` is how far down a victim is from 0 to 1. Any soul digestion `tricks` on a record show up on their own.
- **Hooks:** `EvilSwallowed(owner, victim)`, `EvilDigested(owner, victim)`.
